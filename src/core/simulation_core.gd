class_name SimulationCore
extends RefCounted

const MAX_TURNS           := 1500
const STRATEGY_TIMEOUT_MS := 50
const DEFAULT_STARTING_AZN := 150

var _map: MapData
var _pathfinder: GridPathfinder
var _strategy_paths: Array
var _rng: RandomNumberGenerator

# Runtime state
var _bots: Array               = []  # Array[NanoBotData]
var _next_bot_id: int          = 0
var _player_count: int         = 0
var _scores: Dictionary        = {}  # player_id -> int
var _nano_ai_alive: Dictionary = {}  # player_id -> bool
var _player_azn_bank: Dictionary = {} # player_id -> int (collected AZN available for builds)
var _azn_nodes: Array          = []  # Array[{position, quantity}]
var _habitas_state: Array      = []  # Array[{position, owner, azn_stored}]
var _strategies: Array         = []  # Array[NanoStrategy | null]
var _strategies_loaded: bool   = false  # true after preload_strategies()

func _init(map: MapData, strategy_paths: Array, seed: int = 0) -> void:
	_map            = map
	_strategy_paths = strategy_paths
	_pathfinder     = GridPathfinder.new(map)
	_rng            = RandomNumberGenerator.new()
	_rng.seed       = seed
	_player_count   = maxi(strategy_paths.size(), 2)

# Call from the main thread before run() to load strategy scripts safely.
func preload_strategies() -> void:
	if not _strategies_loaded:
		_load_strategies()

func run() -> MatchLog:
	var log           := MatchLog.new()
	log.map_name       = _map.map_name
	log.player_strategies = _strategy_paths.duplicate()

	_init_match_state()

	var last_turn := MAX_TURNS
	for turn in range(1, MAX_TURNS + 1):
		var events: Array = []

		_decrement_timers()
		_advance_movement(events)
		_call_strategies(turn)
		_apply_action_queues(events)
		_resolve_attacks(events)
		_tick_auto_destruct(events)
		_check_nano_ai_deaths()
		_update_scores()

		log.record_frame(turn, _scores.duplicate(), _bots, _azn_nodes, _habitas_state, events)

		if _check_end_conditions():
			last_turn = turn
			break

	log.total_turns  = last_turn
	log.final_scores = _scores.duplicate()
	log.winner_id    = _determine_winner()
	return log

# ─── initialisation ──────────────────────────────────────────────────────────

func _init_match_state() -> void:
	var starting_azn: int = _map.azn_nodes.size()  # fallback
	# Maps may declare a starting AZN value; default is DEFAULT_STARTING_AZN.
	starting_azn = DEFAULT_STARTING_AZN

	_azn_nodes = _map.azn_nodes.map(
		func(n: Dictionary) -> Dictionary:
			return { "position": n["position"], "quantity": n["quantity"] }
	)
	_habitas_state = _map.habitas_points.map(
		func(pos: Vector2i) -> Dictionary:
			return { "position": pos, "owner": -1, "azn_stored": 0 }
	)

	if not _strategies_loaded:
		_load_strategies()

	for player_id in _player_count:
		_scores[player_id]        = 0
		_nano_ai_alive[player_id] = true
		_player_azn_bank[player_id] = starting_azn

		var spawn := _choose_injection_point(player_id)
		var stats := BotTypeRegistry.get_type("NanoAI")
		var bot   := NanoBotData.new(_next_bot_id, player_id, "NanoAI", spawn, stats)
		_next_bot_id += 1
		_bots.append(bot)

func _load_strategies() -> void:
	_strategies_loaded = true
	_strategies.clear()
	for path: String in _strategy_paths:
		if path.is_empty():
			_strategies.append(null)
			continue
		if not FileAccess.file_exists(path):
			push_error("SimulationCore: strategy file not found: %s" % path)
			_strategies.append(null)
			continue
		var script := load(path) as GDScript
		if script == null or not script.can_instantiate():
			push_error("SimulationCore: failed to load/compile strategy: %s" % path)
			_strategies.append(null)
			continue
		var instance = script.new()
		if not (instance is NanoStrategy):
			push_error("SimulationCore: strategy does not extend NanoStrategy: %s" % path)
			_strategies.append(null)
			continue
		_strategies.append(instance)

	# Pad to _player_count with nulls (covers the >= 2 player guarantee).
	while _strategies.size() < _player_count:
		_strategies.append(null)

func _choose_injection_point(player_id: int) -> Vector2i:
	var default_point := _default_injection_point(player_id)
	var strategy: NanoStrategy = _strategies[player_id] if player_id < _strategies.size() else null
	if strategy == null:
		return default_point
	# Build a turn-0 MapInfo for the strategy to inspect the map.
	var map_info := _build_map_info(player_id, 0)
	var chosen   := strategy.choose_injection_point(map_info)
	# Validate the chosen point is inside the player's injection zone.
	for zone: Dictionary in _map.injection_zones:
		if zone["player"] == player_id:
			var r: Rect2i = zone["rect"]
			if r.has_point(chosen) and _map.is_passable(chosen.x, chosen.y):
				return chosen
	return default_point

func _default_injection_point(player_id: int) -> Vector2i:
	for zone: Dictionary in _map.injection_zones:
		if zone["player"] == player_id:
			return (zone["rect"] as Rect2i).position
	var corners := [
		Vector2i(0, 0),
		Vector2i(_map.width - 1, _map.height - 1),
		Vector2i(_map.width - 1, 0),
		Vector2i(0, _map.height - 1),
	]
	return corners[player_id % corners.size()]

# ─── per-turn phases ──────────────────────────────────────────────────────────

func _decrement_timers() -> void:
	for bot: NanoBotData in _bots:
		if not bot.is_alive:
			continue
		if bot.turns_until_move > 0:
			bot.turns_until_move -= 1
		if bot.auto_destruct_countdown > 0:
			bot.auto_destruct_countdown -= 1

func _advance_movement(events: Array) -> void:
	for bot: NanoBotData in _bots:
		if not bot.is_alive or bot.is_stationary:
			continue
		if bot.turns_until_move > 0 or bot.path_remaining.is_empty():
			continue

		var next_cell: Vector2i = bot.path_remaining[0]
		bot.path_remaining.remove_at(0)

		# Check for dynamic blockers (NanoWall / NanoBlocker) from enemies.
		var wall_here := _find_enemy_wall(next_cell, bot.owner_id)
		if wall_here != null or not _map.is_passable(next_cell.x, next_cell.y):
			bot.path_remaining.clear()
			events.append({ "type": "path_blocked", "bot_id": bot.id, "at": [next_cell.x, next_cell.y] })
			continue

		var cost := _map.movement_cost(bot.position, next_cell)
		if not bot.density_immune:
			# Add NanoBlocker traversal penalty if an enemy blocker is adjacent.
			var blocker := _find_enemy_blocker(next_cell, bot.owner_id)
			if blocker != null:
				cost += blocker.traversal_penalty
		bot.position       = next_cell
		bot.turns_until_move = cost  # decrement runs before movement, so store full cost

func _call_strategies(turn: int) -> void:
	for player_id in _player_count:
		if not _nano_ai_alive.get(player_id, false):
			continue  # NanoAI dead — no new orders for this player
		var strategy: NanoStrategy = _strategies[player_id]
		if strategy == null:
			continue
		var map_info := _build_map_info(player_id, turn)
		var proxies  := _build_proxies(player_id)
		var t_start  := Time.get_ticks_msec()
		strategy.what_to_do_next(map_info, proxies)
		if Time.get_ticks_msec() - t_start > STRATEGY_TIMEOUT_MS:
			push_warning("Player %d: strategy exceeded %d ms — turn forfeited" % [player_id, STRATEGY_TIMEOUT_MS])
			continue  # discard queued actions
		_flush_proxies(proxies)

func _apply_action_queues(events: Array) -> void:
	for bot: NanoBotData in _bots:
		if not bot.is_alive or bot.pending_action == null:
			continue
		var action := bot.pending_action
		bot.pending_action = null
		_execute_action(bot, action, events)

func _resolve_attacks(events: Array) -> void:
	for bot: NanoBotData in _bots:
		if not bot.is_alive or bot.pending_action == null:
			continue
		if bot.pending_action.action_type != ActionRequest.Type.DEFEND:
			continue
		var action := bot.pending_action
		bot.pending_action = null  # consume — DEFEND is a one-shot action per turn
		var stats      := BotTypeRegistry.get_type(bot.type)
		var max_damage := int(stats.get("max_damage", 0))
		var atk_range  := float(stats.get("attack_range", 0.0))
		if max_damage == 0:
			continue
		var target_pos := action.target_position
		if Vector2(bot.position).distance_to(Vector2(target_pos)) > atk_range:
			continue
		for target: NanoBotData in _bots:
			if target.owner_id != bot.owner_id and target.is_alive and target.position == target_pos:
				var dmg := _rng.randi_range(1, max_damage)
				target.take_damage(dmg)
				events.append({ "type": "attack", "attacker": bot.id, "target": target.id, "damage": dmg })
				break

func _tick_auto_destruct(events: Array) -> void:
	for bot: NanoBotData in _bots:
		if bot.is_alive and bot.auto_destruct_countdown == 0:
			bot.is_alive = false
			events.append({ "type": "auto_destruct", "bot_id": bot.id, "owner": bot.owner_id })

func _check_nano_ai_deaths() -> void:
	for bot: NanoBotData in _bots:
		if bot.type == "NanoAI" and not bot.is_alive:
			if _nano_ai_alive.get(bot.owner_id, true):
				_nano_ai_alive[bot.owner_id] = false

func _update_scores() -> void:
	# Reset habitas ownership, then re-derive from alive NanoNeedle bots.
	for hp: Dictionary in _habitas_state:
		hp["owner"]     = -1
		hp["azn_stored"] = 0

	for bot: NanoBotData in _bots:
		if bot.type != "NanoNeedle" or not bot.is_alive:
			continue
		for hp: Dictionary in _habitas_state:
			if hp["position"] == bot.position:
				hp["owner"]      = bot.owner_id
				hp["azn_stored"] = bot.azn_carried
				break

	for pid in _player_count:
		_scores[pid] = 0
	for hp: Dictionary in _habitas_state:
		if hp["owner"] == -1:
			continue
		var owner: int = hp["owner"]
		var azn: int   = hp["azn_stored"]
		_scores[owner] += (20 + 2 * azn) if azn > 0 else 5

func _check_end_conditions() -> bool:
	var living := 0
	for pid in _player_count:
		for bot: NanoBotData in _bots:
			if bot.owner_id == pid and bot.is_alive:
				living += 1
				break
	return living <= 1

func _determine_winner() -> int:
	var best_id    := 0
	var best_score := -1
	for pid: int in _scores:
		if _scores[pid] > best_score:
			best_score = _scores[pid]
			best_id    = pid
	return best_id

# ─── action handlers ─────────────────────────────────────────────────────────

func _execute_action(bot: NanoBotData, action: ActionRequest, events: Array) -> void:
	match action.action_type:
		ActionRequest.Type.MOVE:
			_action_move(bot, action, events)
		ActionRequest.Type.COLLECT:
			_action_collect(bot, action, events)
		ActionRequest.Type.TRANSFER:
			_action_transfer(bot, action, events)
		ActionRequest.Type.BUILD:
			_action_build(bot, action, events)
		ActionRequest.Type.OPEN_IP:
			_action_open_ip(bot, events)
		ActionRequest.Type.STOP:
			bot.path_remaining.clear()
		ActionRequest.Type.SELF_DESTRUCT:
			bot.is_alive = false
			events.append({ "type": "self_destruct", "bot_id": bot.id })
		ActionRequest.Type.DEFEND:
			# Re-attach so _resolve_attacks can find it; that phase clears it.
			bot.pending_action = action

func _action_move(bot: NanoBotData, action: ActionRequest, events: Array) -> void:
	if bot.is_stationary:
		return
	var target := action.target_position
	if bot.position == target:
		bot.path_remaining.clear()
		bot.cached_target = target
		return
	# Reuse cached path when target hasn't changed and path is still valid.
	if target == bot.cached_target and not bot.path_remaining.is_empty():
		return
	var path := _pathfinder.find_path(bot.position, target)
	if path.size() <= 1:
		return  # no path or already there
	bot.path_remaining = path.slice(1)
	bot.cached_target  = target

func _action_collect(bot: NanoBotData, action: ActionRequest, events: Array) -> void:
	var stats    := BotTypeRegistry.get_type(bot.type)
	var capacity := int(stats.get("capacity", 0))
	var rate     := int(stats.get("transfer", 0))
	if capacity == 0 or rate == 0:
		return
	for node: Dictionary in _azn_nodes:
		if node["position"] != action.target_position:
			continue
		if bot.position != action.target_position:
			return  # bot must be on the node
		var room   := capacity - bot.azn_carried
		var amount := mini(mini(rate, room), int(node["quantity"]))
		if amount <= 0:
			return
		bot.azn_carried   += amount
		node["quantity"]  -= amount
		events.append({ "type": "azn_collected", "bot_id": bot.id, "amount": amount,
			"node": [action.target_position.x, action.target_position.y] })
		return

func _action_transfer(bot: NanoBotData, action: ActionRequest, events: Array) -> void:
	if bot.azn_carried == 0:
		return
	var stats := BotTypeRegistry.get_type(bot.type)
	var rate  := int(stats.get("transfer", 0))
	if rate == 0:
		return

	# Case 1: transfer to a friendly NanoNeedle at target position.
	for target: NanoBotData in _bots:
		if target.type != "NanoNeedle" or not target.is_alive:
			continue
		if target.owner_id != bot.owner_id or target.position != action.target_position:
			continue
		if bot.position != action.target_position:
			return  # must be on same cell
		var needle_stats := BotTypeRegistry.get_type("NanoNeedle")
		var cap          := int(needle_stats.get("capacity", 100))
		var room         := cap - target.azn_carried
		var amount       := mini(mini(rate, bot.azn_carried), room)
		bot.azn_carried    -= amount
		target.azn_carried += amount
		events.append({ "type": "azn_transferred", "from": bot.id, "to": target.id, "amount": amount })
		return

	# Case 2: transfer to player AZN bank (bot is at one of the player's injection points).
	if _is_at_injection_point(bot):
		var amount := mini(rate, bot.azn_carried)
		bot.azn_carried -= amount
		_player_azn_bank[bot.owner_id] = _player_azn_bank.get(bot.owner_id, 0) + amount
		events.append({ "type": "azn_banked", "player": bot.owner_id, "amount": amount })

func _action_build(bot: NanoBotData, action: ActionRequest, events: Array) -> void:
	if bot.type != "NanoAI":
		events.append({ "type": "build_failed", "bot_id": bot.id, "reason": "only_nano_ai_can_build" })
		return
	if not BotTypeRegistry.is_valid_type(action.build_type):
		events.append({ "type": "build_failed", "bot_id": bot.id, "reason": "unknown_type" })
		return
	# Target must be adjacent (Manhattan distance == 1) and passable.
	var dist: int = abs(action.target_position.x - bot.position.x) + \
				abs(action.target_position.y - bot.position.y)
	if dist != 1 or not _map.is_passable(action.target_position.x, action.target_position.y):
		events.append({ "type": "build_failed", "bot_id": bot.id, "reason": "invalid_position" })
		return
	var new_stats := BotTypeRegistry.get_type(action.build_type)
	var cost      := int(new_stats.get("build_cost", 0))
	var bank: int = _player_azn_bank.get(bot.owner_id, 0)
	if bank < cost:
		events.append({ "type": "build_failed", "bot_id": bot.id, "reason": "insufficient_azn",
			"have": bank, "need": cost })
		return
	_player_azn_bank[bot.owner_id] = bank - cost
	var new_bot := spawn_bot(bot.owner_id, action.build_type, action.target_position)
	events.append({ "type": "bot_built", "builder": bot.id, "new_bot": new_bot.id,
		"type_name": action.build_type, "cost": cost })

func _action_open_ip(bot: NanoBotData, events: Array) -> void:
	if bot.type != "NanoIPCreator":
		return
	# Register position as a new injection point for this player.
	# The NanoIPCreator will auto-destruct via its countdown.
	events.append({ "type": "injection_point_created",
		"player": bot.owner_id, "pos": [bot.position.x, bot.position.y] })

# ─── helpers ─────────────────────────────────────────────────────────────────

func _build_map_info(player_id: int, turn: int) -> MapInfo:
	return MapInfo.build(
		_map, turn, _habitas_state, _azn_nodes, _bots,
		player_id, _player_azn_bank.get(player_id, 0)
	)

func _build_proxies(player_id: int) -> Array:
	var proxies: Array = []
	for bot: NanoBotData in _bots:
		if bot.owner_id == player_id and bot.is_alive:
			proxies.append(BotProxy.new(bot))
	return proxies

func _flush_proxies(proxies: Array) -> void:
	for proxy: BotProxy in proxies:
		var action := proxy.flush_action()
		if action != null:
			proxy._bot.pending_action = action

func _find_enemy_wall(cell: Vector2i, owner_id: int) -> NanoBotData:
	for bot: NanoBotData in _bots:
		if bot.type == "NanoWall" and bot.is_alive and bot.owner_id != owner_id:
			if bot.position == cell:
				return bot
	return null

func _find_enemy_blocker(cell: Vector2i, owner_id: int) -> NanoBotData:
	for bot: NanoBotData in _bots:
		if bot.type == "NanoBlocker" and bot.is_alive and bot.owner_id != owner_id:
			if bot.position == cell:
				return bot
	return null

func _is_at_injection_point(bot: NanoBotData) -> bool:
	for zone: Dictionary in _map.injection_zones:
		if zone["player"] == bot.owner_id:
			var r: Rect2i = zone["rect"]
			if r.has_point(bot.position):
				return true
	return false

# Public: spawn a new bot (used internally for BUILD; also callable from tests).
func spawn_bot(owner_id: int, bot_type: String, position: Vector2i) -> NanoBotData:
	var stats := BotTypeRegistry.get_type(bot_type)
	if stats.is_empty():
		push_error("SimulationCore: unknown bot type '%s'" % bot_type)
		return null
	var bot := NanoBotData.new(_next_bot_id, owner_id, bot_type, position, stats)
	_next_bot_id += 1
	_bots.append(bot)
	return bot

func get_pathfinder() -> GridPathfinder:
	return _pathfinder

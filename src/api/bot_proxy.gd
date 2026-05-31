class_name BotProxy
extends RefCounted

# Read-only snapshot of this bot's state for the current turn.
var id: int
var type: String
var position: Vector2i
var hp: int
var max_hp: int
var azn: int
var is_alive: bool
var is_moving: bool   # true if mid-step (turns_until_move > 0)
var has_path: bool    # true if a path is queued

# Internal — not accessible to participant code by convention.
var _bot: NanoBotData
var _queued_action: ActionRequest = null

func _init(bot: NanoBotData) -> void:
	_bot = bot
	_sync()

func _sync() -> void:
	id         = _bot.id
	type       = _bot.type
	position   = _bot.position
	hp         = _bot.hp
	max_hp     = _bot.max_hp
	azn        = _bot.azn_carried
	is_alive   = _bot.is_alive
	is_moving  = _bot.turns_until_move > 0
	has_path   = not _bot.path_remaining.is_empty()

# --- action queue ---
# Calling more than one action method per turn: last call wins.

func move_to(target: Vector2i) -> void:
	_queued_action = ActionRequest.move(target)

func collect_from(source_position: Vector2i) -> void:
	_queued_action = ActionRequest.collect(source_position)

func transfer_to(target_position: Vector2i) -> void:
	_queued_action = ActionRequest.transfer(target_position)

func defend(enemy_position: Vector2i) -> void:
	_queued_action = ActionRequest.defend(enemy_position)

func build(bot_type: String, at_position: Vector2i) -> void:
	_queued_action = ActionRequest.build(bot_type, at_position)

func open_ip() -> void:
	_queued_action = ActionRequest.open_ip()

func stop() -> void:
	_queued_action = ActionRequest.stop()

func self_destruct() -> void:
	_queued_action = ActionRequest.self_destruct()

# Called by SimulationCore after the strategy returns.
func flush_action() -> ActionRequest:
	var a := _queued_action
	_queued_action = null
	return a

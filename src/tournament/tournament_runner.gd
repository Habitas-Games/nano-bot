class_name TournamentRunner
extends RefCounted

signal progress_updated(completed: int, total: int)
signal match_finished(result: Dictionary)
signal tournament_finished()

var schedule: Array = []   # Array[Dictionary] { map, player_a, player_b, seed }
var results: Array  = []   # Array[Dictionary] completed match results

var _thread: Thread  = null
var _mutex: Mutex    = null
var _abort: bool     = false

# Build a round-robin schedule and start the tournament in a background thread.
func start(strategy_paths: Array, map_paths: Array) -> void:
	schedule = _build_schedule(strategy_paths, map_paths)
	results.clear()
	_abort  = false
	_mutex  = Mutex.new()
	_thread = Thread.new()
	_thread.start(_thread_main.bind(strategy_paths))

func abort() -> void:
	_abort = true

func wait() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()

# ─── schedule builder ─────────────────────────────────────────────────────────

static func _build_schedule(strategies: Array, maps: Array) -> Array:
	var sched: Array = []
	var seed := 0
	for m: String in maps:
		for i in strategies.size():
			for j in range(i + 1, strategies.size()):
				sched.append({
					"map":      m,
					"player_a": strategies[i],
					"player_b": strategies[j],
					"seed":     seed,
				})
				seed += 1
	return sched

# ─── background thread ────────────────────────────────────────────────────────

func _thread_main(strategies: Array) -> void:
	var total: int = schedule.size()

	for i in total:
		if _abort:
			break
		var entry: Dictionary = schedule[i]

		var map := MapLoader.load_from_file(entry["map"])
		if map == null:
			_record_error(entry, "map_load_failed")
			call_deferred("emit_signal", "progress_updated", i + 1, total)
			continue

		var sim := SimulationCore.new(
			map,
			[entry["player_a"], entry["player_b"]],
			int(entry["seed"])
		)
		var log := sim.run()

		# Auto-save replay
		var replay_path := _replay_path(entry, i)
		log.save_to_file(replay_path)

		var result := {
			"match_index": i,
			"map":         entry["map"],
			"player_a":    entry["player_a"],
			"player_b":    entry["player_b"],
			"winner_id":   log.winner_id,
			"final_scores": log.final_scores,
			"total_turns": log.total_turns,
			"replay_path": replay_path,
			"dq_a":        _was_dq(log, 0),
			"dq_b":        _was_dq(log, 1),
		}

		_mutex.lock()
		results.append(result)
		_mutex.unlock()

		call_deferred("emit_signal", "match_finished", result)
		call_deferred("emit_signal", "progress_updated", i + 1, total)

	call_deferred("emit_signal", "tournament_finished")

# ─── helpers ─────────────────────────────────────────────────────────────────

static func _replay_path(entry: Dictionary, idx: int) -> String:
	var a := (entry["player_a"] as String).get_file().get_basename()
	var b := (entry["player_b"] as String).get_file().get_basename()
	return "res://replays/tournament_%03d_%s_vs_%s.json" % [idx, a, b]

static func _was_dq(log: MatchLog, player_id: int) -> bool:
	# A player is considered DQ if all their bots died before turn 10
	# (a sign the strategy failed to load or immediately crashed).
	if log.frames.is_empty():
		return true
	var early: Dictionary = log.frames[mini(9, log.frames.size() - 1)]
	for bot: Dictionary in early.get("bots", []):
		if int(bot.get("owner", -1)) == player_id and bot.get("alive", false):
			return false
	return true

func _record_error(entry: Dictionary, reason: String) -> void:
	_mutex.lock()
	results.append({
		"map":       entry["map"],
		"player_a":  entry["player_a"],
		"player_b":  entry["player_b"],
		"error":     reason,
	})
	_mutex.unlock()

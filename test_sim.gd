extends SceneTree

func _initialize() -> void:
	print("=== nano-bot simulation test ===")

	# 1. Map loading
	var map := MapLoader.load_from_file("res://maps/simple_tissue.json")
	if map == null:
		print("FAIL: map not loaded")
		quit(1)
		return
	print("OK  map loaded: '%s' (%dx%d)" % [map.map_name, map.width, map.height])
	print("    habitas_points: %d, azn_nodes: %d, injection_zones: %d" % [
		map.habitas_points.size(), map.azn_nodes.size(), map.injection_zones.size()])

	# 2. Movement cost sanity
	var low_cost  := map.movement_cost(Vector2i(0, 0), Vector2i(1, 0))
	print("OK  movement cost low-density: %d (expect 2)" % low_cost)

	# 3. Pathfinder
	var pf   := GridPathfinder.new(map)
	var path := pf.find_path(Vector2i(0, 0), Vector2i(5, 5))
	print("OK  pathfinder  (0,0)->(5,5): %d steps" % path.size())

	# 4. Bot type registry
	var ai_stats := BotTypeRegistry.get_type("NanoAI")
	print("OK  registry NanoAI hp=%s" % ai_stats.get("hp", "?"))

	# 5. Simulation — no strategies (M1 acceptance test)
	print("--- M1: headless sim (no strategies) ---")
	var sim1 := SimulationCore.new(map, [], 0)
	var log1 := sim1.run()
	print("OK  turns=%d, winner=%d" % [log1.total_turns, log1.winner_id])
	print("    scores: %s" % str(log1.final_scores))
	if log1.frames.size() == 0:
		print("FAIL: no frames recorded")
		quit(1); return
	print("OK  frames=%d" % log1.frames.size())

	# Check both NanoAIs alive at turn 1500
	var last_frame: Dictionary = log1.frames[-1]
	var bots_alive: Array = last_frame["bots"].filter(func(b): return b.get("alive", false))
	print("OK  bots alive at end: %d (expect 2)" % bots_alive.size())

	# 6. Simulation — with example strategy (M2 acceptance test)
	print("--- M2: sim with example_strategy vs itself ---")
	var strat := "res://strategies/example_strategy.gd"
	var sim2  := SimulationCore.new(map, [strat, strat], 42)
	var log2  := sim2.run()
	print("OK  turns=%d, winner=%d" % [log2.total_turns, log2.winner_id])
	print("    final scores: %s" % str(log2.final_scores))

	# 7. Save replay
	var replay_path := "res://replays/test_match.json"
	log2.save_to_file(replay_path)
	if FileAccess.file_exists(replay_path):
		print("OK  replay saved to %s" % replay_path)
	else:
		print("FAIL: replay not saved")

	# 8. Reload replay
	var log3 := MatchLog.load_from_file(replay_path)
	if log3 == null:
		print("FAIL: replay not reloadable")
		quit(1); return
	print("OK  replay reloaded: %d frames, map='%s'" % [log3.frames.size(), log3.map_name])

	print("=== all tests passed ===")
	quit(0)

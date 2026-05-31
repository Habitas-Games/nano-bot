extends SceneTree

# Simulates the full Run Match → PlaybackScene path without a display.

func _initialize() -> void:
	print("=== full GUI path test ===")

	# Step 1: simulate _on_run_match
	var map := MapLoader.load_from_file("res://maps/simple_tissue.json")
	if map == null: _fail("map load"); return
	print("OK  map loaded")

	var strat := "res://strategies/example_strategy.gd"
	var sim   := SimulationCore.new(map, [strat, strat], 0)
	var log   := sim.run()
	print("OK  sim run: %d turns" % log.total_turns)

	var out_path := "res://replays/test_full_path.json"
	log.save_to_file(out_path)
	print("OK  saved replay")

	# Step 2: simulate PlaybackScene._ready reading GameState
	# (GameState not available in SceneTree scripts, test load_log_data directly)

	# Step 3: simulate load_log_data
	print("--- testing load_log_data path ---")

	# _find_map simulation
	var found_map := _find_map(log.map_name)
	if found_map == null: _fail("_find_map returned null for '%s'" % log.map_name); return
	print("OK  _find_map: '%s'" % found_map.map_name)

	# _apply_frame simulation (frame 0)
	var frame0: Dictionary = log.frames[0]
	print("OK  frame 0 keys: %s" % str(frame0.keys()))

	# What update_overlay receives
	var hp_array: Array  = frame0.get("habitas_points", [])
	var azn_array: Array = frame0.get("azn_nodes", [])
	print("OK  habitas_points count: %d" % hp_array.size())
	print("OK  azn_nodes count: %d" % azn_array.size())

	if hp_array.size() > 0:
		var hp0: Dictionary = hp_array[0]
		print("    hp0 keys: %s" % str(hp0.keys()))
		var pos0 := MapRenderer._pos(hp0)
		print("OK  hp0 pos resolved: %s" % str(pos0))

	if azn_array.size() > 0:
		var azn0: Dictionary = azn_array[0]
		print("    azn0 keys: %s" % str(azn0.keys()))
		var pos1 := MapRenderer._pos(azn0)
		print("OK  azn0 pos resolved: %s" % str(pos1))

	# What setup_for_log receives
	print("--- testing HUD setup_for_log ---")
	var strategies: Array = log.player_strategies
	print("OK  strategies count: %d" % strategies.size())

	# Check score access in update_frame
	var scores: Dictionary = frame0.get("scores", {})
	print("OK  scores keys: %s  values: %s" % [str(scores.keys()), str(scores.values())])
	for i in 2:
		var s: int = int(scores.get(str(i), scores.get(i, -1)))
		print("    P%d score=%d" % [i, s])

	# Check bot data
	var bots: Array = frame0.get("bots", [])
	print("OK  bots in frame 0: %d" % bots.size())
	for b: Dictionary in bots:
		var pos: Array = b.get("pos", [])
		var cell := Vector2i(int(pos[0]), int(pos[1]))
		print("    bot id=%s type=%s owner=%s pos=%s alive=%s" % [
			b.get("id","?"), b.get("type","?"), b.get("owner","?"),
			str(cell), b.get("alive","?")])

	# Check _auto_replay_path format
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var replay_path := "res://replays/match_%s_example_vs_example.json" % stamp
	print("OK  replay path format: %s" % replay_path)

	print("=== all tests passed ===")
	quit(0)

func _find_map(map_name: String) -> MapData:
	var dir := DirAccess.open("res://maps")
	if dir == null:
		print("FAIL _find_map: DirAccess.open returned null")
		return null
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var candidate := MapLoader.load_from_file("res://maps/" + fname)
			if candidate != null and candidate.map_name == map_name:
				return candidate
		fname = dir.get_next()
	return null

func _fail(msg: String) -> void:
	print("FAIL: %s" % msg)
	quit(1)

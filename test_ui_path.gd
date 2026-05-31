extends SceneTree

func _initialize() -> void:
	print("=== testing Run Match path ===")

	# Reproduce exactly what MainMenu._on_run_match does
	var map := MapLoader.load_from_file("res://maps/simple_tissue.json")
	assert(map != null, "map load failed")

	var strat := "res://strategies/example_strategy.gd"
	var sim   := SimulationCore.new(map, [strat, strat], 0)
	var log   := sim.run()
	print("OK  simulation: %d turns, winner=%d" % [log.total_turns, log.winner_id])

	# Save and reload (simulates what PlaybackScene does when log comes from file)
	var path := "res://replays/test_ui_path.json"
	log.save_to_file(path)
	var log2 := MatchLog.load_from_file(path)
	assert(log2 != null, "reload failed")
	print("OK  reload: %d frames" % log2.frames.size())

	# Test the data formats that hit the renderer
	var frame0: Dictionary = log2.frames[0]

	# AZN nodes from log frame — must have "pos" Array and "qty"
	for azn in frame0.get("azn_nodes", []):
		assert(azn.has("pos"),   "azn missing 'pos'")
		assert(azn.has("qty"),   "azn missing 'qty'")
		var p = azn["pos"]
		assert(p is Array and p.size() == 2, "azn pos not [x,y]")
	print("OK  azn_nodes format correct")

	# Habitas points from log frame — must have "pos" Array and "owner"
	for hp in frame0.get("habitas_points", []):
		assert(hp.has("pos"),   "hp missing 'pos'")
		assert(hp.has("owner"), "hp missing 'owner'")
		var p = hp["pos"]
		assert(p is Array and p.size() == 2, "hp pos not [x,y]")
	print("OK  habitas_points format correct")

	# Bots from log frame — must have "pos" Array, "id", "owner", "type", "alive"
	var bots: Array = frame0.get("bots", [])
	assert(bots.size() > 0, "no bots in frame")
	for b in bots:
		assert(b.has("pos"),   "bot missing 'pos'")
		assert(b.has("id"),    "bot missing 'id'")
		assert(b.has("owner"), "bot missing 'owner'")
		var cell := Vector2i(int(b["pos"][0]), int(b["pos"][1]))
		assert(cell != Vector2i(-1,-1), "bot cell bad")
	print("OK  bot format correct (%d bots in frame 0)" % bots.size())

	# Test MapRenderer _pos helper with both formats
	var renderer := MapRenderer.new()
	renderer.setup(map)

	# Live-state format (Vector2i)
	var live_hp := { "position": Vector2i(10, 10), "owner": -1, "azn_stored": 0 }
	var v1 := MapRenderer._pos(live_hp)
	assert(v1 == Vector2i(10, 10), "live pos failed: %s" % str(v1))
	print("OK  renderer _pos live format")

	# Log format (Array)
	var log_hp := { "pos": [10, 10], "owner": -1, "azn": 0 }
	var v2 := MapRenderer._pos(log_hp)
	assert(v2 == Vector2i(10, 10), "log pos failed: %s" % str(v2))
	print("OK  renderer _pos log format")

	# Scores format: direct (int keys) vs reloaded (string keys)
	var scores_int: Dictionary = log.frames[0]["scores"]
	var scores_str: Dictionary = log2.frames[0]["scores"]
	var s_int: int = int(scores_int.get(str(0), scores_int.get(0, -999)))
	var s_str: int = int(scores_str.get(str(0), scores_str.get(0, -999)))
	assert(s_int >= 0, "int-key score lookup failed")
	assert(s_str >= 0, "str-key score lookup failed")
	print("OK  score key format both work (int=%d str=%d)" % [s_int, s_str])

	print("=== all UI path tests passed ===")
	quit(0)

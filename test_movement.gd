extends SceneTree

func _initialize() -> void:
	print("=== movement diagnostic ===")

	var map  := MapLoader.load_from_file("res://maps/simple_tissue.json")
	var strat := "res://strategies/example_strategy.gd"
	var sim  := SimulationCore.new(map, [strat, strat], 0)
	var log  := sim.run()

	print("total frames: %d" % log.frames.size())

	# Check bot positions at multiple frames
	for turn_idx in [0, 1, 2, 3, 4, 5, 10, 20, 50]:
		if turn_idx >= log.frames.size():
			continue
		var frame: Dictionary = log.frames[turn_idx]
		var bots: Array = frame.get("bots", [])
		var positions: Array = []
		for b: Dictionary in bots:
			var p: Array = b.get("pos", [0,0])
			var alive: bool = b.get("alive", false)
			if alive:
				positions.append("bot%s@(%s,%s)" % [b.get("id","?"), p[0], p[1]])
		print("frame %3d: %s" % [turn_idx, ", ".join(positions)])

	# Check if any bot moves at all across all frames
	var first_frame: Dictionary = log.frames[0]
	var last_frame: Dictionary = log.frames[-1]
	var moved := false
	for b0: Dictionary in first_frame.get("bots", []):
		for b1: Dictionary in last_frame.get("bots", []):
			if b0.get("id") == b1.get("id"):
				var p0: Array = b0.get("pos", [0,0])
				var p1: Array = b1.get("pos", [0,0])
				if p0[0] != p1[0] or p0[1] != p1[1]:
					moved = true
	print("bots moved across log: %s" % str(moved))

	# Check timer duration math
	var speed_dur := {0.25: 0.80, 0.50: 0.40, 1.00: 0.20, 2.00: 0.10, 4.00: 0.05}
	var speed := 1.0
	var dur = speed_dur.get(speed, -1.0)
	print("SPEED_DURATION.get(1.0) = %s (expect 0.2)" % str(dur))

	# Check final scores
	print("final scores: %s" % str(log.final_scores))
	print("winner: %d" % log.winner_id)

	print("=== done ===")
	quit(0)

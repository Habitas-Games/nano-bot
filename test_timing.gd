extends SceneTree
func _initialize() -> void:
	var t := Time.get_ticks_msec()
	var map := MapLoader.load_from_file("res://maps/simple_tissue.json")
	var strat := "res://strategies/example_strategy.gd"
	var sim := SimulationCore.new(map, [strat, strat], 0)
	var log := sim.run()
	var elapsed := Time.get_ticks_msec() - t
	print("simulation took %d ms (%d turns)" % [elapsed, log.total_turns])
	print("final scores: %s" % str(log.final_scores))
	quit(0)

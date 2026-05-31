class_name HeadlessRunner
extends RefCounted

# CLI usage (run from project root):
#   godot --headless -- --map maps/simple_tissue.json \
#                       --strategy_a strategies/example_strategy.gd \
#                       --strategy_b strategies/other.gd \
#                       [--seed 42] [--out replays/my_match.json]
#
# Returns an exit code: 0 = success, 1 = error.

const DEFAULT_OUT_DIR := "replays"

static func run_from_cmdline(tree: SceneTree) -> void:
	var args  := _parse_args(OS.get_cmdline_user_args())
	var code  := _execute(args)
	tree.quit(code)

static func _execute(args: Dictionary) -> int:
	if not args.has("map"):
		push_error("HeadlessRunner: --map is required")
		return 1

	var map := MapLoader.load_from_file(args["map"])
	if map == null:
		push_error("HeadlessRunner: failed to load map: %s" % args["map"])
		return 1

	var strategies: Array = []
	if args.has("strategy_a"):
		strategies.append(args["strategy_a"])
	if args.has("strategy_b"):
		strategies.append(args["strategy_b"])
	# Additional players: --strategy_c, --strategy_d
	for key in ["strategy_c", "strategy_d"]:
		if args.has(key):
			strategies.append(args[key])

	var seed_val := int(args.get("seed", 0))
	var sim      := SimulationCore.new(map, strategies, seed_val)

	print("HeadlessRunner: starting match — map: %s, players: %d, seed: %d" \
		% [map.map_name, maxi(strategies.size(), 2), seed_val])

	var log := sim.run()

	var out_path: String = args.get("out", _auto_out_path(strategies))
	log.save_to_file(out_path)

	print("HeadlessRunner: match complete in %d turns" % log.total_turns)
	print("HeadlessRunner: winner — player %d" % log.winner_id)
	for pid: String in log.final_scores:
		print("  player %s: %d pts" % [pid, log.final_scores[pid]])
	print("HeadlessRunner: replay saved to %s" % out_path)
	return 0

static func _parse_args(raw: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	var i := 0
	while i < raw.size():
		var key: String = raw[i]
		if key.begins_with("--") and i + 1 < raw.size():
			result[key.substr(2)] = raw[i + 1]
			i += 2
		else:
			i += 1
	return result

static func _auto_out_path(strategies: Array) -> String:
	var names: Array = []
	for s: String in strategies:
		names.append(s.get_file().get_basename())
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var label := "_vs_".join(names) if names.size() > 0 else "match"
	return "%s/match_%s_%s.json" % [DEFAULT_OUT_DIR, stamp, label]

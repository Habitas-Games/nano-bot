class_name Leaderboard
extends RefCounted

# One entry per strategy file.
# { path, name, wins, losses, draws, points, matches, dq }
var _entries: Dictionary = {}  # strategy_path -> Dictionary

func add_result(result: Dictionary) -> void:
	if result.has("error"):
		return

	var a: String = result["player_a"]
	var b: String = result["player_b"]
	var wid: int  = int(result.get("winner_id", -1))
	var scores: Dictionary = result.get("final_scores", {})
	var dq_a: bool = result.get("dq_a", false)
	var dq_b: bool = result.get("dq_b", false)

	_ensure(a, dq_a)
	_ensure(b, dq_b)

	_entries[a]["matches"] += 1
	_entries[b]["matches"] += 1
	_entries[a]["points"]  += int(scores.get("0", scores.get(0, 0)))
	_entries[b]["points"]  += int(scores.get("1", scores.get(1, 0)))

	if dq_a and not dq_b:
		_entries[b]["wins"]   += 1
		_entries[a]["losses"] += 1
	elif dq_b and not dq_a:
		_entries[a]["wins"]   += 1
		_entries[b]["losses"] += 1
	elif wid == 0:
		_entries[a]["wins"]   += 1
		_entries[b]["losses"] += 1
	elif wid == 1:
		_entries[b]["wins"]   += 1
		_entries[a]["losses"] += 1
	else:
		_entries[a]["draws"] += 1
		_entries[b]["draws"] += 1

func get_sorted() -> Array:
	var list: Array = _entries.values()
	list.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		if x["wins"] != y["wins"]:
			return x["wins"] > y["wins"]
		return x["points"] > y["points"]
	)
	return list

func save_to_file(path: String) -> void:
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Leaderboard: cannot write to %s" % path)
		return
	file.store_string(JSON.stringify({
		"generated": Time.get_datetime_string_from_system(),
		"entries":   get_sorted(),
	}, "\t"))
	file.close()

func _ensure(path: String, dq: bool) -> void:
	if not _entries.has(path):
		_entries[path] = {
			"path":    path,
			"name":    path.get_file().get_basename(),
			"wins":    0,
			"losses":  0,
			"draws":   0,
			"points":  0,
			"matches": 0,
			"dq":      dq,
		}
	elif dq:
		_entries[path]["dq"] = true

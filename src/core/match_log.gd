class_name MatchLog
extends RefCounted

var map_name: String            = ""
var player_strategies: Array    = []  # Array[String]
var frames: Array               = []  # Array[Dictionary]
var final_scores: Dictionary    = {}  # player_id(String) -> int
var winner_id: int              = -1
var total_turns: int            = 0

func record_frame(
	turn: int,
	scores: Dictionary,
	bots: Array,
	azn_nodes: Array,
	habitas_points: Array,
	events: Array
) -> void:
	frames.append({
		"turn":   turn,
		"scores": scores.duplicate(),
		"bots": _serialize_bots(bots),
		"azn_nodes": _serialize_azn(azn_nodes),
		"habitas_points": _serialize_habitas(habitas_points),
		"events": events.duplicate(),
	})

func save_to_file(path: String) -> void:
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("MatchLog: could not write to: %s" % path)
		return
	file.store_string(JSON.stringify(to_dict(), "\t"))
	file.close()

func to_dict() -> Dictionary:
	return {
		"map_name":          map_name,
		"player_strategies": player_strategies,
		"total_turns":       total_turns,
		"final_scores":      final_scores,
		"winner_id":         winner_id,
		"frames":            frames,
	}

static func load_from_file(path: String) -> MatchLog:
	if not FileAccess.file_exists(path):
		push_error("MatchLog: file not found: %s" % path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("MatchLog: JSON parse error in %s" % path)
		file.close()
		return null
	file.close()
	var log       := MatchLog.new()
	var data: Dictionary = json.data
	log.map_name          = data.get("map_name", "")
	log.player_strategies = data.get("player_strategies", [])
	log.total_turns       = int(data.get("total_turns", 0))
	log.final_scores      = data.get("final_scores", {})
	log.winner_id         = int(data.get("winner_id", -1))
	log.frames            = data.get("frames", [])
	return log

# --- private serialisers ---

static func _serialize_bots(bots: Array) -> Array:
	var out: Array = []
	for bot in bots:
		if bot is NanoBotData:
			out.append(bot.to_log_dict())
	return out

static func _serialize_azn(nodes: Array) -> Array:
	var out: Array = []
	for n: Dictionary in nodes:
		out.append({ "pos": [n["position"].x, n["position"].y], "qty": n["quantity"] })
	return out

static func _serialize_habitas(points: Array) -> Array:
	var out: Array = []
	for hp: Dictionary in points:
		out.append({
			"pos":   [hp["position"].x, hp["position"].y],
			"owner": hp["owner"],
			"azn":   hp["azn_stored"],
		})
	return out

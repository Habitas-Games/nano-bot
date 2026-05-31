class_name BotTypeRegistry
extends RefCounted

# Static singleton — no Node/autoload required.
# Call BotTypeRegistry.get_type("NanoCollector") from anywhere.

const DATA_PATH := "res://data/bot_types.json"

static var _data: Dictionary = {}
static var _loaded: bool     = false

static func get_type(type_name: String) -> Dictionary:
	if not _loaded:
		_load()
	return _data.get(type_name, {})

static func all_types() -> Array:
	if not _loaded:
		_load()
	return _data.keys()

static func is_valid_type(type_name: String) -> bool:
	if not _loaded:
		_load()
	return _data.has(type_name)

static func _load() -> void:
	_loaded = true  # set early to prevent re-entrant calls on error
	if not FileAccess.file_exists(DATA_PATH):
		push_error("BotTypeRegistry: data file not found: %s" % DATA_PATH)
		return
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("BotTypeRegistry: JSON parse error: %s" % json.get_error_message())
		file.close()
		return
	_data = json.data
	file.close()

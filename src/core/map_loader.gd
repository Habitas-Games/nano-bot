class_name MapLoader
extends RefCounted

const _DENSITY_MAP: Dictionary = {
	"low":    MapData.Density.LOW,
	"medium": MapData.Density.MEDIUM,
	"high":   MapData.Density.HIGH,
	"bone":   MapData.Density.BONE,
}

const _STREAM_MAP: Dictionary = {
	"north": MapData.StreamDir.NORTH,
	"south": MapData.StreamDir.SOUTH,
	"east":  MapData.StreamDir.EAST,
	"west":  MapData.StreamDir.WEST,
}

static func load_from_file(path: String) -> MapData:
	if not FileAccess.file_exists(path):
		push_error("MapLoader: file not found: %s" % path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("MapLoader: JSON error in %s — %s" % [path, json.get_error_message()])
		return null
	return _parse(json.data, path)

static func _parse(data: Dictionary, path: String) -> MapData:
	for key in ["width", "height"]:
		if not data.has(key):
			push_error("MapLoader: missing required field '%s' in %s" % [key, path])
			return null

	var map := MapData.new(int(data["width"]), int(data["height"]))
	map.map_name = data.get("name", "Unnamed")

	var default_density: int = _DENSITY_MAP.get(
		data.get("default_density", "low"), MapData.Density.LOW
	)
	for i in map.width * map.height:
		map._cells[i] = { "density": default_density, "stream_dir": MapData.StreamDir.NONE }

	for cd: Dictionary in data.get("cells", []):
		var x := int(cd.get("x", 0))
		var y := int(cd.get("y", 0))
		if not map.is_in_bounds(x, y):
			push_error("MapLoader: cell (%d,%d) out of bounds in %s" % [x, y, path])
			continue
		var density: int = _DENSITY_MAP.get(cd.get("density", "low"), default_density)
		var stream: int  = _STREAM_MAP.get(cd.get("stream", ""), MapData.StreamDir.NONE)
		map.set_cell(x, y, density, stream)

	for hp: Dictionary in data.get("habitas_points", []):
		map.habitas_points.append(Vector2i(int(hp["x"]), int(hp["y"])))

	for azn: Dictionary in data.get("azn_nodes", []):
		map.azn_nodes.append({
			"position": Vector2i(int(azn["x"]), int(azn["y"])),
			"quantity": int(azn.get("quantity", 10)),
		})

	for zone: Dictionary in data.get("injection_zones", []):
		var x1 := int(zone["x1"]); var y1 := int(zone["y1"])
		var x2 := int(zone["x2"]); var y2 := int(zone["y2"])
		map.injection_zones.append({
			"player": int(zone.get("player", 0)),
			"rect":   Rect2i(x1, y1, x2 - x1 + 1, y2 - y1 + 1),
		})

	return map

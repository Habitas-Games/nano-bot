class_name MapIO
extends RefCounted

## JSON <-> MapDocument. This is the single home for load/save/validate and
## the enum<->string conversions. Before this refactor, map_editor.gd defined
## _load_map_from_file, _density_to_string, and _string_to_density TWICE each
## (Phase 1 and Phase 5 versions collided under the same names — analysis.md
## §2) which is a GDScript parse error: the script could not be instantiated
## at all. There is now exactly one definition of each, here.

var last_error: String = ""

func density_to_string(d: int) -> String:
	match d:
		MapDocument.Density.LOW: return "low"
		MapDocument.Density.MEDIUM: return "medium"
		MapDocument.Density.HIGH: return "high"
		MapDocument.Density.BONE: return "bone"
	return "low"

func string_to_density(s: String) -> int:
	match s.to_lower():
		"low": return MapDocument.Density.LOW
		"medium": return MapDocument.Density.MEDIUM
		"high": return MapDocument.Density.HIGH
		"bone": return MapDocument.Density.BONE
	return MapDocument.Density.LOW

func stream_to_string(s: int) -> String:
	match s:
		MapDocument.StreamDir.NORTH: return "north"
		MapDocument.StreamDir.SOUTH: return "south"
		MapDocument.StreamDir.EAST: return "east"
		MapDocument.StreamDir.WEST: return "west"
	return ""

func string_to_stream(s: String) -> int:
	match s.to_lower():
		"north": return MapDocument.StreamDir.NORTH
		"south": return MapDocument.StreamDir.SOUTH
		"east": return MapDocument.StreamDir.EAST
		"west": return MapDocument.StreamDir.WEST
	return MapDocument.StreamDir.NONE

func validate(doc: MapDocument) -> Array:
	"""Returns an array of error strings describing why the map isn't ready to save. Empty = valid."""
	var errors = []
	if doc.habitas_points.size() == 0:
		errors.append("Need at least 1 Habitas Point")
	if doc.azn_nodes.size() == 0:
		errors.append("Need at least 1 AZN Node")
	if doc.injection_zones.size() == 0:
		errors.append("Need at least 1 Injection Zone")
	return errors

func create_json(doc: MapDocument, map_name: String = "Custom Map", starting_azn: int = 150) -> Dictionary:
	var json = {
		"name": map_name,
		"width": doc.width,
		"height": doc.height,
		"default_density": "low",
		"starting_azn": starting_azn,
		"cells": [],
		"habitas_points": [],
		"azn_nodes": [],
		"injection_zones": [],
	}

	# Sparse cell encoding: only cells that differ from the default need listing.
	for i in range(doc.cells.size()):
		var cell = doc.cells[i]
		if cell["density"] != MapDocument.Density.LOW or cell["stream_dir"] != MapDocument.StreamDir.NONE:
			var x = i % doc.width
			var y = i / doc.width
			var cell_obj = {"x": x, "y": y, "density": density_to_string(cell["density"])}
			if cell["stream_dir"] != MapDocument.StreamDir.NONE:
				cell_obj["stream"] = stream_to_string(cell["stream_dir"])
			json["cells"].append(cell_obj)

	for hp in doc.habitas_points:
		json["habitas_points"].append({"x": hp.x, "y": hp.y})

	for azn in doc.azn_nodes:
		json["azn_nodes"].append({
			"x": azn["position"].x,
			"y": azn["position"].y,
			"quantity": azn["quantity"],
		})

	for zone in doc.injection_zones:
		var rect = zone["rect"]
		json["injection_zones"].append({
			"player": zone["player"],
			"x1": rect.position.x,
			"y1": rect.position.y,
			"x2": rect.position.x + rect.size.x - 1,
			"y2": rect.position.y + rect.size.y - 1,
		})

	return json

func save_to_file(doc: MapDocument, filepath: String, map_name: String = "Custom Map") -> bool:
	last_error = ""
	var json_data = create_json(doc, map_name)
	var file = FileAccess.open(filepath, FileAccess.WRITE)
	if file == null:
		last_error = "Failed to save map to " + filepath
		return false
	file.store_string(JSON.stringify(json_data))
	return true

func load_from_file(filepath: String) -> MapDocument:
	"""Returns a populated MapDocument, or null on failure (check last_error)."""
	last_error = ""

	var file = FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		last_error = "Failed to load map from " + filepath
		return null

	var data = JSON.parse_string(file.get_as_text())
	if data == null or typeof(data) != TYPE_DICTIONARY:
		last_error = "Invalid JSON format in " + filepath
		return null

	# src/core/map_loader.gd treats width/height as required and refuses to
	# load a map missing either — match that here instead of silently
	# guessing a size the simulator itself would never accept.
	if not data.has("width") or not data.has("height"):
		last_error = "Map is missing required field 'width' or 'height': " + filepath
		return null

	var doc = MapDocument.new()
	var default_density = string_to_density(data.get("default_density", "low"))
	doc.init_blank(int(data["width"]), int(data["height"]), default_density)

	for cell_data in data.get("cells", []):
		var x = cell_data.get("x", 0)
		var y = cell_data.get("y", 0)
		if not doc.is_in_bounds(x, y):
			continue
		var idx = y * doc.width + x
		doc.cells[idx]["density"] = string_to_density(cell_data.get("density", "low"))
		if cell_data.has("stream"):
			doc.cells[idx]["stream_dir"] = string_to_stream(cell_data["stream"])

	for hp in data.get("habitas_points", []):
		doc.habitas_points.append(Vector2i(hp.get("x", 0), hp.get("y", 0)))

	for azn in data.get("azn_nodes", []):
		doc.azn_nodes.append({
			"position": Vector2i(azn.get("x", 0), azn.get("y", 0)),
			"quantity": azn.get("quantity", 10),
		})

	for zone in data.get("injection_zones", []):
		var x1 = zone.get("x1", 0)
		var y1 = zone.get("y1", 0)
		var x2 = zone.get("x2", 0)
		var y2 = zone.get("y2", 0)
		doc.injection_zones.append({
			"player": zone.get("player", 0),
			"rect": Rect2i(x1, y1, x2 - x1 + 1, y2 - y1 + 1),
		})

	return doc

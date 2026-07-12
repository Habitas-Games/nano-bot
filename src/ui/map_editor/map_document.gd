class_name MapDocument
extends RefCounted

## Map data and mutation. No rendering, no input, no UI — see map_canvas_renderer.gd
## and tools/ for those. Matches the simulator's enums (src/core/map_data.gd).

enum Density { LOW, MEDIUM, HIGH, BONE }
enum StreamDir { NONE, NORTH, SOUTH, EAST, WEST }

var width: int = 60
var height: int = 60
var cells: Array = []
var habitas_points: Array = []
var azn_nodes: Array = []
var injection_zones: Array = []

func init_blank(p_width: int, p_height: int, default_density: int = Density.LOW) -> void:
	width = p_width
	height = p_height
	cells.resize(width * height)
	for i in range(cells.size()):
		cells[i] = {"density": default_density, "stream_dir": StreamDir.NONE}
	habitas_points.clear()
	azn_nodes.clear()
	injection_zones.clear()

func is_in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height

func get_cell(x: int, y: int) -> Dictionary:
	return cells[y * width + x]

func paint_cell(x: int, y: int, density: int) -> void:
	if not is_in_bounds(x, y):
		return
	cells[y * width + x]["density"] = density

func place_stream(x: int, y: int, dir: int) -> void:
	if not is_in_bounds(x, y):
		return
	cells[y * width + x]["stream_dir"] = dir

func flood_fill(start_x: int, start_y: int, new_density: int) -> void:
	if not is_in_bounds(start_x, start_y):
		return
	var start_idx = start_y * width + start_x
	var target_density = cells[start_idx]["density"]
	if target_density == new_density:
		return

	var stack = [[start_x, start_y]]
	var visited = {}

	while stack.size() > 0:
		var pos = stack.pop_back()
		var x = pos[0]
		var y = pos[1]

		if not is_in_bounds(x, y):
			continue

		var key = str(x) + "," + str(y)
		if key in visited:
			continue

		var idx = y * width + x
		if cells[idx]["density"] != target_density:
			continue

		visited[key] = true
		cells[idx]["density"] = new_density

		stack.append([x + 1, y])
		stack.append([x - 1, y])
		stack.append([x, y + 1])
		stack.append([x, y - 1])

func clear_all() -> void:
	"""Reset terrain/streams to default and remove every element. Used by 'Clear Map'."""
	for i in range(cells.size()):
		cells[i]["density"] = Density.LOW
		cells[i]["stream_dir"] = StreamDir.NONE
	habitas_points.clear()
	azn_nodes.clear()
	injection_zones.clear()

func delete_at_position(x: int, y: int) -> void:
	"""Delete terrain/stream and any element at this grid position."""
	if not is_in_bounds(x, y):
		return

	var idx = y * width + x
	cells[idx]["density"] = Density.LOW
	cells[idx]["stream_dir"] = StreamDir.NONE

	var pos = Vector2i(x, y)
	habitas_points = habitas_points.filter(func(hp): return hp != pos)
	azn_nodes = azn_nodes.filter(func(azn): return azn["position"] != pos)
	injection_zones = injection_zones.filter(func(zone): return not zone["rect"].has_point(pos))

## --- Element placement (with duplicate-position guard; analysis.md §4) ---

func place_habitas(x: int, y: int) -> bool:
	"""Place a habitas point. Returns false (no-op) if one already exists here."""
	if not is_in_bounds(x, y):
		return false
	var pos = Vector2i(x, y)
	if habitas_points.has(pos):
		return false
	habitas_points.append(pos)
	return true

func place_azn(x: int, y: int, quantity: int = 30) -> bool:
	"""Place an AZN node. Returns false (no-op) if one already exists here."""
	if not is_in_bounds(x, y):
		return false
	var pos = Vector2i(x, y)
	for azn in azn_nodes:
		if azn["position"] == pos:
			return false
	azn_nodes.append({"position": pos, "quantity": quantity})
	return true

func place_zone(rect: Rect2i, player: int = 0) -> void:
	injection_zones.append({"player": player, "rect": rect})

## --- Element lookup / editing (used by the Edit tool) ---

func find_element_at(x: int, y: int) -> Dictionary:
	"""Returns {type, index} for the topmost element at this position, or {type: 'none'}."""
	var pos = Vector2i(x, y)

	for i in range(habitas_points.size()):
		if habitas_points[i] == pos:
			return {"type": "habitas", "index": i}

	for i in range(azn_nodes.size()):
		if azn_nodes[i]["position"] == pos:
			return {"type": "azn", "index": i}

	for i in range(injection_zones.size()):
		if injection_zones[i]["rect"].has_point(pos):
			return {"type": "zone", "index": i}

	return {"type": "none"}

func move_habitas(index: int, new_pos: Vector2i) -> bool:
	if not is_in_bounds(new_pos.x, new_pos.y):
		return false
	habitas_points[index] = new_pos
	return true

func move_azn(index: int, new_pos: Vector2i) -> bool:
	if not is_in_bounds(new_pos.x, new_pos.y):
		return false
	azn_nodes[index]["position"] = new_pos
	return true

func set_azn_quantity(index: int, quantity: int) -> void:
	azn_nodes[index]["quantity"] = quantity

func move_zone(index: int, offset: Vector2i) -> bool:
	var rect = injection_zones[index]["rect"]
	var new_pos = rect.position + offset
	if new_pos.x < 0 or new_pos.y < 0 or new_pos.x + rect.size.x > width or new_pos.y + rect.size.y > height:
		return false
	injection_zones[index]["rect"] = Rect2i(new_pos, rect.size)
	return true

func detect_zone_corner(grid_x: int, grid_y: int, index: int) -> String:
	"""Returns 'tl'/'tr'/'bl'/'br' if (grid_x, grid_y) is near that corner of the zone, else ''."""
	var rect = injection_zones[index]["rect"]
	var pos = Vector2i(grid_x, grid_y)
	var corners = {
		"tl": rect.position,
		"tr": rect.position + Vector2i(rect.size.x - 1, 0),
		"bl": rect.position + Vector2i(0, rect.size.y - 1),
		"br": rect.position + rect.size - Vector2i(1, 1),
	}
	for corner_name in corners:
		if pos.distance_to(corners[corner_name]) <= 1.5:
			return corner_name
	return ""

func resize_zone(index: int, corner: String, new_grid_x: int, new_grid_y: int) -> bool:
	var rect = injection_zones[index]["rect"]
	var new_pos = Vector2i(new_grid_x, new_grid_y)
	var new_rect: Rect2i

	match corner:
		"tl":
			var new_width = (rect.position.x + rect.size.x) - new_pos.x
			var new_height = (rect.position.y + rect.size.y) - new_pos.y
			if new_width < 2 or new_height < 2 or new_pos.x < 0 or new_pos.y < 0:
				return false
			new_rect = Rect2i(new_pos, Vector2i(new_width, new_height))
		"tr":
			var new_width = new_pos.x - rect.position.x + 1
			var new_height = (rect.position.y + rect.size.y) - new_pos.y
			if new_width < 2 or new_height < 2 or new_pos.x >= width or new_pos.y < 0:
				return false
			new_rect = Rect2i(Vector2i(rect.position.x, new_pos.y), Vector2i(new_width, new_height))
		"bl":
			var new_width = (rect.position.x + rect.size.x) - new_pos.x
			var new_height = new_pos.y - rect.position.y + 1
			if new_width < 2 or new_height < 2 or new_pos.x < 0 or new_pos.y >= height:
				return false
			new_rect = Rect2i(Vector2i(new_pos.x, rect.position.y), Vector2i(new_width, new_height))
		"br":
			var new_width = new_pos.x - rect.position.x + 1
			var new_height = new_pos.y - rect.position.y + 1
			if new_width < 2 or new_height < 2 or new_pos.x >= width or new_pos.y >= height:
				return false
			new_rect = Rect2i(rect.position, Vector2i(new_width, new_height))
		_:
			return false

	injection_zones[index]["rect"] = new_rect
	return true

## --- Snapshot / restore (used by MapHistory for undo) ---

func snapshot() -> Dictionary:
	var cells_copy: Array = []
	for row in cells:
		cells_copy.append(row.duplicate())
	var habitas_copy: Array = habitas_points.duplicate()
	var azn_copy: Array = []
	for azn in azn_nodes:
		azn_copy.append(azn.duplicate())
	var zones_copy: Array = []
	for zone in injection_zones:
		zones_copy.append(zone.duplicate())
	return {
		"width": width,
		"height": height,
		"cells": cells_copy,
		"habitas_points": habitas_copy,
		"azn_nodes": azn_copy,
		"injection_zones": zones_copy,
	}

func restore(snap: Dictionary) -> void:
	width = snap["width"]
	height = snap["height"]
	cells.clear()
	for row in snap["cells"]:
		cells.append(row.duplicate())
	habitas_points = snap["habitas_points"].duplicate()
	azn_nodes = []
	for azn in snap["azn_nodes"]:
		azn_nodes.append(azn.duplicate())
	injection_zones = []
	for zone in snap["injection_zones"]:
		injection_zones.append(zone.duplicate())

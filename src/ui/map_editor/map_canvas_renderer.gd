class_name MapCanvasRenderer
extends RefCounted

## All draw_* calls for the map canvas. Owns its own textures. Draw methods
## here are called synchronously from MapEditor._draw() and draw onto the
## CanvasItem passed in as `ci` — Godot only allows draw_* calls while the
## item is in its drawing phase, which holds as long as this stays a plain
## function call inside that same _draw() call stack.

const CELL_SIZE := 16
const STREAM_COLOR := Color(0.70, 0.25, 0.25, 0.80)
const GRID_COLOR := Color(0.00, 0.00, 0.00, 0.12)
const BRUSH_COLOR := Color(1.0, 1.0, 1.0, 0.5)

var terrain_textures: Dictionary = {}
var stream_h_texture: Texture2D
var stream_v_texture: Texture2D
var habitas_texture: Texture2D
var azn_texture: Texture2D

func _init() -> void:
	terrain_textures[MapDocument.Density.LOW] = load("res://assets/tiles/tile_low.png")
	terrain_textures[MapDocument.Density.MEDIUM] = load("res://assets/tiles/tile_medium.png")
	terrain_textures[MapDocument.Density.HIGH] = load("res://assets/tiles/tile_high.png")
	terrain_textures[MapDocument.Density.BONE] = load("res://assets/tiles/tile_bone.png")
	stream_h_texture = load("res://assets/tiles/tile_stream_h.png")
	stream_v_texture = load("res://assets/tiles/tile_stream_v.png")
	habitas_texture = load("res://assets/markers/habitas_neutral.png")
	azn_texture = load("res://assets/markers/azn_node.png")

## selection: {"type": String, "index": int} for the Edit tool's current selection (or type "none")
## preview_rect: in-progress zone being dragged by ZoneTool (zero-size Rect2i = none)
func draw_all(ci: CanvasItem, doc: MapDocument, canvas_rect: Rect2, zoom: float,
		scroll_x: int, scroll_y: int, brush_cursor_pos: Vector2i,
		selection: Dictionary, azn_hover_index: int, preview_rect: Rect2i = Rect2i()) -> void:
	var cx = int(canvas_rect.position.x)
	var cy = int(canvas_rect.position.y)
	var cw = int(canvas_rect.size.x)
	var ch = int(canvas_rect.size.y)

	ci.draw_rect(Rect2(cx, cy, cw, ch), Color(0.2, 0.2, 0.2))
	_draw_cells(ci, doc, cx, cy, cw, ch, zoom, scroll_x, scroll_y, brush_cursor_pos)
	_draw_zones(ci, doc, cx, cy, zoom, scroll_x, scroll_y, selection)
	_draw_habitas(ci, doc, cx, cy, zoom, scroll_x, scroll_y, selection)
	_draw_azn(ci, doc, cx, cy, zoom, scroll_x, scroll_y, selection, azn_hover_index)
	_draw_preview_rect(ci, preview_rect, cx, cy, zoom, scroll_x, scroll_y)

func _draw_preview_rect(ci: CanvasItem, preview_rect: Rect2i, cx: int, cy: int,
		zoom: float, scroll_x: int, scroll_y: int) -> void:
	if preview_rect.size.x <= 0 or preview_rect.size.y <= 0:
		return
	var screen_x1 = cx + (preview_rect.position.x * CELL_SIZE * zoom) - scroll_x
	var screen_y1 = cy + (preview_rect.position.y * CELL_SIZE * zoom) - scroll_y
	var screen_x2 = cx + ((preview_rect.position.x + preview_rect.size.x) * CELL_SIZE * zoom) - scroll_x
	var screen_y2 = cy + ((preview_rect.position.y + preview_rect.size.y) * CELL_SIZE * zoom) - scroll_y
	ci.draw_rect(Rect2(screen_x1, screen_y1, screen_x2 - screen_x1, screen_y2 - screen_y1), Color(1.0, 1.0, 1.0, 0.15))
	ci.draw_rect(Rect2(screen_x1, screen_y1, screen_x2 - screen_x1, screen_y2 - screen_y1), Color.WHITE, false, 2.0)

func _draw_cells(ci: CanvasItem, doc: MapDocument, cx: int, cy: int, cw: int, ch: int,
		zoom: float, scroll_x: int, scroll_y: int, brush_cursor_pos: Vector2i) -> void:
	for y in range(doc.height):
		for x in range(doc.width):
			var cell = doc.cells[y * doc.width + x]
			var density = cell["density"]
			var stream_dir = cell["stream_dir"]

			var screen_x = cx + (x * CELL_SIZE * zoom) - scroll_x
			var screen_y = cy + (y * CELL_SIZE * zoom) - scroll_y
			var size = CELL_SIZE * zoom

			if screen_x + size < cx or screen_x > cx + cw:
				continue
			if screen_y + size < cy or screen_y > cy + ch:
				continue

			if stream_dir == MapDocument.StreamDir.NONE:
				var tex = terrain_textures[density]
				if tex:
					ci.draw_texture_rect(tex, Rect2(screen_x, screen_y, size, size), false)
				else:
					ci.draw_rect(Rect2(screen_x, screen_y, size, size), Color.GRAY)
			else:
				_draw_stream_cell(ci, screen_x, screen_y, size, stream_dir)

			if Vector2i(x, y) == brush_cursor_pos:
				ci.draw_rect(Rect2(screen_x, screen_y, size, size), BRUSH_COLOR, false, 2.0)

			ci.draw_rect(Rect2(screen_x, screen_y, size, size), GRID_COLOR, false)

func _draw_stream_cell(ci: CanvasItem, screen_x: float, screen_y: float, size: float, stream_dir: int) -> void:
	if stream_dir in [MapDocument.StreamDir.EAST, MapDocument.StreamDir.WEST]:
		if stream_h_texture:
			if stream_dir == MapDocument.StreamDir.WEST:
				ci.draw_texture_rect(stream_h_texture, Rect2(screen_x + size, screen_y, -size, size), false)
			else:
				ci.draw_texture_rect(stream_h_texture, Rect2(screen_x, screen_y, size, size), false)
		else:
			ci.draw_rect(Rect2(screen_x, screen_y, size, size), Color(0.4, 0.2, 0.2))
	else:
		if stream_v_texture:
			if stream_dir == MapDocument.StreamDir.NORTH:
				ci.draw_texture_rect(stream_v_texture, Rect2(screen_x, screen_y + size, size, -size), false)
			else:
				ci.draw_texture_rect(stream_v_texture, Rect2(screen_x, screen_y, size, size), false)
		else:
			ci.draw_rect(Rect2(screen_x, screen_y, size, size), Color(0.4, 0.2, 0.2))

	var center = Vector2(screen_x + size * 0.5, screen_y + size * 0.5)
	var direction = _stream_to_vec(stream_dir)
	var arrow_length = size * 0.5 - 3.5

	var base = center - direction * arrow_length * 0.5
	var tip = center + direction * arrow_length
	ci.draw_line(base, tip, STREAM_COLOR, 1.5)

	var perp = Vector2(-direction.y, direction.x) * 2.5
	var head_base = tip - direction * 3.5
	ci.draw_line(tip, head_base + perp, STREAM_COLOR, 1.5)
	ci.draw_line(tip, head_base - perp, STREAM_COLOR, 1.5)

func _stream_to_vec(dir: int) -> Vector2:
	match dir:
		MapDocument.StreamDir.NORTH: return Vector2(0, -1)
		MapDocument.StreamDir.SOUTH: return Vector2(0, 1)
		MapDocument.StreamDir.EAST: return Vector2(1, 0)
		MapDocument.StreamDir.WEST: return Vector2(-1, 0)
	return Vector2.ZERO

func _draw_zones(ci: CanvasItem, doc: MapDocument, cx: int, cy: int, zoom: float,
		scroll_x: int, scroll_y: int, selection: Dictionary) -> void:
	for i in range(doc.injection_zones.size()):
		var zone = doc.injection_zones[i]
		var rect = zone["rect"]
		var screen_x1 = cx + (rect.position.x * CELL_SIZE * zoom) - scroll_x
		var screen_y1 = cy + (rect.position.y * CELL_SIZE * zoom) - scroll_y
		var screen_x2 = cx + ((rect.position.x + rect.size.x) * CELL_SIZE * zoom) - scroll_x
		var screen_y2 = cy + ((rect.position.y + rect.size.y) * CELL_SIZE * zoom) - scroll_y
		var color = Color(0.25, 0.55, 1.0, 0.2) if zone["player"] == 0 else Color(1.0, 0.3, 0.25, 0.2)
		ci.draw_rect(Rect2(screen_x1, screen_y1, screen_x2 - screen_x1, screen_y2 - screen_y1), color)

		if selection.get("type") == "zone" and selection.get("index") == i:
			ci.draw_rect(Rect2(screen_x1, screen_y1, screen_x2 - screen_x1, screen_y2 - screen_y1), Color(1.0, 1.0, 1.0, 0.3))

			var handle_size = 8
			var corners = [
				Vector2(screen_x1, screen_y1),
				Vector2(screen_x2, screen_y1),
				Vector2(screen_x1, screen_y2),
				Vector2(screen_x2, screen_y2),
			]
			for corner in corners:
				ci.draw_rect(Rect2(corner - Vector2(handle_size / 2, handle_size / 2), Vector2(handle_size, handle_size)), Color.YELLOW)

func _draw_habitas(ci: CanvasItem, doc: MapDocument, cx: int, cy: int, zoom: float,
		scroll_x: int, scroll_y: int, selection: Dictionary) -> void:
	for i in range(doc.habitas_points.size()):
		var hp = doc.habitas_points[i]
		var screen_x = cx + (hp.x * CELL_SIZE * zoom) - scroll_x
		var screen_y = cy + (hp.y * CELL_SIZE * zoom) - scroll_y
		if habitas_texture:
			ci.draw_texture_rect(habitas_texture, Rect2(screen_x, screen_y, CELL_SIZE * zoom, CELL_SIZE * zoom), false)

		if selection.get("type") == "habitas" and selection.get("index") == i:
			ci.draw_rect(Rect2(screen_x, screen_y, CELL_SIZE * zoom, CELL_SIZE * zoom), Color(1.0, 1.0, 0.0, 0.4))

func _draw_azn(ci: CanvasItem, doc: MapDocument, cx: int, cy: int, zoom: float,
		scroll_x: int, scroll_y: int, selection: Dictionary, azn_hover_index: int) -> void:
	for i in range(doc.azn_nodes.size()):
		var azn = doc.azn_nodes[i]
		var pos = azn["position"]
		var screen_x = cx + (pos.x * CELL_SIZE * zoom) - scroll_x
		var screen_y = cy + (pos.y * CELL_SIZE * zoom) - scroll_y
		if azn_texture:
			ci.draw_texture_rect(azn_texture, Rect2(screen_x, screen_y, CELL_SIZE * zoom, CELL_SIZE * zoom), false)

		if selection.get("type") == "azn" and selection.get("index") == i:
			ci.draw_rect(Rect2(screen_x, screen_y, CELL_SIZE * zoom, CELL_SIZE * zoom), Color(1.0, 1.0, 0.0, 0.4))

	if azn_hover_index >= 0 and azn_hover_index < doc.azn_nodes.size():
		var azn = doc.azn_nodes[azn_hover_index]
		var pos = azn["position"]
		var screen_x = cx + (pos.x * CELL_SIZE * zoom) - scroll_x
		var screen_y = cy + (pos.y * CELL_SIZE * zoom) - scroll_y
		var quantity_text = str(azn["quantity"])
		var font = ci.get_theme_font("font")
		if font:
			ci.draw_string(font, Vector2(screen_x + CELL_SIZE * zoom / 2 - 5, screen_y - 15),
				quantity_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.WHITE)

class_name MapRenderer
extends Node2D

const CELL_SIZE := 16

# ── tile textures ─────────────────────────────────────────────────────────────
const TILE_TEX: Dictionary = {
	MapData.Density.LOW:    preload("res://assets/tiles/tile_low.png"),
	MapData.Density.MEDIUM: preload("res://assets/tiles/tile_medium.png"),
	MapData.Density.HIGH:   preload("res://assets/tiles/tile_high.png"),
	MapData.Density.BONE:   preload("res://assets/tiles/tile_bone.png"),
}
const STREAM_TEX_H: Texture2D = preload("res://assets/tiles/tile_stream_h.png")
const STREAM_TEX_V: Texture2D = preload("res://assets/tiles/tile_stream_v.png")

# ── marker textures ────────────────────────────────────────────────────────────
const HABITAS_NEUTRAL: Texture2D = preload("res://assets/markers/habitas_neutral.png")
const HABITAS_OWNED:   Texture2D = preload("res://assets/markers/habitas_owned.png")
const AZN_NODE_TEX:    Texture2D = preload("res://assets/markers/azn_node.png")

# ── colours still used for the grid line and stream arrow overlay ──────────────
const GRID_COLOR   := Color(0.00, 0.00, 0.00, 0.12)
const STREAM_COLOR := Color(0.70, 0.25, 0.25, 0.80)
const OWNED_BLEND  := 0.30   # lerp toward white for the owned-HP tint

const PLAYER_COLORS: Array = [
	Color(0.25, 0.55, 1.00),
	Color(1.00, 0.30, 0.25),
	Color(0.20, 0.85, 0.40),
	Color(1.00, 0.85, 0.15),
]

var _map: MapData         = null
var _habitas_state: Array = []
var _azn_state: Array     = []

func setup(map: MapData) -> void:
	_map = map
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()

func update_overlay(habitas: Array, azn: Array) -> void:
	_habitas_state = habitas
	_azn_state     = azn
	queue_redraw()

func cell_to_pixel(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL_SIZE + CELL_SIZE * 0.5,
				   cell.y * CELL_SIZE + CELL_SIZE * 0.5)

func pixel_to_cell(px: Vector2) -> Vector2i:
	return Vector2i(int(px.x / CELL_SIZE), int(px.y / CELL_SIZE))

func map_pixel_size() -> Vector2:
	if _map == null:
		return Vector2.ZERO
	return Vector2(_map.width * CELL_SIZE, _map.height * CELL_SIZE)

# ── drawing ───────────────────────────────────────────────────────────────────

func _draw() -> void:
	if _map == null:
		return
	_draw_cells()
	_draw_habitas_points()
	_draw_azn_nodes()

func _draw_cells() -> void:
	for y in _map.height:
		for x in _map.width:
			var cell    := _map.get_cell(x, y)
			var density := cell["density"] as int
			var stream  := cell["stream_dir"] as int
			var rx      := x * CELL_SIZE
			var ry      := y * CELL_SIZE

			if stream != MapData.StreamDir.NONE:
				_draw_stream_cell(rx, ry, stream)
			else:
				var tex: Texture2D = TILE_TEX.get(density, TILE_TEX[MapData.Density.LOW])
				draw_texture_rect(tex, Rect2(rx, ry, CELL_SIZE, CELL_SIZE), false)

			draw_rect(Rect2(rx, ry, CELL_SIZE, CELL_SIZE), GRID_COLOR, false)

func _draw_stream_cell(rx: int, ry: int, dir: int) -> void:
	# Draw the biological stream texture (with baked arrows), then add a crisp
	# procedural arrow on top so the direction reads clearly at small sizes.
	match dir:
		MapData.StreamDir.EAST:
			draw_texture_rect(STREAM_TEX_H, Rect2(rx, ry, CELL_SIZE, CELL_SIZE), false)
		MapData.StreamDir.WEST:
			# Flip horizontally via negative width
			draw_texture_rect(STREAM_TEX_H, Rect2(rx + CELL_SIZE, ry, -CELL_SIZE, CELL_SIZE), false)
		MapData.StreamDir.SOUTH:
			draw_texture_rect(STREAM_TEX_V, Rect2(rx, ry, CELL_SIZE, CELL_SIZE), false)
		MapData.StreamDir.NORTH:
			# Flip vertically via negative height
			draw_texture_rect(STREAM_TEX_V, Rect2(rx, ry + CELL_SIZE, CELL_SIZE, -CELL_SIZE), false)

	# Procedural arrow overlay for clarity
	var center := Vector2(rx + CELL_SIZE * 0.5, ry + CELL_SIZE * 0.5)
	var vec    := _stream_vec(dir)
	var half   := CELL_SIZE * 0.5 - 3.5
	var tip    := center + vec * half
	var base   := center - vec * half * 0.5
	var perp   := Vector2(-vec.y, vec.x) * 2.5
	draw_line(base, tip, STREAM_COLOR, 1.5)
	draw_line(tip, tip - vec * 3.5 + perp, STREAM_COLOR, 1.5)
	draw_line(tip, tip - vec * 3.5 - perp, STREAM_COLOR, 1.5)

func _draw_habitas_points() -> void:
	for hp: Dictionary in _habitas_state:
		var p    := _pos(hp)
		var rect := Rect2(p.x * CELL_SIZE, p.y * CELL_SIZE, CELL_SIZE, CELL_SIZE)
		var own: int = hp.get("owner", -1)
		if own == -1:
			draw_texture_rect(HABITAS_NEUTRAL, rect, false)
		else:
			var base_col: Color = PLAYER_COLORS[own % PLAYER_COLORS.size()]
			draw_texture_rect(HABITAS_OWNED, rect, false, base_col.lerp(Color.WHITE, OWNED_BLEND))

func _draw_azn_nodes() -> void:
	for node: Dictionary in _azn_state:
		var qty: int = node.get("qty", node.get("quantity", 0))
		if qty == 0:
			continue
		var p    := _pos(node)
		var rect := Rect2(p.x * CELL_SIZE, p.y * CELL_SIZE, CELL_SIZE, CELL_SIZE)
		draw_texture_rect(AZN_NODE_TEX, rect, false)

# ── helpers ───────────────────────────────────────────────────────────────────

static func _pos(d: Dictionary) -> Vector2i:
	if d.has("position"):
		return d["position"] as Vector2i
	var p = d.get("pos", [0, 0])
	if p is Array:
		return Vector2i(int(p[0]), int(p[1]))
	return p as Vector2i

static func _stream_vec(dir: int) -> Vector2:
	match dir:
		MapData.StreamDir.NORTH: return Vector2( 0, -1)
		MapData.StreamDir.SOUTH: return Vector2( 0,  1)
		MapData.StreamDir.EAST:  return Vector2( 1,  0)
		MapData.StreamDir.WEST:  return Vector2(-1,  0)
	return Vector2.ZERO

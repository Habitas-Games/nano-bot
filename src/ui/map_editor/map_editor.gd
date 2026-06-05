class_name MapEditor
extends Control

# Phase 1: Core Rendering - Display Maps Exactly Like Simulator

const CELL_SIZE := 16

# Enums (match simulator)
enum Density { LOW, MEDIUM, HIGH, BONE }
enum StreamDir { NONE, NORTH, SOUTH, EAST, WEST }

# Textures
var terrain_textures: Dictionary = {}
var stream_h_texture: Texture2D
var stream_v_texture: Texture2D
var habitas_texture: Texture2D
var azn_texture: Texture2D

# Map state
var map_width: int = 60
var map_height: int = 60
var cells: Array = []  # cells[y * width + x] = {density: int, stream_dir: int}
var habitas_points: Array = []
var azn_nodes: Array = []
var injection_zones: Array = []

# View state
var zoom: float = 1.0
var scroll_x: int = 0
var scroll_y: int = 0
var canvas_rect: Rect2 = Rect2()

# Constants
const STREAM_COLOR := Color(0.70, 0.25, 0.25, 0.80)
const GRID_COLOR := Color(0.00, 0.00, 0.00, 0.12)
const MIN_ZOOM := 0.5
const MAX_ZOOM := 3.0
const ZOOM_STEP := 0.1

func _ready() -> void:
	_load_textures()
	_setup_ui()
	_load_default_map()

func _load_textures() -> void:
	"""Load all texture assets"""
	terrain_textures[Density.LOW] = load("res://assets/tiles/tile_low.png")
	terrain_textures[Density.MEDIUM] = load("res://assets/tiles/tile_medium.png")
	terrain_textures[Density.HIGH] = load("res://assets/tiles/tile_high.png")
	terrain_textures[Density.BONE] = load("res://assets/tiles/tile_bone.png")

	stream_h_texture = load("res://assets/tiles/tile_stream_h.png")
	stream_v_texture = load("res://assets/tiles/tile_stream_v.png")

	habitas_texture = load("res://assets/markers/habitas_neutral.png")
	azn_texture = load("res://assets/markers/azn_node.png")

func _setup_ui() -> void:
	"""Create minimal UI: just buttons and labels"""
	var root = HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# LEFT: Canvas area
	var left = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(left)

	# Status bar
	var status = Label.new()
	status.text = "Terrain: LOW | Scroll: zoom | Middle-drag: pan"
	status.add_theme_font_size_override("font_size", 10)
	status.custom_minimum_size = Vector2(0, 30)
	left.add_child(status)

	# Toolbar
	var toolbar = HBoxContainer.new()
	toolbar.custom_minimum_size = Vector2(0, 40)
	toolbar.add_theme_constant_override("separation", 5)
	left.add_child(toolbar)

	var load_btn = Button.new()
	load_btn.text = "Load"
	load_btn.pressed.connect(_show_load_dialog)
	toolbar.add_child(load_btn)

	var save_btn = Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(_show_save_dialog)
	toolbar.add_child(save_btn)

	# Canvas spacer (will draw here)
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 500)
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)

	# Scrollbar spacer
	var scroll_spacer = Control.new()
	scroll_spacer.custom_minimum_size = Vector2(0, 15)
	left.add_child(scroll_spacer)

	# RIGHT: Info panel
	var right = PanelContainer.new()
	right.custom_minimum_size = Vector2(200, 0)
	root.add_child(right)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15)
	right.add_theme_stylebox_override("panel", style)

	var info = VBoxContainer.new()
	info.add_theme_constant_override("separation", 10)
	right.add_child(info)

	var title = Label.new()
	title.text = "Map Editor"
	title.add_theme_font_size_override("font_size", 14)
	info.add_child(title)

	var size_label = Label.new()
	size_label.text = "Size: 60x60"
	size_label.add_theme_font_size_override("font_size", 10)
	info.add_child(size_label)

func _load_default_map() -> void:
	"""Load first available map from res://maps/"""
	var dir = DirAccess.open("res://maps/")
	if not dir:
		print("No maps directory")
		_init_blank_map()
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			_load_map_from_file("res://maps/" + file_name)
			return
		file_name = dir.get_next()

	print("No maps found, creating blank")
	_init_blank_map()

func _init_blank_map() -> void:
	"""Create blank 60x60 map"""
	map_width = 60
	map_height = 60
	cells.clear()
	cells.resize(map_width * map_height)

	for i in range(cells.size()):
		cells[i] = {"density": Density.LOW, "stream_dir": StreamDir.NONE}

	habitas_points.clear()
	azn_nodes.clear()
	injection_zones.clear()

	queue_redraw()

func _load_map_from_file(path: String) -> void:
	"""Load map from JSON using simulator format"""
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("Cannot open: " + path)
		return

	var data = JSON.parse_string(file.get_as_text())
	if data == null or typeof(data) != TYPE_DICTIONARY:
		print("Invalid JSON: " + path)
		return

	_init_blank_map()

	# Load dimensions
	map_width = data.get("width", 60)
	map_height = data.get("height", 60)
	cells.resize(map_width * map_height)

	# Initialize all cells to default
	var default_density = _string_to_density(data.get("default_density", "low"))
	for i in range(cells.size()):
		cells[i] = {"density": default_density, "stream_dir": StreamDir.NONE}

	# Load cells with their density and stream
	for cell_data in data.get("cells", []):
		var x = cell_data.get("x", 0)
		var y = cell_data.get("y", 0)

		if x < 0 or x >= map_width or y < 0 or y >= map_height:
			continue

		var density = _string_to_density(cell_data.get("density", "low"))
		var stream_dir = _string_to_stream_dir(cell_data.get("stream", ""))

		var idx = y * map_width + x
		cells[idx] = {"density": density, "stream_dir": stream_dir}

	# Load habitas points
	habitas_points.clear()
	for hp in data.get("habitas_points", []):
		habitas_points.append(Vector2i(hp.get("x", 0), hp.get("y", 0)))

	# Load AZN nodes
	azn_nodes.clear()
	for azn in data.get("azn_nodes", []):
		azn_nodes.append({
			"position": Vector2i(azn.get("x", 0), azn.get("y", 0)),
			"quantity": azn.get("quantity", 10)
		})

	# Load injection zones
	injection_zones.clear()
	for zone in data.get("injection_zones", []):
		var x1 = zone.get("x1", 0)
		var y1 = zone.get("y1", 0)
		var x2 = zone.get("x2", 0)
		var y2 = zone.get("y2", 0)
		injection_zones.append({
			"player": zone.get("player", 0),
			"rect": Rect2i(x1, y1, x2 - x1 + 1, y2 - y1 + 1)
		})

	zoom = 1.0
	scroll_x = 0
	scroll_y = 0

	queue_redraw()

func _string_to_density(s: String) -> int:
	"""Convert string to Density enum"""
	match s:
		"low": return Density.LOW
		"medium": return Density.MEDIUM
		"high": return Density.HIGH
		"bone": return Density.BONE
	return Density.LOW

func _string_to_stream_dir(s: String) -> int:
	"""Convert string to StreamDir enum"""
	match s:
		"north": return StreamDir.NORTH
		"south": return StreamDir.SOUTH
		"east": return StreamDir.EAST
		"west": return StreamDir.WEST
	return StreamDir.NONE

func _draw() -> void:
	"""Render the map exactly like simulator"""
	# Calculate canvas area
	canvas_rect = Rect2(0, 30, get_size().x - 200, get_size().y - 45)
	var cx = int(canvas_rect.position.x)
	var cy = int(canvas_rect.position.y)
	var cw = int(canvas_rect.size.x)
	var ch = int(canvas_rect.size.y)

	# Background
	draw_rect(Rect2(cx, cy, cw, ch), Color(0.2, 0.2, 0.2))

	# Draw cells
	for y in range(map_height):
		for x in range(map_width):
			var idx = y * map_width + x
			var cell = cells[idx]
			var density = cell["density"]
			var stream_dir = cell["stream_dir"]

			var screen_x = cx + (x * CELL_SIZE * zoom) - scroll_x
			var screen_y = cy + (y * CELL_SIZE * zoom) - scroll_y
			var size = CELL_SIZE * zoom

			# Skip if off-screen
			if screen_x + size < cx or screen_x > cx + cw:
				continue
			if screen_y + size < cy or screen_y > cy + ch:
				continue

			# Draw cell content
			if stream_dir == StreamDir.NONE:
				# Regular terrain cell
				var tex = terrain_textures[density]
				if tex:
					draw_texture_rect(tex, Rect2(screen_x, screen_y, size, size), false)
				else:
					draw_rect(Rect2(screen_x, screen_y, size, size), Color.GRAY)
			else:
				# Stream cell: texture + arrow
				_draw_stream_cell(screen_x, screen_y, size, stream_dir)

			# Grid line
			draw_rect(Rect2(screen_x, screen_y, size, size), GRID_COLOR, false)

	# Draw injection zones
	for zone in injection_zones:
		var rect = zone["rect"]
		var screen_x1 = cx + (rect.position.x * CELL_SIZE * zoom) - scroll_x
		var screen_y1 = cy + (rect.position.y * CELL_SIZE * zoom) - scroll_y
		var screen_x2 = cx + ((rect.position.x + rect.size.x) * CELL_SIZE * zoom) - scroll_x
		var screen_y2 = cy + ((rect.position.y + rect.size.y) * CELL_SIZE * zoom) - scroll_y

		var color = Color(0.25, 0.55, 1.0, 0.2) if zone["player"] == 0 else Color(1.0, 0.3, 0.25, 0.2)
		draw_rect(Rect2(screen_x1, screen_y1, screen_x2 - screen_x1, screen_y2 - screen_y1), color)

	# Draw habitas points
	for hp in habitas_points:
		var screen_x = cx + (hp.x * CELL_SIZE * zoom) - scroll_x
		var screen_y = cy + (hp.y * CELL_SIZE * zoom) - scroll_y
		if habitas_texture:
			draw_texture_rect(habitas_texture, Rect2(screen_x, screen_y, CELL_SIZE * zoom, CELL_SIZE * zoom), false)

	# Draw AZN nodes
	for azn in azn_nodes:
		var pos = azn["position"]
		var screen_x = cx + (pos.x * CELL_SIZE * zoom) - scroll_x
		var screen_y = cy + (pos.y * CELL_SIZE * zoom) - scroll_y
		if azn_texture:
			draw_texture_rect(azn_texture, Rect2(screen_x, screen_y, CELL_SIZE * zoom, CELL_SIZE * zoom), false)

func _draw_stream_cell(screen_x: float, screen_y: float, size: float, stream_dir: int) -> void:
	"""Draw stream texture + procedural arrow overlay"""
	# Draw stream background texture
	if stream_dir in [StreamDir.EAST, StreamDir.WEST]:
		if stream_h_texture:
			if stream_dir == StreamDir.WEST:
				draw_texture_rect(stream_h_texture, Rect2(screen_x + size, screen_y, -size, size), false)
			else:
				draw_texture_rect(stream_h_texture, Rect2(screen_x, screen_y, size, size), false)
	else:  # NORTH, SOUTH
		if stream_v_texture:
			if stream_dir == StreamDir.NORTH:
				draw_texture_rect(stream_v_texture, Rect2(screen_x, screen_y + size, size, -size), false)
			else:
				draw_texture_rect(stream_v_texture, Rect2(screen_x, screen_y, size, size), false)

	# Draw procedural arrow overlay
	var center = Vector2(screen_x + size * 0.5, screen_y + size * 0.5)
	var direction = _stream_to_vec(stream_dir)
	var arrow_length = size * 0.5 - 3.5

	# Arrow shaft
	var base = center - direction * arrow_length * 0.5
	var tip = center + direction * arrow_length
	draw_line(base, tip, STREAM_COLOR, 1.5)

	# Arrowhead (2 perpendicular lines)
	var perp = Vector2(-direction.y, direction.x) * 2.5
	var head_base = tip - direction * 3.5
	draw_line(tip, head_base + perp, STREAM_COLOR, 1.5)
	draw_line(tip, head_base - perp, STREAM_COLOR, 1.5)

func _stream_to_vec(dir: int) -> Vector2:
	"""Convert stream direction to unit vector"""
	match dir:
		StreamDir.NORTH: return Vector2(0, -1)
		StreamDir.SOUTH: return Vector2(0, 1)
		StreamDir.EAST: return Vector2(1, 0)
		StreamDir.WEST: return Vector2(-1, 0)
	return Vector2.ZERO

func _input(event: InputEvent) -> void:
	"""Handle zoom and pan"""
	# Zoom with scroll wheel
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom = min(zoom + ZOOM_STEP, MAX_ZOOM)
			queue_redraw()
			get_tree().root.set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom = max(zoom - ZOOM_STEP, MIN_ZOOM)
			queue_redraw()
			get_tree().root.set_input_as_handled()
			return

	# Pan with middle-click drag
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MIDDLE:
		var delta = event.relative
		var max_x = max(0, int(map_width * CELL_SIZE * zoom - canvas_rect.size.x))
		var max_y = max(0, int(map_height * CELL_SIZE * zoom - canvas_rect.size.y))
		scroll_x = clampi(scroll_x - int(delta.x), 0, max_x)
		scroll_y = clampi(scroll_y - int(delta.y), 0, max_y)
		queue_redraw()

func _show_load_dialog() -> void:
	"""Show load map dialog"""
	var dir = DirAccess.open("res://maps/")
	if not dir:
		print("Maps directory not found")
		return

	var files = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			files.append(file_name)
		file_name = dir.get_next()

	if files.is_empty():
		print("No maps found")
		return

	var popup = PopupMenu.new()
	add_child(popup)

	for i in range(files.size()):
		popup.add_item(files[i].trim_suffix(".json"), i)

	popup.id_pressed.connect(func(id: int):
		_load_map_from_file("res://maps/" + files[id])
		popup.queue_free()
	)

	popup.popup_centered_ratio(0.3)

func _show_save_dialog() -> void:
	"""Show save map dialog"""
	print("Save not yet implemented (Phase 5)")

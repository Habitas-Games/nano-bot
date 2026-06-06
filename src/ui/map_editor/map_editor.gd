class_name MapEditor
extends Control

# Phase 1-2: Core Rendering + Terrain Editing (Per Spec)

const CELL_SIZE := 16
const BRUSH_INDICATOR_SIZE := CELL_SIZE  # Visual brush indicator

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
var cells: Array = []
var habitas_points: Array = []
var azn_nodes: Array = []
var injection_zones: Array = []

# View state
var zoom: float = 1.0
var scroll_x: int = 0
var scroll_y: int = 0
var canvas_rect: Rect2 = Rect2()

# Editing state (Phase 2)
var selected_density: int = Density.LOW
var selected_stream_dir: int = StreamDir.NORTH
var placement_mode: String = "none"  # "none", "habitas", "azn", "zone"
var is_painting: bool = false
var last_paint_pos: Vector2i = Vector2i(-1, -1)

# UI References
var status_label: Label
var terrain_buttons: Dictionary = {}
var stream_buttons: Dictionary = {}
var undo_btn: Button
var brush_cursor_pos: Vector2i = Vector2i(-1, -1)

# History
var history: Array = []
var history_index: int = -1
const MAX_HISTORY := 50

# Constants
const STREAM_COLOR := Color(0.70, 0.25, 0.25, 0.80)
const GRID_COLOR := Color(0.00, 0.00, 0.00, 0.12)
const BRUSH_COLOR := Color(1.0, 1.0, 1.0, 0.5)  # Highlight brush cell
const MIN_ZOOM := 0.5
const MAX_ZOOM := 3.0
const ZOOM_STEP := 0.1

func _ready() -> void:
	_load_textures()
	_setup_ui()
	_load_default_map()

func _load_textures() -> void:
	terrain_textures[Density.LOW] = load("res://assets/tiles/tile_low.png")
	terrain_textures[Density.MEDIUM] = load("res://assets/tiles/tile_medium.png")
	terrain_textures[Density.HIGH] = load("res://assets/tiles/tile_high.png")
	terrain_textures[Density.BONE] = load("res://assets/tiles/tile_bone.png")

	stream_h_texture = load("res://assets/tiles/tile_stream_h.png")
	stream_v_texture = load("res://assets/tiles/tile_stream_v.png")

	habitas_texture = load("res://assets/markers/habitas_neutral.png")
	azn_texture = load("res://assets/markers/azn_node.png")

func _setup_ui() -> void:
	var root = HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# LEFT: Canvas area
	var left = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(left)

	# Status bar
	status_label = Label.new()
	status_label.text = "Terrain: LOW | Click: paint | Right-click: fill | Scroll: zoom"
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.custom_minimum_size = Vector2(0, 30)
	left.add_child(status_label)

	# Toolbar (empty for now - buttons moved to right panel)

	# Canvas spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 500)
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)

	# Scrollbar spacer
	var scroll_spacer = Control.new()
	scroll_spacer.custom_minimum_size = Vector2(0, 15)
	left.add_child(scroll_spacer)

	# RIGHT: Control panel with expandable sections
	var right = PanelContainer.new()
	right.custom_minimum_size = Vector2(250, 0)
	root.add_child(right)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15)
	right.add_theme_stylebox_override("panel", style)

	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	right.add_child(scroll)

	var panel = VBoxContainer.new()
	panel.add_theme_constant_override("separation", 8)
	scroll.add_child(panel)

	var title = Label.new()
	title.text = "Map Editor"
	title.add_theme_font_size_override("font_size", 14)
	panel.add_child(title)

	# TERRAIN SECTION
	var terrain_header = Label.new()
	terrain_header.text = "▼ Terrain"
	terrain_header.add_theme_font_size_override("font_size", 11)
	panel.add_child(terrain_header)

	var terrain_grid = GridContainer.new()
	terrain_grid.columns = 4
	terrain_grid.add_theme_constant_override("h_separation", 2)
	terrain_grid.add_theme_constant_override("v_separation", 2)
	panel.add_child(terrain_grid)

	for density_val in [Density.LOW, Density.MEDIUM, Density.HIGH, Density.BONE]:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(48, 48)
		btn.toggle_mode = true
		
		# Set button texture/appearance
		var tex = terrain_textures[density_val]
		if tex:
			btn.icon = tex
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		# Tooltip with cost
		var cost_text = _get_density_cost_text(density_val)
		btn.tooltip_text = cost_text
		
		if density_val == Density.LOW:
			btn.button_pressed = true
		
		var density_copy = density_val
		btn.pressed.connect(func():
			selected_density = density_copy
			_update_density_buttons()
			_update_status()
		)
		
		terrain_grid.add_child(btn)
		terrain_buttons[density_val] = btn

	panel.add_child(HSeparator.new())

	# STREAM SECTION
	var stream_header = Label.new()
	stream_header.text = "▼ Stream Direction"
	stream_header.add_theme_font_size_override("font_size", 11)
	panel.add_child(stream_header)

	var stream_grid = GridContainer.new()
	stream_grid.columns = 4
	stream_grid.add_theme_constant_override("h_separation", 2)
	stream_grid.add_theme_constant_override("v_separation", 2)
	panel.add_child(stream_grid)

	var directions = [
		{"dir": StreamDir.NORTH, "label": "↑", "hint": "N"},
		{"dir": StreamDir.SOUTH, "label": "↓", "hint": "S"},
		{"dir": StreamDir.EAST, "label": "→", "hint": "E"},
		{"dir": StreamDir.WEST, "label": "←", "hint": "W"},
	]

	for dir_data in directions:
		var btn = Button.new()
		btn.text = dir_data["label"]
		btn.custom_minimum_size = Vector2(48, 48)
		btn.toggle_mode = true
		btn.tooltip_text = dir_data["hint"]
		
		if dir_data["dir"] == StreamDir.NORTH:
			btn.button_pressed = true
		
		var dir_copy = dir_data["dir"]
		btn.pressed.connect(func():
			selected_stream_dir = dir_copy
			_update_stream_buttons()
			_update_status()
		)
		
		stream_grid.add_child(btn)
		stream_buttons[dir_data["dir"]] = btn

	panel.add_child(HSeparator.new())

	# ELEMENTS SECTION
	var elem_header = Label.new()
	elem_header.text = "▼ Elements"
	elem_header.add_theme_font_size_override("font_size", 11)
	panel.add_child(elem_header)

	for elem_data in [
		{"name": "habitas", "label": "Place Habitas"},
		{"name": "azn", "label": "Place AZN"},
		{"name": "zone", "label": "Place Zone"},
	]:
		var btn = Button.new()
		btn.text = elem_data["label"]
		btn.custom_minimum_size = Vector2(0, 28)
		var mode_name = elem_data["name"]
		btn.pressed.connect(func():
			placement_mode = mode_name
			_update_status()
		)
		panel.add_child(btn)

	panel.add_child(HSeparator.new())

	# TOOLS SECTION
	var tools_header = Label.new()
	tools_header.text = "▼ Tools"
	tools_header.add_theme_font_size_override("font_size", 11)
	panel.add_child(tools_header)

	var load_btn = Button.new()
	load_btn.text = "Load"
	load_btn.custom_minimum_size = Vector2(0, 28)
	load_btn.pressed.connect(_show_load_dialog)
	panel.add_child(load_btn)

	var save_btn = Button.new()
	save_btn.text = "Save"
	save_btn.custom_minimum_size = Vector2(0, 28)
	save_btn.pressed.connect(_show_save_dialog)
	panel.add_child(save_btn)

	var clear_btn = Button.new()
	clear_btn.text = "Clear Map"
	clear_btn.custom_minimum_size = Vector2(0, 28)
	clear_btn.pressed.connect(_clear_map)
	panel.add_child(clear_btn)

	var border_btn = Button.new()
	border_btn.text = "Add Border"
	border_btn.custom_minimum_size = Vector2(0, 28)
	border_btn.pressed.connect(_add_border)
	panel.add_child(border_btn)

	panel.add_child(HSeparator.new())

	# HISTORY SECTION
	var history_header = Label.new()
	history_header.text = "▼ History"
	history_header.add_theme_font_size_override("font_size", 11)
	panel.add_child(history_header)

	undo_btn = Button.new()
	undo_btn.text = "Undo"
	undo_btn.custom_minimum_size = Vector2(0, 28)
	undo_btn.disabled = true
	undo_btn.pressed.connect(_undo)
	panel.add_child(undo_btn)

func _get_density_cost_text(density: int) -> String:
	match density:
		Density.LOW: return "LOW\n2 turns"
		Density.MEDIUM: return "MEDIUM\n3 turns"
		Density.HIGH: return "HIGH\n4 turns"
		Density.BONE: return "BONE\nblocked"
	return ""

func _load_default_map() -> void:
	var dir = DirAccess.open("res://maps/")
	if not dir:
		_init_blank_map()
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			_load_map_from_file("res://maps/" + file_name)
			return
		file_name = dir.get_next()

	_init_blank_map()

func _init_blank_map() -> void:
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
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("Cannot open: " + path)
		return

	var data = JSON.parse_string(file.get_as_text())
	if data == null or typeof(data) != TYPE_DICTIONARY:
		print("Invalid JSON: " + path)
		return

	_init_blank_map()

	map_width = data.get("width", 60)
	map_height = data.get("height", 60)
	cells.resize(map_width * map_height)

	var default_density = _string_to_density(data.get("default_density", "low"))
	for i in range(cells.size()):
		cells[i] = {"density": default_density, "stream_dir": StreamDir.NONE}

	for cell_data in data.get("cells", []):
		var x = cell_data.get("x", 0)
		var y = cell_data.get("y", 0)

		if x < 0 or x >= map_width or y < 0 or y >= map_height:
			continue

		var density = _string_to_density(cell_data.get("density", "low"))
		var stream_dir = _string_to_stream_dir(cell_data.get("stream", ""))

		var idx = y * map_width + x
		cells[idx] = {"density": density, "stream_dir": stream_dir}

	habitas_points.clear()
	for hp in data.get("habitas_points", []):
		habitas_points.append(Vector2i(hp.get("x", 0), hp.get("y", 0)))

	azn_nodes.clear()
	for azn in data.get("azn_nodes", []):
		azn_nodes.append({
			"position": Vector2i(azn.get("x", 0), azn.get("y", 0)),
			"quantity": azn.get("quantity", 10)
		})

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
	history.clear()
	history_index = -1
	_save_state()

	_update_status()
	queue_redraw()

func _string_to_density(s: String) -> int:
	match s:
		"low": return Density.LOW
		"medium": return Density.MEDIUM
		"high": return Density.HIGH
		"bone": return Density.BONE
	return Density.LOW

func _density_to_string(d: int) -> String:
	match d:
		Density.LOW: return "low"
		Density.MEDIUM: return "medium"
		Density.HIGH: return "high"
		Density.BONE: return "bone"
	return "low"

func _string_to_stream_dir(s: String) -> int:
	match s:
		"north": return StreamDir.NORTH
		"south": return StreamDir.SOUTH
		"east": return StreamDir.EAST
		"west": return StreamDir.WEST
	return StreamDir.NONE

func _stream_dir_to_string(d: int) -> String:
	match d:
		StreamDir.NORTH: return "north"
		StreamDir.SOUTH: return "south"
		StreamDir.EAST: return "east"
		StreamDir.WEST: return "west"
	return ""

func _draw() -> void:
	canvas_rect = Rect2(0, 30, get_size().x - 250, get_size().y - 45)
	var cx = int(canvas_rect.position.x)
	var cy = int(canvas_rect.position.y)
	var cw = int(canvas_rect.size.x)
	var ch = int(canvas_rect.size.y)

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

			if screen_x + size < cx or screen_x > cx + cw:
				continue
			if screen_y + size < cy or screen_y > cy + ch:
				continue

			# Draw cell content
			if stream_dir == StreamDir.NONE:
				var tex = terrain_textures[density]
				if tex:
					draw_texture_rect(tex, Rect2(screen_x, screen_y, size, size), false)
				else:
					draw_rect(Rect2(screen_x, screen_y, size, size), Color.GRAY)
			else:
				_draw_stream_cell(screen_x, screen_y, size, stream_dir)

			# Brush indicator (when painting)
			if Vector2i(x, y) == brush_cursor_pos:
				draw_rect(Rect2(screen_x, screen_y, size, size), BRUSH_COLOR, false, 2.0)

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
	if stream_dir in [StreamDir.EAST, StreamDir.WEST]:
		if stream_h_texture:
			if stream_dir == StreamDir.WEST:
				draw_texture_rect(stream_h_texture, Rect2(screen_x + size, screen_y, -size, size), false)
			else:
				draw_texture_rect(stream_h_texture, Rect2(screen_x, screen_y, size, size), false)
	else:
		if stream_v_texture:
			if stream_dir == StreamDir.NORTH:
				draw_texture_rect(stream_v_texture, Rect2(screen_x, screen_y + size, size, -size), false)
			else:
				draw_texture_rect(stream_v_texture, Rect2(screen_x, screen_y, size, size), false)

	var center = Vector2(screen_x + size * 0.5, screen_y + size * 0.5)
	var direction = _stream_to_vec(stream_dir)
	var arrow_length = size * 0.5 - 3.5

	var base = center - direction * arrow_length * 0.5
	var tip = center + direction * arrow_length
	draw_line(base, tip, STREAM_COLOR, 1.5)

	var perp = Vector2(-direction.y, direction.x) * 2.5
	var head_base = tip - direction * 3.5
	draw_line(tip, head_base + perp, STREAM_COLOR, 1.5)
	draw_line(tip, head_base - perp, STREAM_COLOR, 1.5)

func _stream_to_vec(dir: int) -> Vector2:
	match dir:
		StreamDir.NORTH: return Vector2(0, -1)
		StreamDir.SOUTH: return Vector2(0, 1)
		StreamDir.EAST: return Vector2(1, 0)
		StreamDir.WEST: return Vector2(-1, 0)
	return Vector2.ZERO

func _input(event: InputEvent) -> void:
	var cx = int(canvas_rect.position.x)
	var cy = int(canvas_rect.position.y)
	var cw = int(canvas_rect.size.x)
	var ch = int(canvas_rect.size.y)

	# Zoom
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

		# Left click: paint cell
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var local_pos = event.position
			if _is_in_canvas(local_pos):
				var grid_x = int((local_pos.x - cx + scroll_x) / (CELL_SIZE * zoom))
				var grid_y = int((local_pos.y - cy + scroll_y) / (CELL_SIZE * zoom))

				if grid_x >= 0 and grid_x < map_width and grid_y >= 0 and grid_y < map_height:
					is_painting = true
					last_paint_pos = Vector2i(grid_x, grid_y)
					_paint_cell(grid_x, grid_y)
					get_tree().root.set_input_as_handled()
					return

		# Left release
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			is_painting = false
			brush_cursor_pos = Vector2i(-1, -1)
			queue_redraw()

		# Right click: flood fill
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var local_pos = event.position
			if _is_in_canvas(local_pos):
				var grid_x = int((local_pos.x - cx + scroll_x) / (CELL_SIZE * zoom))
				var grid_y = int((local_pos.y - cy + scroll_y) / (CELL_SIZE * zoom))

				if grid_x >= 0 and grid_x < map_width and grid_y >= 0 and grid_y < map_height:
					_save_state()
					_flood_fill(grid_x, grid_y)
					get_tree().root.set_input_as_handled()
					return

	# Drag paint (exclusive input)
	if event is InputEventMouseMotion and is_painting:
		var local_pos = event.position
		if _is_in_canvas(local_pos):
			var grid_x = int((local_pos.x - cx + scroll_x) / (CELL_SIZE * zoom))
			var grid_y = int((local_pos.y - cy + scroll_y) / (CELL_SIZE * zoom))

			if grid_x >= 0 and grid_x < map_width and grid_y >= 0 and grid_y < map_height:
				brush_cursor_pos = Vector2i(grid_x, grid_y)
				if Vector2i(grid_x, grid_y) != last_paint_pos:
					_paint_cell(grid_x, grid_y)
					last_paint_pos = Vector2i(grid_x, grid_y)

		get_tree().root.set_input_as_handled()
		return

	# Pan (middle-click drag)
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MIDDLE:
		var delta = event.relative
		var max_x = max(0, int(map_width * CELL_SIZE * zoom - cw))
		var max_y = max(0, int(map_height * CELL_SIZE * zoom - ch))
		scroll_x = clampi(scroll_x - int(delta.x), 0, max_x)
		scroll_y = clampi(scroll_y - int(delta.y), 0, max_y)
		queue_redraw()

func _is_in_canvas(pos: Vector2) -> bool:
	var cx = int(canvas_rect.position.x)
	var cy = int(canvas_rect.position.y)
	var cw = int(canvas_rect.size.x)
	var ch = int(canvas_rect.size.y)
	return pos.x >= cx and pos.x < cx + cw and pos.y >= cy and pos.y < cy + ch

func _paint_cell(x: int, y: int) -> void:
	var idx = y * map_width + x
	cells[idx]["density"] = selected_density
	queue_redraw()

func _flood_fill(start_x: int, start_y: int) -> void:
	var start_idx = start_y * map_width + start_x
	var target_density = cells[start_idx]["density"]

	var stack = [[start_x, start_y]]
	var visited = {}

	while stack.size() > 0:
		var pos = stack.pop_back()
		var x = pos[0]
		var y = pos[1]

		if x < 0 or x >= map_width or y < 0 or y >= map_height:
			continue

		var key = str(x) + "," + str(y)
		if key in visited:
			continue

		var idx = y * map_width + x
		if cells[idx]["density"] != target_density:
			continue

		visited[key] = true
		cells[idx]["density"] = selected_density

		stack.append([x + 1, y])
		stack.append([x - 1, y])
		stack.append([x, y + 1])
		stack.append([x, y - 1])

	queue_redraw()

func _clear_map() -> void:
	_save_state()
	for i in range(cells.size()):
		cells[i]["density"] = Density.LOW
	queue_redraw()

func _add_border() -> void:
	_save_state()
	for x in range(map_width):
		cells[0 * map_width + x]["density"] = Density.BONE
		cells[(map_height - 1) * map_width + x]["density"] = Density.BONE
	for y in range(map_height):
		cells[y * map_width + 0]["density"] = Density.BONE
		cells[y * map_width + (map_width - 1)]["density"] = Density.BONE
	queue_redraw()

func _save_state() -> void:
	if history_index < history.size() - 1:
		history.resize(history_index + 1)

	var state: Array = []
	for row in cells:
		state.append(row.duplicate())
	history.append(state)
	history_index = history.size() - 1

	if history.size() > MAX_HISTORY:
		history.pop_front()
		history_index -= 1

	if undo_btn:
		undo_btn.disabled = (history_index <= 0)

func _undo() -> void:
	if history_index > 0:
		history_index -= 1
		cells.clear()
		for row in history[history_index]:
			cells.append(row.duplicate())
		queue_redraw()
		if undo_btn:
			undo_btn.disabled = (history_index <= 0)

func _update_density_buttons() -> void:
	for density_val in terrain_buttons.keys():
		terrain_buttons[density_val].button_pressed = (density_val == selected_density)

func _update_stream_buttons() -> void:
	for stream_val in stream_buttons.keys():
		stream_buttons[stream_val].button_pressed = (stream_val == selected_stream_dir)

func _update_status() -> void:
	var status = ""
	match placement_mode:
		"habitas":
			status = "Mode: Place Habitas | Click to place, drag to move"
		"azn":
			status = "Mode: Place AZN | Click to place, drag to move"
		"zone":
			status = "Mode: Place Zone | Drag to create"
		_:
			var density_name = _density_to_string(selected_density).to_upper()
			status = "Terrain: %s | Click: paint | Right-click: fill | Scroll: zoom" % density_name

	if status_label:
		status_label.text = status

func _show_load_dialog() -> void:
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
	print("Save not yet implemented (Phase 5)")

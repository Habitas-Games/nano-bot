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
var active_tool: String = "terrain"  # "terrain", "stream", "habitas", "azn", "zone"
var selected_density: int = Density.LOW
var selected_stream_dir: int = StreamDir.NORTH
var is_painting: bool = false
var last_paint_pos: Vector2i = Vector2i(-1, -1)

# UI References
var status_label: Label
var terrain_buttons: Dictionary = {}
var stream_buttons: Dictionary = {}
var undo_btn: Button
var brush_cursor_pos: Vector2i = Vector2i(-1, -1)

# Edit mode state
var edit_selected_type: String = ""  # "habitas", "azn", "zone"
var edit_selected_index: int = -1
var edit_drag_offset: Vector2i = Vector2i.ZERO
var zone_resize_corner: String = ""  # "tl", "tr", "bl", "br" or ""

# AZN hover state
var azn_hover_index: int = -1
var azn_hover_time: float = 0.0
const AZN_HOVER_DELAY: float = 0.3

# AZN quantity editor dialog
var azn_edit_dialog: ConfirmationDialog
var azn_quantity_input: SpinBox

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

	# Canvas area
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 500)
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)

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
			_activate_tool("terrain")
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
			_activate_tool("stream")
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
			_activate_tool(mode_name)
			_update_status()
		)
		panel.add_child(btn)

	panel.add_child(HSeparator.new())

	# TOOLS SECTION
	var tools_header = Label.new()
	tools_header.text = "▼ Tools"
	tools_header.add_theme_font_size_override("font_size", 11)
	panel.add_child(tools_header)

	var pan_btn = Button.new()
	pan_btn.text = "Pan ✋"
	pan_btn.custom_minimum_size = Vector2(0, 28)
	pan_btn.pressed.connect(func():
		_activate_tool("pan")
	)
	panel.add_child(pan_btn)

	var edit_btn = Button.new()
	edit_btn.text = "Edit ✏️"
	edit_btn.custom_minimum_size = Vector2(0, 28)
	edit_btn.pressed.connect(func():
		_activate_tool("edit")
	)
	panel.add_child(edit_btn)

	var delete_btn = Button.new()
	delete_btn.text = "Delete 🗑️"
	delete_btn.custom_minimum_size = Vector2(0, 28)
	delete_btn.pressed.connect(func():
		_activate_tool("delete")
	)
	panel.add_child(delete_btn)

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

	# Setup AZN quantity editor dialog
	_setup_azn_quantity_dialog()

func _setup_azn_quantity_dialog() -> void:
	"""Create the AZN quantity editor dialog"""
	azn_edit_dialog = ConfirmationDialog.new()
	azn_edit_dialog.title = "Edit AZN Quantity"
	azn_edit_dialog.size = Vector2i(300, 150)
	add_child(azn_edit_dialog)

	var vbox = VBoxContainer.new()
	azn_edit_dialog.add_child(vbox)

	var label = Label.new()
	label.text = "Quantity:"
	vbox.add_child(label)

	azn_quantity_input = SpinBox.new()
	azn_quantity_input.min_value = 1
	azn_quantity_input.max_value = 9999
	azn_quantity_input.value = 10
	azn_quantity_input.custom_minimum_size = Vector2(200, 0)
	vbox.add_child(azn_quantity_input)

	azn_edit_dialog.confirmed.connect(_on_azn_quantity_confirmed)

func _on_azn_quantity_confirmed() -> void:
	"""Called when user confirms AZN quantity edit"""
	if edit_selected_type == "azn" and edit_selected_index >= 0:
		var new_qty = int(azn_quantity_input.value)
		_save_state()
		azn_nodes[edit_selected_index]["quantity"] = new_qty
		queue_redraw()

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
	for i in range(injection_zones.size()):
		var zone = injection_zones[i]
		var rect = zone["rect"]
		var screen_x1 = cx + (rect.position.x * CELL_SIZE * zoom) - scroll_x
		var screen_y1 = cy + (rect.position.y * CELL_SIZE * zoom) - scroll_y
		var screen_x2 = cx + ((rect.position.x + rect.size.x) * CELL_SIZE * zoom) - scroll_x
		var screen_y2 = cy + ((rect.position.y + rect.size.y) * CELL_SIZE * zoom) - scroll_y
		var color = Color(0.25, 0.55, 1.0, 0.2) if zone["player"] == 0 else Color(1.0, 0.3, 0.25, 0.2)
		draw_rect(Rect2(screen_x1, screen_y1, screen_x2 - screen_x1, screen_y2 - screen_y1), color)

		# Highlight if selected
		if edit_selected_type == "zone" and edit_selected_index == i:
			draw_rect(Rect2(screen_x1, screen_y1, screen_x2 - screen_x1, screen_y2 - screen_y1), Color(1.0, 1.0, 1.0, 0.3))

			# Draw resize handles at corners
			var handle_size = 8
			var corners = [
				Vector2(screen_x1, screen_y1),  # TL
				Vector2(screen_x2, screen_y1),  # TR
				Vector2(screen_x1, screen_y2),  # BL
				Vector2(screen_x2, screen_y2)   # BR
			]
			for corner in corners:
				draw_rect(Rect2(corner - Vector2(handle_size/2, handle_size/2), Vector2(handle_size, handle_size)), Color.YELLOW)

	# Draw habitas points
	for i in range(habitas_points.size()):
		var hp = habitas_points[i]
		var screen_x = cx + (hp.x * CELL_SIZE * zoom) - scroll_x
		var screen_y = cy + (hp.y * CELL_SIZE * zoom) - scroll_y
		if habitas_texture:
			draw_texture_rect(habitas_texture, Rect2(screen_x, screen_y, CELL_SIZE * zoom, CELL_SIZE * zoom), false)

		# Highlight if selected
		if edit_selected_type == "habitas" and edit_selected_index == i:
			draw_rect(Rect2(screen_x, screen_y, CELL_SIZE * zoom, CELL_SIZE * zoom), Color(1.0, 1.0, 0.0, 0.4))

	# Draw AZN nodes
	for i in range(azn_nodes.size()):
		var azn = azn_nodes[i]
		var pos = azn["position"]
		var screen_x = cx + (pos.x * CELL_SIZE * zoom) - scroll_x
		var screen_y = cy + (pos.y * CELL_SIZE * zoom) - scroll_y
		if azn_texture:
			draw_texture_rect(azn_texture, Rect2(screen_x, screen_y, CELL_SIZE * zoom, CELL_SIZE * zoom), false)

		# Highlight if selected
		if edit_selected_type == "azn" and edit_selected_index == i:
			draw_rect(Rect2(screen_x, screen_y, CELL_SIZE * zoom, CELL_SIZE * zoom), Color(1.0, 1.0, 0.0, 0.4))

	# Draw AZN hover tooltip
	if azn_hover_index >= 0 and azn_hover_index < azn_nodes.size():
		var azn = azn_nodes[azn_hover_index]
		var pos = azn["position"]
		var screen_x = cx + (pos.x * CELL_SIZE * zoom) - scroll_x
		var screen_y = cy + (pos.y * CELL_SIZE * zoom) - scroll_y
		var quantity_text = str(azn["quantity"])
		var font = get_theme_font("font")
		if font:
			draw_string(font, Vector2(screen_x + CELL_SIZE * zoom / 2 - 5, screen_y - 15), quantity_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.WHITE)

func _draw_stream_cell(screen_x: float, screen_y: float, size: float, stream_dir: int) -> void:
	# Draw stream background texture
	if stream_dir in [StreamDir.EAST, StreamDir.WEST]:
		if stream_h_texture:
			if stream_dir == StreamDir.WEST:
				draw_texture_rect(stream_h_texture, Rect2(screen_x + size, screen_y, -size, size), false)
			else:
				draw_texture_rect(stream_h_texture, Rect2(screen_x, screen_y, size, size), false)
		else:
			draw_rect(Rect2(screen_x, screen_y, size, size), Color(0.4, 0.2, 0.2))
	else:
		if stream_v_texture:
			if stream_dir == StreamDir.NORTH:
				draw_texture_rect(stream_v_texture, Rect2(screen_x, screen_y + size, size, -size), false)
			else:
				draw_texture_rect(stream_v_texture, Rect2(screen_x, screen_y, size, size), false)
		else:
			draw_rect(Rect2(screen_x, screen_y, size, size), Color(0.4, 0.2, 0.2))

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

	# Keyboard input for edit mode
	if event is InputEventKey and event.pressed:
		if event.keycode == 4194309 and active_tool == "edit" and edit_selected_type == "azn":  # 4194309 = Enter key
			# Show AZN quantity editor
			azn_quantity_input.value = azn_nodes[edit_selected_index]["quantity"]
			azn_edit_dialog.popup_centered()
			get_tree().root.set_input_as_handled()
			return

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

		# Left click: tool-dependent action
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var local_pos = event.position
			if _is_in_canvas(local_pos):
				match active_tool:
					"pan":
						# Pan tool: start panning with left-click drag
						is_painting = true
						get_tree().root.set_input_as_handled()
						return
					_:
						# Other tools: grid-based operations
						var grid_x = int((local_pos.x - cx + scroll_x) / (CELL_SIZE * zoom))
						var grid_y = int((local_pos.y - cy + scroll_y) / (CELL_SIZE * zoom))

						if grid_x >= 0 and grid_x < map_width and grid_y >= 0 and grid_y < map_height:
							match active_tool:
								"terrain":
									is_painting = true
									last_paint_pos = Vector2i(grid_x, grid_y)
									_save_state()
									_paint_cell(grid_x, grid_y)
									get_tree().root.set_input_as_handled()
									return
								"stream":
									is_painting = true
									last_paint_pos = Vector2i(grid_x, grid_y)
									_save_state()
									var idx = grid_y * map_width + grid_x
									cells[idx]["stream_dir"] = selected_stream_dir
									queue_redraw()
									get_tree().root.set_input_as_handled()
									return
								"habitas":
									_save_state()
									habitas_points.append(Vector2i(grid_x, grid_y))
									queue_redraw()
									get_tree().root.set_input_as_handled()
									return
								"azn":
									_save_state()
									azn_nodes.append({"position": Vector2i(grid_x, grid_y), "quantity": 30})
									queue_redraw()
									get_tree().root.set_input_as_handled()
									return
								"delete":
									is_painting = true
									last_paint_pos = Vector2i(grid_x, grid_y)
									_save_state()
									_delete_at_position(grid_x, grid_y)
									get_tree().root.set_input_as_handled()
									return
								"edit":
									# Edit mode: click to select element
									var element = _find_element_at(grid_x, grid_y)
									if element["type"] != "none":
										edit_selected_type = element["type"]
										edit_selected_index = element["index"]
										is_painting = true
										_save_state()

										# For zones, check if clicking on corner (resize mode)
										if element["type"] == "zone":
											var corner = _detect_zone_corner(grid_x, grid_y, injection_zones[element["index"]])
											if corner != "":
												zone_resize_corner = corner
										else:
											zone_resize_corner = ""

										_update_status()
										queue_redraw()
										get_tree().root.set_input_as_handled()
										return
									else:
										# Click on empty area deselects
										_deselect_edit_element()
										get_tree().root.set_input_as_handled()
										return
								"zone":
									# Zone placement will be drag-based (not implemented yet)
									pass

		# Left release
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			is_painting = false
			brush_cursor_pos = Vector2i(-1, -1)
			queue_redraw()

		# Right click: flood fill (terrain tool only)
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and active_tool == "terrain":
			var local_pos = event.position
			if _is_in_canvas(local_pos):
				var grid_x = int((local_pos.x - cx + scroll_x) / (CELL_SIZE * zoom))
				var grid_y = int((local_pos.y - cy + scroll_y) / (CELL_SIZE * zoom))

				if grid_x >= 0 and grid_x < map_width and grid_y >= 0 and grid_y < map_height:
					_save_state()
					_flood_fill(grid_x, grid_y)
					get_tree().root.set_input_as_handled()
					return

	# Drag operations (exclusive input when is_painting)
	if event is InputEventMouseMotion and is_painting:
		if active_tool == "pan":
			# Pan mode: drag to move map
			set_default_cursor_shape(CURSOR_MOVE)
			var delta = event.relative
			var max_x = max(0, int(map_width * CELL_SIZE * zoom - cw))
			var max_y = max(0, int(map_height * CELL_SIZE * zoom - ch))
			scroll_x = clampi(scroll_x - int(delta.x), 0, max_x)
			scroll_y = clampi(scroll_y - int(delta.y), 0, max_y)
			queue_redraw()
		else:
			# Terrain paint or stream drag mode
			var local_pos = event.position
			if _is_in_canvas(local_pos):
				var grid_x = int((local_pos.x - cx + scroll_x) / (CELL_SIZE * zoom))
				var grid_y = int((local_pos.y - cy + scroll_y) / (CELL_SIZE * zoom))

				if grid_x >= 0 and grid_x < map_width and grid_y >= 0 and grid_y < map_height:
					if active_tool == "terrain":
						# Terrain paint: drag to paint
						brush_cursor_pos = Vector2i(grid_x, grid_y)
						if Vector2i(grid_x, grid_y) != last_paint_pos:
							_paint_cell(grid_x, grid_y)
							last_paint_pos = Vector2i(grid_x, grid_y)
					elif active_tool == "stream":
						# Stream placement: drag to place streams
						if Vector2i(grid_x, grid_y) != last_paint_pos:
							var idx = grid_y * map_width + grid_x
							cells[idx]["stream_dir"] = selected_stream_dir
							last_paint_pos = Vector2i(grid_x, grid_y)
							queue_redraw()
					elif active_tool == "delete":
						# Delete mode: drag to erase everything
						brush_cursor_pos = Vector2i(grid_x, grid_y)
						if Vector2i(grid_x, grid_y) != last_paint_pos:
							_delete_at_position(grid_x, grid_y)
							last_paint_pos = Vector2i(grid_x, grid_y)
							queue_redraw()
					elif active_tool == "edit" and edit_selected_type != "":
						# Edit mode: move selected element
						if edit_selected_type == "habitas":
							_move_habitas(edit_selected_index, Vector2i(grid_x, grid_y))
						elif edit_selected_type == "azn":
							_move_azn(edit_selected_index, Vector2i(grid_x, grid_y))
						elif edit_selected_type == "zone":
							if zone_resize_corner != "":
								# Resize mode: resize from corner
								_resize_zone(edit_selected_index, zone_resize_corner, grid_x, grid_y)
							else:
								# Move mode: drag to move zone
								var offset = Vector2i(grid_x, grid_y) - last_paint_pos
								if offset != Vector2i.ZERO:
									_move_zone(edit_selected_index, offset)
									last_paint_pos = Vector2i(grid_x, grid_y)

		get_tree().root.set_input_as_handled()
		return

	# Middle-click is disabled - use Pan tool instead for explicit control
	# (Pan tool is in Tools section and uses left-click drag)

	# Update cursor based on active tool and check AZN hover
	if event is InputEventMouseMotion:
		if active_tool == "pan":
			set_default_cursor_shape(CURSOR_MOVE)
		else:
			set_default_cursor_shape(CURSOR_ARROW)

		# Check AZN hover for tooltip
		var local_pos = event.position
		if _is_in_canvas(local_pos):
			var grid_x = int((local_pos.x - cx + scroll_x) / (CELL_SIZE * zoom))
			var grid_y = int((local_pos.y - cy + scroll_y) / (CELL_SIZE * zoom))

			if grid_x >= 0 and grid_x < map_width and grid_y >= 0 and grid_y < map_height:
				var pos = Vector2i(grid_x, grid_y)
				var found_azn = -1
				for i in range(azn_nodes.size()):
					if azn_nodes[i]["position"] == pos:
						found_azn = i
						break

				if found_azn >= 0:
					azn_hover_index = found_azn
					azn_hover_time = 0.0
					queue_redraw()
				else:
					azn_hover_index = -1
			else:
				azn_hover_index = -1
		else:
			azn_hover_index = -1

func _delete_at_position(x: int, y: int) -> void:
	"""Delete everything at grid position"""
	if x < 0 or x >= map_width or y < 0 or y >= map_height:
		return

	# Delete terrain and streams
	var idx = y * map_width + x
	cells[idx]["density"] = Density.LOW
	cells[idx]["stream_dir"] = StreamDir.NONE

	# Delete habitas at this position
	habitas_points = habitas_points.filter(func(hp): return hp != Vector2i(x, y))

	# Delete AZN at this position
	azn_nodes = azn_nodes.filter(func(azn): return azn["position"] != Vector2i(x, y))

	# Delete zones containing this position
	injection_zones = injection_zones.filter(func(zone):
		return not zone["rect"].has_point(Vector2i(x, y))
	)

func _find_element_at(x: int, y: int) -> Dictionary:
	"""Find which element (if any) is at grid position. Returns {type, index} or {type: 'none'}"""
	var pos = Vector2i(x, y)

	# Check habitas
	for i in range(habitas_points.size()):
		if habitas_points[i] == pos:
			return {"type": "habitas", "index": i}

	# Check AZN
	for i in range(azn_nodes.size()):
		if azn_nodes[i]["position"] == pos:
			return {"type": "azn", "index": i}

	# Check zones
	for i in range(injection_zones.size()):
		if injection_zones[i]["rect"].has_point(pos):
			return {"type": "zone", "index": i}

	return {"type": "none"}

func _deselect_edit_element() -> void:
	"""Deselect currently selected element"""
	edit_selected_type = ""
	edit_selected_index = -1
	zone_resize_corner = ""
	queue_redraw()

func _move_habitas(index: int, new_pos: Vector2i) -> void:
	"""Move habitas point to new position"""
	if new_pos.x >= 0 and new_pos.x < map_width and new_pos.y >= 0 and new_pos.y < map_height:
		habitas_points[index] = new_pos
		queue_redraw()

func _move_azn(index: int, new_pos: Vector2i) -> void:
	"""Move AZN node to new position"""
	if new_pos.x >= 0 and new_pos.x < map_width and new_pos.y >= 0 and new_pos.y < map_height:
		azn_nodes[index]["position"] = new_pos
		queue_redraw()

func _move_zone(index: int, offset: Vector2i) -> void:
	"""Move zone by offset"""
	var zone = injection_zones[index]
	var rect = zone["rect"]
	var new_pos = rect.position + offset

	# Check bounds
	if new_pos.x >= 0 and new_pos.y >= 0 and new_pos.x + rect.size.x <= map_width and new_pos.y + rect.size.y <= map_height:
		injection_zones[index]["rect"] = Rect2i(new_pos, rect.size)
		queue_redraw()

func _detect_zone_corner(grid_x: int, grid_y: int, zone: Dictionary) -> String:
	"""Detect which corner of zone is near the given position. Returns 'tl', 'tr', 'bl', 'br', or ''"""
	var rect = zone["rect"]
	var pos = Vector2i(grid_x, grid_y)
	var corners = {
		"tl": rect.position,
		"tr": rect.position + Vector2i(rect.size.x - 1, 0),
		"bl": rect.position + Vector2i(0, rect.size.y - 1),
		"br": rect.position + rect.size - Vector2i(1, 1)
	}

	for corner_name in corners:
		if pos.distance_to(corners[corner_name]) <= 1.5:
			return corner_name
	return ""

func _resize_zone(index: int, corner: String, new_grid_x: int, new_grid_y: int) -> void:
	"""Resize zone from specified corner"""
	var zone = injection_zones[index]
	var rect = zone["rect"]
	var new_pos = Vector2i(new_grid_x, new_grid_y)

	match corner:
		"tl":  # Top-left corner - adjust position and size
			var new_width = (rect.position.x + rect.size.x) - new_pos.x
			var new_height = (rect.position.y + rect.size.y) - new_pos.y
			if new_width >= 2 and new_height >= 2 and new_pos.x >= 0 and new_pos.y >= 0:
				injection_zones[index]["rect"] = Rect2i(new_pos, Vector2i(new_width, new_height))
				queue_redraw()
		"tr":  # Top-right corner
			var new_width = new_pos.x - rect.position.x + 1
			var new_height = (rect.position.y + rect.size.y) - new_pos.y
			if new_width >= 2 and new_height >= 2 and new_pos.x < map_width and new_pos.y >= 0:
				injection_zones[index]["rect"] = Rect2i(Vector2i(rect.position.x, new_pos.y), Vector2i(new_width, new_height))
				queue_redraw()
		"bl":  # Bottom-left corner
			var new_width = (rect.position.x + rect.size.x) - new_pos.x
			var new_height = new_pos.y - rect.position.y + 1
			if new_width >= 2 and new_height >= 2 and new_pos.x >= 0 and new_pos.y < map_height:
				injection_zones[index]["rect"] = Rect2i(Vector2i(new_pos.x, rect.position.y), Vector2i(new_width, new_height))
				queue_redraw()
		"br":  # Bottom-right corner
			var new_width = new_pos.x - rect.position.x + 1
			var new_height = new_pos.y - rect.position.y + 1
			if new_width >= 2 and new_height >= 2 and new_pos.x < map_width and new_pos.y < map_height:
				injection_zones[index]["rect"] = Rect2i(rect.position, Vector2i(new_width, new_height))
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
	"""Clear entire map: terrain, streams, and all elements"""
	_save_state()

	# Clear terrain (density) and streams
	for i in range(cells.size()):
		cells[i]["density"] = Density.LOW
		cells[i]["stream_dir"] = StreamDir.NONE

	# Clear all elements
	habitas_points.clear()
	azn_nodes.clear()
	injection_zones.clear()

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
	match active_tool:
		"terrain":
			var density_name = _density_to_string(selected_density).to_upper()
			status = "Tool: Terrain (%s) | Click: paint | Right-click: fill | Scroll: zoom" % density_name
		"stream":
			var dir_name = _stream_dir_to_name(selected_stream_dir)
			status = "Tool: Stream (%s) | Click to place stream" % dir_name
		"habitas":
			status = "Tool: Place Habitas | Click to place"
		"azn":
			status = "Tool: Place AZN | Click to place"
		"zone":
			status = "Tool: Place Zone | Drag to create rectangle"
		"pan":
			status = "Tool: Pan ✋ | Click + drag to move map"
		"edit":
			status = "Tool: Edit ✏️ | Click element to edit, drag to move"
		"delete":
			status = "Tool: Delete 🗑️ | Click + drag to erase terrain, streams, elements"

	if status_label:
		status_label.text = status

func _stream_dir_to_name(dir: int) -> String:
	match dir:
		StreamDir.NORTH: return "NORTH"
		StreamDir.SOUTH: return "SOUTH"
		StreamDir.EAST: return "EAST"
		StreamDir.WEST: return "WEST"
	return "NONE"

func _deactivate_all_tools() -> void:
	"""Completely deactivate all tools - called before activating a new one"""
	# Reset all editing state
	is_painting = false
	brush_cursor_pos = Vector2i(-1, -1)
	# Don't modify selected_density or selected_stream_dir - user preference
	# Only reset active state

func _activate_tool(tool_name: String) -> void:
	"""Activate a tool exclusively - deactivates all other tools first"""
	_deactivate_all_tools()
	active_tool = tool_name
	_update_status()
	queue_redraw()

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

class_name MapEditor
extends Control

const TILE_SIZE: int = 16
const DEFAULT_WIDTH: int = 60
const DEFAULT_HEIGHT: int = 60

var map_width: int = DEFAULT_WIDTH
var map_height: int = DEFAULT_HEIGHT
var grid: Array = []
var selected_density: String = "low"
var zoom: float = 1.0
var scroll_x: int = 0
var scroll_y: int = 0

var sprites: Dictionary = {}
var terrain_buttons: Dictionary = {}
var stream_direction_buttons: Dictionary = {}
var history: Array = []
var history_index: int = -1
const MAX_HISTORY: int = 50
var scrollbar_height: int = 15
var scrollbar_width: int = 15

# Map elements
var habitas_points: Array = []
var azn_nodes: Array = []
var injection_zones: Array = []
var bloodstreams: Array = []

# Editor mode
var editor_mode: String = "terrain"
var mode_buttons: Dictionary = {}
var selected_stream_direction: String = "north"

# Injection zone editing
var editing_injection_zone: bool = false
var injection_zone_start: Vector2 = Vector2.ZERO
var temp_injection_zone: Dictionary = {}

func _ready() -> void:
	_load_sprites()
	_init_grid()
	_setup_ui()
	_load_first_map()

func _load_sprites() -> void:
	var sprite_paths = {
		"low": "res://assets/tiles/tile_low.png",
		"medium": "res://assets/tiles/tile_medium.png",
		"high": "res://assets/tiles/tile_high.png",
		"bone": "res://assets/tiles/tile_bone.png",
	}
	for density in sprite_paths.keys():
		if ResourceLoader.exists(sprite_paths[density]):
			sprites[density] = load(sprite_paths[density])

func _init_grid() -> void:
	grid.clear()
	for y in range(map_height):
		var row: Array = []
		for x in range(map_width):
			row.append("low")
		grid.append(row)

func _setup_ui() -> void:
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# LEFT SIDE - Canvas and scrollbars
	var left := VBoxContainer.new()
	root.add_child(left)

	# Status bar
	var status := Label.new()
	status.text = "Click & drag to paint | Right-click to fill | Scroll wheel to zoom | Middle-click to pan"
	status.add_theme_font_size_override("font_size", 10)
	left.add_child(status)

	# Canvas area
	var canvas_wrapper := Control.new()
	canvas_wrapper.custom_minimum_size = Vector2(800, 600)
	canvas_wrapper.draw.connect(_on_canvas_draw)
	canvas_wrapper.gui_input.connect(_on_canvas_input)
	left.add_child(canvas_wrapper)

	# Store canvas reference
	var canvas = canvas_wrapper

	# Horizontal scrollbar
	var h_scroll := HScrollBar.new()
	h_scroll.custom_minimum_size = Vector2(0, 15)
	h_scroll.value_changed.connect(func(v): scroll_x = int(v); canvas.queue_redraw())
	left.add_child(h_scroll)

	# RIGHT SIDE - Control panel (like simulator)
	var right := PanelContainer.new()
	right.custom_minimum_size = Vector2(250, 0)
	root.add_child(right)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.15)
	right.add_theme_stylebox_override("panel", panel_style)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	right.add_child(scroll)

	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 10)
	scroll.add_child(panel)

	var title := Label.new()
	title.text = "Map Editor"
	title.add_theme_font_size_override("font_size", 16)
	panel.add_child(title)

	# Terrain section
	var tile_label := Label.new()
	tile_label.text = "Terrain"
	tile_label.add_theme_font_size_override("font_size", 13)
	panel.add_child(tile_label)

	for dens in ["low", "medium", "high", "bone"]:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 40)
		btn.text = "  " + dens.to_upper()
		btn.toggle_mode = true
		if sprites.get(dens):
			btn.icon = sprites[dens]
		var dens_copy = dens
		btn.pressed.connect(func(): _set_editor_mode("terrain"); selected_density = dens_copy)
		panel.add_child(btn)
		terrain_buttons[dens] = btn
		if dens == "low":
			btn.button_pressed = true

	var border_btn := Button.new()
	border_btn.text = "⬜ Add Border"
	border_btn.custom_minimum_size = Vector2(0, 40)
	border_btn.pressed.connect(_add_border)
	panel.add_child(border_btn)

	panel.add_child(HSeparator.new())

	# Elements section
	var elements_label := Label.new()
	elements_label.text = "Elements"
	elements_label.add_theme_font_size_override("font_size", 13)
	panel.add_child(elements_label)

	var modes = [
		{"name": "habitas", "text": "🔴 Habitas Points"},
		{"name": "azn", "text": "🟡 AZN Nodes"},
		{"name": "injection", "text": "🟢 Injection Zones"},
		{"name": "stream", "text": "➡️ Bloodstreams"}
	]

	for mode_data in modes:
		var mode_btn := Button.new()
		mode_btn.text = mode_data["text"]
		mode_btn.custom_minimum_size = Vector2(0, 30)
		mode_btn.toggle_mode = true
		var mode_name = mode_data["name"]
		mode_btn.pressed.connect(func(): _set_editor_mode(mode_name))
		panel.add_child(mode_btn)
		mode_buttons[mode_name] = mode_btn

	# Stream direction selector (hidden by default)
	var stream_label := Label.new()
	stream_label.text = "Stream Direction"
	stream_label.add_theme_font_size_override("font_size", 11)
	stream_label.visible = false
	panel.add_child(stream_label)

	var directions = [
		{"name": "north", "text": "↑ North"},
		{"name": "south", "text": "↓ South"},
		{"name": "east", "text": "→ East"},
		{"name": "west", "text": "← West"},
		{"name": "ns", "text": "↕ N-S"},
		{"name": "ew", "text": "↔ E-W"}
	]

	for dir_data in directions:
		var dir_btn := Button.new()
		dir_btn.text = dir_data["text"]
		dir_btn.custom_minimum_size = Vector2(0, 28)
		dir_btn.toggle_mode = true
		dir_btn.visible = false
		var dir_name = dir_data["name"]
		dir_btn.pressed.connect(func(): _set_stream_direction(dir_name))
		panel.add_child(dir_btn)
		stream_direction_buttons[dir_name] = dir_btn
		if dir_name == "north":
			dir_btn.button_pressed = true

	panel.add_child(HSeparator.new())

	# Tools section
	var tools_label := Label.new()
	tools_label.text = "Tools"
	tools_label.add_theme_font_size_override("font_size", 13)
	panel.add_child(tools_label)

	var load_btn := Button.new()
	load_btn.text = "📂 Load Map"
	load_btn.pressed.connect(_show_load_dialog)
	panel.add_child(load_btn)

	var clear_btn := Button.new()
	clear_btn.text = "🗑️ Clear"
	clear_btn.pressed.connect(_clear_map)
	panel.add_child(clear_btn)

	var undo_btn := Button.new()
	undo_btn.text = "↶ Undo"
	undo_btn.pressed.connect(_undo)
	panel.add_child(undo_btn)

	var save_btn := Button.new()
	save_btn.text = "💾 Save Map"
	save_btn.pressed.connect(_save_map)
	panel.add_child(save_btn)

	panel.add_child(Control.new())

	var back_btn := Button.new()
	back_btn.text = "← Back to Menu"
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_scene.tscn"))
	panel.add_child(back_btn)

func _set_editor_mode(mode: String) -> void:
	editor_mode = mode
	for m in mode_buttons.keys():
		mode_buttons[m].button_pressed = (m == mode)
	var show_stream = (mode == "stream")
	for btn in stream_direction_buttons.values():
		btn.visible = show_stream

func _set_stream_direction(direction: String) -> void:
	selected_stream_direction = direction
	for d in stream_direction_buttons.keys():
		stream_direction_buttons[d].button_pressed = (d == direction)

func _on_canvas_draw() -> void:
	var start_x = 0
	var start_y = 0
	var canvas_width = get_size().x - 250 - scrollbar_width
	var canvas_height = get_size().y - 45 - scrollbar_height

	# Draw background
	draw_rect(Rect2(start_x, start_y, canvas_width, canvas_height), Color(0.2, 0.2, 0.2))

	# Draw grid
	for y in range(map_height):
		for x in range(map_width):
			var screen_x = start_x + (x * TILE_SIZE * zoom) - scroll_x
			var screen_y = start_y + (y * TILE_SIZE * zoom) - scroll_y
			var size = TILE_SIZE * zoom

			if screen_x + size < start_x or screen_x > start_x + canvas_width:
				continue
			if screen_y + size < start_y or screen_y > start_y + canvas_height:
				continue

			var density = grid[y][x]
			var color = Color.WHITE

			match density:
				"low": color = Color(0.8, 0.6, 0.6)
				"medium": color = Color(0.7, 0.5, 0.7)
				"high": color = Color(0.5, 0.2, 0.5)
				"bone": color = Color(0.2, 0.2, 0.2)

			if sprites.get(density):
				draw_texture_rect(sprites[density], Rect2(screen_x, screen_y, size, size), false)
			else:
				draw_rect(Rect2(screen_x, screen_y, size, size), color)

			draw_rect(Rect2(screen_x, screen_y, size, size), Color.GRAY, false, 1.0)

	# Draw injection zones
	for zone in injection_zones:
		var x1 = int(zone["x1"])
		var y1 = int(zone["y1"])
		var x2 = int(zone["x2"])
		var y2 = int(zone["y2"])
		var screen_x1 = start_x + (x1 * TILE_SIZE * zoom) - scroll_x
		var screen_y1 = start_y + (y1 * TILE_SIZE * zoom) - scroll_y
		var screen_x2 = start_x + ((x2 + 1) * TILE_SIZE * zoom) - scroll_x
		var screen_y2 = start_y + ((y2 + 1) * TILE_SIZE * zoom) - scroll_y
		var zone_color = Color(0, 1, 0, 0.2) if zone["player"] == 0 else Color(1, 0, 0, 0.2)
		draw_rect(Rect2(screen_x1, screen_y1, screen_x2 - screen_x1, screen_y2 - screen_y1), zone_color)

	# Draw habitas points (red circles)
	for point in habitas_points:
		var screen_x = start_x + (point["x"] * TILE_SIZE * zoom) - scroll_x + (TILE_SIZE * zoom) / 2
		var screen_y = start_y + (point["y"] * TILE_SIZE * zoom) - scroll_y + (TILE_SIZE * zoom) / 2
		draw_circle(Vector2(screen_x, screen_y), 5 * zoom, Color.RED)

	# Draw AZN nodes (yellow circles)
	for node in azn_nodes:
		var screen_x = start_x + (node["x"] * TILE_SIZE * zoom) - scroll_x + (TILE_SIZE * zoom) / 2
		var screen_y = start_y + (node["y"] * TILE_SIZE * zoom) - scroll_y + (TILE_SIZE * zoom) / 2
		draw_circle(Vector2(screen_x, screen_y), 4 * zoom, Color.YELLOW)

	# Draw bloodstreams as ARROWS ONLY (no full tile background)
	for stream in bloodstreams:
		var screen_x = start_x + (stream["x"] * TILE_SIZE * zoom) - scroll_x + (TILE_SIZE * zoom) / 2
		var screen_y = start_y + (stream["y"] * TILE_SIZE * zoom) - scroll_y + (TILE_SIZE * zoom) / 2
		var arrow_size = 6 * zoom
		var direction = stream.get("stream", "")
		var arrow_color = Color.LIGHT_CORAL
		match direction:
			"north":
				draw_line(Vector2(screen_x, screen_y), Vector2(screen_x, screen_y - arrow_size), arrow_color, 2)
			"south":
				draw_line(Vector2(screen_x, screen_y), Vector2(screen_x, screen_y + arrow_size), arrow_color, 2)
			"east":
				draw_line(Vector2(screen_x, screen_y), Vector2(screen_x + arrow_size, screen_y), arrow_color, 2)
			"west":
				draw_line(Vector2(screen_x, screen_y), Vector2(screen_x - arrow_size, screen_y), arrow_color, 2)

func _on_canvas_input(event: InputEvent) -> void:
	var start_x = 0
	var start_y = 0
	var canvas_width = get_size().x - 250 - scrollbar_width
	var canvas_height = get_size().y - 45 - scrollbar_height

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = min(zoom + 0.1, 3.0)
			queue_redraw()
			get_tree().root.set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = max(zoom - 0.1, 0.5)
			queue_redraw()
			get_tree().root.set_input_as_handled()
			return

	if event is InputEventMouseButton and event.pressed:
		var local_pos = event.position
		if local_pos.x < canvas_width and local_pos.y > 45 and local_pos.y < 45 + canvas_height:
			var grid_x = int((local_pos.x + scroll_x) / (TILE_SIZE * zoom))
			var grid_y = int((local_pos.y - 45 + scroll_y) / (TILE_SIZE * zoom))

			if grid_x >= 0 and grid_x < map_width and grid_y >= 0 and grid_y < map_height:
				_save_state()
				if editor_mode == "terrain":
					if event.button_index == MOUSE_BUTTON_LEFT:
						grid[grid_y][grid_x] = selected_density
					elif event.button_index == MOUSE_BUTTON_RIGHT:
						_flood_fill(grid_x, grid_y, grid[grid_y][grid_x])
				elif editor_mode == "habitas" and event.button_index == MOUSE_BUTTON_LEFT:
					habitas_points.append({"x": grid_x, "y": grid_y})
				elif editor_mode == "azn" and event.button_index == MOUSE_BUTTON_LEFT:
					azn_nodes.append({"x": grid_x, "y": grid_y, "quantity": 30})
				elif editor_mode == "stream" and event.button_index == MOUSE_BUTTON_LEFT:
					bloodstreams.append({"x": grid_x, "y": grid_y, "stream": selected_stream_direction})
					grid[grid_y][grid_x] = "medium"
				elif editor_mode == "injection" and event.button_index == MOUSE_BUTTON_LEFT:
					if not editing_injection_zone:
						editing_injection_zone = true
						injection_zone_start = Vector2(grid_x, grid_y)
				queue_redraw()

	if event is InputEventMouseButton and not event.pressed:
		if editor_mode == "injection" and editing_injection_zone:
			var local_pos = event.position
			var grid_x = int((local_pos.x + scroll_x) / (TILE_SIZE * zoom))
			var grid_y = int((local_pos.y - 45 + scroll_y) / (TILE_SIZE * zoom))
			var x1 = min(int(injection_zone_start.x), grid_x)
			var x2 = max(int(injection_zone_start.x), grid_x)
			var y1 = min(int(injection_zone_start.y), grid_y)
			var y2 = max(int(injection_zone_start.y), grid_y)
			injection_zones.append({"player": 0, "x1": x1, "y1": y1, "x2": x2, "y2": y2})
			editing_injection_zone = false
			queue_redraw()

func _clear_map() -> void:
	_save_state()
	_init_grid()
	queue_redraw()

func _add_border() -> void:
	_save_state()
	for x in range(map_width):
		grid[0][x] = "bone"
		grid[map_height - 1][x] = "bone"
	for y in range(map_height):
		grid[y][0] = "bone"
		grid[y][map_width - 1] = "bone"
	queue_redraw()

func _show_load_dialog() -> void:
	var dir = DirAccess.open("res://maps/")
	if not dir:
		return
	var files = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			files.append(file_name)
		file_name = dir.get_next()

	if files.is_empty():
		return

	var popup := PopupMenu.new()
	add_child(popup)

	for i in range(files.size()):
		var map_name = files[i].trim_suffix(".json")
		popup.add_item(map_name, i)

	popup.id_pressed.connect(func(id: int):
		_load_map(files[id])
		popup.queue_free()
	)

	popup.popup_centered_ratio(0.3)

func _load_first_map() -> void:
	var dir = DirAccess.open("res://maps/")
	if not dir:
		return
	var files = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			files.append(file_name)
		file_name = dir.get_next()

	if not files.is_empty():
		_load_map(files[0])

func _load_map(filename: String) -> void:
	var file = FileAccess.open("res://maps/" + filename, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	if data:
		map_width = data.get("width", DEFAULT_WIDTH)
		map_height = data.get("height", DEFAULT_HEIGHT)
		_init_grid()

		bloodstreams.clear()
		for cell in data.get("cells", []):
			if "x" in cell and "y" in cell and cell["x"] < map_width and cell["y"] < map_height:
				grid[cell["y"]][cell["x"]] = cell.get("density", "low")
				if cell.get("stream"):
					bloodstreams.append({"x": cell["x"], "y": cell["y"], "stream": cell["stream"]})

		habitas_points = data.get("habitas_points", []).duplicate()
		azn_nodes = data.get("azn_nodes", []).duplicate()
		injection_zones = data.get("injection_zones", []).duplicate()

		scroll_x = 0
		scroll_y = 0
		history.clear()
		history_index = -1
		_save_state()
		queue_redraw()

func _save_map() -> void:
	var cells = []
	for y in range(map_height):
		for x in range(map_width):
			if grid[y][x] != "low":
				var cell_data = {"x": x, "y": y, "density": grid[y][x]}
				for stream in bloodstreams:
					if stream["x"] == x and stream["y"] == y:
						cell_data["stream"] = stream.get("stream", "")
						break
				cells.append(cell_data)

	var map_data = {
		"name": "Custom Map",
		"width": map_width,
		"height": map_height,
		"default_density": "low",
		"starting_azn": 150,
		"cells": cells,
		"habitas_points": habitas_points,
		"azn_nodes": azn_nodes,
		"injection_zones": injection_zones
	}
	var file = FileAccess.open("user://custom_map.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(map_data))

func _save_state() -> void:
	if history_index < history.size() - 1:
		history.resize(history_index + 1)
	var state = []
	for row in grid:
		state.append(row.duplicate())
	history.append(state)
	history_index = history.size() - 1
	if history.size() > MAX_HISTORY:
		history.pop_front()
		history_index -= 1

func _undo() -> void:
	if history_index > 0:
		history_index -= 1
		grid.clear()
		for row in history[history_index]:
			grid.append(row.duplicate())
		queue_redraw()

func _flood_fill(start_x: int, start_y: int, target: String) -> void:
	if start_x < 0 or start_x >= map_width or start_y < 0 or start_y >= map_height:
		return
	var stack = [[start_x, start_y]]
	var visited = []
	while stack.size() > 0:
		var pos = stack.pop_back()
		var x = pos[0]
		var y = pos[1]
		if x < 0 or x >= map_width or y < 0 or y >= map_height or [x, y] in visited or grid[y][x] != target:
			continue
		visited.append([x, y])
		grid[y][x] = selected_density
		stack.append([x + 1, y])
		stack.append([x - 1, y])
		stack.append([x, y + 1])
		stack.append([x, y - 1])

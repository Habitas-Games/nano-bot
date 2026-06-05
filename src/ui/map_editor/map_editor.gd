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
var is_panning: bool = false
var pan_start: Vector2 = Vector2.ZERO
var is_painting: bool = false
var last_painted_pos: Vector2 = Vector2.ZERO

var sprites: Dictionary = {}
var canvas: Control
var scroll_container: ScrollContainer

func _ready() -> void:
	_load_sprites()
	_setup_ui()
	_init_grid()

func _load_sprites() -> void:
	var sprite_paths = {
		"low": "res://assets/tiles/tile_low.png",
		"medium": "res://assets/tiles/tile_medium.png",
		"high": "res://assets/tiles/tile_high.png",
		"bone": "res://assets/tiles/tile_bone.png",
	}

	for density in sprite_paths.keys():
		var path = sprite_paths[density]
		if ResourceLoader.exists(path):
			sprites[density] = load(path)

func _setup_ui() -> void:
	var main := HBoxContainer.new()
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(main)

	# LEFT PANEL
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(200, 0)
	panel.add_theme_constant_override("separation", 8)
	main.add_child(panel)

	# Title
	var title := Label.new()
	title.text = "Map Editor"
	title.add_theme_font_size_override("font_size", 16)
	panel.add_child(title)

	panel.add_child(Label.new())  # Spacer

	# Tile selector
	var tile_title := Label.new()
	tile_title.text = "Terrain:"
	tile_title.add_theme_font_size_override("font_size", 12)
	panel.add_child(tile_title)

	var tile_container := VBoxContainer.new()
	tile_container.add_theme_constant_override("separation", 4)
	panel.add_child(tile_container)

	for dens in ["low", "medium", "high", "bone"]:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 40)
		btn.text = "  " + dens.to_upper()
		btn.toggle_mode = true
		btn.pressed.connect(func():
			selected_density = dens
		)
		tile_container.add_child(btn)
		if dens == "low":
			btn.button_pressed = true

	panel.add_child(Label.new())  # Spacer

	# Tools section
	var tools_title := Label.new()
	tools_title.text = "Tools:"
	tools_title.add_theme_font_size_override("font_size", 12)
	panel.add_child(tools_title)

	var tools_container := VBoxContainer.new()
	tools_container.add_theme_constant_override("separation", 4)
	panel.add_child(tools_container)

	var load_btn := Button.new()
	load_btn.text = "📂 Load Map"
	load_btn.custom_minimum_size = Vector2(0, 32)
	load_btn.pressed.connect(_load_map)
	tools_container.add_child(load_btn)

	var clear_btn := Button.new()
	clear_btn.text = "🗑️  Clear"
	clear_btn.custom_minimum_size = Vector2(0, 32)
	clear_btn.pressed.connect(_clear_map)
	tools_container.add_child(clear_btn)

	var border_btn := Button.new()
	border_btn.text = "⬜ Add Border"
	border_btn.custom_minimum_size = Vector2(0, 32)
	border_btn.pressed.connect(_add_border)
	tools_container.add_child(border_btn)

	var save_btn := Button.new()
	save_btn.text = "💾 Save Map"
	save_btn.custom_minimum_size = Vector2(0, 32)
	save_btn.pressed.connect(_save_map)
	tools_container.add_child(save_btn)

	panel.add_child(Label.new())  # Spacer

	var back_btn := Button.new()
	back_btn.text = "← Back to Menu"
	back_btn.custom_minimum_size = Vector2(0, 32)
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_scene.tscn"))
	panel.add_child(back_btn)

	panel.add_child(Control.new())  # Fill rest

	# RIGHT SIDE - Canvas + Status
	var canvas_section := VBoxContainer.new()
	main.add_child(canvas_section)

	# Status bar
	var status_container := HBoxContainer.new()
	status_container.custom_minimum_size = Vector2(0, 30)
	canvas_section.add_child(status_container)

	var status_label_left := Label.new()
	status_label_left.text = "Click & drag to paint | Right-click to fill | Scroll wheel to zoom | Middle-click to pan"
	status_label_left.add_theme_font_size_override("font_size", 10)
	status_container.add_child(status_label_left)

	# ScrollContainer for canvas
	scroll_container = ScrollContainer.new()
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	canvas_section.add_child(scroll_container)

	# Canvas Control for drawing
	canvas = Control.new()
	canvas.custom_minimum_size = Vector2(map_width * TILE_SIZE + 100, map_height * TILE_SIZE + 100)
	canvas.draw.connect(_on_canvas_draw)
	canvas.gui_input.connect(_on_canvas_input)
	scroll_container.add_child(canvas)

func _on_canvas_draw() -> void:
	for y in range(map_height):
		for x in range(map_width):
			var screen_pos = Vector2(x, y) * TILE_SIZE
			var screen_size = TILE_SIZE

			var density = grid[y][x]
			var color = Color.WHITE

			match density:
				"low":
					color = Color(0.8, 0.6, 0.6)
				"medium":
					color = Color(0.7, 0.5, 0.7)
				"high":
					color = Color(0.5, 0.2, 0.5)
				"bone":
					color = Color(0.2, 0.2, 0.2)

			if sprites.get(density) != null:
				canvas.draw_set_transform(screen_pos, 0, Vector2(1, 1))
				canvas.draw_texture(sprites[density], Vector2.ZERO)
				canvas.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			else:
				var rect = Rect2(screen_pos, Vector2(screen_size, screen_size))
				canvas.draw_rect(rect, color)

			var rect = Rect2(screen_pos, Vector2(screen_size, screen_size))
			canvas.draw_rect(rect, Color.GRAY, false, 1.0)

func _on_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = min(zoom + 0.2, 3.0)
			_update_canvas_size()
			canvas.queue_redraw()
			get_tree().root.set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = max(zoom - 0.2, 0.5)
			_update_canvas_size()
			canvas.queue_redraw()
			get_tree().root.set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			is_panning = true
			pan_start = event.position
			return
		elif event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
			is_panning = false
			return

	if event is InputEventMouseMotion and is_panning:
		var delta = event.position - pan_start
		scroll_container.scroll_horizontal -= int(delta.x)
		scroll_container.scroll_vertical -= int(delta.y)
		pan_start = event.position
		return

	if event is InputEventMouseMotion and is_painting:
		_paint_line(last_painted_pos, event.position)
		last_painted_pos = event.position
		canvas.queue_redraw()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_painting = true
				last_painted_pos = event.position
				_paint_at(event.position)
				canvas.queue_redraw()
			else:
				is_painting = false
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var grid_pos = _get_grid_pos(event.position)
			var x = int(grid_pos.x)
			var y = int(grid_pos.y)

			if x >= 0 and x < map_width and y >= 0 and y < map_height:
				_flood_fill(x, y, grid[y][x])
				canvas.queue_redraw()

func _update_canvas_size() -> void:
	canvas.custom_minimum_size = Vector2(map_width * TILE_SIZE * zoom + 100, map_height * TILE_SIZE * zoom + 100)

func _get_grid_pos(screen_pos: Vector2) -> Vector2:
	var local_pos = canvas.get_local_mouse_position()
	return local_pos / TILE_SIZE

func _paint_at(screen_pos: Vector2) -> void:
	var grid_pos = _get_grid_pos(screen_pos)
	var x = int(grid_pos.x)
	var y = int(grid_pos.y)

	if x >= 0 and x < map_width and y >= 0 and y < map_height:
		grid[y][x] = selected_density

func _paint_line(from_pos: Vector2, to_pos: Vector2) -> void:
	var start_grid = _get_grid_pos(from_pos)
	var end_grid = _get_grid_pos(to_pos)

	var x0 = int(start_grid.x)
	var y0 = int(start_grid.y)
	var x1 = int(end_grid.x)
	var y1 = int(end_grid.y)

	var dx = abs(x1 - x0)
	var dy = abs(y1 - y0)
	var sx = 1 if x1 > x0 else -1
	var sy = 1 if y1 > y0 else -1
	var err = dx - dy

	var x = x0
	var y = y0

	while true:
		if x >= 0 and x < map_width and y >= 0 and y < map_height:
			grid[y][x] = selected_density

		if x == x1 and y == y1:
			break

		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy

func _init_grid() -> void:
	grid.clear()
	for y in range(map_height):
		var row: Array = []
		for x in range(map_width):
			row.append("low")
		grid.append(row)

func _clear_map() -> void:
	_init_grid()
	canvas.queue_redraw()

func _add_border() -> void:
	for x in range(map_width):
		grid[0][x] = "bone"
		grid[map_height - 1][x] = "bone"
	for y in range(map_height):
		grid[y][0] = "bone"
		grid[y][map_width - 1] = "bone"
	canvas.queue_redraw()

func _load_map() -> void:
	var dir = DirAccess.open("res://maps/")
	if dir == null:
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

	var map_path = "res://maps/" + files[0]
	var file = FileAccess.open(map_path, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())

	if data:
		map_width = data.get("width", DEFAULT_WIDTH)
		map_height = data.get("height", DEFAULT_HEIGHT)
		_init_grid()

		for cell in data.get("cells", []):
			if "x" in cell and "y" in cell:
				var x = cell["x"]
				var y = cell["y"]
				if x >= 0 and x < map_width and y >= 0 and y < map_height:
					grid[y][x] = cell.get("density", "low")

		_update_canvas_size()
		canvas.queue_redraw()

func _save_map() -> void:
	var cells: Array = []
	for y in range(map_height):
		for x in range(map_width):
			if grid[y][x] != "low":
				cells.append({"x": x, "y": y, "density": grid[y][x]})

	var map_data = {
		"name": "Custom Map",
		"width": map_width,
		"height": map_height,
		"default_density": "low",
		"starting_azn": 150,
		"cells": cells,
		"habitas_points": [
			{"x": 2, "y": 2},
			{"x": map_width - 3, "y": map_height - 3}
		],
		"azn_nodes": [
			{"x": map_width / 2, "y": map_height / 2, "quantity": 30}
		],
		"injection_zones": [
			{"player": 0, "x1": 0, "y1": 0, "x2": 4, "y2": 4},
			{"player": 1, "x1": max(0, map_width - 5), "y1": max(0, map_height - 5), "x2": map_width - 1, "y2": map_height - 1}
		]
	}

	var file = FileAccess.open("user://custom_map.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(map_data))

func _flood_fill(start_x: int, start_y: int, target: String) -> void:
	if start_x < 0 or start_x >= map_width or start_y < 0 or start_y >= map_height:
		return

	var stack: Array = [[start_x, start_y]]
	var visited: Array = []
	var count = 0

	while stack.size() > 0 and count < 10000:
		count += 1
		var pos = stack.pop_back()
		var x = pos[0]
		var y = pos[1]

		if x < 0 or x >= map_width or y < 0 or y >= map_height:
			continue
		if [x, y] in visited:
			continue
		if grid[y][x] != target:
			continue

		visited.append([x, y])
		grid[y][x] = selected_density

		stack.append([x + 1, y])
		stack.append([x - 1, y])
		stack.append([x, y + 1])
		stack.append([x, y - 1])

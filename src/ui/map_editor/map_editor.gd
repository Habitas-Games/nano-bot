class_name MapEditor
extends Control

const TILE_SIZE: int = 16
const DEFAULT_WIDTH: int = 60
const DEFAULT_HEIGHT: int = 60

var map_width: int = DEFAULT_WIDTH
var map_height: int = DEFAULT_HEIGHT
var grid: Array = []
var selected_density: String = "low"

var status_label: Label
var zoom: float = 1.0
var pan: Vector2 = Vector2.ZERO
var is_panning: bool = false
var pan_start: Vector2 = Vector2.ZERO

var sprites: Dictionary = {}

func _ready() -> void:
	_load_sprites()
	_setup_ui()
	_init_grid()

func _load_sprites() -> void:
	# Load sprite tiles for each density type
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
		else:
			# Fallback: create a colored rectangle if sprite doesn't exist
			sprites[density] = null

func _setup_ui() -> void:
	var main := VBoxContainer.new()
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(main)

	# Toolbar
	var toolbar := HBoxContainer.new()
	toolbar.custom_minimum_size = Vector2(0, 50)
	toolbar.add_theme_constant_override("separation", 10)
	main.add_child(toolbar)

	var title := Label.new()
	title.text = "Tile:  "
	title.add_theme_font_size_override("font_size", 12)
	toolbar.add_child(title)

	for dens in ["low", "medium", "high", "bone"]:
		var btn := Button.new()
		btn.text = dens
		btn.custom_minimum_size = Vector2(70, 30)
		btn.toggle_mode = true
		btn.pressed.connect(func():
			selected_density = dens
		)
		toolbar.add_child(btn)
		if dens == "low":
			btn.button_pressed = true

	toolbar.add_child(Control.new())  # Spacer

	var load_btn := Button.new()
	load_btn.text = "Load Map"
	load_btn.pressed.connect(_load_map)
	toolbar.add_child(load_btn)

	var clear_btn := Button.new()
	clear_btn.text = "Clear"
	clear_btn.pressed.connect(_clear_map)
	toolbar.add_child(clear_btn)

	var border_btn := Button.new()
	border_btn.text = "Add Border"
	border_btn.pressed.connect(_add_border)
	toolbar.add_child(border_btn)

	var save_btn := Button.new()
	save_btn.text = "Save Map"
	save_btn.pressed.connect(_save_map)
	toolbar.add_child(save_btn)

	var back_btn := Button.new()
	back_btn.text = "← Back"
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_scene.tscn"))
	toolbar.add_child(back_btn)

	# Status
	status_label = Label.new()
	status_label.text = "Click to paint | Right-click to fill | Scroll to zoom | Middle-click to drag"
	status_label.add_theme_font_size_override("font_size", 10)
	main.add_child(status_label)

func _init_grid() -> void:
	grid.clear()
	for y in range(map_height):
		var row: Array = []
		for x in range(map_width):
			row.append("low")
		grid.append(row)

func _input(event: InputEvent) -> void:
	# Zoom with mouse wheel
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = min(zoom + 0.2, 3.0)
			queue_redraw()
			get_tree().root.set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = max(zoom - 0.2, 0.5)
			queue_redraw()
			get_tree().root.set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			is_panning = true
			pan_start = get_local_mouse_position()
			return
		elif event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
			is_panning = false
			return

	# Pan with middle mouse button
	if event is InputEventMouseMotion and is_panning:
		var delta = get_local_mouse_position() - pan_start
		pan += delta
		pan_start = get_local_mouse_position()
		queue_redraw()
		return

	# Paint tiles
	if event is InputEventMouseButton and event.pressed:
		var local_pos = get_local_mouse_position() - Vector2(0, 50)
		var grid_pos = (local_pos - pan) / (TILE_SIZE * zoom)
		var x = int(grid_pos.x)
		var y = int(grid_pos.y)

		if x >= 0 and x < map_width and y >= 0 and y < map_height:
			if event.button_index == MOUSE_BUTTON_LEFT:
				grid[y][x] = selected_density
				status_label.text = "Painted (%d,%d): %s | Zoom: %.1fx" % [x, y, selected_density, zoom]
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_flood_fill(x, y, grid[y][x])
				status_label.text = "Filled with: %s | Zoom: %.1fx" % [selected_density, zoom]

			queue_redraw()

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

func _clear_map() -> void:
	_init_grid()
	queue_redraw()
	status_label.text = "Map cleared"

func _add_border() -> void:
	for x in range(map_width):
		grid[0][x] = "bone"
		grid[map_height - 1][x] = "bone"
	for y in range(map_height):
		grid[y][0] = "bone"
		grid[y][map_width - 1] = "bone"
	queue_redraw()
	status_label.text = "Border added"

func _load_map() -> void:
	var dir = DirAccess.open("res://maps/")
	if dir == null:
		status_label.text = "Could not open maps directory"
		return

	var files = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			files.append(file_name)
		file_name = dir.get_next()

	if files.is_empty():
		status_label.text = "No maps found"
		return

	# Load the first available map (in a real version, you'd show a dialog)
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

		queue_redraw()
		status_label.text = "Loaded: %s (%dx%d)" % [files[0], map_width, map_height]

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
	status_label.text = "✓ Saved to user://custom_map.json"

func _draw() -> void:
	# Draw grid with sprites or colors
	for y in range(map_height):
		for x in range(map_width):
			var screen_pos = pan + Vector2(x, y) * TILE_SIZE * zoom
			var screen_size = TILE_SIZE * zoom
			var rect = Rect2(screen_pos, Vector2(screen_size, screen_size))

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

			# Draw sprite if available, otherwise colored rectangle
			if sprites.get(density) != null:
				draw_set_transform(screen_pos, 0, Vector2(zoom, zoom))
				draw_texture(sprites[density], Vector2.ZERO)
				draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
			else:
				draw_rect(rect, color)

			# Draw grid outline
			draw_rect(rect, Color.GRAY, false, 1.0)

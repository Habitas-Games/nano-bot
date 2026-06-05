class_name MapEditor
extends Control

const TILE_SIZE: int = 16
const DEFAULT_WIDTH: int = 60
const DEFAULT_HEIGHT: int = 60

var map_width: int = DEFAULT_WIDTH
var map_height: int = DEFAULT_HEIGHT
var grid: Array = []  # Array[Array] of density strings
var selected_density: String = "low"
var selected_stream: String = ""

var canvas: Control
var tile_info_label: Label
var status_label: Label

func _ready() -> void:
	_setup_ui()
	_init_grid()

func _setup_ui() -> void:
	# Main container
	var main_container := VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(main_container)

	# Top toolbar
	var toolbar := HBoxContainer.new()
	toolbar.custom_minimum_size = Vector2(0, 120)
	main_container.add_child(toolbar)

	# Map size controls
	var size_section := VBoxContainer.new()
	size_section.custom_minimum_size = Vector2(200, 0)
	toolbar.add_child(size_section)

	var size_title := Label.new()
	size_title.text = "Map Size"
	size_title.add_theme_font_size_override("font_size", 10)
	size_section.add_child(size_title)

	var size_container := HBoxContainer.new()
	size_section.add_child(size_container)

	var width_label := Label.new()
	width_label.text = "Width:"
	width_label.custom_minimum_size = Vector2(50, 0)
	size_container.add_child(width_label)

	var width_spin := SpinBox.new()
	width_spin.min_value = 20
	width_spin.max_value = 100
	width_spin.value = map_width
	width_spin.value_changed.connect(_on_width_changed)
	size_container.add_child(width_spin)

	var height_label := Label.new()
	height_label.text = "Height:"
	height_label.custom_minimum_size = Vector2(50, 0)
	size_container.add_child(height_label)

	var height_spin := SpinBox.new()
	height_spin.min_value = 20
	height_spin.max_value = 100
	height_spin.value = map_height
	height_spin.value_changed.connect(_on_height_changed)
	size_container.add_child(height_spin)

	# Tile selector
	var tile_section := VBoxContainer.new()
	tile_section.custom_minimum_size = Vector2(280, 0)
	toolbar.add_child(tile_section)

	var tile_title := Label.new()
	tile_title.text = "Tile Type"
	tile_title.add_theme_font_size_override("font_size", 10)
	tile_section.add_child(tile_title)

	var density_container := HBoxContainer.new()
	tile_section.add_child(density_container)

	for density in ["low", "medium", "high", "bone"]:
		var btn := Button.new()
		btn.text = density
		btn.custom_minimum_size = Vector2(60, 25)
		btn.toggled.connect(func(pressed: bool) -> void:
			if pressed:
				selected_density = density
				selected_stream = ""
		)
		btn.toggle_mode = true
		density_container.add_child(btn)
		if density == "low":
			btn.button_pressed = true

	# Stream selector
	var stream_label := Label.new()
	stream_label.text = "Stream:"
	stream_label.add_theme_font_size_override("font_size", 9)
	tile_section.add_child(stream_label)

	var stream_container := HBoxContainer.new()
	tile_section.add_child(stream_container)

	for stream in ["", "north", "south", "east", "west"]:
		var btn := Button.new()
		btn.text = stream if stream else "none"
		btn.custom_minimum_size = Vector2(50, 25)
		btn.toggled.connect(func(pressed: bool) -> void:
			if pressed:
				selected_stream = stream
		)
		btn.toggle_mode = true
		stream_container.add_child(btn)
		if stream == "":
			btn.button_pressed = true

	# Tools
	var tool_section := VBoxContainer.new()
	tool_section.custom_minimum_size = Vector2(140, 0)
	toolbar.add_child(tool_section)

	var tool_title := Label.new()
	tool_title.text = "Tools"
	tool_title.add_theme_font_size_override("font_size", 10)
	tool_section.add_child(tool_title)

	var clear_btn := Button.new()
	clear_btn.text = "Clear Map"
	clear_btn.pressed.connect(_clear_map)
	tool_section.add_child(clear_btn)

	var fill_btn := Button.new()
	fill_btn.text = "Fill All"
	fill_btn.pressed.connect(_fill_all)
	tool_section.add_child(fill_btn)

	# File operations
	var file_section := VBoxContainer.new()
	file_section.custom_minimum_size = Vector2(140, 0)
	toolbar.add_child(file_section)

	var file_title := Label.new()
	file_title.text = "File"
	file_title.add_theme_font_size_override("font_size", 10)
	file_section.add_child(file_title)

	var save_btn := Button.new()
	save_btn.text = "Save Map"
	save_btn.pressed.connect(_save_map)
	file_section.add_child(save_btn)

	var load_btn := Button.new()
	load_btn.text = "Load Map"
	load_btn.pressed.connect(_load_map)
	file_section.add_child(load_btn)

	# Back button
	var back_section := VBoxContainer.new()
	back_section.custom_minimum_size = Vector2(120, 0)
	toolbar.add_child(back_section)

	var back_title := Label.new()
	back_title.text = "Menu"
	back_title.add_theme_font_size_override("font_size", 10)
	back_section.add_child(back_title)

	var back_btn := Button.new()
	back_btn.text = "← Back"
	back_btn.pressed.connect(_back_to_menu)
	back_section.add_child(back_btn)

	# Canvas area (custom control for drawing)
	canvas = Control.new()
	canvas.draw.connect(_on_canvas_draw)
	canvas.gui_input.connect(_on_canvas_input)
	main_container.add_child(canvas)

	# Status bar
	var status_container := HBoxContainer.new()
	status_container.custom_minimum_size = Vector2(0, 30)
	main_container.add_child(status_container)

	tile_info_label = Label.new()
	tile_info_label.text = "Selected: low"
	tile_info_label.add_theme_font_size_override("font_size", 11)
	status_container.add_child(tile_info_label)

	status_label = Label.new()
	status_label.text = "Ready"
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", Color.GREEN)
	status_container.add_child(status_label)

func _init_grid() -> void:
	grid.clear()
	for y in range(map_height):
		var row: Array = []
		for x in range(map_width):
			row.append({"density": "low", "stream": ""})
		grid.append(row)
	if canvas:
		canvas.queue_redraw()

func _on_canvas_draw() -> void:
	for y in range(map_height):
		for x in range(map_width):
			var cell = grid[y][x]
			var tile_rect := Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)

			var color := Color.WHITE
			match cell["density"]:
				"low":
					color = Color(0.8, 0.6, 0.6)
				"medium":
					color = Color(0.7, 0.5, 0.7)
				"high":
					color = Color(0.6, 0.3, 0.6)
				"bone":
					color = Color(0.2, 0.2, 0.2)

			canvas.draw_rect(tile_rect, color)
			canvas.draw_rect(tile_rect, Color.GRAY, false, 1.0)

func _on_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var local_pos := canvas.get_local_mouse_position()
		var grid_x := int(local_pos.x / TILE_SIZE)
		var grid_y := int(local_pos.y / TILE_SIZE)

		if grid_x >= 0 and grid_x < map_width and grid_y >= 0 and grid_y < map_height:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_flood_fill(grid_x, grid_y)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_paint_single(grid_x, grid_y)
			canvas.queue_redraw()

func _paint_single(x: int, y: int) -> void:
	if x >= 0 and x < map_width and y >= 0 and y < map_height:
		grid[y][x]["density"] = selected_density
		grid[y][x]["stream"] = selected_stream
		tile_info_label.text = "Painted: %s @ (%d,%d)" % [selected_density, x, y]

func _flood_fill(start_x: int, start_y: int) -> void:
	if start_x < 0 or start_x >= map_width or start_y < 0 or start_y >= map_height:
		return

	var target_density: String = grid[start_y][start_x]["density"]
	var queue: Array = [[start_x, start_y]]
	var visited: Array = []

	while queue.size() > 0:
		var pos: Array = queue.pop_front() as Array
		var x: int = pos[0]
		var y: int = pos[1]

		if x < 0 or x >= map_width or y < 0 or y >= map_height:
			continue
		if [x, y] in visited:
			continue

		visited.append([x, y])

		if grid[y][x]["density"] == target_density:
			grid[y][x]["density"] = selected_density
			grid[y][x]["stream"] = selected_stream

			queue.append([x + 1, y])
			queue.append([x - 1, y])
			queue.append([x, y + 1])
			queue.append([x, y - 1])

	tile_info_label.text = "Filled %d cells with %s" % [visited.size(), selected_density]

func _clear_map() -> void:
	_init_grid()
	status_label.text = "Map cleared"
	status_label.add_theme_color_override("font_color", Color.GREEN)

func _fill_all() -> void:
	for y in range(map_height):
		for x in range(map_width):
			grid[y][x]["density"] = selected_density
			grid[y][x]["stream"] = selected_stream
	canvas.queue_redraw()
	status_label.text = "Filled entire map with %s" % selected_density
	status_label.add_theme_color_override("font_color", Color.GREEN)

func _save_map() -> void:
	var map_data: Dictionary = {
		"name": "Custom Map",
		"width": map_width,
		"height": map_height,
		"default_density": "low",
		"starting_azn": 150,
		"cells": [],
		"habitas_points": [],
		"azn_nodes": [],
		"injection_zones": [
			{"player": 0, "x1": 0, "y1": 0, "x2": 4, "y2": 4},
			{"player": 1, "x1": map_width - 5, "y1": map_height - 5, "x2": map_width - 1, "y2": map_height - 1}
		]
	}

	for y in range(map_height):
		for x in range(map_width):
			var cell = grid[y][x]
			if cell["density"] != "low" or cell["stream"] != "":
				var cell_data: Dictionary = {"x": x, "y": y, "density": cell["density"]}
				if cell["stream"] != "":
					cell_data["stream"] = cell["stream"]
				map_data["cells"].append(cell_data)

	var timestamp := Time.get_ticks_msec()
	var filename := "user://custom_map_%d.json" % timestamp
	var json_string := JSON.stringify(map_data)
	var file := FileAccess.open(filename, FileAccess.WRITE)
	file.store_string(json_string)

	status_label.text = "Map saved to %s" % filename
	status_label.add_theme_color_override("font_color", Color.GREEN)

func _load_map() -> void:
	status_label.text = "Load feature coming soon"
	status_label.add_theme_color_override("font_color", Color.YELLOW)

func _on_width_changed(value: float) -> void:
	map_width = int(value)
	_init_grid()

func _on_height_changed(value: float) -> void:
	map_height = int(value)
	_init_grid()

func _back_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_scene.tscn")

class_name MapEditor
extends Control

const TILE_SIZE: int = 20
const DEFAULT_WIDTH: int = 40
const DEFAULT_HEIGHT: int = 40

var map_width: int = DEFAULT_WIDTH
var map_height: int = DEFAULT_HEIGHT
var grid: Array = []
var selected_density: String = "low"

var status_label: Label

func _ready() -> void:
	_setup_ui()
	_init_grid()

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
	title.text = "← Tile:  "
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

	var clear_btn := Button.new()
	clear_btn.text = "Clear"
	clear_btn.pressed.connect(_clear_map)
	toolbar.add_child(clear_btn)

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
	status_label.text = "Click to paint | Right-click to fill"
	status_label.add_theme_font_size_override("font_size", 11)
	main.add_child(status_label)

func _init_grid() -> void:
	grid.clear()
	for y in range(map_height):
		var row: Array = []
		for x in range(map_width):
			row.append("low")
		grid.append(row)

func _clear_map() -> void:
	_init_grid()
	queue_redraw()
	status_label.text = "Map cleared"

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var pos = get_local_mouse_position()
		var x = int(pos.x / TILE_SIZE)
		var y = int((pos.y - 50) / TILE_SIZE)  # Account for toolbar height

		if x >= 0 and x < map_width and y >= 0 and y < map_height:
			if event.button_index == MOUSE_BUTTON_LEFT:
				grid[y][x] = selected_density
				status_label.text = "Painted (%d,%d): %s" % [x, y, selected_density]
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_flood_fill(x, y, grid[y][x])
				status_label.text = "Filled with: %s" % selected_density

			queue_redraw()
			get_tree().root.get_mouse_position()  # Consume input

func _flood_fill(start_x: int, start_y: int, target: String) -> void:
	if start_x < 0 or start_x >= map_width or start_y < 0 or start_y >= map_height:
		return

	var stack: Array = [[start_x, start_y]]
	var visited: Array = []
	var count = 0

	while stack.size() > 0 and count < 10000:  # Safety limit
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
	# Draw the grid
	for y in range(map_height):
		for x in range(map_width):
			var color = Color.WHITE
			match grid[y][x]:
				"low":
					color = Color(0.8, 0.6, 0.6)
				"medium":
					color = Color(0.7, 0.5, 0.7)
				"high":
					color = Color(0.5, 0.2, 0.5)
				"bone":
					color = Color(0.2, 0.2, 0.2)

			var rect = Rect2(x * TILE_SIZE, 50 + y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			draw_rect(rect, color)
			draw_rect(rect, Color.GRAY, false, 1)

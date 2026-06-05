class_name MapEditor
extends Control

const TILE_SIZE: int = 20
const DEFAULT_WIDTH: int = 40
const DEFAULT_HEIGHT: int = 40

var map_width: int = DEFAULT_WIDTH
var map_height: int = DEFAULT_HEIGHT
var grid: Array = []
var selected_density: String = "low"

var canvas_control: Control
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
	toolbar.custom_minimum_size = Vector2(0, 60)
	main.add_child(toolbar)

	var title := Label.new()
	title.text = "Map Editor - Left click to paint, Right click to fill"
	toolbar.add_child(title)

	var density_label := Label.new()
	density_label.text = "Tile:"
	toolbar.add_child(density_label)

	for dens in ["low", "medium", "high", "bone"]:
		var btn := Button.new()
		btn.text = dens
		btn.custom_minimum_size = Vector2(70, 30)
		btn.toggle_mode = true
		btn.pressed.connect(func():
			selected_density = dens
			_update_buttons(toolbar, dens)
		)
		toolbar.add_child(btn)
		if dens == "low":
			btn.button_pressed = true

	toolbar.add_child(Label.new())

	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(_save_map)
	toolbar.add_child(save_btn)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_scene.tscn"))
	toolbar.add_child(back_btn)

	# Canvas
	canvas_control = Control.new()
	canvas_control.custom_minimum_size = Vector2(800, 800)
	canvas_control.gui_input.connect(_on_input)
	main.add_child(canvas_control)

	# Status
	status_label = Label.new()
	status_label.text = "Ready"
	main.add_child(status_label)

func _init_grid() -> void:
	grid.clear()
	for y in range(map_height):
		var row: Array = []
		for x in range(map_width):
			row.append("low")
		grid.append(row)
	canvas_control.queue_redraw()

func _update_buttons(toolbar: Node, selected: String) -> void:
	for child in toolbar.get_children():
		if child is Button and child.toggle_mode:
			child.button_pressed = (child.text == selected)

func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var pos = canvas_control.get_local_mouse_position()
		var x = int(pos.x / TILE_SIZE)
		var y = int(pos.y / TILE_SIZE)

		if x >= 0 and x < map_width and y >= 0 and y < map_height:
			if event.button_index == MOUSE_BUTTON_LEFT:
				grid[y][x] = selected_density
				status_label.text = "Painted at (%d, %d): %s" % [x, y, selected_density]
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_flood_fill(x, y, grid[y][x])
				status_label.text = "Filled with: %s" % selected_density

			canvas_control.queue_redraw()

func _flood_fill(start_x: int, start_y: int, target: String) -> void:
	var stack: Array = [[start_x, start_y]]
	var visited: Array = []

	while stack.size() > 0:
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
		"name": "Editor Map",
		"width": map_width,
		"height": map_height,
		"default_density": "low",
		"starting_azn": 150,
		"cells": cells,
		"habitas_points": [{"x": 5, "y": 5}, {"x": map_width - 6, "y": map_height - 6}],
		"azn_nodes": [{"x": map_width / 2, "y": map_height / 2, "quantity": 30}],
		"injection_zones": [
			{"player": 0, "x1": 0, "y1": 0, "x2": 4, "y2": 4},
			{"player": 1, "x1": map_width - 5, "y1": map_height - 5, "x2": map_width - 1, "y2": map_height - 1}
		]
	}

	var file = FileAccess.open("user://custom_map.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(map_data))
	status_label.text = "Saved to user://custom_map.json"

func _draw() -> void:
	var draw_target = canvas_control
	if draw_target == null:
		return

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

			var rect = Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			draw_rect(rect, color)
			draw_rect(rect, Color.GRAY, false, 1)

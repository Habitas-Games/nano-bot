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
var is_painting: bool = false
var scroll_pos: Vector2 = Vector2.ZERO

var sprites: Dictionary = {}
var terrain_buttons: Dictionary = {}
var scroll_container: ScrollContainer
var canvas_control: Control

func _ready() -> void:
	_load_sprites()
	_init_grid()
	_setup_ui()

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

	# LEFT PANEL
	var panel_bg := PanelContainer.new()
	panel_bg.custom_minimum_size = Vector2(220, 0)
	root.add_child(panel_bg)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.15)
	panel_bg.add_theme_stylebox_override("panel", panel_style)

	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 10)
	panel_bg.add_child(panel)

	var title := Label.new()
	title.text = "Map Editor"
	title.add_theme_font_size_override("font_size", 18)
	panel.add_child(title)

	# Terrain section
	var tile_label := Label.new()
	tile_label.text = "Terrain"
	tile_label.add_theme_font_size_override("font_size", 13)
	panel.add_child(tile_label)

	for dens in ["low", "medium", "high", "bone"]:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 50)
		btn.text = "  " + dens.to_upper()
		btn.toggle_mode = true
		if sprites.get(dens):
			btn.icon = sprites[dens]
		var dens_copy = dens
		btn.pressed.connect(func(): _select_density(dens_copy))
		panel.add_child(btn)
		terrain_buttons[dens] = btn
		if dens == "low":
			btn.button_pressed = true

	# Add Border button
	var border_btn := Button.new()
	border_btn.text = "⬜ Add Border"
	border_btn.custom_minimum_size = Vector2(0, 40)
	border_btn.pressed.connect(_add_border)
	panel.add_child(border_btn)

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

	var save_btn := Button.new()
	save_btn.text = "💾 Save Map"
	save_btn.pressed.connect(_save_map)
	panel.add_child(save_btn)

	panel.add_child(Control.new())

	var back_btn := Button.new()
	back_btn.text = "← Back to Menu"
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_scene.tscn"))
	panel.add_child(back_btn)

	# RIGHT SIDE
	var right := VBoxContainer.new()
	root.add_child(right)

	var status := Label.new()
	status.text = "Click & drag to paint | Right-click to fill | Scroll to zoom"
	status.add_theme_font_size_override("font_size", 10)
	right.add_child(status)

	# ScrollContainer for canvas
	scroll_container = ScrollContainer.new()
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	right.add_child(scroll_container)

	# Canvas in scroll container
	canvas_control = Control.new()
	canvas_control.custom_minimum_size = Vector2(map_width * TILE_SIZE, map_height * TILE_SIZE)
	canvas_control.draw.connect(_on_canvas_draw)
	canvas_control.gui_input.connect(_on_canvas_input)
	scroll_container.add_child(canvas_control)

func _select_density(dens: String) -> void:
	selected_density = dens
	for d in terrain_buttons.keys():
		terrain_buttons[d].button_pressed = (d == dens)

func _on_canvas_draw() -> void:
	for y in range(map_height):
		for x in range(map_width):
			var screen_x = x * TILE_SIZE * zoom
			var screen_y = y * TILE_SIZE * zoom
			var size = TILE_SIZE * zoom

			var density = grid[y][x]
			var color = Color.WHITE

			match density:
				"low": color = Color(0.8, 0.6, 0.6)
				"medium": color = Color(0.7, 0.5, 0.7)
				"high": color = Color(0.5, 0.2, 0.5)
				"bone": color = Color(0.2, 0.2, 0.2)

			if sprites.get(density):
				canvas_control.draw_texture_rect(sprites[density], Rect2(screen_x, screen_y, size, size), false)
			else:
				canvas_control.draw_rect(Rect2(screen_x, screen_y, size, size), color)

			canvas_control.draw_rect(Rect2(screen_x, screen_y, size, size), Color.GRAY, false, 1.0)

func _on_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = min(zoom + 0.1, 3.0)
			canvas_control.custom_minimum_size = Vector2(map_width * TILE_SIZE * zoom, map_height * TILE_SIZE * zoom)
			canvas_control.queue_redraw()
			get_tree().root.set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = max(zoom - 0.1, 0.5)
			canvas_control.custom_minimum_size = Vector2(map_width * TILE_SIZE * zoom, map_height * TILE_SIZE * zoom)
			canvas_control.queue_redraw()
			get_tree().root.set_input_as_handled()
			return

	if event is InputEventMouseButton and event.pressed:
		var local_pos = canvas_control.get_local_mouse_position()
		var grid_x = int(local_pos.x / (TILE_SIZE * zoom))
		var grid_y = int(local_pos.y / (TILE_SIZE * zoom))

		if grid_x >= 0 and grid_x < map_width and grid_y >= 0 and grid_y < map_height:
			if event.button_index == MOUSE_BUTTON_LEFT:
				is_painting = true
				grid[grid_y][grid_x] = selected_density
				canvas_control.queue_redraw()
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_flood_fill(grid_x, grid_y, grid[grid_y][grid_x])
				canvas_control.queue_redraw()

	if event is InputEventMouseButton and not event.pressed:
		is_painting = false

	if event is InputEventMouseMotion and is_painting:
		var local_pos = canvas_control.get_local_mouse_position()
		var grid_x = int(local_pos.x / (TILE_SIZE * zoom))
		var grid_y = int(local_pos.y / (TILE_SIZE * zoom))

		if grid_x >= 0 and grid_x < map_width and grid_y >= 0 and grid_y < map_height:
			grid[grid_y][grid_x] = selected_density
			canvas_control.queue_redraw()

func _clear_map() -> void:
	_init_grid()
	canvas_control.queue_redraw()

func _add_border() -> void:
	for x in range(map_width):
		grid[0][x] = "bone"
		grid[map_height - 1][x] = "bone"
	for y in range(map_height):
		grid[y][0] = "bone"
		grid[y][map_width - 1] = "bone"
	canvas_control.queue_redraw()

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

	# Create dialog
	var dialog = AcceptDialog.new()
	dialog.title = "Load Map"
	dialog.initial_position = Window.WINDOW_POS_CENTER_SCREEN
	dialog.size = Vector2i(400, 300)
	add_child(dialog)

	var container := VBoxContainer.new()
	dialog.add_child(container)

	var label := Label.new()
	label.text = "Select a map to edit:"
	container.add_child(label)

	var item_list := ItemList.new()
	item_list.custom_minimum_size = Vector2(400, 250)
	for file in files:
		item_list.add_item(file.trim_suffix(".json"))
	container.add_child(item_list)

	dialog.confirmed.connect(func():
		var idx = item_list.get_selected_items()
		if idx.size() > 0:
			_load_map(files[idx[0]])
		dialog.queue_free()
	)
	dialog.popup_centered_ratio(0.5)

func _load_map(filename: String) -> void:
	var file = FileAccess.open("res://maps/" + filename, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	if data:
		map_width = data.get("width", DEFAULT_WIDTH)
		map_height = data.get("height", DEFAULT_HEIGHT)
		_init_grid()
		for cell in data.get("cells", []):
			if "x" in cell and "y" in cell and cell["x"] < map_width and cell["y"] < map_height:
				grid[cell["y"]][cell["x"]] = cell.get("density", "low")
		canvas_control.custom_minimum_size = Vector2(map_width * TILE_SIZE * zoom, map_height * TILE_SIZE * zoom)
		canvas_control.queue_redraw()

func _save_map() -> void:
	var cells = []
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
		"habitas_points": [{"x": 2, "y": 2}, {"x": map_width - 3, "y": map_height - 3}],
		"azn_nodes": [{"x": map_width / 2, "y": map_height / 2, "quantity": 30}],
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

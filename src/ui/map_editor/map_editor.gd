class_name MapEditor
extends Control

# Phase 1: Core Canvas Implementation

const TILE_SIZE: int = 16
const DEFAULT_WIDTH: int = 60
const DEFAULT_HEIGHT: int = 60
const MIN_ZOOM: float = 0.5
const MAX_ZOOM: float = 3.0
const ZOOM_STEP: float = 0.1

# Map data
var map_width: int = DEFAULT_WIDTH
var map_height: int = DEFAULT_HEIGHT
var grid: Array[Array[String]] = []

# Sprites
var sprites: Dictionary[String, Texture2D] = {}

# View state
var zoom: float = 1.0
var scroll_x: int = 0
var scroll_y: int = 0

# UI references
var canvas_control: Control

# Editing state
var selected_density: String = "low"
var is_painting: bool = false

func _ready() -> void:
	_load_sprites()
	_init_grid()
	_setup_ui()
	_load_default_map()

func _load_sprites() -> void:
	"""Load terrain sprite assets"""
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
	"""Initialize empty grid with default density"""
	grid.clear()
	for y in range(map_height):
		var row: Array[String] = []
		for x in range(map_width):
			row.append("low")
		grid.append(row)

func _setup_ui() -> void:
	"""Create UI layout: top toolbar + canvas + horizontal scrollbar on left, right panel on right"""
	var root = HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# LEFT CONTAINER: Canvas area
	var left_container = VBoxContainer.new()
	left_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(left_container)

	# Top toolbar
	var toolbar = HBoxContainer.new()
	toolbar.custom_minimum_size = Vector2(0, 50)
	toolbar.add_theme_constant_override("separation", 10)
	left_container.add_child(toolbar)

	var load_btn = Button.new()
	load_btn.text = "📂 Load Map"
	load_btn.pressed.connect(_show_load_dialog)
	toolbar.add_child(load_btn)

	var save_btn = Button.new()
	save_btn.text = "💾 Save Map"
	save_btn.pressed.connect(_save_map)
	toolbar.add_child(save_btn)

	var clear_btn = Button.new()
	clear_btn.text = "🗑️ Clear"
	clear_btn.pressed.connect(_clear_map)
	toolbar.add_child(clear_btn)

	# Canvas
	canvas_control = Control.new()
	canvas_control.custom_minimum_size = Vector2(800, 600)
	canvas_control.draw.connect(_on_canvas_draw)
	canvas_control.gui_input.connect(_on_canvas_input)
	left_container.add_child(canvas_control)
	canvas_control.size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Horizontal scrollbar
	var h_scroll = HScrollBar.new()
	h_scroll.custom_minimum_size = Vector2(0, 15)
	h_scroll.value_changed.connect(func(v): 
		scroll_x = int(v)
		canvas_control.queue_redraw()
	)
	left_container.add_child(h_scroll)

	# RIGHT CONTAINER: Info panel
	var right_panel = PanelContainer.new()
	right_panel.custom_minimum_size = Vector2(220, 0)
	root.add_child(right_panel)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.15)
	right_panel.add_theme_stylebox_override("panel", panel_style)

	var panel_vbox = VBoxContainer.new()
	panel_vbox.add_theme_constant_override("separation", 10)
	right_panel.add_child(panel_vbox)

	var title = Label.new()
	title.text = "Map Editor"
	title.add_theme_font_size_override("font_size", 16)
	panel_vbox.add_child(title)

	# Legend
	var legend_title = Label.new()
	legend_title.text = "Legend"
	legend_title.add_theme_font_size_override("font_size", 12)
	panel_vbox.add_child(legend_title)

	for label in ["🟨 Low (2 turns)", "🟪 Medium (3 turns)", "🟩 High (4 turns)", "⬛ Bone (blocked)"]:
		var lbl = Label.new()
		lbl.text = label
		lbl.add_theme_font_size_override("font_size", 10)
		panel_vbox.add_child(lbl)

	panel_vbox.add_child(Control.new())  # spacer

	# Terrain selector
	var terrain_label = Label.new()
	terrain_label.text = "Select Terrain"
	terrain_label.add_theme_font_size_override("font_size", 11)
	panel_vbox.add_child(terrain_label)

	for density in ["low", "medium", "high", "bone"]:
		var btn = Button.new()
		btn.text = density.to_upper()
		btn.custom_minimum_size = Vector2(0, 30)
		btn.toggle_mode = true
		btn.button_pressed = (density == "low")
		var density_copy = density
		btn.pressed.connect(func():
			selected_density = density_copy
			for d in ["low", "medium", "high", "bone"]:
				# Update button states - simplified
				pass
		)
		panel_vbox.add_child(btn)

func _load_default_map() -> void:
	"""Load first available map or use blank grid"""
	var dir = DirAccess.open("res://maps/")
	if not dir:
		queue_redraw()
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			_load_map("res://maps/" + file_name)
			return
		file_name = dir.get_next()

	queue_redraw()

func _load_map(path: String) -> void:
	"""Load map from JSON file"""
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open: " + path)
		return

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error != OK:
		push_error("Invalid JSON: " + path)
		return

	var data = json.data
	if data == null or not data.is_dict():
		push_error("Invalid map format: " + path)
		return

	map_width = data.get("width", DEFAULT_WIDTH)
	map_height = data.get("height", DEFAULT_HEIGHT)
	_init_grid()

	# Load terrain cells
	var cells = data.get("cells", [])
	for cell in cells:
		if "x" in cell and "y" in cell:
			var x = cell["x"]
			var y = cell["y"]
			if x >= 0 and x < map_width and y >= 0 and y < map_height:
				grid[y][x] = cell.get("density", "low")

	# Reset view
	zoom = 1.0
	scroll_x = 0
	scroll_y = 0

	queue_redraw()

func _on_canvas_draw() -> void:
	"""Render the map canvas"""
	var canvas_pos = canvas_control.global_position
	var canvas_size = canvas_control.size

	# Draw background
	draw_rect(Rect2(canvas_pos, canvas_size), Color(0.2, 0.2, 0.2))

	# Draw terrain grid
	for y in range(map_height):
		for x in range(map_width):
			var screen_x = canvas_pos.x + (x * TILE_SIZE * zoom) - scroll_x
			var screen_y = canvas_pos.y + (y * TILE_SIZE * zoom) - scroll_y
			var size = TILE_SIZE * zoom

			# Skip if off-screen
			if screen_x + size < canvas_pos.x or screen_x > canvas_pos.x + canvas_size.x:
				continue
			if screen_y + size < canvas_pos.y or screen_y > canvas_pos.y + canvas_size.y:
				continue

			var density = grid[y][x]
			var color = Color.WHITE

			# Get color based on density
			match density:
				"low": color = Color(0.8, 0.6, 0.6)
				"medium": color = Color(0.7, 0.5, 0.7)
				"high": color = Color(0.5, 0.2, 0.5)
				"bone": color = Color(0.2, 0.2, 0.2)

			# Draw sprite or fallback color
			if sprites.get(density):
				draw_texture_rect(sprites[density], Rect2(screen_x, screen_y, size, size), false)
			else:
				draw_rect(Rect2(screen_x, screen_y, size, size), color)

			# Draw grid lines
			draw_rect(Rect2(screen_x, screen_y, size, size), Color.GRAY, false, 1.0)

func _on_canvas_input(event: InputEvent) -> void:
	"""Handle canvas input"""
	var canvas_pos = canvas_control.global_position
	var canvas_size = canvas_control.size

	# Scroll wheel zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom = min(zoom + ZOOM_STEP, MAX_ZOOM)
			canvas_control.queue_redraw()
			get_tree().root.set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom = max(zoom - ZOOM_STEP, MIN_ZOOM)
			canvas_control.queue_redraw()
			get_tree().root.set_input_as_handled()
			return

	# Left click to paint
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local_pos = event.position
		if _is_in_canvas(local_pos, canvas_pos, canvas_size):
			var grid_x = int((local_pos.x - canvas_pos.x + scroll_x) / (TILE_SIZE * zoom))
			var grid_y = int((local_pos.y - canvas_pos.y + scroll_y) / (TILE_SIZE * zoom))

			if grid_x >= 0 and grid_x < map_width and grid_y >= 0 and grid_y < map_height:
				grid[grid_y][grid_x] = selected_density
				is_painting = true
				canvas_control.queue_redraw()
				get_tree().root.set_input_as_handled()

	# Left click release
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		is_painting = false

	# Left click drag to paint
	if event is InputEventMouseMotion and is_painting:
		var local_pos = event.position
		if _is_in_canvas(local_pos, canvas_pos, canvas_size):
			var grid_x = int((local_pos.x - canvas_pos.x + scroll_x) / (TILE_SIZE * zoom))
			var grid_y = int((local_pos.y - canvas_pos.y + scroll_y) / (TILE_SIZE * zoom))

			if grid_x >= 0 and grid_x < map_width and grid_y >= 0 and grid_y < map_height:
				grid[grid_y][grid_x] = selected_density
				canvas_control.queue_redraw()

	# Middle click drag to pan
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MIDDLE:
		var delta = event.relative
		var max_scroll_x = max(0, map_width * TILE_SIZE * zoom - canvas_size.x)
		var max_scroll_y = max(0, map_height * TILE_SIZE * zoom - canvas_size.y)
		scroll_x = clampi(scroll_x - int(delta.x), 0, max_scroll_x)
		scroll_y = clampi(scroll_y - int(delta.y), 0, max_scroll_y)
		canvas_control.queue_redraw()

func _is_in_canvas(pos: Vector2, canvas_pos: Vector2, canvas_size: Vector2) -> bool:
	"""Check if position is inside canvas area"""
	return pos.x >= canvas_pos.x and pos.x < canvas_pos.x + canvas_size.x and \
	       pos.y >= canvas_pos.y and pos.y < canvas_pos.y + canvas_size.y

func _show_load_dialog() -> void:
	"""Show load map dialog"""
	var dir = DirAccess.open("res://maps/")
	if not dir:
		push_error("Maps directory not found")
		return

	var files = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			files.append(file_name)
		file_name = dir.get_next()

	if files.is_empty():
		push_error("No maps found")
		return

	var popup = PopupMenu.new()
	add_child(popup)

	for i in range(files.size()):
		var map_name = files[i].trim_suffix(".json")
		popup.add_item(map_name, i)

	popup.id_pressed.connect(func(id: int):
		_load_map("res://maps/" + files[id])
		popup.queue_free()
	)

	popup.popup_centered_ratio(0.3)

func _save_map() -> void:
	"""Save map to JSON"""
	var cells = []
	for y in range(map_height):
		for x in range(map_width):
			if grid[y][x] != "low":  # Only save non-default
				cells.append({"x": x, "y": y, "density": grid[y][x]})

	var map_data = {
		"name": "Custom Map",
		"width": map_width,
		"height": map_height,
		"default_density": "low",
		"starting_azn": 150,
		"cells": cells,
		"habitas_points": [],
		"azn_nodes": [],
		"injection_zones": []
	}

	var file = FileAccess.open("user://custom_map.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(map_data))
		print("Map saved to user://custom_map.json")
	else:
		push_error("Failed to save map")

func _clear_map() -> void:
	"""Clear map to all low density"""
	_init_grid()
	canvas_control.queue_redraw()

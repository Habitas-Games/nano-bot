class_name MapEditor
extends Control

# Map Editor - All Phases Implementation (1-5)

const TILE_SIZE: int = 16
const DEFAULT_WIDTH: int = 60
const DEFAULT_HEIGHT: int = 60
const MIN_ZOOM: float = 0.5
const MAX_ZOOM: float = 3.0
const ZOOM_STEP: float = 0.1
const MAX_HISTORY: int = 50

# Map data
var map_width: int = DEFAULT_WIDTH
var map_height: int = DEFAULT_HEIGHT
var grid: Array = []

# Map elements
var habitas_points: Array = []
var azn_nodes: Array = []
var injection_zones: Array = []
var bloodstreams: Array = []

# Sprites
var sprites: Dictionary = {}

# View state
var zoom: float = 1.0
var scroll_x: int = 0
var scroll_y: int = 0

# UI references
var canvas_control: Control
var status_label: Label
var undo_btn: Button

# Editing state
var selected_density: String = "low"
var selected_mode: String = "terrain"
var selected_stream_dir: String = "north"
var selected_element_type: String = ""
var is_painting: bool = false
var last_paint_pos: Vector2i = Vector2i(-1, -1)

# History
var history: Array = []
var history_index: int = -1

# Element editing
var selected_element: Dictionary = {}
var editing_zone_start: Vector2i = Vector2i(-1, -1)
var is_editing_zone: bool = false

func _ready() -> void:
	_load_sprites()
	_init_grid()
	_setup_ui()
	_load_default_map()
	_save_state()

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
	"""Create full UI layout"""
	var root = HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	# LEFT CONTAINER
	var left_container = VBoxContainer.new()
	left_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(left_container)

	# Status bar (Phase 5)
	status_label = Label.new()
	status_label.text = "Terrain: LOW | Click: paint | Drag: continuous | Right-click: fill | Scroll: zoom | Middle-drag: pan"
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.custom_minimum_size = Vector2(0, 30)
	left_container.add_child(status_label)

	# Top toolbar (Phase 4)
	var toolbar = HBoxContainer.new()
	toolbar.custom_minimum_size = Vector2(0, 40)
	toolbar.add_theme_constant_override("separation", 5)
	left_container.add_child(toolbar)

	var load_btn = Button.new()
	load_btn.text = "📂 Load"
	load_btn.pressed.connect(_show_load_dialog)
	toolbar.add_child(load_btn)

	var save_btn = Button.new()
	save_btn.text = "💾 Save"
	save_btn.pressed.connect(_show_save_dialog)
	toolbar.add_child(save_btn)

	var clear_btn = Button.new()
	clear_btn.text = "🗑️ Clear"
	clear_btn.pressed.connect(_clear_map)
	toolbar.add_child(clear_btn)

	undo_btn = Button.new()
	undo_btn.text = "↶ Undo"
	undo_btn.pressed.connect(_undo)
	undo_btn.disabled = true
	toolbar.add_child(undo_btn)

	# Canvas
	canvas_control = Control.new()
	canvas_control.custom_minimum_size = Vector2(800, 600)
	canvas_control.draw.connect(_on_canvas_draw)
	canvas_control.gui_input.connect(_on_canvas_input)
	canvas_control.mouse_entered.connect(_on_canvas_mouse_entered)
	canvas_control.mouse_exited.connect(_on_canvas_mouse_exited)
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

	# RIGHT CONTAINER: Control panel
	var right_panel = PanelContainer.new()
	right_panel.custom_minimum_size = Vector2(220, 0)
	root.add_child(right_panel)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.15)
	right_panel.add_theme_stylebox_override("panel", panel_style)

	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	right_panel.add_child(scroll)

	var panel_vbox = VBoxContainer.new()
	panel_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(panel_vbox)

	var title = Label.new()
	title.text = "Map Editor"
	title.add_theme_font_size_override("font_size", 16)
	panel_vbox.add_child(title)

	# Map info
	var map_info = Label.new()
	map_info.text = "Size: 60x60"
	map_info.add_theme_font_size_override("font_size", 10)
	panel_vbox.add_child(map_info)

	panel_vbox.add_child(HSeparator.new())

	# Legend
	var legend_title = Label.new()
	legend_title.text = "Legend"
	legend_title.add_theme_font_size_override("font_size", 12)
	panel_vbox.add_child(legend_title)

	for label in ["🟨 Low", "🟪 Medium", "🟩 High", "⬛ Bone"]:
		var lbl = Label.new()
		lbl.text = label
		lbl.add_theme_font_size_override("font_size", 10)
		panel_vbox.add_child(lbl)

	panel_vbox.add_child(HSeparator.new())

	# Terrain selector (Phase 2)
	var terrain_title = Label.new()
	terrain_title.text = "Terrain"
	terrain_title.add_theme_font_size_override("font_size", 11)
	panel_vbox.add_child(terrain_title)

	for density in ["low", "medium", "high", "bone"]:
		var btn = Button.new()
		btn.text = density.to_upper()
		btn.custom_minimum_size = Vector2(0, 28)
		btn.toggle_mode = true
		btn.button_pressed = (density == "low")
		var density_copy = density
		btn.pressed.connect(func():
			selected_density = density_copy
			selected_mode = "terrain"
			_update_status()
		)
		panel_vbox.add_child(btn)

	var border_btn = Button.new()
	border_btn.text = "⬜ Add Border"
	border_btn.custom_minimum_size = Vector2(0, 28)
	border_btn.pressed.connect(_add_border)
	panel_vbox.add_child(border_btn)

	panel_vbox.add_child(HSeparator.new())

	# Element tools (Phase 3)
	var elem_title = Label.new()
	elem_title.text = "Elements"
	elem_title.add_theme_font_size_override("font_size", 11)
	panel_vbox.add_child(elem_title)

	for mode_data in [
		{"name": "habitas", "text": "🔴 Habitas"},
		{"name": "azn", "text": "🟡 AZN"},
		{"name": "zones", "text": "🟢 Zones"},
		{"name": "streams", "text": "➡️ Streams"}
	]:
		var btn = Button.new()
		btn.text = mode_data["text"]
		btn.custom_minimum_size = Vector2(0, 28)
		btn.toggle_mode = true
		var mode_name = mode_data["name"]
		btn.pressed.connect(func():
			selected_mode = mode_name
			_update_status()
		)
		panel_vbox.add_child(btn)

	# Stream direction selector (Phase 3)
	var stream_title = Label.new()
	stream_title.text = "Stream Dir"
	stream_title.add_theme_font_size_override("font_size", 10)
	panel_vbox.add_child(stream_title)

	for dir in ["north", "south", "east", "west", "ns", "ew"]:
		var btn = Button.new()
		match dir:
			"north": btn.text = "↑ N"
			"south": btn.text = "↓ S"
			"east": btn.text = "→ E"
			"west": btn.text = "← W"
			"ns": btn.text = "↕ NS"
			"ew": btn.text = "↔ EW"
		btn.custom_minimum_size = Vector2(0, 24)
		btn.toggle_mode = true
		btn.button_pressed = (dir == "north")
		var dir_copy = dir
		btn.pressed.connect(func():
			selected_stream_dir = dir_copy
		)
		panel_vbox.add_child(btn)

func _load_default_map() -> void:
	"""Load first available map"""
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
	"""Load map from JSON"""
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_show_error("Cannot open: " + path)
		return

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error != OK:
		_show_error("Invalid JSON: " + path)
		return

	var data = json.data
	if data == null or not data.is_dict():
		_show_error("Invalid map format")
		return

	map_width = data.get("width", DEFAULT_WIDTH)
	map_height = data.get("height", DEFAULT_HEIGHT)
	_init_grid()

	# Load cells
	for cell in data.get("cells", []):
		if "x" in cell and "y" in cell:
			var x = cell["x"]
			var y = cell["y"]
			if x >= 0 and x < map_width and y >= 0 and y < map_height:
				grid[y][x] = cell.get("density", "low")
				if cell.get("stream"):
					bloodstreams.append({"x": x, "y": y, "stream": cell["stream"]})

	habitas_points = data.get("habitas_points", []).duplicate()
	azn_nodes = data.get("azn_nodes", []).duplicate()
	injection_zones = data.get("injection_zones", []).duplicate()

	zoom = 1.0
	scroll_x = 0
	scroll_y = 0
	history.clear()
	history_index = -1
	_save_state()

	_update_status()
	queue_redraw()

func _on_canvas_draw() -> void:
	"""Render the map"""
	var canvas_pos = canvas_control.global_position
	var canvas_size = canvas_control.size

	# Background
	draw_rect(Rect2(canvas_pos, canvas_size), Color(0.2, 0.2, 0.2))

	# Terrain
	for y in range(map_height):
		for x in range(map_width):
			var screen_x = canvas_pos.x + (x * TILE_SIZE * zoom) - scroll_x
			var screen_y = canvas_pos.y + (y * TILE_SIZE * zoom) - scroll_y
			var size = TILE_SIZE * zoom

			if screen_x + size < canvas_pos.x or screen_x > canvas_pos.x + canvas_size.x:
				continue
			if screen_y + size < canvas_pos.y or screen_y > canvas_pos.y + canvas_size.y:
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

	# Injection zones
	for zone in injection_zones:
		var x1 = zone["x1"]
		var y1 = zone["y1"]
		var x2 = zone["x2"] + 1
		var y2 = zone["y2"] + 1
		var screen_x1 = canvas_pos.x + (x1 * TILE_SIZE * zoom) - scroll_x
		var screen_y1 = canvas_pos.y + (y1 * TILE_SIZE * zoom) - scroll_y
		var screen_x2 = canvas_pos.x + (x2 * TILE_SIZE * zoom) - scroll_x
		var screen_y2 = canvas_pos.y + (y2 * TILE_SIZE * zoom) - scroll_y
		var zone_color = Color(0, 1, 0, 0.2) if zone["player"] == 0 else Color(1, 0, 0, 0.2)
		draw_rect(Rect2(screen_x1, screen_y1, screen_x2 - screen_x1, screen_y2 - screen_y1), zone_color)

	# Habitas points
	for pt in habitas_points:
		var screen_x = canvas_pos.x + (pt["x"] * TILE_SIZE * zoom) - scroll_x + (TILE_SIZE * zoom) / 2
		var screen_y = canvas_pos.y + (pt["y"] * TILE_SIZE * zoom) - scroll_y + (TILE_SIZE * zoom) / 2
		draw_circle(Vector2(screen_x, screen_y), 5 * zoom, Color.RED)

	# AZN nodes
	for node in azn_nodes:
		var screen_x = canvas_pos.x + (node["x"] * TILE_SIZE * zoom) - scroll_x + (TILE_SIZE * zoom) / 2
		var screen_y = canvas_pos.y + (node["y"] * TILE_SIZE * zoom) - scroll_y + (TILE_SIZE * zoom) / 2
		draw_circle(Vector2(screen_x, screen_y), 4 * zoom, Color.YELLOW)

	# Bloodstreams (arrows)
	for stream in bloodstreams:
		var screen_x = canvas_pos.x + (stream["x"] * TILE_SIZE * zoom) - scroll_x + (TILE_SIZE * zoom) / 2
		var screen_y = canvas_pos.y + (stream["y"] * TILE_SIZE * zoom) - scroll_y + (TILE_SIZE * zoom) / 2
		var arrow_size = 6 * zoom
		var dir = stream.get("stream", "")
		var color = Color(1.0, 0.5, 0.3)  # Orange

		match dir:
			"north":
				draw_line(Vector2(screen_x, screen_y), Vector2(screen_x, screen_y - arrow_size), color, 2)
			"south":
				draw_line(Vector2(screen_x, screen_y), Vector2(screen_x, screen_y + arrow_size), color, 2)
			"east":
				draw_line(Vector2(screen_x, screen_y), Vector2(screen_x + arrow_size, screen_y), color, 2)
			"west":
				draw_line(Vector2(screen_x, screen_y), Vector2(screen_x - arrow_size, screen_y), color, 2)
			"ns":
				draw_line(Vector2(screen_x, screen_y), Vector2(screen_x, screen_y - arrow_size), color, 2)
				draw_line(Vector2(screen_x, screen_y), Vector2(screen_x, screen_y + arrow_size), color, 2)
			"ew":
				draw_line(Vector2(screen_x, screen_y), Vector2(screen_x - arrow_size, screen_y), color, 2)
				draw_line(Vector2(screen_x, screen_y), Vector2(screen_x + arrow_size, screen_y), color, 2)

	# Highlight selected element
	if selected_element and "x" in selected_element and "y" in selected_element:
		var screen_x = canvas_pos.x + (selected_element["x"] * TILE_SIZE * zoom) - scroll_x
		var screen_y = canvas_pos.y + (selected_element["y"] * TILE_SIZE * zoom) - scroll_y
		var size = TILE_SIZE * zoom
		draw_rect(Rect2(screen_x, screen_y, size, size), Color.YELLOW, false, 3.0)

func _on_canvas_input(event: InputEvent) -> void:
	"""Handle canvas input"""
	var canvas_pos = canvas_control.global_position
	var canvas_size = canvas_control.size

	# Zoom
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

	# Click to paint/place
	if event is InputEventMouseButton and event.pressed:
		var local_pos = event.position
		if _is_in_canvas(local_pos, canvas_pos, canvas_size):
			var grid_x = int((local_pos.x - canvas_pos.x + scroll_x) / (TILE_SIZE * zoom))
			var grid_y = int((local_pos.y - canvas_pos.y + scroll_y) / (TILE_SIZE * zoom))

			if grid_x >= 0 and grid_x < map_width and grid_y >= 0 and grid_y < map_height:
				_save_state()

				if selected_mode == "terrain":
					if event.button_index == MOUSE_BUTTON_LEFT:
						is_painting = true
						last_paint_pos = Vector2i(grid_x, grid_y)
						grid[grid_y][grid_x] = selected_density
					elif event.button_index == MOUSE_BUTTON_RIGHT:
						_flood_fill(grid_x, grid_y, grid[grid_y][grid_x])
				elif selected_mode == "habitas" and event.button_index == MOUSE_BUTTON_LEFT:
					habitas_points.append({"x": grid_x, "y": grid_y})
				elif selected_mode == "azn" and event.button_index == MOUSE_BUTTON_LEFT:
					azn_nodes.append({"x": grid_x, "y": grid_y, "quantity": 30})
				elif selected_mode == "streams" and event.button_index == MOUSE_BUTTON_LEFT:
					bloodstreams.append({"x": grid_x, "y": grid_y, "stream": selected_stream_dir})
					grid[grid_y][grid_x] = "medium"
				elif selected_mode == "zones" and event.button_index == MOUSE_BUTTON_LEFT:
					is_editing_zone = true
					editing_zone_start = Vector2i(grid_x, grid_y)

				_update_status()
				canvas_control.queue_redraw()

	# Release
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_painting = false

			if selected_mode == "zones" and is_editing_zone:
				var local_pos = event.position
				var grid_x = int((local_pos.x - canvas_pos.x + scroll_x) / (TILE_SIZE * zoom))
				var grid_y = int((local_pos.y - canvas_pos.y + scroll_y) / (TILE_SIZE * zoom))

				var x1 = mini(editing_zone_start.x, grid_x)
				var x2 = maxi(editing_zone_start.x, grid_x)
				var y1 = mini(editing_zone_start.y, grid_y)
				var y2 = maxi(editing_zone_start.y, grid_y)

				injection_zones.append({"player": 0, "x1": x1, "y1": y1, "x2": x2, "y2": y2})
				is_editing_zone = false
				canvas_control.queue_redraw()

	# Drag paint
	if event is InputEventMouseMotion and is_painting:
		var local_pos = event.position
		if _is_in_canvas(local_pos, canvas_pos, canvas_size):
			var grid_x = int((local_pos.x - canvas_pos.x + scroll_x) / (TILE_SIZE * zoom))
			var grid_y = int((local_pos.y - canvas_pos.y + scroll_y) / (TILE_SIZE * zoom))

			if grid_x >= 0 and grid_x < map_width and grid_y >= 0 and grid_y < map_height:
				if Vector2i(grid_x, grid_y) != last_paint_pos:
					grid[grid_y][grid_x] = selected_density
					last_paint_pos = Vector2i(grid_x, grid_y)
					canvas_control.queue_redraw()

	# Pan
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MIDDLE:
		var delta = event.relative
		var max_x = max(0, map_width * TILE_SIZE * zoom - canvas_size.x)
		var max_y = max(0, map_height * TILE_SIZE * zoom - canvas_size.y)
		scroll_x = clampi(scroll_x - int(delta.x), 0, max_x)
		scroll_y = clampi(scroll_y - int(delta.y), 0, max_y)
		canvas_control.queue_redraw()

func _on_canvas_mouse_entered() -> void:
	pass

func _on_canvas_mouse_exited() -> void:
	is_painting = false

func _is_in_canvas(pos: Vector2, canvas_pos: Vector2, canvas_size: Vector2) -> bool:
	return pos.x >= canvas_pos.x and pos.x < canvas_pos.x + canvas_size.x and \
		   pos.y >= canvas_pos.y and pos.y < canvas_pos.y + canvas_size.y

func _show_load_dialog() -> void:
	"""Show load dialog"""
	var dir = DirAccess.open("res://maps/")
	if not dir:
		_show_error("Maps directory not found")
		return

	var files = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			files.append(file_name)
		file_name = dir.get_next()

	if files.is_empty():
		_show_error("No maps found")
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

func _show_save_dialog() -> void:
	"""Show save dialog with filename input"""
	var dialog = AcceptDialog.new()
	var vbox = VBoxContainer.new()
	dialog.add_child(vbox)

	var label = Label.new()
	label.text = "Save as:"
	vbox.add_child(label)

	var input = LineEdit.new()
	input.text = "custom_map"
	input.custom_minimum_size = Vector2(300, 0)
	vbox.add_child(input)

	dialog.confirmed.connect(func():
		_save_map_as(input.text)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())

	add_child(dialog)
	dialog.popup_centered()

func _save_map() -> void:
	"""Quick save (Phase 4)"""
	_save_map_as("custom_map")

func _save_map_as(filename: String) -> void:
	"""Save map with validation (Phase 4)"""
	# Validation warnings
	var warnings = []
	if habitas_points.is_empty():
		warnings.append("No habitas points (game needs at least 1)")
	if injection_zones.is_empty():
		warnings.append("No injection zones (game needs spawn areas)")
	if azn_nodes.is_empty():
		warnings.append("No AZN nodes (game needs resources)")

	if not warnings.is_empty():
		var msg = "Warnings:\n" + "\n".join(warnings) + "\n\nSave anyway?"
		var dialog = ConfirmationDialog.new()
		dialog.dialog_text = msg
		dialog.confirmed.connect(func():
			_do_save(filename)
			dialog.queue_free()
		)
		dialog.canceled.connect(func(): dialog.queue_free())
		add_child(dialog)
		dialog.popup_centered()
	else:
		_do_save(filename)

func _do_save(filename: String) -> void:
	"""Actually save the map"""
	var cells = []
	for y in range(map_height):
		for x in range(map_width):
			if grid[y][x] != "low":
				var cell = {"x": x, "y": y, "density": grid[y][x]}
				for stream in bloodstreams:
					if stream["x"] == x and stream["y"] == y:
						cell["stream"] = stream["stream"]
						break
				cells.append(cell)

	var map_data = {
		"name": filename,
		"width": map_width,
		"height": map_height,
		"default_density": "low",
		"starting_azn": 150,
		"cells": cells,
		"habitas_points": habitas_points,
		"azn_nodes": azn_nodes,
		"injection_zones": injection_zones
	}

	var file = FileAccess.open("user://" + filename + ".json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(map_data))
		_show_status("Saved to user://" + filename + ".json")
	else:
		_show_error("Save failed")

func _clear_map() -> void:
	"""Clear map (Phase 2)"""
	_save_state()
	_init_grid()
	habitas_points.clear()
	azn_nodes.clear()
	injection_zones.clear()
	bloodstreams.clear()
	selected_element.clear()
	canvas_control.queue_redraw()

func _add_border() -> void:
	"""Add bone border (Phase 2)"""
	_save_state()
	for x in range(map_width):
		grid[0][x] = "bone"
		grid[map_height - 1][x] = "bone"
	for y in range(map_height):
		grid[y][0] = "bone"
		grid[y][map_width - 1] = "bone"
	canvas_control.queue_redraw()

func _flood_fill(start_x: int, start_y: int, target: String) -> void:
	"""Flood fill (Phase 2)"""
	var stack = [[start_x, start_y]]
	var visited = []

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

func _save_state() -> void:
	"""Save grid state for undo (Phase 2)"""
	if history_index < history.size() - 1:
		history.resize(history_index + 1)

	var state: Array = []
	for row in grid:
		state.append(row.duplicate())
	history.append(state)
	history_index = history.size() - 1

	if history.size() > MAX_HISTORY:
		history.pop_front()
		history_index -= 1

	undo_btn.disabled = (history_index <= 0)

func _undo() -> void:
	"""Undo (Phase 2)"""
	if history_index > 0:
		history_index -= 1
		grid.clear()
		for row in history[history_index]:
			grid.append(row.duplicate())
		canvas_control.queue_redraw()
		undo_btn.disabled = (history_index <= 0)

func _update_status() -> void:
	"""Update status bar (Phase 5)"""
	var mode_text = selected_mode.to_upper()
	if selected_mode == "terrain":
		mode_text = "Terrain: " + selected_density.to_upper()
	elif selected_mode == "streams":
		mode_text = "Stream: " + selected_stream_dir.to_upper()

	status_label.text = mode_text + " | Click: place | Right-click: fill | Scroll: zoom | Middle-drag: pan"

func _show_status(msg: String) -> void:
	"""Show status message (Phase 5)"""
	status_label.text = msg

func _show_error(msg: String) -> void:
	"""Show error message (Phase 5)"""
	status_label.text = "ERROR: " + msg
	print("Map Editor Error: " + msg)

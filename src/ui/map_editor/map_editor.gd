class_name MapEditor
extends Control

## Root of the map editor. Owns the document, undo history, file I/O,
## renderer, sidebar, and the active tool — and forwards _input()/_draw()
## to them. See docs/versioning/v0.0.3/analysis.md and plan.md for why this
## was split out of one 1374-line file.

var doc: MapDocument
var history: MapHistory
var map_io: MapIO
var renderer: MapCanvasRenderer
var sidebar: MapEditorSidebar

var tools: Dictionary = {}
var current_tool: EditorTool
var active_tool_name: String = "terrain"

# Shared interaction state read/written by tools (see tools/editor_tool.gd).
var zoom: float = 1.0
var scroll_x: int = 0
var scroll_y: int = 0
var canvas_rect: Rect2 = Rect2()
var is_dragging: bool = false
var brush_cursor_pos: Vector2i = Vector2i(-1, -1)
var last_paint_pos: Vector2i = Vector2i(-1, -1)
var selected_density: int = MapDocument.Density.LOW
var selected_stream_dir: int = MapDocument.StreamDir.NORTH
var edit_selected_type: String = ""
var edit_selected_index: int = -1
var zone_resize_corner: String = ""
var preview_rect: Rect2i = Rect2i()
var azn_hover_index: int = -1

var status_label: Label
var azn_edit_dialog: ConfirmationDialog
var azn_quantity_input: SpinBox

const MIN_ZOOM := 0.5
const MAX_ZOOM := 3.0
const ZOOM_STEP := 0.1

func _ready() -> void:
	doc = MapDocument.new()
	history = MapHistory.new()
	map_io = MapIO.new()
	renderer = MapCanvasRenderer.new()

	_setup_ui()
	_setup_tools()
	_load_default_map()
	_activate_tool("terrain")

func _setup_ui() -> void:
	var root = HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var left = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(left)

	status_label = Label.new()
	status_label.text = ""
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.custom_minimum_size = Vector2(0, 30)
	left.add_child(status_label)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 500)
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(spacer)

	sidebar = MapEditorSidebar.new()
	root.add_child(sidebar)
	sidebar.setup(renderer.terrain_textures)

	sidebar.density_selected.connect(func(d: int):
		selected_density = d
		_activate_tool("terrain")
	)
	sidebar.stream_dir_selected.connect(func(d: int):
		selected_stream_dir = d
		_activate_tool("stream")
	)
	sidebar.tool_selected.connect(_activate_tool)
	sidebar.load_requested.connect(_show_load_dialog)
	sidebar.save_requested.connect(_show_save_dialog)
	sidebar.clear_requested.connect(_clear_map)
	sidebar.undo_requested.connect(_undo)

	_setup_azn_quantity_dialog()

func _setup_tools() -> void:
	tools = {
		"terrain": TerrainTool.new(self),
		"stream": StreamTool.new(self),
		"habitas": HabitasTool.new(self),
		"azn": AznTool.new(self),
		"zone": ZoneTool.new(self),
		"pan": PanTool.new(self),
		"edit": EditTool.new(self),
		"delete": DeleteTool.new(self),
	}

func _setup_azn_quantity_dialog() -> void:
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

func show_azn_quantity_dialog(index: int) -> void:
	azn_quantity_input.value = doc.azn_nodes[index]["quantity"]
	azn_edit_dialog.popup_centered()

func _on_azn_quantity_confirmed() -> void:
	if edit_selected_type == "azn" and edit_selected_index >= 0:
		history.save_state(doc)
		doc.set_azn_quantity(edit_selected_index, int(azn_quantity_input.value))
		queue_redraw()

## --- Tool activation ---

func _activate_tool(tool_name: String) -> void:
	if current_tool:
		current_tool.on_deactivate()
	is_dragging = false
	brush_cursor_pos = Vector2i(-1, -1)
	preview_rect = Rect2i()
	active_tool_name = tool_name
	current_tool = tools[tool_name]
	current_tool.on_activate()
	update_status()
	queue_redraw()

func request_redraw() -> void:
	queue_redraw()

func update_status() -> void:
	if status_label and current_tool:
		status_label.text = current_tool.get_status_text()

## --- Map load/save ---

func _load_default_map() -> void:
	var dir = DirAccess.open("res://maps/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json"):
				if _load_map_from_file("res://maps/" + file_name):
					return
			file_name = dir.get_next()

	doc.init_blank(60, 60)
	history.reset()
	history.save_state(doc)
	sidebar.set_undo_enabled(history.can_undo())

func _load_map_from_file(path: String) -> bool:
	var loaded = map_io.load_from_file(path)
	if loaded == null:
		_show_error(map_io.last_error)
		return false

	doc = loaded
	zoom = 1.0
	scroll_x = 0
	scroll_y = 0
	history.reset()
	history.save_state(doc)
	sidebar.set_undo_enabled(history.can_undo())

	_show_notification("Map loaded: " + path.get_file())
	queue_redraw()
	return true

func _show_load_dialog() -> void:
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
		_show_error("No maps found in res://maps/")
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
	var errors = map_io.validate(doc)
	if errors.size() > 0:
		var dialog = ConfirmationDialog.new()
		dialog.title = "Validation Warning"
		dialog.dialog_text = "Map incomplete:\n" + "\n".join(errors) + "\n\nContinue anyway?"
		add_child(dialog)
		dialog.confirmed.connect(func(): _show_save_filename_dialog(); dialog.queue_free())
		dialog.canceled.connect(func(): dialog.queue_free())
		dialog.popup_centered_ratio(0.4)
	else:
		_show_save_filename_dialog()

func _show_save_filename_dialog() -> void:
	var file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.filters = ["*.json ; JSON Map Files"]
	file_dialog.current_dir = "res://maps/"
	file_dialog.current_file = "my_map.json"
	add_child(file_dialog)

	file_dialog.file_selected.connect(func(path: String):
		if map_io.save_to_file(doc, path):
			_show_notification("Map saved: " + path.get_file())
		else:
			_show_error(map_io.last_error)
		file_dialog.queue_free()
	)
	file_dialog.canceled.connect(func(): file_dialog.queue_free())
	file_dialog.popup_centered_ratio(0.6)

func _clear_map() -> void:
	history.save_state(doc)
	doc.clear_all()
	sidebar.set_undo_enabled(history.can_undo())
	queue_redraw()

func _undo() -> void:
	history.undo(doc)
	sidebar.set_undo_enabled(history.can_undo())
	queue_redraw()

func _show_notification(msg: String) -> void:
	if status_label:
		status_label.text = msg

func _show_error(msg: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Error"
	dialog.dialog_text = msg
	add_child(dialog)
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.popup_centered_ratio(0.4)

## --- Rendering ---

func _draw() -> void:
	var panel_width = sidebar.custom_minimum_size.x
	canvas_rect = Rect2(0, 30, get_size().x - panel_width, get_size().y - 45)

	var selection = {"type": edit_selected_type, "index": edit_selected_index}
	renderer.draw_all(self, doc, canvas_rect, zoom, scroll_x, scroll_y,
		brush_cursor_pos, selection, azn_hover_index, preview_rect)

## --- Input ---

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if current_tool and current_tool.handle_key(event):
			get_tree().root.set_input_as_handled()
			return

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

		if event.pressed and _is_in_canvas(event.position):
			var grid_pos = _to_grid_pos(event.position)
			if current_tool.handle_press(grid_pos, event.button_index):
				if event.button_index == MOUSE_BUTTON_LEFT:
					is_dragging = true
				get_tree().root.set_input_as_handled()
				return

		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and is_dragging:
			is_dragging = false
			current_tool.handle_release()

	if event is InputEventMouseMotion:
		if is_dragging:
			var grid_pos = _to_grid_pos(event.position)
			current_tool.handle_drag(grid_pos, event)
			get_tree().root.set_input_as_handled()
			return

		set_default_cursor_shape(current_tool.get_cursor() if current_tool else CURSOR_ARROW)
		_update_azn_hover(event.position)

func _update_azn_hover(screen_pos: Vector2) -> void:
	if not _is_in_canvas(screen_pos):
		azn_hover_index = -1
		return

	var grid_pos = _to_grid_pos(screen_pos)
	if not doc.is_in_bounds(grid_pos.x, grid_pos.y):
		azn_hover_index = -1
		return

	var found = -1
	for i in range(doc.azn_nodes.size()):
		if doc.azn_nodes[i]["position"] == grid_pos:
			found = i
			break

	if found != azn_hover_index:
		azn_hover_index = found
		queue_redraw()

func _to_grid_pos(screen_pos: Vector2) -> Vector2i:
	var cx = int(canvas_rect.position.x)
	var cy = int(canvas_rect.position.y)
	var grid_x = int((screen_pos.x - cx + scroll_x) / (MapCanvasRenderer.CELL_SIZE * zoom))
	var grid_y = int((screen_pos.y - cy + scroll_y) / (MapCanvasRenderer.CELL_SIZE * zoom))
	return Vector2i(grid_x, grid_y)

func _is_in_canvas(pos: Vector2) -> bool:
	var cx = int(canvas_rect.position.x)
	var cy = int(canvas_rect.position.y)
	var cw = int(canvas_rect.size.x)
	var ch = int(canvas_rect.size.y)
	return pos.x >= cx and pos.x < cx + cw and pos.y >= cy and pos.y < cy + ch

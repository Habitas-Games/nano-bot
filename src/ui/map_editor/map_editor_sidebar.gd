class_name MapEditorSidebar
extends PanelContainer

## Builds the right-hand control panel and exposes user intent as signals.
## MapEditor owns the MapDocument/tools and reacts to these — the sidebar
## itself holds no map state, only the toggle-button UI state mirroring it.

signal density_selected(density: int)
signal stream_dir_selected(dir: int)
signal tool_selected(tool_name: String)
signal load_requested
signal save_requested
signal clear_requested
signal undo_requested

var terrain_buttons: Dictionary = {}
var stream_buttons: Dictionary = {}
var undo_btn: Button

func setup(terrain_textures: Dictionary) -> void:
	custom_minimum_size = Vector2(250, 0)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15)
	add_theme_stylebox_override("panel", style)

	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(scroll)

	var panel = VBoxContainer.new()
	panel.add_theme_constant_override("separation", 8)
	scroll.add_child(panel)

	var title = Label.new()
	title.text = "Map Editor"
	title.add_theme_font_size_override("font_size", 14)
	panel.add_child(title)

	_build_terrain_section(panel, terrain_textures)
	panel.add_child(HSeparator.new())
	_build_stream_section(panel)
	panel.add_child(HSeparator.new())
	_build_elements_section(panel)
	panel.add_child(HSeparator.new())
	_build_tools_section(panel)
	panel.add_child(HSeparator.new())
	_build_history_section(panel)

func _build_terrain_section(panel: VBoxContainer, terrain_textures: Dictionary) -> void:
	var header = Label.new()
	header.text = "▼ Terrain"
	header.add_theme_font_size_override("font_size", 11)
	panel.add_child(header)

	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	panel.add_child(grid)

	for density_val in [MapDocument.Density.LOW, MapDocument.Density.MEDIUM, MapDocument.Density.HIGH, MapDocument.Density.BONE]:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(48, 48)
		btn.toggle_mode = true

		var tex = terrain_textures.get(density_val)
		if tex:
			btn.icon = tex
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER

		btn.tooltip_text = _density_cost_text(density_val)

		if density_val == MapDocument.Density.LOW:
			btn.button_pressed = true

		var density_copy = density_val
		btn.pressed.connect(func():
			density_selected.emit(density_copy)
			_update_density_buttons(density_copy)
		)

		grid.add_child(btn)
		terrain_buttons[density_val] = btn

func _density_cost_text(density: int) -> String:
	match density:
		MapDocument.Density.LOW: return "LOW\n2 turns"
		MapDocument.Density.MEDIUM: return "MEDIUM\n3 turns"
		MapDocument.Density.HIGH: return "HIGH\n4 turns"
		MapDocument.Density.BONE: return "BONE\nblocked"
	return ""

func _build_stream_section(panel: VBoxContainer) -> void:
	var header = Label.new()
	header.text = "▼ Stream Direction"
	header.add_theme_font_size_override("font_size", 11)
	panel.add_child(header)

	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	panel.add_child(grid)

	var directions = [
		{"dir": MapDocument.StreamDir.NORTH, "label": "↑", "hint": "N"},
		{"dir": MapDocument.StreamDir.SOUTH, "label": "↓", "hint": "S"},
		{"dir": MapDocument.StreamDir.EAST, "label": "→", "hint": "E"},
		{"dir": MapDocument.StreamDir.WEST, "label": "←", "hint": "W"},
	]

	for dir_data in directions:
		var btn = Button.new()
		btn.text = dir_data["label"]
		btn.custom_minimum_size = Vector2(48, 48)
		btn.toggle_mode = true
		btn.tooltip_text = dir_data["hint"]

		if dir_data["dir"] == MapDocument.StreamDir.NORTH:
			btn.button_pressed = true

		var dir_copy = dir_data["dir"]
		btn.pressed.connect(func():
			stream_dir_selected.emit(dir_copy)
			_update_stream_buttons(dir_copy)
		)

		grid.add_child(btn)
		stream_buttons[dir_data["dir"]] = btn

func _build_elements_section(panel: VBoxContainer) -> void:
	var header = Label.new()
	header.text = "▼ Elements"
	header.add_theme_font_size_override("font_size", 11)
	panel.add_child(header)

	for elem_data in [
		{"name": "habitas", "label": "Place Habitas"},
		{"name": "azn", "label": "Place AZN"},
		{"name": "zone", "label": "Place Zone"},
	]:
		var btn = Button.new()
		btn.text = elem_data["label"]
		btn.custom_minimum_size = Vector2(0, 28)
		var mode_name = elem_data["name"]
		btn.pressed.connect(func(): tool_selected.emit(mode_name))
		panel.add_child(btn)

func _build_tools_section(panel: VBoxContainer) -> void:
	var header = Label.new()
	header.text = "▼ Tools"
	header.add_theme_font_size_override("font_size", 11)
	panel.add_child(header)

	var pan_btn = Button.new()
	pan_btn.text = "Pan ✋"
	pan_btn.custom_minimum_size = Vector2(0, 28)
	pan_btn.pressed.connect(func(): tool_selected.emit("pan"))
	panel.add_child(pan_btn)

	var edit_btn = Button.new()
	edit_btn.text = "Edit ✏️"
	edit_btn.custom_minimum_size = Vector2(0, 28)
	edit_btn.pressed.connect(func(): tool_selected.emit("edit"))
	panel.add_child(edit_btn)

	var delete_btn = Button.new()
	delete_btn.text = "Delete 🗑️"
	delete_btn.custom_minimum_size = Vector2(0, 28)
	delete_btn.pressed.connect(func(): tool_selected.emit("delete"))
	panel.add_child(delete_btn)

	var load_btn = Button.new()
	load_btn.text = "Load"
	load_btn.custom_minimum_size = Vector2(0, 28)
	load_btn.pressed.connect(func(): load_requested.emit())
	panel.add_child(load_btn)

	var save_btn = Button.new()
	save_btn.text = "Save"
	save_btn.custom_minimum_size = Vector2(0, 28)
	save_btn.pressed.connect(func(): save_requested.emit())
	panel.add_child(save_btn)

	var clear_btn = Button.new()
	clear_btn.text = "Clear Map"
	clear_btn.custom_minimum_size = Vector2(0, 28)
	clear_btn.pressed.connect(func(): clear_requested.emit())
	panel.add_child(clear_btn)

func _build_history_section(panel: VBoxContainer) -> void:
	var header = Label.new()
	header.text = "▼ History"
	header.add_theme_font_size_override("font_size", 11)
	panel.add_child(header)

	undo_btn = Button.new()
	undo_btn.text = "Undo"
	undo_btn.custom_minimum_size = Vector2(0, 28)
	undo_btn.disabled = true
	undo_btn.pressed.connect(func(): undo_requested.emit())
	panel.add_child(undo_btn)

func _update_density_buttons(selected: int) -> void:
	for density_val in terrain_buttons.keys():
		terrain_buttons[density_val].button_pressed = (density_val == selected)

func _update_stream_buttons(selected: int) -> void:
	for stream_val in stream_buttons.keys():
		stream_buttons[stream_val].button_pressed = (stream_val == selected)

func set_undo_enabled(enabled: bool) -> void:
	if undo_btn:
		undo_btn.disabled = not enabled

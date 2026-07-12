class_name EditTool
extends EditorTool

## Selection itself (editor.edit_selected_type/index) lives on the editor,
## not here, because the canvas renderer needs to read it to draw the
## highlight and resize handles, and it should stay decoupled from tool
## classes (analysis.md's split keeps the renderer knowing only about
## MapDocument + plain selection data, never about EditorTool subclasses).
##
## Selection deliberately persists across switching to another tool and
## back, matching pre-refactor behavior — _deactivate_all_tools() never
## cleared edit_selected_type either.

func handle_press(grid_pos: Vector2i, button: int) -> bool:
	if button != MOUSE_BUTTON_LEFT or not editor.doc.is_in_bounds(grid_pos.x, grid_pos.y):
		return false

	var element = editor.doc.find_element_at(grid_pos.x, grid_pos.y)
	if element["type"] != "none":
		editor.edit_selected_type = element["type"]
		editor.edit_selected_index = element["index"]
		editor.last_paint_pos = grid_pos
		editor.history.save_state(editor.doc)

		editor.zone_resize_corner = ""
		if element["type"] == "zone":
			editor.zone_resize_corner = editor.doc.detect_zone_corner(grid_pos.x, grid_pos.y, element["index"])

		editor.update_status()
		editor.request_redraw()
		return true
	else:
		editor.edit_selected_type = ""
		editor.edit_selected_index = -1
		editor.zone_resize_corner = ""
		editor.request_redraw()
		return true

func handle_drag(grid_pos: Vector2i, _raw_event: InputEventMouseMotion) -> void:
	if editor.edit_selected_type == "" or not editor.doc.is_in_bounds(grid_pos.x, grid_pos.y):
		return

	match editor.edit_selected_type:
		"habitas":
			if editor.doc.move_habitas(editor.edit_selected_index, grid_pos):
				editor.request_redraw()
		"azn":
			if editor.doc.move_azn(editor.edit_selected_index, grid_pos):
				editor.request_redraw()
		"zone":
			if editor.zone_resize_corner != "":
				if editor.doc.resize_zone(editor.edit_selected_index, editor.zone_resize_corner, grid_pos.x, grid_pos.y):
					editor.request_redraw()
			else:
				var offset = grid_pos - editor.last_paint_pos
				if offset != Vector2i.ZERO and editor.doc.move_zone(editor.edit_selected_index, offset):
					editor.last_paint_pos = grid_pos
					editor.request_redraw()

func handle_key(event: InputEventKey) -> bool:
	if event.pressed and event.keycode == KEY_ENTER and editor.edit_selected_type == "azn":
		editor.show_azn_quantity_dialog(editor.edit_selected_index)
		return true
	return false

func get_status_text() -> String:
	return "Tool: Edit ✏️ | Click element to edit, drag to move"

func get_cursor() -> int:
	return Control.CURSOR_POINTING_HAND

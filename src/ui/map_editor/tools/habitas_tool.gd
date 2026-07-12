class_name HabitasTool
extends EditorTool

func handle_press(grid_pos: Vector2i, button: int) -> bool:
	if button != MOUSE_BUTTON_LEFT or not editor.doc.is_in_bounds(grid_pos.x, grid_pos.y):
		return false
	# Don't stack a habitas point on top of any existing element (analysis.md §4 dedup guard).
	if editor.doc.find_element_at(grid_pos.x, grid_pos.y)["type"] != "none":
		return true
	editor.history.save_state(editor.doc)
	editor.doc.place_habitas(grid_pos.x, grid_pos.y)
	editor.request_redraw()
	return true

func get_status_text() -> String:
	return "Tool: Place Habitas | Click to place"

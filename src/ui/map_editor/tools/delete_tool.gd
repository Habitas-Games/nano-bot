class_name DeleteTool
extends EditorTool

func handle_press(grid_pos: Vector2i, button: int) -> bool:
	if button != MOUSE_BUTTON_LEFT or not editor.doc.is_in_bounds(grid_pos.x, grid_pos.y):
		return false
	editor.history.save_state(editor.doc)
	editor.doc.delete_at_position(grid_pos.x, grid_pos.y)
	editor.last_paint_pos = grid_pos
	editor.brush_cursor_pos = grid_pos
	editor.request_redraw()
	return true

func handle_drag(grid_pos: Vector2i, _raw_event: InputEventMouseMotion) -> void:
	if not editor.doc.is_in_bounds(grid_pos.x, grid_pos.y):
		return
	editor.brush_cursor_pos = grid_pos
	if grid_pos != editor.last_paint_pos:
		editor.doc.delete_at_position(grid_pos.x, grid_pos.y)
		editor.last_paint_pos = grid_pos
		editor.request_redraw()

func handle_release() -> void:
	editor.brush_cursor_pos = Vector2i(-1, -1)
	editor.request_redraw()

func get_status_text() -> String:
	return "Tool: Delete 🗑️ | Click + drag to erase terrain, streams, elements"

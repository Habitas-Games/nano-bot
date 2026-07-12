class_name StreamTool
extends EditorTool

func handle_press(grid_pos: Vector2i, button: int) -> bool:
	if button != MOUSE_BUTTON_LEFT or not editor.doc.is_in_bounds(grid_pos.x, grid_pos.y):
		return false
	editor.history.save_state(editor.doc)
	editor.doc.place_stream(grid_pos.x, grid_pos.y, editor.selected_stream_dir)
	editor.last_paint_pos = grid_pos
	editor.request_redraw()
	return true

func handle_drag(grid_pos: Vector2i, _raw_event: InputEventMouseMotion) -> void:
	if not editor.doc.is_in_bounds(grid_pos.x, grid_pos.y):
		return
	if grid_pos != editor.last_paint_pos:
		editor.doc.place_stream(grid_pos.x, grid_pos.y, editor.selected_stream_dir)
		editor.last_paint_pos = grid_pos
		editor.request_redraw()

func get_status_text() -> String:
	var dir_name = editor.map_io.stream_to_string(editor.selected_stream_dir).to_upper()
	return "Tool: Stream (%s) | Click to place stream" % dir_name

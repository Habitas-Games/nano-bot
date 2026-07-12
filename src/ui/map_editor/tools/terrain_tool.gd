class_name TerrainTool
extends EditorTool

func handle_press(grid_pos: Vector2i, button: int) -> bool:
	if not editor.doc.is_in_bounds(grid_pos.x, grid_pos.y):
		return false

	if button == MOUSE_BUTTON_LEFT:
		editor.history.save_state(editor.doc)
		editor.doc.paint_cell(grid_pos.x, grid_pos.y, editor.selected_density)
		editor.last_paint_pos = grid_pos
		editor.brush_cursor_pos = grid_pos
		editor.request_redraw()
		return true
	elif button == MOUSE_BUTTON_RIGHT:
		editor.history.save_state(editor.doc)
		editor.doc.flood_fill(grid_pos.x, grid_pos.y, editor.selected_density)
		editor.request_redraw()
		return true
	return false

func handle_drag(grid_pos: Vector2i, _raw_event: InputEventMouseMotion) -> void:
	if not editor.doc.is_in_bounds(grid_pos.x, grid_pos.y):
		return
	editor.brush_cursor_pos = grid_pos
	if grid_pos != editor.last_paint_pos:
		editor.doc.paint_cell(grid_pos.x, grid_pos.y, editor.selected_density)
		editor.last_paint_pos = grid_pos
		editor.request_redraw()

func handle_release() -> void:
	editor.brush_cursor_pos = Vector2i(-1, -1)
	editor.request_redraw()

func get_status_text() -> String:
	var density_name = editor.map_io.density_to_string(editor.selected_density).to_upper()
	return "Tool: Terrain (%s) | Click: paint | Right-click: fill | Scroll: zoom" % density_name

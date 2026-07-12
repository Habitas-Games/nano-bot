class_name PanTool
extends EditorTool

func handle_press(_grid_pos: Vector2i, button: int) -> bool:
	return button == MOUSE_BUTTON_LEFT

func handle_drag(_grid_pos: Vector2i, raw_event: InputEventMouseMotion) -> void:
	var delta = raw_event.relative
	var cw = int(editor.canvas_rect.size.x)
	var ch = int(editor.canvas_rect.size.y)
	var max_x = max(0, int(editor.doc.width * MapCanvasRenderer.CELL_SIZE * editor.zoom - cw))
	var max_y = max(0, int(editor.doc.height * MapCanvasRenderer.CELL_SIZE * editor.zoom - ch))
	editor.scroll_x = clampi(editor.scroll_x - int(delta.x), 0, max_x)
	editor.scroll_y = clampi(editor.scroll_y - int(delta.y), 0, max_y)
	editor.request_redraw()

func get_status_text() -> String:
	return "Tool: Pan ✋ | Click + drag to move map"

func get_cursor() -> int:
	return Control.CURSOR_MOVE

class_name ZoneTool
extends EditorTool

## Drag rectangle to place — this is exactly what PHASE_2_SPEC.md already
## specified ("Injection zones: Drag rectangle to place, drag later to
## move"). The button existed and the status text described this behavior
## since Phase 2, but the press handler was a literal `pass` (analysis.md
## §4) — never implemented.
##
## New zones default to player 0. A player-selector UI for zone *creation*
## was an open question in PHASE_4_ANALYSIS.md that was never resolved, and
## inventing one is out of scope for a cleanup pass (plan.md step 6) — flagged
## here rather than guessed. Existing zones with player 1 (e.g. from loaded
## maps) are unaffected; the Edit tool can still move/resize them.

var _drag_start: Vector2i = Vector2i(-1, -1)
var _drag_current: Vector2i = Vector2i(-1, -1)

func handle_press(grid_pos: Vector2i, button: int) -> bool:
	if button != MOUSE_BUTTON_LEFT or not editor.doc.is_in_bounds(grid_pos.x, grid_pos.y):
		return false
	_drag_start = grid_pos
	_drag_current = grid_pos
	editor.preview_rect = Rect2i(grid_pos, Vector2i(1, 1))
	editor.request_redraw()
	return true

func handle_drag(grid_pos: Vector2i, _raw_event: InputEventMouseMotion) -> void:
	if not editor.doc.is_in_bounds(grid_pos.x, grid_pos.y) or _drag_start == Vector2i(-1, -1):
		return
	_drag_current = grid_pos
	editor.preview_rect = _compute_rect()
	editor.request_redraw()

func handle_release() -> void:
	if _drag_start != Vector2i(-1, -1):
		var rect = _compute_rect()
		editor.history.save_state(editor.doc)
		editor.doc.place_zone(rect, 0)
		editor.request_redraw()
	_drag_start = Vector2i(-1, -1)
	_drag_current = Vector2i(-1, -1)
	editor.preview_rect = Rect2i()

func _compute_rect() -> Rect2i:
	var x1 = min(_drag_start.x, _drag_current.x)
	var y1 = min(_drag_start.y, _drag_current.y)
	var x2 = max(_drag_start.x, _drag_current.x)
	var y2 = max(_drag_start.y, _drag_current.y)
	return Rect2i(x1, y1, x2 - x1 + 1, y2 - y1 + 1)

func get_status_text() -> String:
	return "Tool: Place Zone | Drag to create rectangle (player 0; use Edit tool to reposition)"

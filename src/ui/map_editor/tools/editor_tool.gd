class_name EditorTool
extends RefCounted

## Base class for the map editor's tools. Before this refactor, every tool's
## behavior was spread across three separate `match active_tool:` blocks
## inside MapEditor._input() (mouse-down, drag, and an implicit cursor-update
## switch) — see analysis.md §3. Each subclass now owns its own press/drag/
## release/key/cursor/status behavior in one place.
##
## `editor` is intentionally untyped (not `MapEditor`) to avoid a circular
## class_name dependency between this script and map_editor.gd. Tools call
## back into a small public surface on the editor: doc, history, scroll_x/y,
## zoom, canvas_rect, brush_cursor_pos, last_paint_pos, selected_density,
## selected_stream_dir, edit_selected_type/index, zone_resize_corner,
## preview_rect, request_redraw(), update_status(), show_azn_quantity_dialog().

var editor: Node

func _init(p_editor: Node) -> void:
	editor = p_editor

func on_activate() -> void:
	pass

func on_deactivate() -> void:
	pass

## Return true if this press was handled (caller starts a drag and marks input handled).
func handle_press(_grid_pos: Vector2i, _button: int) -> bool:
	return false

func handle_drag(_grid_pos: Vector2i, _raw_event: InputEventMouseMotion) -> void:
	pass

func handle_release() -> void:
	pass

## Return true if handled.
func handle_key(_event: InputEventKey) -> bool:
	return false

func get_status_text() -> String:
	return ""

func get_cursor() -> int:
	return Control.CURSOR_ARROW

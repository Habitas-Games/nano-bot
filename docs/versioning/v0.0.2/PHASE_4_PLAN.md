# Phase 4: Implementation Plan

**Status:** Ready to implement
**Date:** 2026-06-06

---

## Implementation Strategy

Build in order of complexity:

1. **Delete Tool** (simpler) - Drag to delete
2. **Edit Tool** - Click to select and edit
3. **AZN Hover** - Tooltip on hover
4. **Polish** - Cursors, visual feedback

---

## Phase 4.1: Delete Tool Implementation

### UI Changes
1. Add "Delete 🗑️" button in Tools section (after Pan button)
2. Button connects to `_activate_tool("delete")`
3. Status bar updates: "Tool: Delete 🗑️ | Click + drag to erase..."

### Code Changes
1. Add to active_tool states: `"delete"` option
2. Reuse `is_painting` flag for delete drag
3. Reuse `last_paint_pos` to avoid duplicate deletions
4. On left-click (delete mode): `_save_state()` at drag start
5. On drag motion (delete mode): Delete everything at cursor position
6. Track deleted positions to avoid deleting same element twice

### Delete Logic
```gdscript
# On left-click press (delete mode)
_save_state()  # Save entire map state
is_painting = true
brush_cursor_pos = grid_pos

# On mouse motion (delete mode, is_painting)
if grid_pos != last_paint_pos:
    # Delete at this position
    _delete_at_position(grid_x, grid_y)
    last_paint_pos = grid_pos
```

### Delete Function
```gdscript
func _delete_at_position(x: int, y: int) -> void:
    # Delete terrain
    cells[idx]["density"] = Density.LOW
    cells[idx]["stream_dir"] = StreamDir.NONE
    
    # Delete habitas at position
    habitas_points.erase(Vector2i(x, y))
    
    # Delete AZN at position
    azn_nodes = azn_nodes.filter(func(azn): return azn["position"] != Vector2i(x, y))
    
    # Delete zone containing position
    injection_zones = injection_zones.filter(func(zone): 
        return not zone["rect"].has_point(Vector2i(x, y))
    )
```

### Cursor Feedback
- Active: CURSOR_FORBIDDEN or similar eraser cursor
- Brush outline: Draw delete area like paint mode

---

## Phase 4.2: Edit Tool Implementation

### UI Changes
1. Add "Edit ✏️" button in Tools section (before Delete)
2. Button connects to `_activate_tool("edit")`
3. Status bar updates: "Tool: Edit ✏️ | Click element to edit..."

### Code Changes
1. Add `edit_mode` state tracking:
   - `edit_selected_type: String` (habitas/azn/zone)
   - `edit_selected_index: int`
   - `edit_drag_offset: Vector2i` (for moving)

2. On click (edit mode):
   - Detect which element clicked
   - Set selected_type and selected_index
   - Store offset for dragging

3. On drag (edit mode):
   - Move habitas to new position
   - Move/resize zones (drag interior vs corners)
   - For AZN: Show quantity editor popup

### Edit Functions
```gdscript
func _click_on_element(x: int, y: int) -> Dictionary:
    # Check habitas
    if habitas_points.has(Vector2i(x, y)):
        return {type: "habitas", index: habitas_points.find(Vector2i(x, y))}
    
    # Check AZN
    for i in range(azn_nodes.size()):
        if azn_nodes[i]["position"] == Vector2i(x, y):
            return {type: "azn", index: i}
    
    # Check zones
    for i in range(injection_zones.size()):
        if injection_zones[i]["rect"].has_point(Vector2i(x, y)):
            return {type: "zone", index: i}
    
    return {type: "none"}

func _edit_habitas_move(index: int, new_pos: Vector2i) -> void:
    if 0 <= new_pos.x < map_width and 0 <= new_pos.y < map_height:
        habitas_points[index] = new_pos
        queue_redraw()

func _edit_azn_quantity(index: int) -> void:
    # Show popup with quantity spinner
    var current = azn_nodes[index]["quantity"]
    # TODO: Show quantity editor UI
```

### Selection Visual Feedback
- Selected element: Draw highlight/outline
- Show handles on zones (corners)
- Pen cursor when hovering

---

## Phase 4.3: AZN Hover Implementation

### Tooltip Display
1. Track hover position during mouse motion
2. Check if hovering over AZN marker
3. Show quantity as label above marker
4. Fade out when cursor moves away

### Code
```gdscript
func _check_azn_hover(grid_x: int, grid_y: int) -> void:
    for azn in azn_nodes:
        if azn["position"] == Vector2i(grid_x, grid_y):
            _show_azn_tooltip(azn["quantity"])
            return
    _hide_azn_tooltip()

func _draw_azn_tooltip(value: int, screen_pos: Vector2) -> void:
    # Draw text label above AZN marker
    draw_string(font, screen_pos + Vector2(0, -20), str(value))
```

---

## Phase 4.4: Polish

1. Cursor styling (pen, eraser, hand icons)
2. Selection highlights (color, outline thickness)
3. Zone resize handles (small squares at corners)
4. Keyboard shortcuts (Delete key to confirm delete?)

---

## Testing Checklist

### Delete Tool
- [ ] Drag deletes terrain (density → LOW)
- [ ] Drag deletes streams (stream_dir → NONE)
- [ ] Drag deletes habitas points
- [ ] Drag deletes AZN nodes
- [ ] Drag deletes injection zones
- [ ] Undo restores everything
- [ ] No duplicates (same element deleted twice)
- [ ] Brush outline visible during drag

### Edit Tool
- [ ] Click habitas → selects and highlights
- [ ] Drag habitas → moves to new position
- [ ] Click AZN → shows quantity popup
- [ ] Quantity editor works
- [ ] Click zone → selects and shows handles
- [ ] Drag zone interior → moves zone
- [ ] Drag zone corner → resizes
- [ ] Click empty → deselects

### AZN Hover
- [ ] Hover over AZN → tooltip appears
- [ ] Tooltip shows correct value
- [ ] Move cursor away → tooltip disappears
- [ ] Works in all modes

### Visual Feedback
- [ ] Pen cursor when edit tool active
- [ ] Eraser cursor when delete tool active
- [ ] Brush outline shows delete area
- [ ] Selected elements highlighted
- [ ] Zone handles visible

---

## Implementation Order

1. Add Delete button to UI
2. Implement delete drag logic
3. Implement _delete_at_position function
4. Test delete thoroughly
5. Add Edit button to UI
6. Implement edit selection logic
7. Implement habitas move
8. Implement AZN quantity editor
9. Implement zone move/resize
10. Add AZN hover tooltip
11. Polish cursors and visual feedback
12. Final testing

---

## Ready to Start

Delete tool implementation begins immediately.

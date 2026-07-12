# Phase 4 Polish: Advanced Editing Features

**Status:** Design & Implementation
**Date:** 2026-06-08

---

## Features to Implement

### 1. AZN Quantity Editing

**Current State:**
- Click AZN in edit mode → selects it (shows yellow highlight)
- Hover shows quantity tooltip
- But no way to change the quantity

**Desired Behavior:**
- Select AZN (already works)
- Press Enter key to edit quantity
- Simple number input dialog appears
- User types new quantity (1-9999)
- Press Enter to confirm or Escape to cancel

**Implementation:**
- Track if user pressed Enter while AZN selected
- Show simple input dialog (CanvasLayer with LineEdit)
- Parse input and validate (1-9999)
- Update azn_nodes[index]["quantity"]
- _save_state() to allow undo

**Alternative (Simpler):**
- Right-click on selected AZN → shows popup menu with "Edit Quantity"
- Click "Edit Quantity" → input dialog

---

### 2. Zone Corner Resize

**Current State:**
- Click zone → selects it (shows white highlight)
- Drag zone interior → moves entire zone
- But no way to resize (change size)

**Desired Behavior:**
- Select zone (already works)
- Hover near corner → cursor changes (resize cursor)
- Drag corner → resize zone from that corner
- Other corners stay in place
- Zone minimum size: 2x2 cells

**Detection:**
- When hovering over zone, check if near corner (within 10 pixels)
- Draw small resize handles at corners (optional visual)
- If dragging near corner + zone selected → resize mode

**Corners:**
- Top-left: (rect.x, rect.y)
- Top-right: (rect.x + rect.w, rect.y)
- Bottom-left: (rect.x, rect.y + rect.h)
- Bottom-right: (rect.x + rect.w, rect.y + rect.h)

**Implementation:**
- _detect_zone_corner(x, y, zone) → returns which corner or "none"
- Track resize_corner when entering resize mode
- On drag: update rect corner based on resize_corner
- Constrain new size (min 2x2, stay in bounds)

---

## Implementation Order

1. **AZN Quantity Editing** (simpler)
   - Detect Enter key press
   - Create input dialog
   - Parse and validate input
   - Update quantity

2. **Zone Corner Resize** (more complex)
   - Detect corner hover
   - Visual feedback (cursor change)
   - Resize logic
   - Bounds checking

---

## Code Structure

### AZN Quantity Editing

```gdscript
# In edit mode input handler
if event is InputEventKey and event.pressed and active_tool == "edit":
    if event.keycode == KEY_RETURN and edit_selected_type == "azn":
        _show_azn_quantity_dialog(edit_selected_index)

func _show_azn_quantity_dialog(index: int) -> void:
    # Show input dialog
    # Get current quantity
    # User types new value
    # Validate and update

func _update_azn_quantity(index: int, new_qty: int) -> void:
    if new_qty >= 1 and new_qty <= 9999:
        _save_state()
        azn_nodes[index]["quantity"] = new_qty
        queue_redraw()
```

### Zone Corner Resize

```gdscript
func _detect_zone_corner(grid_x: int, grid_y: int, zone: Dictionary) -> String:
    var rect = zone["rect"]
    var corners = [
        {"name": "tl", "pos": rect.position},
        {"name": "tr", "pos": rect.position + Vector2i(rect.size.x, 0)},
        {"name": "bl", "pos": rect.position + Vector2i(0, rect.size.y)},
        {"name": "br", "pos": rect.position + rect.size}
    ]
    
    for corner in corners:
        if Vector2i(grid_x, grid_y).distance_to(corner["pos"]) <= 1:
            return corner["name"]
    return "none"

func _resize_zone(index: int, corner: String, new_pos: Vector2i) -> void:
    # Update rect based on which corner is being dragged
    # Maintain minimum size (2x2)
```

---

## Testing Checklist

### AZN Quantity Editing
- [ ] Select AZN in edit mode
- [ ] Press Enter
- [ ] Dialog appears
- [ ] Type new quantity (e.g., 50)
- [ ] Press Enter to confirm
- [ ] Quantity updates on map
- [ ] Undo restores old quantity
- [ ] Escape cancels without changing

### Zone Corner Resize
- [ ] Select zone in edit mode
- [ ] Hover near corner → cursor changes
- [ ] Drag corner to resize
- [ ] Zone resizes from dragged corner
- [ ] Other corners stay in place
- [ ] Minimum size enforced (2x2)
- [ ] Stays in map bounds
- [ ] Undo restores old size

---

## Ready for Implementation

Both features are straightforward additions to existing edit mode.
AZN quantity editing is simpler and faster to implement.

# Phase 4: Element Placement & Editing - Specification

**Status:** Design locked, ready for implementation
**Date:** 2026-06-06

---

## 1. Design Decisions (Your Preferences)

### Element Management Tools

**Edit Tool ✏️**
- Button in Tools section (like Pan)
- Activates edit mode for placed elements
- Left-click on element to edit:
  - **Habitas:** Drag to move
  - **AZN:** Popup shows quantity, spin to change
  - **Zones:** Drag to move, drag corners to resize
- Visual feedback: Selected element highlighted
- Cancel: Click canvas empty area or select different tool

**Delete Tool 🗑️**
- Button in Tools section (like Pan)
- Activates delete mode
- Left-click drag over map deletes everything touched:
  - ✅ Terrain → Set to LOW
  - ✅ Streams → Set to NONE
  - ✅ Habitas points → Remove from array
  - ✅ AZN nodes → Remove from array
  - ✅ Injection zones → Remove from array
- Visual feedback: Brush outline shows delete area
- Result: "Erase" effect - left-click drag clears path

**AZN Hover Info**
- When cursor hovers over AZN node:
  - Show quantity value as tooltip or label
  - Example: "30" displays near marker
- Works in all modes (except delete - no hover, just delete)

---

## 2. Tool Placement in UI

### Tools Section Layout
```
▼ Tools
[Pan ✋]      <- Existing
[Edit ✏️]      <- NEW
[Delete 🗑️]    <- NEW
[Clear Map]   <- Existing
[Load] [Save] <- Existing
```

**Button Sizing:** Same as Pan button (48x48 for icons, or full-width for text)

---

## 3. Edit Mode Details

### Habitas Editing
- **Select:** Click on gold marker
- **Action:** Drag marker to new position
- **Visual:** Marker highlights when selected, shows drag cursor
- **Result:** Position updates in array

### AZN Editing
- **Select:** Click on yellow marker
- **Action:** Popup shows current quantity
  - Spinner: +/- buttons or type number
  - Range: 1-9999
  - Default: 10
- **Visual:** Marker highlights, popup positioned near marker
- **Result:** Quantity updates in array

### Zone Editing
- **Select:** Click on zone rectangle edge/interior
- **Actions:**
  - Drag interior: Move entire zone
  - Drag corner: Resize zone
- **Visual:** Zone highlights, corners show resize handles
- **Constraints:** Zone must be at least 2x2 cells
- **Result:** Rectangle coordinates update in array

---

## 4. Delete Mode Details

### Delete Brush Behavior
- **Activation:** Click "Delete" tool button
- **Input:** Left-click and drag on map
- **Effect:** Everything under cursor is removed
  - Terrain: Density → LOW, Stream_dir → NONE
  - Habitas: Removed from array
  - AZN: Removed from array
  - Zones: Removed from array
- **Visual:** White outline brush (like paint mode) shows area

### Delete Path
- Continuous path: Like painting, track last_delete_pos
- Avoid duplicates: Don't delete same element twice in one drag
- Update immediately: queue_redraw() after each deletion
- Undo: Full _save_state() call (or single state after drag ends?)

**Question:** Undo for delete - save state:
- Option A: Save state at drag START, undo restores everything
- Option B: Save state continuously during drag, undo one step at a time

---

## 5. Implementation Structure

### Active Tool States
```gdscript
active_tool: String = 
  "terrain" | "stream" | "habitas" | "azn" | "zone" | 
  "pan" | "edit" | "delete"
```

### Edit Mode Variables
```gdscript
# Selected element for editing
edit_selected_element: String = ""  # "habitas", "azn", "zone"
edit_selected_index: int = -1        # Index in array
edit_drag_offset: Vector2i           # For moving
```

### Delete Mode Variables
```gdscript
# Same as painting: is_painting, brush_cursor_pos, last_paint_pos
# Reuse existing infrastructure
```

---

## 6. Cursor Feedback ✅ LOCKED

- **Edit Tool:** Pen cursor (visual pen icon for editing)
- **Delete Tool:** Eraser cursor (visual eraser icon)
- **Edit/Delete Hover:** Different cursor over elements vs. empty
  - Over element: Grab/hand cursor
  - Over empty: No change

---

## 7. AZN Quantity Display (Hover) ✅ LOCKED

### When to Show
- Any mode, any time
- Hover cursor over AZN marker → tooltip appears
- Show for 0.5 seconds (short delay to avoid spam)

### How to Display
- **Tooltip (CHOSEN):**
  - Small text label appears above marker
  - Shows "30" or "Quantity: 30"
  - Disappears when cursor moves away
  - Non-intrusive, clean

---

## 8. Status Bar Updates

```
Tool: Edit ✏️ | Click element to edit, drag to move
Tool: Delete 🗑️ | Click + drag to erase terrain, streams, elements
```

---

## 8. Delete Undo Strategy ✅ LOCKED

### Single State at Drag Start
- When left-click pressed (drag starts): `_save_state()` captures entire map
- During drag: Delete everything touched (no intermediate saves)
- On release: Drag is complete
- Undo: Restores entire map to pre-deletion state with one undo

**Benefits:**
- Simple implementation
- User knows exactly what undo does
- No spam of undo states during drag
- Clear intent: "Delete now, one undo if mistake"

---

## 9. Testing Requirements

### Edit Mode
- [ ] Click habitas → can drag to new position
- [ ] Click AZN → popup shows quantity, can edit
- [ ] Click zone → can drag to move or resize
- [ ] Click empty area → deselect element
- [ ] Select different tool → exit edit mode

### Delete Mode
- [ ] Click drag to delete terrain
- [ ] Click drag to delete streams
- [ ] Click drag to delete habitas points
- [ ] Click drag to delete AZN nodes
- [ ] Click drag to delete injection zones
- [ ] Undo restores deleted elements

### AZN Hover
- [ ] Hover over AZN node shows quantity
- [ ] Value correct in all modes

### Visual Feedback
- [ ] Selected elements highlight
- [ ] Delete brush shows outline
- [ ] Cursor changes appropriately
- [ ] Status bar updates

---

## 10. Implementation Priority

1. **Delete Tool** (simpler) - Drag to delete everything
2. **Edit Tool** - Click to select, then edit
3. **AZN Hover** - Show quantity on hover
4. **Polish** - Cursors, feedback, animations

---

## 11. Ready for Implementation

**Locked Design:**
- ✅ Edit button in Tools section
- ✅ Delete button in Tools section
- ✅ Delete by drag (clears everything)
- ✅ Edit mode for all element types
- ✅ AZN quantity display on hover

**ALL DECISIONS LOCKED:** ✅

1. **AZN Quantity Display:** Tooltip (shows on hover, disappears when cursor moves)
2. **Delete Undo:** Single state at drag start (undo = full restore)
3. **Edit Cursor:** Pen icon (CURSOR_POINTING_HAND or visual pen)

---

## Implementation Ready

All design decisions are locked. Phase 4 implementation can begin immediately.

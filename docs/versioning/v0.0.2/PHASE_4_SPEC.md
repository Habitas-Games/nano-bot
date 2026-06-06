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

## 6. Cursor Feedback

- **Edit Tool:** Cursor shows edit icon (crosshair or hand)
- **Delete Tool:** Cursor shows delete icon (eraser or X)
- **Edit/Delete Hover:** Different cursor over elements vs. empty
  - Over element: Grab/hand cursor
  - Over empty: No change

---

## 7. AZN Quantity Display (Hover)

### When to Show
- Any mode, any time
- Hover cursor over AZN marker
- Show for 0.5 seconds (short delay to avoid spam)

### How to Display
- **Option A:** Tooltip (text label above marker)
  - Shows "30" or "Quantity: 30"
- **Option B:** Label permanently visible
  - Small text next to each marker
- **Option C:** Only in edit mode when selected

**Question:** Which approach preferred?

---

## 8. Status Bar Updates

```
Tool: Edit ✏️ | Click element to edit, drag to move
Tool: Delete 🗑️ | Click + drag to erase terrain, streams, elements
```

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

**Pending User Input:**
1. AZN quantity display: Tooltip, permanent label, or edit-mode-only?
2. Delete undo: State at start or continuously during drag?
3. Edit cursor style preference?

Once you clarify these, Phase 4 implementation begins.

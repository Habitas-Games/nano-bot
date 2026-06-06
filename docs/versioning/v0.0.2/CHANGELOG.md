# v0.0.2 Changelog

**Version:** 0.0.2  
**Status:** Phase 2 In Progress  
**Date Started:** 2026-06-06

---

## Commits This Session

### Phase 2: Terrain Editing (Foundation)

**Commit 444b4ba:** Phase 2: Full implementation per locked specification
- Implemented terrain painting (left-click)
- Implemented drag painting (continuous paths)
- Implemented flood fill (right-click)
- Implemented clear map and add border buttons
- Implemented undo/redo system (50 state limit)
- Added brush indicator (white outline on painted cell)
- **Status:** Working but had integration issues with other features

**Issues Found:**
- Stream and terrain modes both active simultaneously
- Scrollbars broken and removed
- Element placement partially implemented but not working
- Stream placement partially implemented but not working

---

### Bug Fixes & Refactoring

**Commit bda2cce:** Fix GDScript dictionary literal syntax
- Changed `{key: value}` to `{"key": value}` in dictionary literals
- GDScript 4.6 requires string keys in dictionary literals
- Fixed parse errors on lines 200-203, 235-237

**Commit a327c40:** Move Load/Save to Tools section in right panel
- Removed Load/Save from toolbar (was in wrong place)
- Added to Tools section in right panel menu
- All tools now consistently in right panel

**Commit 13981e5:** Remove broken scrollbars, add hand cursor for panning
- Removed non-functional scrollbar UI code
- Removed scrollbar variable references
- Added hand cursor (CURSOR_MOVE) for middle-click panning
- Simplified canvas layout back to working state

---

### Architecture: Exclusive Tool Mode

**Commit 38ee586:** Implement exclusive tool mode - only one active at a time
- **Problem:** Stream and terrain buttons both active → confused input handling
- **Solution:** Added `active_tool` variable with exclusive activation
- **Features:**
  - Terrain buttons activate terrain mode
  - Stream buttons activate stream mode
  - Element buttons activate their respective modes
  - Only active tool processes input events
  - Left-click routes to active tool only
  - Right-click flood-fill works only in terrain mode
  - When tool activates: deactivates painting, clears brush
  - Status bar shows active tool + mode details

**Design Pattern:**
```gdscript
active_tool: String = "terrain" | "stream" | "habitas" | "azn" | "zone"

func _activate_tool(tool_name: String) -> void:
  active_tool = tool_name
  is_painting = false
  brush_cursor_pos = Vector2i(-1, -1)
  _update_status()
  queue_redraw()
```

---

### Feature: Pan Tool (Explicit Control)

**Commit ff741be:** Add Pan tool with hand cursor - exclusive mode
- **Problem:** Pan was implicit (middle-click), could mix with editing
- **Solution:** Pan as explicit tool like terrain/stream/elements
- **Features:**
  - "Pan ✋" button in Tools section
  - When active: Left-click drag moves map (not painting)
  - Hand cursor always visible in pan mode
  - Cursor automatically updates when tool changes
  - Status bar shows "Tool: Pan ✋ | Click + drag to move map"
  - Exclusive mode: Only panning works when active

**Implementation:**
- Pan mode triggers on left-click (like painting)
- `is_painting = true` when dragging in pan mode
- Drag motion handler checks `active_tool == "pan"` for pan vs paint
- Cursor shows hand icon (CURSOR_MOVE) always in pan mode

---

## Current Status

### ✅ Phase 1: Complete (Verified)
- [x] Map loading from JSON
- [x] Terrain rendering (density tiles)
- [x] Stream rendering (texture + arrow overlay)
- [x] Element rendering (habitas, AZN, zones)
- [x] Zoom (0.5x - 3.0x)
- [x] Pan via middle-click drag

### 🔄 Phase 2: In Progress
- [x] Terrain painting (single cell)
- [x] Drag painting (continuous paths)
- [x] Flood fill (connected regions)
- [x] Brush indicator (visual feedback)
- [x] Clear map (reset to LOW)
- [x] Add border (set edges to BONE)
- [x] Undo history (50 states, undo only)
- [x] Exclusive tool mode (terrain, stream, elements, pan)
- [x] Pan tool with hand cursor

**Status:** Ready for testing - all Phase 2 terrain editing features implemented with proper tool isolation.

### Bug Fixes

**Commit 7ada7a4:** Fix stream texture rendering - add fallback for missing textures
- **Problem:** Last placed stream shows black instead of stream texture
- **Root Cause:** If stream texture fails to load, only arrow lines draw
- **Solution:** Added dark red fallback color if texture is null
- **Benefit:** Debug info - black = texture loaded, dark red = texture missing

**Commit 5fe14fe:** Fix tool deactivation - global reset before activating new tool
- **Problem 1:** Stream direction button still pans map
  - Root cause: Middle-click panning was always enabled
  - Solution: Removed implicit middle-click panning
  - Result: Only Pan tool can pan now
- **Problem 2:** Tool deactivation incomplete
  - Root cause: Only deactivated painting, not all state
  - Solution: Created _deactivate_all_tools() function
  - Result: Complete state reset before activation
- **Problem 3:** Pan tool not truly exclusive
  - Root cause: Middle-click bypassed tool exclusivity
  - Solution: Removed middle-click handler completely
  - Result: Users MUST select Pan tool to pan

### ❌ Phase 3+: Not Started
- [ ] Stream placement (direction selector + click)
- [ ] Element placement (habitas, AZN, zones)
- [ ] File save (JSON export)
- [ ] Validation (map checking)
- [ ] Polish (keyboard shortcuts, etc.)

---

## Design Decisions Made

### Exclusive Tool Mode (Why)
- **Problem:** Multiple modes active simultaneously caused confusion
- **User Feedback:** "both the stream and the tile are activated at the same time"
- **Solution:** Only one tool active - deactivates others
- **Benefit:** Clear input priority, no overlapping operations

### Pan Tool (Why Explicit)
- **Problem:** Implicit middle-click pan mixed with editing operations
- **User Feedback:** "add a hand icon as the tool to drag, no other"
- **Solution:** Pan as explicit tool button in Tools section
- **Benefit:** Visual feedback (hand cursor), exclusive control, consistent tool model

### Status Bar (Per Tool)
- **Problem:** User couldn't tell which mode was active
- **Solution:** Status bar shows active tool + mode details
- **Examples:**
  - "Tool: Terrain (LOW) | Click: paint | Right-click: fill"
  - "Tool: Stream (NORTH) | Click to place stream"
  - "Tool: Pan ✋ | Click + drag to move map"

---

## Testing Notes

**What Works:**
✅ Terrain painting - single cells and drag paths
✅ Flood fill - fills connected density regions
✅ Brush indicator - white outline shows painted cell
✅ Undo - reverts changes (50 state history)
✅ Pan tool - moves map with hand cursor
✅ Tool switching - deactivates old tool, activates new
✅ Status bar - updates for each tool

**What Needs Testing:**
- [ ] Stream placement (implemented but needs user test)
- [ ] Element placement (implemented but needs user test)
- [ ] Tool switching under various conditions
- [ ] Edge cases (zoom then paint, pan with zoom, etc.)

---

## Documentation Updates

- **analysis.md:** Added section 10 documenting exclusive tool mode and pan tool discovery
- **plan.md:** Added section 7 with implementation notes, design patterns, and testing requirements
- **CHANGELOG.md:** This file - tracks all commits and design decisions

---

## Next Steps

1. **Test Phase 2 thoroughly** - Verify all terrain editing works
2. **Fix any remaining issues** - User testing will reveal problems
3. **Plan Phase 3** - Stream placement (separate analysis/design)
4. **Plan Phase 4** - Element placement (separate analysis/design)
5. **Document everything** - Don't patch without updating docs

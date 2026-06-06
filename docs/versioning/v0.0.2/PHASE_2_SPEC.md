# Phase 2 Implementation Specification

**Status:** Design locked, ready for implementation
**Date:** 2026-06-05

---

## Design Decisions (Final)

### Terrain Editing
- **Selection:** Tile images as buttons with hover text showing cost
  - LOW: 2 turns
  - MEDIUM: 3 turns
  - HIGH: 4 turns
  - BONE: blocked
- **Painting:** Left-click drag with **visual brush indicator** around cursor
- **Flood fill:** Right-click to fill connected region

### Stream Placement
- **Selection:** One row with 4 direction icons (N, S, E, W) + title label
- **Placement:** Click cell to place stream in selected direction
- **Editing:** 
  - Overwrite: Click cell with different direction replaces stream
  - Erase: Paint terrain over stream (terrain overwrites stream)
  - Cannot delete stream separately - only by overwriting with terrain

### Element Placement
- **Workflow:** Place first, then move later
- **Habitas points:** Click to place, drag existing to move
- **AZN nodes:** Click to place, drag existing to move
- **Injection zones:** Drag rectangle to place, drag later to move

### Map Navigation
- **Pan:** Middle-click drag to pan map
- **Cursor:** Standard cursor (no special hand icon)
- **Zoom:** Scroll wheel (existing)

### History
- **Undo:** Only undo (no redo)
- **Max states:** 50

### Right Panel Layout
- **Style:** Expandable sections
- **Sections:**
  1. Terrain (with 4 tile buttons)
  2. Streams (with 4 direction buttons)
  3. Elements (place habitas, AZN, zones)
  4. Tools (clear, border)
  5. History (undo button)

---

## Implementation Requirements

### Terrain Selection UI
```
[Terrain Section - Expandable]
┌────────────────────────┐
│ Terrain                │
│ [tile] [tile] [tile] [tile]
│ (hover shows: "LOW 2", etc)
│ Selected: LOW          │
└────────────────────────┘
```

**Implementation:**
- 4 buttons, each with tile texture as background/icon
- Toggle mode (one selected)
- On hover: Show tooltip with "DENSITY turns"
- On click: Set selected_density + update status bar

### Stream Selection UI
```
[Streams Section - Expandable]
┌────────────────────────┐
│ Stream Direction       │
│ [↑] [↓] [→] [←]       │
│ (N) (S) (E) (W)       │
│ Selected: NORTH        │
└────────────────────────┘
```

**Implementation:**
- 4 buttons with arrow icons
- Toggle mode (one selected)
- On click: Set selected_stream_dir + update status bar

### Elements UI
```
[Elements Section - Expandable]
┌────────────────────────┐
│ Elements               │
│ [Place Habitas]        │
│ [Place AZN]            │
│ [Place Zone]           │
│ Mode: None             │
└────────────────────────┘
```

**Implementation:**
- Buttons to switch modes
- Show current mode in label
- Track placement_mode variable

### Tools Section
```
[Tools Section - Expandable]
┌────────────────────────┐
│ [Clear Map]            │
│ [Add Border]           │
│ [Undo]                 │
└────────────────────────┘
```

### Paint Brush Visual Indicator
**When dragging to paint terrain:**
- Show visual feedback (circle or square) around cursor
- Indicate brush area
- Show which cell will be painted

**Options:**
- Highlight the current grid cell in bright color
- Draw circle/square around cursor position
- Draw outline of affected cell(s)

**Recommended:** Highlight the grid cell being painted in a distinct color (e.g., white outline or semi-transparent overlay)

### Stream Placement Behavior
1. User selects direction (default: NORTH)
2. User clicks cell
3. New stream placed (overwrites old if exists)
4. Visual: Arrow appears pointing in selected direction

**Overwrite behavior:**
- Clicking cell with different direction replaces stream
- Painting terrain over cell erases stream

### Element Placement Behavior
1. User clicks "Place Habitas" button
2. Click cell to place habitas point
3. Drag existing habitas point to move it
4. Click different element button to switch modes

**Movement workflow:**
- Click existing element to select
- Drag to new position
- Release to place

---

## Input Handling Summary

**Canvas Input Priority (Exclusive):**

1. **Terrain painting (is_painting = true)**
   - Left-click drag: Paint with visual brush indicator
   - Exclusive input (blocks other handlers)
   - Call: `set_input_as_handled()`

2. **Right-click (lowest priority)**
   - Flood fill on canvas
   - Works only when not painting

3. **Middle-click drag (pan)**
   - Pan map with mouse drag
   - Works only when not painting

4. **Element drag (future)**
   - Drag placed elements to move
   - Will have input priority when active

**Key:** Active operation (painting) has exclusive input. No mixing.

---

## Data Changes Required

**New variables:**
```gdscript
placement_mode: String  # "none", "habitas", "azn", "zone"
selected_stream_dir: int  # StreamDir enum
brush_indicator_visible: bool
```

**Existing variables (update):**
```gdscript
selected_density: int  # Already exists
is_painting: bool  # Already exists
```

---

## UI Button Specifications

### Terrain Buttons
- Size: 48x48 pixels (larger for tile visibility)
- Background: Tile texture
- Border: 2px, gray when unselected, white when selected
- Hover tooltip: "DENSITY cost" (e.g., "LOW 2")
- Toggle mode: Only one selected

### Stream Buttons
- Size: 36x36 pixels
- Icon: Arrow (↑ ↓ → ←)
- Border: 2px, gray/white like terrain buttons
- Label below: N, S, E, W
- Toggle mode: Only one selected

### Tool Buttons
- Size: Full width (auto-expand)
- Text: Clear Map, Add Border, Undo
- Standard button style

---

## Status Bar Updates

**Current:** Shows selected terrain

**New:**
- Show selected terrain OR stream direction OR element placement mode
- Update as user switches modes

Example:
- "Terrain: LOW" when painting
- "Stream: NORTH" when placing streams
- "Mode: Place Habitas" when placing elements

---

## Visual Feedback Checklist

- ✅ Tile buttons show actual textures
- ✅ Hover text shows cost
- ✅ Selected button highlighted
- ✅ Stream direction icons clear
- ✅ Status bar updates with mode
- ✅ Brush indicator visible when dragging
- ✅ Undo button available
- ✅ Clear/Border buttons available

---

## Ready for Implementation

All design decisions locked. This specification is complete and unambiguous.

Next step: Update Phase 2 plan with this specification, then implement.

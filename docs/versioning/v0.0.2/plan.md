# v0.0.2 — Map Editor Implementation Plan

**Status:** Plan (based on corrected analysis)
**Reference:** [analysis.md](./analysis.md)

---

## 1. Overview

Implement a map editor that matches the simulator's exact data model, format, and visual rendering.

**Critical Correction from Analysis:**
- Stream is a CELL PROPERTY (density + stream_dir), not separate metadata
- Stream doesn't change terrain density
- Stream rendering: Use stream texture + procedural arrow overlay

---

## 2. Core Architecture

### Data Model (Matches Simulator)

```gdscript
# In-memory representation
class MapState:
  width: int
  height: int
  cells: Array  # cells[y * width + x] = {density: int, stream_dir: int}
  
  habitas_points: Array[Vector2i]
  azn_nodes: Array[{position: Vector2i, quantity: int}]
  injection_zones: Array[{player: int, rect: Rect2i}]
```

### Key Constants

```gdscript
CELL_SIZE = 16

# Density Enum
Density = {LOW: 0, MEDIUM: 1, HIGH: 2, BONE: 3}

# StreamDir Enum  
StreamDir = {NONE: 0, NORTH: 1, SOUTH: 2, EAST: 3, WEST: 4}

# Rendering
STREAM_COLOR = Color(0.70, 0.25, 0.25, 0.80)  # Arrow color
```

### Texture Assets (Actual Files)

```
Terrain:
  res://assets/tiles/tile_low.png
  res://assets/tiles/tile_medium.png
  res://assets/tiles/tile_high.png
  res://assets/tiles/tile_bone.png

Streams:
  res://assets/tiles/tile_stream_h.png
  res://assets/tiles/tile_stream_v.png

Elements:
  res://assets/markers/habitas_neutral.png
  res://assets/markers/habitas_owned.png
  res://assets/markers/azn_node.png
```

---

## 3. Implementation Phases

### Phase 1: Core Rendering (Canvas + Correct Display)

**Goal:** Display maps exactly as simulator shows them

**Features:**
1. Load map JSON file using MapLoader format
2. Initialize MapData structure correctly (flat cell array)
3. Render terrain:
   - If stream_dir == NONE: draw terrain texture
   - If stream_dir != NONE: draw stream texture
4. Render stream arrows (procedural):
   - Shaft from cell center in direction vector
   - Arrowhead with 2 perpendicular lines
   - Color: STREAM_COLOR
5. Render grid lines (subtle, per cell)
6. Render elements (habitas, AZN, zones)
7. Zoom: 0.5x to 3.0x
8. Pan: middle-click drag

**Deliverables:**
- Map loads and displays identically to simulator
- All terrain colors correct
- Streams show as stream texture + arrow (not full tile)
- Arrows point in correct direction
- Elements visible
- Zoom/pan smooth

**Time:** 6-8 hours

**Tests:**
- Load simple_tissue.json, compare pixel-for-pixel to simulator
- Verify arrow directions match stream_dir enum
- Verify terrain color matches tile texture
- Zoom in/out, verify no artifacts
- Pan, verify scrolling correct

---

### Phase 2: Terrain Editing

**Goal:** Paint terrain while keeping streams intact

**Features:**
1. Left-click to paint single cell
2. Left-click drag to paint continuous path
3. Right-click to flood-fill connected region
4. Tool selector: choose density (LOW/MEDIUM/HIGH/BONE)
5. Clear map button
6. Add border button
7. CRITICAL: When painting, only change density, NOT stream_dir

**Deliverables:**
- Can select density from UI
- Painting changes only density, preserves streams
- Flood-fill works on connected density regions
- Clear resets all to LOW/NONE
- Border adds BONE cells around edge

**Time:** 4-5 hours

**Tests:**
- Paint cell, verify density changed but stream_dir unchanged
- Flood-fill, verify all connected same-density cells change
- Paint over stream cell, verify arrow still shows
- Save/load, verify stream preserved

---

### Phase 3: Stream Placement

**Goal:** Place streams with correct enum values

**Features:**
1. Stream placement mode
2. Direction selector: N/S/E/W
3. Click to place stream on cell (changes stream_dir, not density)
4. Verify cell shows stream texture + arrow
5. Can place stream on any terrain type
6. CRITICAL: Don't change terrain when placing stream

**Deliverables:**
- Direction buttons for N/S/E/W
- Click places stream with correct enum value
- Stream texture appears
- Arrow points correctly
- Can place over any density terrain

**Time:** 3-4 hours

**Tests:**
- Place stream N/S/E/W, verify arrow direction
- Place stream on each density, verify terrain visible under stream texture
- Verify JSON stream field matches direction

---

### Phase 4: Element Placement

**Goal:** Place habitas, AZN, zones

**Features:**
1. Habitas mode: click to place point
2. AZN mode: click to place with quantity selector
3. Zone mode: drag rectangle to define injection zone, assign player
4. Display elements as markers on canvas
5. Delete selected elements

**Deliverables:**
- Elements place at correct grid positions
- Habitas shows as marker
- AZN shows with quantity
- Zones show as rectangles
- Can delete any element

**Time:** 4-5 hours

**Tests:**
- Place each element type
- Verify JSON format matches loader expectations
- Delete and undo works

---

### Phase 5: File I/O and Persistence

**Goal:** Save/load maps in correct JSON format

**Features:**
1. Load dialog: browse res://maps/, select map
2. Save As dialog: custom filename
3. Generate correct JSON:
   - Array of cells with x, y, density, stream (if not NONE)
   - Arrays for habitas_points, azn_nodes, injection_zones
   - Correct format for loader to parse
4. Validation warnings:
   - At least 1 habitas point
   - At least 1 AZN node
   - At least 1 injection zone
5. Round-trip test: load → save → load produces identical result

**Deliverables:**
- Load existing maps
- Save with custom filename
- Warnings before incomplete map save
- Saved JSON loads in simulator without error

**Time:** 3-4 hours

**Tests:**
- Load map, verify data matches simulator
- Edit, save, load again
- Compare loaded vs original (should be identical)
- Try save without required elements, verify warning

---

### Phase 6: Undo/History and Polish

**Goal:** User comfort and error recovery

**Features:**
1. Undo button: reverts last action
2. History limit: 50 states
3. Saves full state: all cells + streams + elements
4. Status bar:
   - Current tool
   - Coordinates on hover
   - Mode feedback
5. Keyboard shortcuts: Ctrl+Z (undo), Ctrl+S (save)

**Deliverables:**
- Undo works for all operations
- Status bar clear
- Error messages helpful
- No data loss

**Time:** 2-3 hours

**Tests:**
- Paint, undo, verify reverted
- Undo multiple times, verify state correct
- Place element, undo, verify removed

---

## 4. Implementation Order

```
Phase 1: Rendering (CRITICAL FIRST)
  ├── Load map using MapLoader format
  ├── Display terrain texture (based on density)
  ├── Display stream texture (tile_stream_h or tile_stream_v)
  ├── Draw procedural arrows (3-line arrowhead)
  ├── Draw elements
  └── Zoom/pan controls

Phase 2: Terrain Editing
  ├── Paint single cell (preserve stream_dir)
  ├── Drag paint
  ├── Flood fill
  └── Clear/border buttons

Phase 3: Streams
  ├── Stream mode selector
  ├── Direction buttons
  ├── Click to place (set stream_dir)
  └── Verify rendering correct

Phase 4: Elements
  ├── Habitas placement
  ├── AZN placement
  ├── Zone creation
  └── Delete operations

Phase 5: File I/O
  ├── Load dialog
  ├── Save dialog
  ├── JSON generation (correct format)
  └── Validation warnings

Phase 6: Polish
  ├── Undo/history
  ├── Status bar
  ├── Shortcuts
  └── Error handling
```

---

## 5. Critical Implementation Details

### Cell Rendering Logic

```
For each visible cell (x, y):
  if cell.stream_dir == StreamDir.NONE:
    // Draw terrain
    texture = TILE_TEX[cell.density]
    draw_texture(texture, screen_pos, CELL_SIZE)
  else:
    // Draw stream cell
    if cell.stream_dir in [EAST, WEST]:
      texture = STREAM_TEX_H
      if cell.stream_dir == WEST:
        flip_horizontal = true
    else:  // NORTH, SOUTH
      texture = STREAM_TEX_V
      if cell.stream_dir == NORTH:
        flip_vertical = true
    
    draw_texture(texture, screen_pos, CELL_SIZE)
    draw_stream_arrow(screen_pos, cell.stream_dir)
  
  // Draw grid line
  draw_rect_outline(screen_pos, CELL_SIZE, GRID_COLOR)
```

### Stream Arrow Rendering

```
func draw_stream_arrow(screen_pos: Vector2, stream_dir: int):
  center = screen_pos + Vector2(CELL_SIZE * 0.5, CELL_SIZE * 0.5)
  direction_vec = stream_to_vec(stream_dir)
  
  // Arrow shaft
  shaft_length = CELL_SIZE * 0.5 - 3.5
  base = center - direction_vec * shaft_length * 0.5
  tip = center + direction_vec * shaft_length
  draw_line(base, tip, STREAM_COLOR, 1.5)
  
  // Arrowhead (2 perpendicular lines)
  perpendicular = Vector2(-direction_vec.y, direction_vec.x) * 2.5
  head_back = tip - direction_vec * 3.5
  draw_line(tip, head_back + perpendicular, STREAM_COLOR, 1.5)
  draw_line(tip, head_back - perpendicular, STREAM_COLOR, 1.5)
```

### JSON Generation for Save

```
cells = []
for y in range(height):
  for x in range(width):
    cell = cells[y * width + x]
    if cell.density != Density.LOW or cell.stream_dir != StreamDir.NONE:
      cell_obj = {
        "x": x,
        "y": y,
        "density": density_to_string(cell.density)
      }
      if cell.stream_dir != StreamDir.NONE:
        cell_obj["stream"] = stream_dir_to_string(cell.stream_dir)
      cells.append(cell_obj)

map_data = {
  "name": filename,
  "width": width,
  "height": height,
  "default_density": "low",
  "cells": cells,
  "habitas_points": habitas_points,
  "azn_nodes": azn_nodes,
  "injection_zones": injection_zones
}
```

### JSON Loading

Use existing MapLoader format - editor must produce identical output to what simulator loads.

---

## 6. Data Type Mappings

### String → Enum (Load)
```
"low" → Density.LOW (0)
"medium" → Density.MEDIUM (1)
"high" → Density.HIGH (2)
"bone" → Density.BONE (3)

"north" → StreamDir.NORTH (1)
"south" → StreamDir.SOUTH (2)
"east" → StreamDir.EAST (3)
"west" → StreamDir.WEST (4)
(missing) → StreamDir.NONE (0)
```

### Enum → String (Save)
```
Density.LOW → "low"
Density.MEDIUM → "medium"
Density.HIGH → "high"
Density.BONE → "bone"

StreamDir.NORTH → "north"
StreamDir.SOUTH → "south"
StreamDir.EAST → "east"
StreamDir.WEST → "west"
(StreamDir.NONE is omitted from JSON)
```

---

## 7. Success Criteria

### Phase 1 Complete When
- ✓ Load map, display matches simulator pixel-for-pixel
- ✓ Terrain colors correct for all 4 densities
- ✓ Streams show stream texture + arrow (not full tile)
- ✓ Arrow directions match stream_dir values
- ✓ Zoom/pan smooth and correct

### Phase 2 Complete When
- ✓ Can paint terrain without affecting streams
- ✓ Flood-fill works correctly
- ✓ Stream preserved when painting over it
- ✓ Clear and border work

### Phase 3 Complete When
- ✓ Can place streams in all 4 directions
- ✓ Arrow shows immediately after placement
- ✓ Terrain unchanged when placing stream

### Phase 4 Complete When
- ✓ All element types placeable
- ✓ Elements display correctly
- ✓ Can delete elements

### Phase 5 Complete When
- ✓ JSON format matches loader exactly
- ✓ Round-trip load→save→load produces identical result
- ✓ Validation warnings work
- ✓ Saved maps load in simulator error-free

### Phase 6 Complete When
- ✓ Undo reverts all operations
- ✓ History limit enforced (50 states)
- ✓ Status bar clear
- ✓ No crashes or data loss

### Overall Complete When
- ✓ Matches simulator rendering exactly
- ✓ Can create/edit maps intuitively
- ✓ JSON format perfect match
- ✓ No visual discrepancies
- ✓ User can complete map in <5 minutes

---

## 8. Risk Mitigation

| Risk | Mitigation |
|---|---|
| Arrow direction wrong | Implement exactly like simulator, test all 4 directions |
| JSON format mismatch | Use MapLoader to verify format |
| Stream texture missing | Verify files exist before load |
| Performance issues | Profile with 80×80 maps, optimize if needed |
| Coordinate math off | Test at various zoom levels, verify clicks map to correct cells |
| Data loss | Keep history, add confirmation dialogs |

---

## 9. Timeline

| Phase | Hours | Note |
|-------|-------|------|
| Phase 1 | 6-8 | Critical: rendering must be exact |
| Phase 2 | 4-5 | Core editing feature |
| Phase 3 | 3-4 | Stream placement |
| Phase 4 | 4-5 | Element placement |
| Phase 5 | 3-4 | File I/O |
| Phase 6 | 2-3 | Polish |
| **Total** | **22-29 hours** | |

---

## 10. Start Condition

✅ Analysis complete and based on simulator code review
✅ Data model correct (stream as cell property)
✅ Rendering algorithm documented (stream texture + arrow)
✅ JSON format specified
✅ Ready to implement Phase 1

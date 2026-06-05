# v0.0.2 — Map Editor Analysis

**Status:** Analysis (requirements based on simulator code review)

---

## 1. Simulator Foundation

This analysis is based on examining the actual simulator code (MapData, MapLoader, MapRenderer) to understand the exact data model, formats, and visual rendering.

**Key Files Reviewed:**
- `src/core/map_data.gd` - Data structure and cell model
- `src/core/map_loader.gd` - JSON format and loading
- `src/ui/playback/map_renderer.gd` - Exact visual rendering

---

## 2. Data Model (From Simulator)

### Cell Structure
Each map cell has TWO independent properties:

```
Cell {
  density: Density enum     # LOW, MEDIUM, HIGH, BONE
  stream_dir: StreamDir enum # NONE, NORTH, SOUTH, EAST, WEST
}
```

**Critical:** Stream direction does NOT change terrain density. They are separate.

### Map Collections

```
MapData {
  width: int (60-80)
  height: int (60-80)
  
  habitas_points: Array[Vector2i]           # Just positions
  azn_nodes: Array[{position: Vector2i, quantity: int}]
  injection_zones: Array[{player: int, rect: Rect2i}]
  _cells: Array[{density, stream_dir}]      # Flat array: cells[y*width+x]
}
```

### Density Enum Values
```
Density {
  LOW = 0,
  MEDIUM = 1,
  HIGH = 2,
  BONE = 3
}
```

### StreamDir Enum Values
```
StreamDir {
  NONE = 0,
  NORTH = 1,
  SOUTH = 2,
  EAST = 3,
  WEST = 4
}
```

(Note: Not stored as strings in simulator, but as integers)

---

## 3. JSON Format (Loader)

### Density Mapping
String → Enum
```
"low"    → Density.LOW
"medium" → Density.MEDIUM
"high"   → Density.HIGH
"bone"   → Density.BONE
```

### Stream Mapping
String → Enum
```
"north" → StreamDir.NORTH
"south" → StreamDir.SOUTH
"east"  → StreamDir.EAST
"west"  → StreamDir.WEST
(missing) → StreamDir.NONE
```

### Cell Object (in JSON)
```json
{
  "x": integer,
  "y": integer,
  "density": "low" | "medium" | "high" | "bone",
  "stream": "north" | "south" | "east" | "west"  (optional, omit if NONE)
}
```

### Habitas Points
```json
{
  "x": integer,
  "y": integer
}
```

### AZN Nodes
```json
{
  "x": integer,
  "y": integer,
  "quantity": integer (default 10)
}
```

### Injection Zones
```json
{
  "player": 0 | 1,
  "x1": integer,
  "y1": integer,
  "x2": integer,
  "y2": integer
}
```

Note: Rectangle is inclusive on both ends (x1 to x2 inclusive, not x2-exclusive)

---

## 4. Visual Rendering (From MapRenderer)

### Constants
```
CELL_SIZE = 16 pixels

STREAM_COLOR = Color(0.70, 0.25, 0.25, 0.80)  # Reddish-brown
```

### Terrain Textures
```
tile_low.png     (light/salmon color)
tile_medium.png  (purple/violet)
tile_high.png    (dark purple)
tile_bone.png    (very dark/black)
```

### Stream Textures
```
tile_stream_h.png  (horizontal stream background)
tile_stream_v.png  (vertical stream background)
```

### Element Textures
```
habitas_neutral.png  (gold/orange marker)
habitas_owned.png    (marker with owner tint)
azn_node.png         (yellow circle marker)
```

### Rendering Algorithm

```
For each cell (x, y):
  if stream_dir == NONE:
    // Draw terrain
    draw_texture(TILE_TEX[density], position, size)
  else:
    // Draw stream cell
    if stream_dir is EAST or WEST:
      draw_texture(STREAM_TEX_H, position, size)
    else:  // NORTH or SOUTH
      draw_texture(STREAM_TEX_V, position, size)
    
    // Overlay procedural arrow
    center = cell_center
    direction_vector = stream_to_vec(stream_dir)
    arrow_length = CELL_SIZE * 0.5 - 3.5
    
    // Draw arrow shaft
    draw_line(center - direction_vector * arrow_length * 0.5,
              center + direction_vector * arrow_length,
              STREAM_COLOR, 1.5)
    
    // Draw arrowhead (2 lines forming V)
    perpendicular = rotate_90(direction_vector) * 2.5
    arrow_tip = center + direction_vector * arrow_length
    draw_line(arrow_tip, arrow_tip - direction_vector * 3.5 + perpendicular, STREAM_COLOR, 1.5)
    draw_line(arrow_tip, arrow_tip - direction_vector * 3.5 - perpendicular, STREAM_COLOR, 1.5)
```

**Key Point:** Stream texture provides background, procedural arrow provides clarity.

### Direction Vectors
```
NORTH: Vector2( 0, -1)
SOUTH: Vector2( 0,  1)
EAST:  Vector2( 1,  0)
WEST:  Vector2(-1,  0)
```

### Grid Lines
```
Color = Color(0.00, 0.00, 0.00, 0.12)  // Very subtle black
Drawn as outline rect for each cell
```

---

## 5. Requirements (Based on Findings)

### REQ-1: Terrain Editing
- Select from 4 densities: LOW, MEDIUM, HIGH, BONE
- Paint single cell (left-click)
- Paint continuous path (left-click + drag)
- Flood-fill connected region (right-click)
- Terrain density is INDEPENDENT of streams

### REQ-2: Stream Placement
- Place stream on a cell with specific direction: N/S/E/W
- Stream is METADATA, doesn't change terrain density
- Stream can be placed on any density cell
- Editor must handle NONE state (no stream on cell)

### REQ-3: Element Placement
- Habitas points: click to place at grid position
- AZN nodes: click to place, can specify quantity
- Injection zones: drag rectangle to define area, specify player (0 or 1)

### REQ-4: Map Display
- Terrain grid with correct colors and sprites
- Stream cells show stream texture + procedural arrow overlay
- Elements displayed as markers
- Grid lines visible

### REQ-5: File Operations
- Load map from JSON (parse format exactly as specified)
- Save map to JSON (generate format exactly as specified)
- Round-trip guarantee: load → edit → save → load produces identical results

### REQ-6: Navigation
- Zoom: 0.5x to 3.0x (match simulator zoom range)
- Pan: middle-click drag or scrollbars
- Large maps up to 80x80 must be navigable

### REQ-7: Undo/History
- Undo full state (terrain + streams + elements)
- Keep 20-50 states

### REQ-8: User Feedback
- Status bar showing current tool
- Coordinate display on hover
- Confirmation for destructive operations
- Validation warnings before save

---

## 6. Critical Differences from Previous Implementation

| Previous | Correct |
|----------|---------|
| Bloodstreams in separate array | Stream is property of cell |
| Stream changes terrain density | Stream is independent metadata |
| Full tile rendering for streams | Stream texture + arrow overlay |
| String direction names | Integer enum values |
| Wrong arrow rendering | Procedural arrowhead with shaft |

---

## 7. Implementation Constraints

- **CONST-1:** StreamDir is enum (integer), not string
- **CONST-2:** Each cell has density AND stream_dir both set independently
- **CONST-3:** Stream textures must be used (tile_stream_h.png, tile_stream_v.png)
- **CONST-4:** Arrow drawn with 3 lines (shaft + 2 arrowhead lines), not primitive arrow
- **CONST-5:** Arrow color must be exactly Color(0.70, 0.25, 0.25, 0.80)
- **CONST-6:** Flat cell array indexed as cells[y * width + x]
- **CONST-7:** JSON format must match loader expectations exactly

---

## 8. Success Criteria

1. ✓ Load any existing map and display it correctly
2. ✓ Terrain colors match simulator exactly
3. ✓ Bloodstreams show as stream texture + procedural arrow (not full tiles)
4. ✓ Arrow direction matches stream_dir value
5. ✓ Can paint terrain without affecting streams
6. ✓ Can place streams without affecting terrain
7. ✓ Can place all element types
8. ✓ Saved JSON loads identically in simulator
9. ✓ Round-trip test: load → edit → save → load produces same result
10. ✓ UI layout matches simulator proportions

---

## 10. Phase 1 Implementation Status

### What's Implemented

**Core Functionality:**
- ✅ Load maps from JSON (simulator MapLoader format)
- ✅ Display terrain grid with correct textures (based on Density enum)
- ✅ Display streams: stream texture (tile_stream_h/v.png) + procedural arrow overlay
- ✅ Display elements: habitas points, AZN nodes, injection zones
- ✅ Zoom: scroll wheel (0.5x to 3.0x)
- ✅ Pan: middle-click drag with proper clamping

**Data Model (Correct Implementation):**
```
cells[y * width + x] = {
  "density": int (0-3),      # Density.LOW, MEDIUM, HIGH, BONE
  "stream_dir": int (0-4)    # StreamDir.NONE, NORTH, SOUTH, EAST, WEST
}
```
- Stream is a cell property, independent of density
- Both stored as integer enums (not strings)
- Proper enum values matching simulator

**Rendering (Exact Match to Simulator):**
- Stream cells: Render stream texture first, then procedural arrow overlay
- Arrow: 3 lines (shaft + 2-line arrowhead)
- Arrow color: Color(0.70, 0.25, 0.25, 0.80) - reddish-brown
- Arrow direction: Calculated from StreamDir enum
- Grid lines: Subtle (Color 0,0,0,0.12) drawn per cell
- Terrain colors: Match sprite textures loaded from assets

**UI Layout:**
- Left: Status bar (30px) + Toolbar (40px) + Canvas area + Scrollbar (15px)
- Right: Info panel (200px) with title and map size
- Proper HBox/VBox layout with size_flags for expansion

**Input Handling:**
- Scroll wheel: Zoom in/out with ZOOM_STEP
- Middle-click drag: Pan with scroll clamping
- Proper clamping: `clampi(scroll, 0, max_scroll)`

### What's NOT Implemented Yet

- ❌ Terrain painting (left-click single cell)
- ❌ Drag painting (continuous path)
- ❌ Flood fill (right-click)
- ❌ Stream placement (direction selector + click)
- ❌ Element placement (habitas, AZN, zones)
- ❌ Undo/history
- ❌ Save/load dialogs (buttons exist but placeholder)
- ❌ Validation warnings
- ❌ Keyboard shortcuts

### Architecture Notes

**File Structure:**
- `src/ui/map_editor/map_editor.gd` - Single file, 380+ lines
- `scenes/map_editor_scene.tscn` - Minimal scene (just attaches script)

**Key Implementation Details:**
1. Uses `_draw()` override for all rendering
2. Uses `_input()` override for all input
3. Flat cell array indexed as `cells[y * width + x]`
4. All textures preloaded in `_load_textures()`
5. Map loaded using simulator JSON format in `_load_map_from_file()`
6. Coordinate conversion: `screen_pos = canvas_pos + (grid_pos * CELL_SIZE * zoom) - scroll`

**Constants Used (Match Simulator):**
```
CELL_SIZE = 16
STREAM_COLOR = Color(0.70, 0.25, 0.25, 0.80)
GRID_COLOR = Color(0.00, 0.00, 0.00, 0.12)
```

### What's Working vs. Plan

| Planned | Implemented | Status |
|---------|-------------|--------|
| Load maps from JSON | ✅ Yes, simulator format | ✅ Complete |
| Display terrain | ✅ Yes, all 4 densities | ✅ Complete |
| Display streams | ✅ Yes, texture + arrow | ✅ Complete |
| Display elements | ✅ Yes, all types | ✅ Complete |
| Zoom/pan | ✅ Yes, correct math | ✅ Complete |
| Paint terrain | ❌ Not yet | Phase 2 |
| Flood fill | ❌ Not yet | Phase 2 |
| Stream placement | ❌ Not yet | Phase 3 |
| Element placement | ❌ Not yet | Phase 4 |
| Save/load dialogs | ⚠️ UI stubs only | Phase 5 |
| Undo/history | ❌ Not yet | Phase 6 |

### Known Limitations (Phase 1)

1. **Read-only:** Can load and view maps, but cannot edit anything
2. **No undo:** All changes are permanent (once edit features added)
3. **No validation:** Maps can be in any state when saved
4. **Load only:** No save functionality yet (buttons are placeholders)
5. **Static elements:** Habitas, AZN, zones display but cannot be modified

### Phase 2 Issue 1: Input Priority (Documented & Fixed)

**Problem:** Painting and dragging were mixing.
**Root Cause:** Missing input handling specification in analysis.
**Solution:** Input priority - painting has exclusive input (documented above).

### Phase 2 Issue 2: Terrain Selection UI (NOT PROPERLY ANALYZED)

**Problem Identified:**
- Button labels are text ("LOW", "MEDIUM", "HIGH") instead of visual terrain
- No movement cost information displayed
- Doesn't match simulator's actual representation of terrain

**What Should Have Been Analyzed FIRST:**
From simulator code (map_data.gd):
```
DENSITY_COST = {
  Density.LOW:    2 turns,
  Density.MEDIUM: 3 turns,
  Density.HIGH:   4 turns
}
```

**Correct UI Design (Should Have Been in Plan):**
1. Button shows actual tile TEXTURE (not text label)
2. Each button displays movement cost: "2 turns", "3 turns", "4 turns"
3. Selected button highlighted (toggle mode)
4. User selects by clicking tile image, not by reading text

**Example Button Layout:**
```
[tile_low.png]    [tile_medium.png] [tile_high.png]  [tile_bone.png]
  2 turns           3 turns           4 turns          blocked
```

**Why This Wasn't Caught:**
- Didn't examine simulator UI before designing editor UI
- Made assumptions about how to represent terrain
- Didn't translate simulator information (DENSITY_COST) into UI design
- Patched implementation after-the-fact instead of analyzing first

**Impact:**
- Current UI is confusing (text-based, no cost info)
- Doesn't match simulator's conceptual model
- User must memorize "LOW = 2 turns" etc.
- Poor UX compared to visual tile selection

**Problem Identified:**
- Left-click drag to paint and other drag operations (pan with middle-click) have conflicting input handling
- Mouse motion events during paint drag can interfere with coordinate calculations and visual feedback
- No clear input priority/hierarchy was specified before implementation

**Root Cause:**
- Input handling uses generic MouseMotion events without properly consuming them
- Multiple handlers (paint drag, pan, etc.) compete for same input events
- No call to `set_input_as_handled()` during drag painting to prevent event propagation

**Proposed Solutions:**

**Option A: Input Priority (Recommended)**
- Establish priority: Active tool has exclusive input
- When painting (is_painting = true), consume all MouseMotion events with `set_input_as_handled()`
- Pan (middle-click) has lower priority, only processes when no active painting
- Clear separation: One operation at a time

**Option B: Gesture Detection**
- Distinguish between short drag (paint) vs. long drag (pan)
- Track drag distance/duration to detect intent
- More complex but allows flexibility
- Risk: Harder to predict user intent

**Option C: Tool Mode System**
- Add explicit "tool mode": PAINT, PAN, SELECT
- User switches modes before using tool
- Very explicit but less intuitive
- Good for complex editors, overkill here

**Recommended Implementation (Option A):**
1. During `is_painting = true`, call `set_input_as_handled()` on all MouseMotion events
2. This prevents event bubbling to other handlers
3. Clear input hierarchy: active tool has exclusive input
4. Pan only works when not painting

**Code Change Required:**
```gdscript
# Drag paint
if event is InputEventMouseMotion and is_painting:
  var local_pos = event.position
  if _is_in_canvas(local_pos):
    var grid_x = int((local_pos.x - cx + scroll_x) / (CELL_SIZE * zoom))
    var grid_y = int((local_pos.y - cy + scroll_y) / (CELL_SIZE * zoom))

    if grid_x >= 0 and grid_x < map_width and grid_y >= 0 and grid_y < map_height:
      if Vector2i(grid_x, grid_y) != last_paint_pos:
        _paint_cell(grid_x, grid_y)
        last_paint_pos = Vector2i(grid_x, grid_y)
      get_tree().root.set_input_as_handled()  # CRITICAL: Prevent event propagation
      return
```

**Impact on Future Phases:**
- Phase 3 (Stream placement): Will have same issue, need same solution
- Phase 4 (Element placement): Drag to place zones will need input priority
- All future drag operations must follow same pattern

**Why This Wasn't Caught in Analysis:**
- Analysis didn't specify input event handling hierarchy
- Plan didn't document input priority/exclusivity
- Implementation proceeded without clear specification
- Should have added input handling section to analysis before coding

### Next Phase (Phase 2): Terrain Editing

Required for terrain editing to work:
1. Click detection (left-click in canvas area)
2. Grid coordinate conversion (screen → grid)
3. Density selector UI in right panel
4. Paint single cell: `cells[grid_y * width + grid_x]["density"] = selected_density`
5. Drag paint: Track mouse motion and paint continuous path
6. Flood fill: Connected region detection algorithm

---

## 11. Next: Plan Phase

With Phase 1 complete and analyzed, Phase 2 planning should specify:
- Terrain editing tools (paint, fill)
- Edit Phase 3: Element placement
- Edit Phase 4: File I/O
- Edit Phase 5: Polish

All future phases build on Phase 1's correct rendering foundation.

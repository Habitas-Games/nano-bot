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

## 9. Next: Plan Phase

With actual requirements documented, plan.md should specify:
- Phase 1: Canvas with correct terrain + stream rendering
- Phase 2: Editing tools (paint, fill)
- Phase 3: Element placement
- Phase 4: File I/O
- Phase 5: Polish

All based on actual simulator behavior, not assumptions.

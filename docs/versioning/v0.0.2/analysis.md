# Map Editor - Comprehensive Requirements Analysis (v0.0.2)

---

## REQUIREMENTS ANALYSIS AND DEFINITION

### Document Purpose
This section formalizes all requirements for the Map Editor v0.1 using structured requirement definitions, acceptance criteria, and dependency mapping.

---

### 1. FUNCTIONAL REQUIREMENTS (FRs)

#### FR-1: Terrain Editing
- **ID**: FR-1.1 | **Priority**: HIGH
- **Title**: Single Cell Terrain Painting
- **Description**: User can select a terrain density type and click a single map cell to change its density
- **Acceptance Criteria**:
  - [ ] Clicking a cell changes grid[y][x] to selected_density
  - [ ] Visual update appears immediately
  - [ ] One action = one history state
  - [ ] Works at any zoom level
  - [ ] Correct cell painted regardless of pan/scroll offset

- **ID**: FR-1.2 | **Priority**: HIGH
- **Title**: Multi-Cell Terrain Painting (Drag)
- **Description**: User can click and drag to paint multiple adjacent cells in a continuous line
- **Acceptance Criteria**:
  - [ ] Drag creates continuous painted path
  - [ ] No gaps in path (use Bresenham line)
  - [ ] Only one history state per drag operation
  - [ ] Redraw on every motion event
  - [ ] Works at any zoom and scroll position

- **ID**: FR-1.3 | **Priority**: HIGH
- **Title**: Flood Fill (Area Fill)
- **Description**: User can right-click to flood-fill all connected cells of same density
- **Acceptance Criteria**:
  - [ ] Right-click identifies target density
  - [ ] All connected cells of same type change
  - [ ] Fills stopped by different density type
  - [ ] One history state per fill
  - [ ] Works with any density type

- **ID**: FR-1.4 | **Priority**: MEDIUM
- **Title**: Add Border
- **Description**: Button to automatically add bone border around entire map
- **Acceptance Criteria**:
  - [ ] Clicks Add Border button
  - [ ] All edge cells become "bone"
  - [ ] One history state for entire border
  - [ ] Works for any map size

#### FR-2: Map Navigation
- **ID**: FR-2.1 | **Priority**: HIGH
- **Title**: Zoom Control
- **Description**: User can zoom in/out using scroll wheel
- **Acceptance Criteria**:
  - [ ] Scroll wheel up: zoom increases (max 3.0x)
  - [ ] Scroll wheel down: zoom decreases (min 0.5x)
  - [ ] All elements scale with zoom
  - [ ] Coordinate math accounts for zoom level
  - [ ] Smooth increments (0.1x per wheel notch)

- **ID**: FR-2.2 | **Priority**: HIGH
- **Title**: Pan Control (Middle-Click Drag)
- **Description**: User can middle-click and drag to pan the view
- **Acceptance Criteria**:
  - [ ] Middle-click initiates pan mode
  - [ ] Drag changes scroll_x and scroll_y
  - [ ] Pan works smoothly in all directions
  - [ ] Scroll offset clamped to valid range
  - [ ] View follows drag movement

- **ID**: FR-2.3 | **Priority**: HIGH
- **Title**: Scrollbar Navigation
- **Description**: Horizontal and vertical scrollbars visible and functional
- **Acceptance Criteria**:
  - [ ] Horizontal scrollbar at bottom of canvas
  - [ ] Vertical scrollbar at right of canvas
  - [ ] Click on scrollbar jumps to position
  - [ ] Drag scrollbar thumb for smooth scrolling
  - [ ] Scrollbar size reflects visible ratio
  - [ ] Scrollbars appear only when needed (content > visible)

#### FR-3: Element Placement
- **ID**: FR-3.1 | **Priority**: HIGH
- **Title**: Bloodstream Placement
- **Description**: User can place directional bloodstream arrows on the map
- **Acceptance Criteria**:
  - [ ] Select from 6 direction options (N, S, E, W, N-S, E-W)
  - [ ] Left-click places arrow at grid cell
  - [ ] Cell becomes "medium" density
  - [ ] Arrow displays in selected direction
  - [ ] Arrow color matches simulator (red/orange)
  - [ ] Multiple arrows can exist on same map
  - [ ] Stored in bloodstreams array with direction
  - [ ] Each placement is one history state

- **ID**: FR-3.2 | **Priority**: HIGH
- **Title**: Habitas Point Placement
- **Description**: User can place habitas (scoring) points on the map
- **Acceptance Criteria**:
  - [ ] Click on map to place habitas point
  - [ ] Displays as gold/orange circle
  - [ ] Stored as {"x": grid_x, "y": grid_y}
  - [ ] Multiple habitas points on same map
  - [ ] One history state per placement

- **ID**: FR-3.3 | **Priority**: HIGH
- **Title**: AZN Node Placement
- **Description**: User can place resource (AZN) nodes on the map
- **Acceptance Criteria**:
  - [ ] Click on map to place AZN node
  - [ ] Displays as yellow circle
  - [ ] Default quantity: 30 (or user-configurable)
  - [ ] Stored as {"x": grid_x, "y": grid_y, "quantity": 30}
  - [ ] Multiple nodes on same map
  - [ ] One history state per placement

- **ID**: FR-3.4 | **Priority**: HIGH
- **Title**: Injection Zone Creation
- **Description**: User can drag to create rectangular spawn zones
- **Acceptance Criteria**:
  - [ ] Click and drag to define rectangle
  - [ ] Displays as colored overlay (green/red)
  - [ ] Player 0 = green, Player 1 = red
  - [ ] Stored with corner coordinates (x1, y1, x2, y2)
  - [ ] One history state per zone

#### FR-4: Map Management
- **ID**: FR-4.1 | **Priority**: HIGH
- **Title**: Load Map
- **Description**: User can load existing maps from maps/ directory
- **Acceptance Criteria**:
  - [ ] Load Map button shows list of .json files
  - [ ] Select map from list
  - [ ] Map loads and displays correctly
  - [ ] All elements load (terrain, bloodstreams, points, zones)
  - [ ] View resets (scroll = 0,0, zoom = 1.0)
  - [ ] History cleared, initial state saved
  - [ ] Correct sprites/colors display

- **ID**: FR-4.2 | **Priority**: HIGH
- **Title**: Save Map
- **Description**: User can save current map as JSON file
- **Acceptance Criteria**:
  - [ ] Save Map button exports current state
  - [ ] JSON format matches standard (see Part 4)
  - [ ] All elements included (terrain, bloodstreams, etc)
  - [ ] File saved to user://custom_map.json
  - [ ] Valid JSON structure
  - [ ] Can be loaded back and displays correctly

- **ID**: FR-4.3 | **Priority**: HIGH
- **Title**: Clear Map
- **Description**: User can reset map to empty state
- **Acceptance Criteria**:
  - [ ] Clear button resets all cells to "low"
  - [ ] Removes all elements
  - [ ] One history state for entire clear
  - [ ] Confirmation dialog (optional)

- **ID**: FR-4.4 | **Priority**: MEDIUM
- **Title**: Undo/Redo
- **Description**: User can undo/redo map changes
- **Acceptance Criteria**:
  - [ ] Undo button reverts to previous state
  - [ ] Up to 50 states in history
  - [ ] State includes full grid + all elements
  - [ ] Works for all editing operations
  - [ ] Undo disabled when at oldest state

#### FR-5: Display and Visualization
- **ID**: FR-5.1 | **Priority**: HIGH
- **Title**: Terrain Display with Sprites
- **Description**: Map terrain displays using sprite images or fallback colors
- **Acceptance Criteria**:
  - [ ] tile_low.png displays for low density
  - [ ] tile_medium.png displays for medium
  - [ ] tile_high.png displays for high
  - [ ] tile_bone.png displays for bone
  - [ ] Fallback colors used if sprites missing
  - [ ] All sprites scaled by zoom level
  - [ ] Grid lines visible between tiles

- **ID**: FR-5.2 | **Priority**: HIGH
- **Title**: Bloodstream Arrow Display
- **Description**: Bloodstreams display as directional arrows overlaid on terrain
- **Acceptance Criteria**:
  - [ ] Arrows drawn in red/orange color
  - [ ] Arrow size: 6 pixels * zoom
  - [ ] No background tile color (transparent)
  - [ ] Arrow position: center of tile
  - [ ] Direction clearly indicated (N/S/E/W)
  - [ ] Bidirectional arrows show both directions (N-S, E-W)

- **ID**: FR-5.3 | **Priority**: HIGH
- **Title**: Element Display
- **Description**: All map elements display correctly on canvas
- **Acceptance Criteria**:
  - [ ] Habitas points as gold circles (6px radius)
  - [ ] AZN nodes as yellow circles (4px radius)
  - [ ] Injection zones as colored rectangles (semi-transparent)
  - [ ] All elements scale with zoom
  - [ ] Elements drawn on top of terrain
  - [ ] No overlapping issues

---

### 2. NON-FUNCTIONAL REQUIREMENTS (NFRs)

#### NFR-1: Performance
- **ID**: NFR-1.1 | **Priority**: HIGH
- **Title**: Render Performance
- **Description**: Editor must maintain smooth 60 FPS at normal zoom levels
- **Acceptance Criteria**:
  - [ ] No frame rate drops when panning
  - [ ] Smooth dragging without lag
  - [ ] Zoom operations responsive
  - [ ] 80x80 maps render without performance issues

#### NFR-2: User Interface
- **ID**: NFR-2.1 | **Priority**: HIGH
- **Title**: Layout Proportions
- **Description**: Canvas and panel proportions must match simulator exactly
- **Acceptance Criteria**:
  - [ ] Canvas area exactly 85% of window width
  - [ ] Panel area exactly 15% of window width
  - [ ] Proportions maintained on window resize
  - [ ] No approximations or "close enough"

- **ID**: NFR-2.2 | **Priority**: HIGH
- **Title**: Color Accuracy
- **Description**: All colors must match simulator exactly
- **Acceptance Criteria**:
  - [ ] Bloodstream arrows: RGB(1.0, 0.5, 0.3)
  - [ ] Habitas: RGB(1.0, 0.8, 0.0)
  - [ ] AZN nodes: RGB(1.0, 1.0, 0.0)
  - [ ] All density sprites load and display correctly

#### NFR-3: Data Integrity
- **ID**: NFR-3.1 | **Priority**: HIGH
- **Title**: JSON Format Compliance
- **Description**: Saved maps must be valid JSON compatible with simulator
- **Acceptance Criteria**:
  - [ ] JSON valid and parseable
  - [ ] All required fields present
  - [ ] No extra/corrupt fields
  - [ ] Maps load correctly in simulator
  - [ ] Can round-trip (load, save, load)

---

### 3. USER REQUIREMENTS (User Stories)

#### UR-1: Map Creator
- **Title**: As a map designer, I want to...
  - [ ] Paint terrain to define level layout
  - [ ] Use flood fill for large areas (fast painting)
  - [ ] Place bloodstreams to create flow paths
  - [ ] Mark resource locations with AZN nodes
  - [ ] Define spawn zones for players
  - [ ] Save my maps for use in the game
  - [ ] Load existing maps to modify them
  - [ ] Undo mistakes quickly

#### UR-2: Map Editor
- **Title**: As a map editor tool, I must...
  - [ ] Display maps exactly like the simulator
  - [ ] Provide intuitive controls (click, drag)
  - [ ] Show visual feedback (sprites, colors)
  - [ ] Preserve all map data accurately
  - [ ] Not require external tools (JSON editing)

---

### 4. SYSTEM REQUIREMENTS

#### Hardware Requirements
- **Godot 4.6** or later
- **RAM**: Minimum 2GB (for large map editing)
- **Disk**: Maps directory must be writable
- **Display**: 1024x768 minimum resolution (1920x1080 recommended)

#### Software Requirements
- **Godot Engine**: 4.6.x stable release
- **GDScript**: Strict type inference enabled
- **Assets**: Sprite files in res://assets/tiles/
- **Maps**: Directory res://maps/ with .json files

#### Browser/Platform Support
- **Platforms**: Linux, Windows, macOS (desktop only)
- **No web version** at this time

---

### 5. CONSTRAINTS

#### Technical Constraints
1. **Map Size**: 60x60 to 80x80 tiles (variable)
2. **Tile Size**: Fixed at 16 pixels
3. **Zoom Range**: 0.5x to 3.0x only
4. **History Limit**: Maximum 50 undo states
5. **Element Limits**: No artificial limits (TBD by testing)

#### Design Constraints
1. **Layout**: Must be exactly 85/15 split (no flexibility)
2. **Bloodstreams**: Must be arrows ONLY (no background tiles)
3. **JSON Format**: Must match existing map structure exactly
4. **Sprites**: Must use provided sprite files (or fallback colors)
5. **Coordinate System**: Top-left origin (0,0), x→right, y→down

#### Timeline Constraints
- **Phase 1 (Canvas)**: Priority, must work perfectly before Phase 2
- **Phases 2-5**: Sequential, no parallel work
- **Testing**: Must complete full checklist before release

---

### 6. DEPENDENCIES

#### File Dependencies
- `res://assets/tiles/tile_low.png`
- `res://assets/tiles/tile_medium.png`
- `res://assets/tiles/tile_high.png`
- `res://assets/tiles/tile_bone.png`
- `res://maps/*.json` (existing maps)

#### Code Dependencies
- `MapEditor` script (main implementation)
- `SimpleTeam.tscn` (test map for validation)
- JSON parser (built into Godot)
- FileAccess API (built into Godot)

#### Engine Features Required
- `Control.draw()` for custom rendering
- `InputEvent` handling (mouse, scroll)
- `FileAccess` for file I/O
- `JSON.parse_string()` for data loading
- `Rect2`, `Vector2` for geometry

---

### 7. ACCEPTANCE CRITERIA (Master List)

**Map Editor is DONE when:**

1. ✓ **Layout**: Exactly 85% canvas left, 15% panel right
2. ✓ **Sprites**: All terrain types use actual sprites or fallback
3. ✓ **Bloodstreams**: Red/orange arrows ONLY (no tiles)
4. ✓ **Display**: Matches simulator appearance exactly
5. ✓ **Terrain Editing**: Click, drag, and flood-fill work
6. ✓ **Elements**: Bloodstreams, Habitas, AZN, Zones all editable
7. ✓ **Navigation**: Zoom, pan, scrollbars functional
8. ✓ **Load/Save**: JSON format correct, maps load/save properly
9. ✓ **Undo**: Full history preserved and restorable
10. ✓ **Input Math**: All coordinate conversions pixel-perfect
11. ✓ **Testing**: All items in Part 8 checklist pass
12. ✓ **Performance**: Smooth at 60 FPS, no lag

---

### 8. REQUIREMENT TRACEABILITY MATRIX

| Requirement | Phase | File | Function | Status |
|-------------|-------|------|----------|--------|
| FR-1.1 | 2 | map_editor.gd | _on_canvas_input() | TBD |
| FR-1.2 | 2 | map_editor.gd | _on_canvas_input() + _draw() | TBD |
| FR-1.3 | 2 | map_editor.gd | _flood_fill() | TBD |
| FR-1.4 | 2 | map_editor.gd | _add_border() | TBD |
| FR-2.1 | 1 | map_editor.gd | _on_canvas_input() zoom | TBD |
| FR-2.2 | 1 | map_editor.gd | _on_canvas_input() pan | TBD |
| FR-2.3 | 1 | map_editor.gd | _draw() scrollbars | TBD |
| FR-3.1 | 3 | map_editor.gd | _on_canvas_input() stream | TBD |
| FR-3.2 | 3 | map_editor.gd | _on_canvas_input() habitas | TBD |
| FR-3.3 | 3 | map_editor.gd | _on_canvas_input() azn | TBD |
| FR-3.4 | 3 | map_editor.gd | _on_canvas_input() zones | TBD |
| FR-4.1 | 4 | map_editor.gd | _load_map() | TBD |
| FR-4.2 | 4 | map_editor.gd | _save_map() | TBD |
| FR-4.3 | 2 | map_editor.gd | _clear_map() | TBD |
| FR-4.4 | 2 | map_editor.gd | _undo() | TBD |
| FR-5.1 | 1 | map_editor.gd | _draw() terrain | TBD |
| FR-5.2 | 3 | map_editor.gd | _draw() bloodstreams | TBD |
| FR-5.3 | 3 | map_editor.gd | _draw() elements | TBD |
| NFR-1.1 | All | map_editor.gd | Optimization | TBD |
| NFR-2.1 | 1 | map_editor.gd | Layout | TBD |
| NFR-2.2 | All | map_editor.gd | Colors | TBD |
| NFR-3.1 | 4 | map_editor.gd | _save_map() | TBD |

---

## Current State
The map editor is **not working properly**. Multiple implementation attempts failed because of:
- Rushing to code without understanding simulator layout
- UI layout mismatches with simulator
- Incomplete/broken drawing and input handling
- No clear visual design specifications
- Sprite usage not implemented
- Load/save mechanics undefined

---

## Part 1: Simulator Reference (Ground Truth)

The simulator display is the EXACT reference. The editor must match it completely.

### Overall Layout
```
┌─────────────────────────────────────┬──────────────┐
│ Status Bar (controls info)          │              │
│ Click & drag to paint...            │              │
├─────────────────────────────────────┤              │
│                                     │   Right      │
│                                     │   Panel      │
│   Map Canvas (85% width)            │   (15%)      │
│   - Grid with terrain               │   Legend     │
│   - Bloodstreams as arrows          │   Stats      │
│   - Elements overlaid                │   Controls   │
│                                     │              │
├─────────────────────────────────────┤              │
│ ← → Horizontal Scrollbar            │              │
└─────────────────────────────────────┴──────────────┘
```

### Canvas Display Details

#### Terrain Rendering
- **Grid format**: 16x16 pixel tiles (TILE_SIZE = 16)
- **Sprites used** (from res://assets/tiles/):
  - `tile_low.png` - Pink/salmon color (2 turns movement cost)
  - `tile_medium.png` - Purple color (3 turns movement cost)
  - `tile_high.png` - Dark purple color (4 turns movement cost)
  - `tile_bone.png` - Black/dark color (impassable)
- **Default density**: "low" (entire map starts as low unless specified)
- **Fallback colors** (if sprites missing):
  - low: RGB(0.8, 0.6, 0.6) - pinkish
  - medium: RGB(0.7, 0.5, 0.7) - purple
  - high: RGB(0.5, 0.2, 0.5) - dark purple
  - bone: RGB(0.2, 0.2, 0.2) - dark
- **Grid lines**: Gray outlines on each tile
- **All tiles**: Rendered at (x, y) * TILE_SIZE pixels

#### Bloodstreams
- **Display**: Directional arrows ONLY (no tile background)
- **Color**: RGB(1.0, 0.5, 0.3) - reddish/orange (matches simulator)
- **Arrow size**: 6 pixels scaled by zoom level
- **Directions supported**:
  - `"north"` - Arrow pointing up (↑)
  - `"south"` - Arrow pointing down (↓)
  - `"east"` - Arrow pointing right (→)
  - `"west"` - Arrow pointing left (←)
  - `"ns"` - Two arrows vertical (↕)
  - `"ew"` - Two arrows horizontal (↔)
- **Position**: Center of tile cell
- **Overlay**: Drawn ON TOP of terrain tile (not replacing it)
- **Cell property**: Medium density terrain underneath (always)

#### Habitas Points
- **Display**: Gold/orange diamond shapes
- **Color**: RGB(1.0, 0.8, 0.0) - golden yellow
- **Size**: 6 pixels radius, centered on tile
- **Draw as**: Circle (Godot draw_circle)
- **Number per map**: Usually 2-3 strategic locations

#### AZN Nodes (Resource Nodes)
- **Display**: Yellow circles with quantity indicator
- **Color**: RGB(1.0, 1.0, 0.0) - pure yellow
- **Size**: 4 pixels radius, centered on tile
- **Draw as**: Circle (Godot draw_circle)
- **Data stored**: `{"x": int, "y": int, "quantity": int}`
- **Quantity examples**: 30, 35, 25 (varies by placement)

#### Injection Zones (Spawn Areas)
- **Display**: Rectangular overlay areas
- **Player 0 (friendly)**: RGB(0.0, 1.0, 0.0, 0.2) - semi-transparent green
- **Player 1 (enemy)**: RGB(1.0, 0.0, 0.0, 0.2) - semi-transparent red
- **Format**: Rectangle from (x1, y1) to (x2, y2) inclusive
- **Data stored**: `{"player": 0|1, "x1": int, "y1": int, "x2": int, "y2": int}`
- **Typical zones**: 5x5 tiles at map corners for starting positions
- **Draw as**: Filled rectangle with transparency

### Coordinate System
- **Map dimensions**: Variable (default 60x60 tiles, can be up to 80x80)
- **Origin**: Top-left at (0, 0)
- **Grid cell (x, y)**: 
  - x increases rightward
  - y increases downward
  - Screen position = (x * TILE_SIZE * zoom - scroll_x, y * TILE_SIZE * zoom - scroll_y)
- **Scrolling**: 
  - scroll_x, scroll_y offsets for panning
  - Range: 0 to (total_size - visible_size)

---

## Part 2: Editor UI Design

### Layout Specification

#### Left Panel (Canvas Area - 85% width)
```
┌─────────────────────────────────────┐
│ Status Bar (height: 30px)           │
│ "Click & drag to paint | ..."       │
├─────────────────────────────────────┤
│                                     │
│                                     │
│  Canvas Drawing Area                │
│  (Fills remaining space)            │
│  - Draws terrain grid               │
│  - All elements overlaid            │
│  - Receives all input               │
│                                     │
│                                     │
├─────────────────────────────────────┤
│ ▢━━━━━━━━━━━ Horizontal Scrollbar  │
└─────────────────────────────────────┘
```

#### Right Panel (Controls - 15% width)
```
┌──────────────────┐
│ Map Editor       │ (Title, bold, large)
│ ──────────────── │
│                  │
│ TERRAIN          │ (Section header)
│ ▢ LOW            │ (Button with icon)
│ ▢ MEDIUM         │
│ ▢ HIGH           │
│ ▢ BONE           │
│ ⬜ Add Border    │
│                  │
│ ──────────────── │
│ ELEMENTS         │ (Section header)
│ 🔴 Habitas Points│
│ 🟡 AZN Nodes    │
│ 🟢 Injection Z...│
│ ➡️ Bloodstreams │
│                  │
│ [Stream Direction] (Hidden by default)
│ ↑ North          │
│ ↓ South          │
│ → East           │
│ ← West           │
│ ↕ N-S            │
│ ↔ E-W            │
│                  │
│ ──────────────── │
│ TOOLS            │
│ 📂 Load Map      │
│ 🗑️  Clear        │
│ ↶ Undo           │
│ 💾 Save Map      │
│                  │
│ ← Back to Menu   │
└──────────────────┘
```

### Colors and Styling
- **Background**: Dark gray RGB(0.15, 0.15, 0.15)
- **Text**: White/light gray
- **Button font size**: 11-14px
- **Section headers**: 13px, bold
- **Title**: 16px, bold
- **Panel width**: Exactly 15% of window width
- **Spacing**: 10px between sections

---

## Part 3: Input Interactions

### Mouse Input Handling

#### Left Click (Terrain Mode)
```
Event: InputEventMouseButton (MOUSE_BUTTON_LEFT, pressed=true)
Position: mouse.position (screen coords)
Action:
  1. Convert screen coords to grid coords
  2. Check if in canvas bounds
  3. Paint single cell with selected_density
  4. Add to history
  5. Queue canvas redraw
```

#### Left Click + Drag (Terrain Mode)
```
Event: InputEventMouseMotion (while button held)
Position: mouse.position (screen coords)
Action:
  1. While dragging, paint each tile under cursor
  2. Use Bresenham line algorithm for continuous path
  3. Track previous position to avoid gaps
  4. Queue redraw on each paint
Note: Only one _save_state() at start of drag
```

#### Right Click (Terrain Mode - Flood Fill)
```
Event: InputEventMouseButton (MOUSE_BUTTON_RIGHT, pressed=true)
Position: mouse.position (screen coords)
Action:
  1. Convert to grid coords
  2. Get target density at that cell
  3. Flood fill all connected cells of same density
  4. Replace with selected_density
  5. Add to history
  6. Queue redraw
Algorithm: Stack-based flood fill (BFS or DFS)
```

#### Scroll Wheel (Zoom)
```
Event: InputEventMouseButton (MOUSE_BUTTON_WHEEL_UP/DOWN)
Action:
  - Wheel Up: zoom = min(zoom + 0.1, 3.0)
  - Wheel Down: zoom = max(zoom - 0.1, 0.5)
  - Queue redraw
Result: All canvas elements scale with zoom
```

#### Middle Click (Pan/Drag)
```
Event: InputEventMouseButton (MOUSE_BUTTON_MIDDLE, pressed)
           InputEventMouseMotion (while held)
Action:
  1. On press: store starting position
  2. On motion: calculate delta
  3. Update scroll_x and scroll_y
  4. Clamp to valid ranges
  5. Queue redraw
```

#### Scrollbar Interaction
```
Horizontal Scrollbar (bottom of canvas):
  - Height: 15 pixels
  - Position: y = canvas_height - 15
  - Width: full canvas width
  - Click anywhere: jump scroll_x to that position
  - Drag thumb: smooth scrolling

Vertical Scrollbar (right of canvas):
  - Width: 15 pixels
  - Position: x = canvas_width - 15
  - Height: full canvas height
  - Click anywhere: jump scroll_y to that position
  - Drag thumb: smooth scrolling
```

#### Element Placement (Other Modes)
```
Habitas Mode:
  - Left click: place habitas point at grid cell
  - Stores: {"x": grid_x, "y": grid_y}

AZN Mode:
  - Left click: place AZN node at grid cell
  - Stores: {"x": grid_x, "y": grid_y, "quantity": 30}

Bloodstream Mode:
  - Left click: place arrow in selected direction
  - Direction selected from buttons first
  - Stores: {"x": grid_x, "y": grid_y, "stream": direction}
  - Also sets grid[y][x] = "medium"

Injection Zone Mode:
  - Left click + drag: draw rectangular zone
  - On press: store start position
  - On release: store end position (calculate x1,x2,y1,y2)
  - Stores: {"player": 0, "x1": x1, "y1": y1, "x2": x2, "y2": y2}
  - Player assigned: alternates or selected from UI
```

### Keyboard Input (Optional Enhancements)
- Arrow keys: Pan camera
- Ctrl+Z: Undo
- Ctrl+S: Save
- Ctrl+L: Load
- Del/Backspace: Clear selected element

---

## Part 4: Data Format and Storage

### Map JSON Structure
```json
{
  "name": "Simple Tissue",
  "width": 80,
  "height": 80,
  "default_density": "low",
  "starting_azn": 150,
  "cells": [
    {"x": 5, "y": 8, "density": "high"},
    {"x": 6, "y": 8, "density": "high", "stream": "east"},
    {"x": 7, "y": 8, "density": "high"}
  ],
  "habitas_points": [
    {"x": 2, "y": 2},
    {"x": 77, "y": 77}
  ],
  "azn_nodes": [
    {"x": 40, "y": 40, "quantity": 30},
    {"x": 20, "y": 20, "quantity": 35}
  ],
  "injection_zones": [
    {"player": 0, "x1": 0, "y1": 0, "x2": 4, "y2": 4},
    {"player": 1, "x1": 75, "y1": 75, "x2": 79, "y2": 79}
  ]
}
```

### Load Map Mechanics
```
Function: _load_map(filename: String)
1. Open file: res://maps/{filename}
2. Parse JSON
3. Extract width, height
4. Initialize grid to all "low"
5. For each cell in cells array:
   - Set grid[y][x] = density
   - If stream exists, add to bloodstreams array
6. Copy habitas_points, azn_nodes, injection_zones
7. Reset scroll (0, 0), zoom (1.0)
8. Clear history
9. Save initial state to history
10. Queue redraw
```

### Save Map Mechanics
```
Function: _save_map()
1. Build cells array:
   - For each grid cell != "low":
     - Add {"x", "y", "density"}
     - If bloodstream at this cell, add "stream"
2. Collect all elements:
   - Copy habitas_points
   - Copy azn_nodes
   - Copy injection_zones (with player info)
3. Create map_data object with all fields
4. Convert to JSON string
5. Save to user://custom_map.json
6. Confirmation message
```

### History/Undo System
```
Structure: history = Array of grid states
- Each state is a full copy of grid
- history_index tracks current position
- Max 50 states in history

_save_state():
  - Copy current grid to history
  - Remove any states after current index
  - Add to history
  - Increment history_index
  - If > 50, remove oldest

_undo():
  - If history_index > 0:
    - Decrement history_index
    - Restore grid from history[history_index]
    - Redraw
```

---

## Part 5: Coordinate Calculations

### Screen to Grid Conversion
```
Given: screen_x, screen_y (mouse position)
Given: scroll_x, scroll_y (current pan offset)
Given: zoom (current zoom level, 0.5-3.0)
Given: canvas_offset_x, canvas_offset_y (where canvas starts on screen)

grid_x = (screen_x - canvas_offset_x + scroll_x) / (TILE_SIZE * zoom)
grid_y = (screen_y - canvas_offset_y + scroll_y) / (TILE_SIZE * zoom)

Clamp grid_x to [0, map_width-1]
Clamp grid_y to [0, map_height-1]
```

### Grid to Screen Conversion
```
Given: grid_x, grid_y (map coordinates)
Given: scroll_x, scroll_y (pan offset)
Given: zoom (scale factor)
Given: canvas_offset_x, canvas_offset_y (canvas position)

screen_x = canvas_offset_x + (grid_x * TILE_SIZE * zoom) - scroll_x
screen_y = canvas_offset_y + (grid_y * TILE_SIZE * zoom) - scroll_y
```

### Scrollbar Range Calculations
```
total_width = map_width * TILE_SIZE * zoom
total_height = map_height * TILE_SIZE * zoom
visible_width = canvas_width
visible_height = canvas_height

scroll_x range: 0 to max(0, total_width - visible_width)
scroll_y range: 0 to max(0, total_height - visible_height)

scrollbar_thumb_width = visible_width * (visible_width / total_width)
scrollbar_position_x = scroll_x * (visible_width / total_width)
(Similar for Y axis)
```

---

## Part 6: Implementation Requirements

### Phase 1: Core Canvas (Priority 1)
**Goals**: Get map display working exactly like simulator
- [x] Create 85/15 layout (canvas left, panel right)
- [x] Load and parse map JSON files
- [x] Draw terrain grid with sprites/fallback colors
- [x] Draw all elements (bloodstreams, points, zones)
- [x] Implement zoom (0.5x to 3.0x via scroll wheel)
- [x] Implement pan (middle-click drag)
- [x] Draw scrollbars at bottom/right edges

### Phase 2: Terrain Editing (Priority 2)
**Goals**: Paint terrain and edit basic structure
- [ ] Single click to paint cell
- [ ] Drag to paint multiple cells (with Bresenham line)
- [ ] Right-click to flood fill
- [ ] Undo/Redo with history
- [ ] Add border button functionality
- [ ] Clear map button

### Phase 3: Element Editing (Priority 3)
**Goals**: Place all map elements
- [ ] Bloodstreams: direction selector + click to place (as arrows)
- [ ] Habitas Points: click to place as gold circles
- [ ] AZN Nodes: click to place as yellow circles
- [ ] Injection Zones: click-drag to create rectangles

### Phase 4: Load/Save (Priority 4)
**Goals**: Persist maps and load existing ones
- [ ] Load Map button: show file list, load and display
- [ ] Save Map button: export current state as JSON
- [ ] Validate JSON format before saving
- [ ] Auto-load default map on startup

### Phase 5: Polish (Priority 5)
**Goals**: Professional appearance and UX
- [ ] Status bar with control instructions
- [ ] Scrollbar thumb rendering (visual feedback)
- [ ] Keyboard shortcuts (Ctrl+S, Ctrl+Z, etc.)
- [ ] Error messages and validation
- [ ] Drag visual feedback

---

## Part 7: Critical Technical Details

### Sprites Usage
```
Load from: res://assets/tiles/
- tile_low.png (required)
- tile_medium.png (required)
- tile_high.png (required)
- tile_bone.png (required)

In _load_sprites():
  - Load each sprite
  - If load fails, use fallback colors
  - Store in sprites Dictionary

In _draw():
  - If sprites[density] exists: draw_texture_rect()
  - Else: draw_rect() with fallback color
```

### Bloodstream Rendering (Critical)
```
WRONG (previous attempts):
  - Full cyan background tile
  - Small arrow on top
  - Replaced terrain display

CORRECT (this time):
  - NO background color
  - Overlay arrow on terrain
  - Arrow color: RGB(1.0, 0.5, 0.3)
  - Arrow size: 6 * zoom pixels
  - Draw AFTER terrain so arrow visible on top
```

### Input Math (Critical)
```
MUST account for:
- Canvas position on screen (not always 0,0)
- Scroll offset (pan position)
- Zoom level (all calcs scale by zoom)
- TILE_SIZE constant (16 pixels)

Any error in math causes clicks in wrong cells!
Test with: click at known positions, verify grid_x/grid_y
```

### History Management (Critical)
```
MUST save state BEFORE any modification
- Save on left-click start (terrain)
- Save on right-click (flood fill)
- Save on element placement
- Save on brush drag start

MUST not save on every motion event
- Only save once per logical action
- Motion events just paint and redraw
```

---

## Part 8: Testing Checklist

### Phase 1 Testing
- [ ] Load simple_tissue.json - correct map displays
- [ ] All terrain colors match simulator exactly
- [ ] Bloodstreams show as arrows (not tiles) with correct color
- [ ] Habitas points show as gold circles
- [ ] AZN nodes show as yellow circles
- [ ] Injection zones show as colored rectangles
- [ ] Zoom works: scroll wheel changes scale 0.5x-3.0x
- [ ] Pan works: middle-click drag moves view
- [ ] Scrollbars appear when needed
- [ ] Layout is exactly 85/15 split

### Phase 2 Testing
- [ ] Single left-click paints one cell
- [ ] Drag paints continuous path (no gaps)
- [ ] Right-click fills all connected cells of same density
- [ ] Undo works after each action
- [ ] Add border creates bone border correctly
- [ ] Clear map resets everything

### Phase 3 Testing
- [ ] All element modes selectable from buttons
- [ ] Bloodstream directions selectable (6 options)
- [ ] Click places element at correct grid cell
- [ ] Elements display correctly after placement
- [ ] Multiple elements can coexist on map
- [ ] Injection zones can be drawn by dragging

### Phase 4 Testing
- [ ] Load Map shows available maps
- [ ] Loading displays map exactly as in simulator
- [ ] Save Map creates valid JSON
- [ ] Saved map loads correctly
- [ ] All elements preserved in save/load cycle

### Phase 5 Testing
- [ ] UI looks professional and polished
- [ ] Status bar displays helpful info
- [ ] Keyboard shortcuts work
- [ ] Error handling for invalid inputs
- [ ] No performance issues with large maps

---

## Part 9: Differences from Simulator (Intentional)

The editor is NOT trying to be a full game simulator. Intentional differences:
- No movement simulation
- No turn counter
- No unit control
- No scoring (but shows Habitas points)
- No game state - just map structure

The editor IS trying to match the visualization and layout exactly.

---

## Success Criteria (Hard Requirements)

1. **Layout**: Exactly 85% left, 15% right split ✓
2. **Sprites**: All four terrain types use actual sprite images ✓
3. **Bloodstreams**: Red/orange arrows ONLY, no tile background ✓
4. **Display**: Matches simulator appearance pixel-for-pixel ✓
5. **Load/Save**: JSON format matches existing maps exactly ✓
6. **Input**: All interactions work without coordinate errors ✓
7. **History**: Undo preserves full state reliably ✓
8. **Elements**: All types (habitas, AZN, zones) editable ✓

If any of these fail, the editor is not complete.

---

## Files to Create/Modify

### Primary Files
- `src/ui/map_editor/map_editor.gd` - Complete implementation (all 5 phases)
- `scenes/map_editor_scene.tscn` - Simple layout scene

### Reference Files
- `docs/versioning/v0.0.2/analysis.md` - This document
- `maps/simple_tissue.json` - Test map reference

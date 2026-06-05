# v0.0.2 — Map Editor Implementation Plan

**Status:** Plan (pre-implementation)
**Reference:** [analysis.md](./analysis.md)

---

## 1. Overview

This plan outlines how to implement the map editor based on requirements in `analysis.md`.

**Key principles:**
- Build in phases (core → features → polish)
- Each phase is independently testable
- Dependencies must be resolved in order
- UI consistent with simulator

---

## 2. Core Architecture

### Entry Point
- Scene: `scenes/map_editor_scene.tscn`
- Script: `src/ui/map_editor/map_editor.gd`
- Launches from: Main menu (existing button)

### Major Components

| Component | Purpose | Scope |
|-----------|---------|-------|
| Canvas (Control node) | Displays and handles map editing | Direct _draw() rendering |
| Left Panel | Tool selection and options | VBoxContainer with expandable groups |
| Right Panel | Map info and reference | Legend, statistics, element properties |
| Top Toolbar | File and history operations | HBoxContainer with buttons |
| Scrollbars | Large map navigation | Drawn, not UI elements |
| File System | Load/save maps | FileAccess + JSON |
| History System | Undo functionality | Array of grid snapshots |

### Data Structures

```gdscript
# In-memory map state
grid: Array[Array[String]]                        # grid[y][x] = density
bloodstreams: Array[Dictionary]                  # {x, y, stream: direction}
habitas_points: Array[Dictionary]                # {x, y}
azn_nodes: Array[Dictionary]                     # {x, y, quantity}
injection_zones: Array[Dictionary]               # {player, x1, y1, x2, y2}

# Editor state
selected_tool: String                            # "terrain" | "habitas" | "azn" | "stream" | "zone"
selected_density: String                         # "low" | "medium" | "high" | "bone"
selected_element: Dictionary                     # currently selected element (if any)
history: Array[GridSnapshot]                     # full grid states
zoom: float                                      # 0.5 to 3.0
scroll_x, scroll_y: int                          # pan offset
```

---

## 3. Implementation Phases

### Phase 1: Core Canvas (CRITICAL)
**Goal:** Get map display and basic painting working

**Features:**
1. Load map from JSON
2. Display terrain grid with sprites/fallback colors
3. Single left-click painting
4. Basic zoom (scroll wheel)
5. Pan (middle-click drag)
6. Scrollbars visible

**Deliverables:**
- Map loads and displays correctly
- Can paint single cells
- Zoom/pan work
- Visual feedback (grid, colors)

**Time estimate:** 4-6 hours
**Tests:**
- Load simple_tissue.json, verify display matches simulator
- Paint a cell, verify color changes
- Zoom in/out, verify tile size changes
- Pan with middle-click, verify offset correct

---

### Phase 2: Terrain Tools
**Goal:** Complete terrain editing workflows

**Features:**
1. Multi-cell painting (click + drag with Bresenham line)
2. Flood fill (right-click)
3. Undo/Redo with history
4. Clear map button
5. Add border button
6. Tool selection UI (left panel)

**Deliverables:**
- Left panel with terrain options (LOW, MEDIUM, HIGH, BONE)
- Drag painting works smoothly
- Flood fill fills correctly
- Undo reverts changes
- Clear and border buttons work

**Time estimate:** 4-5 hours
**Tests:**
- Drag paint across 10+ cells in a line, verify continuous
- Right-click on region, verify all connected cells fill
- Undo after fill, verify grid restores
- Add border, verify edge cells are bone

---

### Phase 3: Element Placement
**Goal:** Place all four element types

**Features:**
1. Bloodstreams (with direction selector: N, S, E, W, N-S, E-W)
2. Habitas points (click to place)
3. AZN nodes (click to place)
4. Injection zones (click-drag rectangle)
5. Element selection and properties display
6. Delete selected elements

**Deliverables:**
- Right panel shows legend and element counts
- Can place all element types
- Elements display correctly on canvas
- Can select and modify elements
- Can delete elements

**Time estimate:** 5-6 hours
**Tests:**
- Place bloodstream in each direction, verify arrow displays correctly
- Place habitas point, verify red circle appears
- Place AZN node with quantity, verify yellow circle appears
- Drag to create injection zone, verify rectangle appears
- Click element, verify properties display in right panel
- Delete element, verify it's removed

---

### Phase 4: File Operations
**Goal:** Load, save, and persist maps

**Features:**
1. Load Map button (shows file list)
2. Save Map button (custom filename)
3. Confirmation dialogs (clear, load over unsaved, overwrite)
4. Save validation (warns about missing elements)
5. JSON format matches simulator exactly
6. Round-trip test (load → edit → save → load)

**Deliverables:**
- Load dialog shows available maps
- Can select and load any map
- Can save with custom filename
- Confirmation prevents data loss
- Validation warnings display before save
- Saved maps load in simulator

**Time estimate:** 3-4 hours
**Tests:**
- Load simple_tissue.json, edit, save as new name, load new file
- Verify saved JSON format matches simulator requirement
- Try to clear unsaved map, verify confirmation
- Save map without habitas points, verify warning

---

### Phase 5: Polish & Refinement
**Goal:** Professional appearance and UX

**Features:**
1. Status bar with coordinate display
2. Hover coordinates on cells
3. Visual feedback for current tool
4. Keyboard shortcuts (Ctrl+S, Ctrl+Z, arrow pan)
5. Help/About dialog
6. Better error messages
7. Auto-save functionality (optional)

**Deliverables:**
- Status bar shows current tool and coordinates
- Cursor changes based on mode (crosshair for place, etc.)
- Keyboard shortcuts work
- Help dialog shows all shortcuts
- Error messages are clear and actionable

**Time estimate:** 2-3 hours
**Tests:**
- Hover over cells, verify coordinates display
- Press Ctrl+S, verify save works
- Press Arrow keys, verify pan works
- Click Help, verify shortcuts listed

---

## 4. Implementation Order & Dependencies

```
Phase 1: Core Canvas (no dependencies)
  ├── Load map JSON
  ├── Render grid with sprites
  ├── Single click paint
  ├── Zoom (scroll wheel)
  ├── Pan (middle-click)
  └── Scrollbars

Phase 2: Terrain Tools (depends on Phase 1)
  ├── Multi-cell drag paint
  ├── Flood fill
  ├── History/undo system
  ├── Tool selection UI
  └── Button actions (clear, border)

Phase 3: Elements (depends on Phase 1, Phase 2)
  ├── Bloodstream placement
  ├── Habitas placement
  ├── AZN placement
  ├── Injection zone creation
  ├── Element selection
  └── Element deletion

Phase 4: File Ops (depends on all previous)
  ├── Load dialog
  ├── Save dialog
  ├── Confirmation dialogs
  ├── Validation warnings
  └── JSON persistence

Phase 5: Polish (depends on all previous)
  ├── Status bar
  ├── Coordinate display
  ├── Visual feedback
  ├── Keyboard shortcuts
  └── Help dialog
```

---

## 5. Coordinate System & Math

### Screen to Grid Conversion
```gdscript
grid_x = (screen_x - canvas_x + scroll_x) / (TILE_SIZE * zoom)
grid_y = (screen_y - canvas_y + scroll_y) / (TILE_SIZE * zoom)

# Clamp to map bounds
grid_x = clampi(grid_x, 0, map_width - 1)
grid_y = clampi(grid_y, 0, map_height - 1)
```

### Grid to Screen Conversion
```gdscript
screen_x = canvas_x + (grid_x * TILE_SIZE * zoom) - scroll_x
screen_y = canvas_y + (grid_y * TILE_SIZE * zoom) - scroll_y
```

### Scroll Range
```gdscript
max_scroll_x = max(0, map_width * TILE_SIZE * zoom - canvas_width)
max_scroll_y = max(0, map_height * TILE_SIZE * zoom - canvas_height)

scroll_x = clampi(scroll_x, 0, max_scroll_x)
scroll_y = clampi(scroll_y, 0, max_scroll_y)
```

---

## 6. Key Implementation Details

### Terrain Rendering
- Use sprites if available (res://assets/tiles/tile_*.png)
- Fallback to solid colors if sprites missing
- Always draw grid lines (Color.GRAY)
- Iterate only visible tiles (cull off-screen)

### Bloodstream Display
- Draw as directional arrow (red/orange color)
- Arrow at center of tile
- Arrow size: 6 pixels * zoom
- Overlaid on terrain (drawn after terrain)
- No background tile color

### Element Display
- Habitas: Gold circle (6px radius)
- AZN: Yellow circle (4px radius)  
- Zones: Semi-transparent rectangles (green/red)
- All drawn on top of terrain

### History System
- Save full grid state before each action
- Max 50 states in history
- Undo removes from end, decrements index
- New action after undo clears redo states
- Memory: ~800KB per 60×60 map state

### File Operations
- Load: `FileAccess.open()` + `JSON.parse_string()`
- Save: Build map object + `JSON.stringify()` + `FileAccess.open(..., WRITE)`
- Format: Exactly matches existing map JSON structure
- Validation: Check required fields before save

---

## 7. Testing Strategy

### Unit Tests (per phase)
- Coordinate math: screen↔grid conversion at various zoom/pan
- Flood fill: Connected region detection
- History: State save/restore
- JSON: Round-trip (load → save → load)

### Integration Tests
- Load map → paint → save → load → verify match
- Element placement → selection → modification → save
- Undo chain (multiple actions → undo all → verify initial state)

### Visual Tests
- Load simple_tissue.json, compare to simulator screenshot
- Verify sprite colors match
- Verify bloodstream arrows position and direction
- Verify element positions and appearance

---

## 8. Risk Mitigation

| Risk | Phase | Mitigation |
|---|---|---|
| Coordinate math errors | Phase 1 | Thorough testing, visual debugging |
| Performance lag on large maps | Phase 1-2 | Profile, optimize hot paths |
| JSON format mismatch | Phase 4 | Validate against existing maps |
| Undo state bloat | Phase 2 | Limit to 50 states, memory budget |
| Data loss on crash | Phase 4 | Auto-save every N minutes |
| Confusing UI | Phase 5 | User testing, clear feedback |

---

## 9. File Structure

```
src/ui/map_editor/
├── map_editor.gd              (main script, all logic)
└── (optional) map_editor_ui.gd (separate if UI grows complex)

scenes/
└── map_editor_scene.tscn      (scene layout)

assets/tiles/
├── tile_low.png               (required)
├── tile_medium.png            (required)
├── tile_high.png              (required)
└── tile_bone.png              (required)

maps/
├── simple_tissue.json          (test map)
├── vascular_network.json       (test map)
└── ...

docs/versioning/v0.0.2/
├── analysis.md                (requirements)
└── plan.md                    (this document)
```

---

## 10. Success Metrics

### Phase 1 Complete When
- ✓ simple_tissue.json loads and displays
- ✓ Can paint single cell with left-click
- ✓ Zoom in/out works (0.5x to 3.0x)
- ✓ Pan smooth and correct
- ✓ No crashes or obvious bugs

### Phase 2 Complete When
- ✓ Drag painting works smoothly (Bresenham line)
- ✓ Flood fill fills entire connected region
- ✓ Undo chain works (undo multiple actions in sequence)
- ✓ Tool selection shows in UI
- ✓ Clear and border buttons work

### Phase 3 Complete When
- ✓ All element types placeable
- ✓ Elements display correctly on map
- ✓ Element selection works
- ✓ Can delete elements
- ✓ Right panel shows updated counts

### Phase 4 Complete When
- ✓ Load dialog shows available maps
- ✓ Can load and edit existing maps
- ✓ Save with custom filename works
- ✓ Validation warnings display
- ✓ Saved map loads in simulator without errors

### Phase 5 Complete When
- ✓ Coordinates display on hover
- ✓ Keyboard shortcuts work
- ✓ Visual feedback clear for current tool
- ✓ Help/shortcuts dialog works
- ✓ No remaining usability issues

### Overall Complete When
- ✓ All 15 success criteria from analysis.md met
- ✓ User can create maps in under 5 minutes
- ✓ UI consistent with simulator
- ✓ No crashes or data loss
- ✓ Saved maps work in game

---

## 11. Timeline Estimate

| Phase | Hours | Cumulative |
|-------|-------|-----------|
| Phase 1 | 4-6 | 4-6 |
| Phase 2 | 4-5 | 8-11 |
| Phase 3 | 5-6 | 13-17 |
| Phase 4 | 3-4 | 16-21 |
| Phase 5 | 2-3 | 18-24 |
| **Total** | **18-24 hours** | |

**Note:** Assumes focused work, minimal interruptions, no major bugs requiring rework.

---

## 12. Start Condition

All requirements locked in `analysis.md`. Ready to implement Phase 1.


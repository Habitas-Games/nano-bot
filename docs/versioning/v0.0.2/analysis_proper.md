# Map Editor v0.1 - Proper Analysis & Design

## Executive Summary

The previous attempts at a map editor failed because they tried to copy a game UI (the simulator) into an editor. **Editors and games are fundamentally different tools** with different interaction patterns.

This analysis starts from scratch: What does a GOOD map editor actually look like, and how should it work?

---

## Part 1: What Makes a Good Map Editor?

### Reference: Professional Map Editors
- **Unity**: Hierarchy panel (objects), Inspector panel (properties), Scene view (canvas), Toolbar (tools)
- **Unreal**: Content browser (assets), Details panel (properties), Viewport (canvas), Toolbar (tools)
- **Tiled Map Editor**: Tileset panel (left), Map canvas (center), Properties panel (right), Toolbar (top)
- **Godot Scene Editor**: Scene tree (left), Viewport (center), Inspector (right), Toolbar (top)

### Common Pattern
```
┌──────────────┬─────────────────────┬──────────────┐
│   Tools      │                     │  Properties  │
│   Panel      │   Main Canvas       │  / Info      │
│   (Left)     │   (Center - 70%)    │   (Right)    │
│              │                     │              │
└──────────────┴─────────────────────┴──────────────┘
```

### Key Principles
1. **Canvas dominates** - Takes up most space (70-80%)
2. **Tools are contextual** - Show only what's relevant
3. **Properties are live** - Change shows immediately
4. **Clear selection** - What you're editing is obvious
5. **Visual feedback** - Hover, select, and active states are clear

---

## Part 2: Nano-Bot Map Editor Requirements

### What Are We Editing?
A map is a 2D grid where each cell has:
- **Density** (low, medium, high, bone) - determines movement cost
- **Optional Stream** (north, south, east, west, ns, ew) - directional flow
- **Optional Elements** (habitas point, AZN node) - placed at specific cells
- **Optional Zones** (injection zones) - rectangular areas for player spawns

### What Operations Does the User Need?
1. **Paint terrain** - Click/drag to fill cells with density
2. **Bulk fill** - Right-click to flood-fill region
3. **Place elements** - Click to place single element
4. **Create zones** - Drag to create rectangular areas
5. **Save/Load** - Persist maps
6. **Undo** - Revert mistakes
7. **Navigate** - Zoom and pan large maps

### What Does the User See?
- The map as a grid of tiles
- What density each tile has (via sprites)
- Where elements are placed
- What they're currently editing

---

## Part 3: Proper Editor Layout

### Window Layout (FINAL DESIGN)
```
┌─────────────────────────────────────────────────────┐
│                    TOOLBAR (50px)                   │
│  [Load] [Save] [Clear] | [Undo] | [Zoom] [Pan]    │
├─────────────┬─────────────────────────┬─────────────┤
│   Tools     │                         │  Properties │
│   (20%)     │    Map Canvas (60%)     │    (20%)    │
│             │                         │             │
│   [Terrain] │  Grid display           │ Map Info    │
│   [Elements]│  - Sprites              │ Legend      │
│   [Zones]   │  - Elements overlaid    │ Statistics  │
│   [Stream]  │  - Selection highlight  │             │
│             │  - Scrollbars           │             │
│             │                         │             │
└─────────────┴─────────────────────────┴─────────────┘
```

### Why This Layout?
- **Tools on left**: Standard UI pattern (Unity, Unreal, Godot)
- **Canvas center**: User's main focus
- **Properties right**: Shows what's selected (like simulator legend)
- **Toolbar top**: Global operations (save, undo)

---

## Part 4: Left Tools Panel (20% width)

### Tool Groups (Expandable/Collapsible)

#### Group: TERRAIN
```
[▼ TERRAIN]
  Density: [LOW] [MEDIUM] [HIGH] [BONE]
  
  Actions:
  [✓ Paint (click/drag)]
  [ ] Fill (right-click)
  [⬜ Add Border]
```

**What it does:**
- Select density to paint with
- Toggle paint vs fill modes
- Add border shortcut

**State:**
- One density is always selected (default: LOW)
- Paint mode: left-click paints, right-click fills
- Visual feedback: selected density highlighted

---

#### Group: ELEMENTS
```
[▼ ELEMENTS]
  Element Type: [HABITAS] [AZN] [STREAMS] [ZONES]
  
  [🔴 Habitas Points]
    Info: Click to place
    
  [🟡 AZN Nodes]
    Info: Click to place
    Quantity: [30 ▼]
    
  [➡️ Bloodstreams]
    Direction: [↑N] [↓S] [→E] [←W] [↕NS] [↔EW]
    Click to place arrow
    
  [🟢 Injection Zones]
    Player: [0: Green] [1: Red]
    Click-drag to create zone
```

**What it does:**
- Select element type to place
- Configure element options (quantity, direction, player)
- Click canvas to place selected element

**State:**
- One element type active (or none)
- Options change based on element type
- Visual feedback: cursor changes (crosshair for place)

---

### Right Properties Panel (20% width)

#### Section: Map Info
```
MAP PROPERTIES
──────────────
Map Name: Simple Tissue
Width: 80
Height: 80
Total Cells: 6400

Default Density: Low
Starting AZN: 150
```

#### Section: Legend
```
LEGEND (Color Reference)
────────────────────────
🟨 Low (2 turns to cross)
🟪 Medium (3 turns)
🟩 High (4 turns)
⬛ Bone (impassable)

Elements:
🔴 Habitas Point
🟡 AZN Node  
➡️ Bloodstream
🟢 Injection Zone
```

#### Section: Statistics
```
STATISTICS
──────────
Low cells: 5,658
Medium cells: 234
High cells: 98
Bone cells: 10

Habitas Points: 2
AZN Nodes: 6
Bloodstreams: 28
Injection Zones: 2
```

#### Section: Current Selection (when element selected)
```
SELECTED ELEMENT
────────────────
Type: Bloodstream
Position: (32, 45)
Direction: East
[🗑️ Delete] [Reset]
```

**What it shows:**
- Read-only map reference (like simulator legend)
- Statistics on what's on the map
- Details of currently selected element
- Live-updates as you edit

---

## Part 5: Toolbar (Top, 50px)

### Left Section: File Operations
```
[📂 Load Map ▼] [💾 Save]
```
- Load: Click to open dropdown list of maps
- Save: Exports to user://custom_map.json

### Middle Section: Editing
```
| [🗑️ Clear Map] |
```
- Clears entire map (with confirmation)

### Right Section: History & Navigation
```
| [↶ Undo] [↷ Redo] | [🔍 Zoom] [⊕ Pan] |
```
- Undo/Redo: Navigate history
- Zoom: Shows current zoom level, dropdown for presets
- Pan: Shortcut info (middle-click drag)

---

## Part 6: Canvas (Center, 60% width)

### Display
- **Grid**: 16x16 pixel tiles (TILE_SIZE constant)
- **Terrain**: Sprites or fallback colors
- **Bloodstreams**: Red/orange directional arrows (overlaid on terrain)
- **Elements**: Habitas (gold circles), AZN (yellow circles), Zones (transparent rectangles)
- **Grid lines**: Gray outlines between tiles
- **Selection**: Highlighted cell with yellow border
- **Scrollbars**: Bottom (horizontal) and right (vertical)

### Interactions
```
LEFT-CLICK:
  In Terrain mode: Paint cell with selected density
  In Elements mode: Place selected element type at cell
  In Zones mode: Start drag for zone rectangle

LEFT-CLICK + DRAG:
  In Terrain mode: Paint continuous path (Bresenham line)
  In Zones mode: Draw rectangular zone (shows preview)

RIGHT-CLICK:
  In Terrain mode: Flood-fill connected cells of same density
  Elsewhere: Context menu (copy/delete element if selected)

MIDDLE-CLICK + DRAG:
  Pan the view (scroll_x, scroll_y change)

SCROLL WHEEL:
  Zoom in/out (0.5x to 3.0x, centered on mouse)

HOVER:
  Show grid coordinates in status bar
  Show element info if hovering over element
```

---

## Part 7: Data Model & Persistence

### In-Memory Grid
```gdscript
grid: Array[Array[String]]  # grid[y][x] = "low"|"medium"|"high"|"bone"
```

### Elements (Separate Arrays)
```gdscript
bloodstreams: Array[Dictionary]  # {"x": int, "y": int, "stream": direction}
habitas_points: Array[Dictionary]  # {"x": int, "y": int}
azn_nodes: Array[Dictionary]  # {"x": int, "y": int, "quantity": int}
injection_zones: Array[Dictionary]  # {"player": 0|1, "x1": int, "y1": int, "x2": int, "y2": int}
```

### Save Format
```json
{
  "name": "Simple Tissue",
  "width": 80,
  "height": 80,
  "default_density": "low",
  "starting_azn": 150,
  "cells": [
    {"x": 5, "y": 8, "density": "high"},
    {"x": 6, "y": 8, "density": "medium", "stream": "east"}
  ],
  "habitas_points": [{"x": 2, "y": 2}],
  "azn_nodes": [{"x": 40, "y": 40, "quantity": 30}],
  "injection_zones": [{"player": 0, "x1": 0, "y1": 0, "x2": 4, "y2": 4}]
}
```

---

## Part 8: User Workflows

### Workflow 1: Create New Map
1. Open editor (defaults to blank 60x60 map)
2. Left panel: TERRAIN group, LOW selected
3. Click and drag on canvas to paint low areas
4. Switch to MEDIUM, paint medium areas
5. Add HIGH areas for obstacles
6. Right-click to flood-fill large regions
7. Switch to ELEMENTS, select BLOODSTREAMS
8. Choose direction (East)
9. Click to place bloodstream arrows
10. Add remaining elements
11. Top toolbar: Save button
12. Map saved to user://custom_map.json

### Workflow 2: Edit Existing Map
1. Top toolbar: Load button
2. Select "simple_tissue" from list
3. Map loads and displays
4. Right panel shows statistics
5. Click terrain to see current cell
6. Left panel: TERRAIN group, select new density
7. Paint changes, right panel updates statistics
8. Use Undo (right panel) to revert
9. Save when done

### Workflow 3: Add Elements
1. Map already loaded
2. Left panel: ELEMENTS group, click [🔴 Habitas Points]
3. Cursor becomes crosshair
4. Click on map cells to place
5. Right panel: Statistics shows "+1 Habitas"
6. Switch to [🟢 Injection Zones]
7. Select Player 0 (green)
8. Click and drag on canvas to create rectangular zone
9. Right panel shows zone added

---

## Part 9: Implementation Phases

### Phase 1: Core Canvas & Navigation (CRITICAL)
- [x] 20/60/20 layout
- [x] Load map and display grid
- [x] Terrain sprites or fallback colors
- [x] Left-click zoom
- [x] Scroll wheel zoom (0.5x-3.0x)
- [x] Middle-click pan
- [x] Scrollbars
- [ ] Grid coordinate display on hover
- [ ] Current selection highlight

### Phase 2: Terrain Editing
- [ ] Left-click paint single cell
- [ ] Left-click drag paint continuous
- [ ] Right-click flood-fill
- [ ] Undo/redo history
- [ ] Add Border button
- [ ] Clear Map button
- [ ] Paint mode visual feedback

### Phase 3: Elements
- [ ] Bloodstream arrows (directional)
- [ ] Habitas point placement
- [ ] AZN node placement (with quantity)
- [ ] Injection zone creation (drag)
- [ ] Element selection and info display
- [ ] Delete element (right-click or key)

### Phase 4: Load/Save
- [ ] Load button with file list
- [ ] Save button export JSON
- [ ] Map statistics calculation
- [ ] Data validation

### Phase 5: Polish
- [ ] Status bar with coordinates
- [ ] Cursor changes per mode
- [ ] Zoom presets
- [ ] Pan shortcut help text
- [ ] Confirmation dialogs
- [ ] Error messages

---

## Part 10: Success Criteria

**The editor is DONE when:**

1. ✓ Layout is 20/60/20 split (Tools/Canvas/Properties)
2. ✓ User can paint terrain by selecting density and clicking/dragging
3. ✓ Flood-fill (right-click) works correctly
4. ✓ User can place all element types (bloodstreams, habitas, AZN, zones)
5. ✓ Zoom/pan works smoothly (0.5x to 3.0x)
6. ✓ Load/save works with valid JSON
7. ✓ Undo/redo preserves full state
8. ✓ Properties panel shows map info and statistics live
9. ✓ Display matches simulator appearance (sprites, colors, layout)
10. ✓ All interactions are intuitive (no confusing buttons)
11. ✓ Performance is smooth (60+ FPS)
12. ✓ No "junk" UI - every button/panel serves a clear purpose

---

## What's Different from Previous Attempts

| Old Approach | New Approach |
|---|---|
| Tried to copy simulator UI | Design for editing (not game) |
| Buttons that don't do anything | Every button has one clear purpose |
| All controls in right panel | Tools on left (standard pattern) |
| Right panel was confusing | Right panel is info-only (legend/stats) |
| 85/15 layout (arbitrary) | 20/60/20 layout (proven pattern) |
| No clear mode selection | Group-based tool selection (expandable) |
| Confusing interaction flow | Clear step-by-step workflows |
| Over-engineered | Minimal, purposeful design |

---

## Files Needed

- `src/ui/map_editor/map_editor.gd` - Main implementation
- `scenes/map_editor_scene.tscn` - Scene layout
- `res://assets/tiles/tile_*.png` - Sprite assets (required)
- `res://maps/*.json` - Test maps (reference)

## Next Steps

1. ✓ This analysis is approved
2. Implement Phase 1 based on this design
3. Test and iterate
4. Build phases 2-5 in order
5. Validate against success criteria


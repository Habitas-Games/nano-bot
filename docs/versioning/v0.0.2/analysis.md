# v0.0.2 — Map Editor Analysis

**Status:** Analysis (pre-plan)

---

## 1. Overview

The nano-bot game requires a way to create maps. Currently, maps are hand-crafted JSON files, which is:
- Difficult to visualize
- Error-prone (invalid data, missing elements)
- Time-consuming to modify
- Impossible to preview without loading the simulator

**Purpose of this analysis:** Define what a map editor must do, what constraints exist, and what questions must be answered before implementation.

**Key constraint:** The UI should be consistent with the simulator's visual style and layout, so users recognize the same map format in both the editor and the game.

---

## 2. Problem Statement

### What Is a Map?
A map is a 2D grid where:
- Each cell has a **terrain density** (low, medium, high, bone)
- Some cells have a **bloodstream direction** (north, south, east, west, or bidirectional)
- Elements are placed at specific cells:
  - **Habitas points** (scoring locations)
  - **AZN nodes** (resource locations with quantity)
  - **Injection zones** (rectangular areas where players spawn)

### What's Needed?
A tool that allows a human to:
1. Create a map from scratch
2. Modify existing maps
3. Visualize what they're creating
4. Save the result in a format the game understands
5. Load previously saved maps for editing

### Why Previous Attempts Failed
1. Copied game UI into editor (editors and games are different tools)
2. Buttons didn't do what users expected (unclear interaction model)
3. Layout was arbitrary (85/15 split based on simulator, not editing patterns)
4. No clear workflows (how does a user actually create a map?)
5. Confusion between display and creation (showing arrows vs placing bloodstreams)

---

## 3. Requirements Inventory

### REQ-1: Core Map Editing
The editor must allow users to:
- **REQ-1.1** Select a terrain density (low, medium, high, bone)
- **REQ-1.2** Paint single cells by clicking
- **REQ-1.3** Paint multiple cells by dragging
- **REQ-1.4** Fill connected regions (right-click flood-fill)
- **REQ-1.5** View their changes immediately (no confirmation)

### REQ-2: Element Placement
The editor must allow users to place all map elements:
- **REQ-2.1** Bloodstreams (with directional indication: N, S, E, W, N-S, E-W)
- **REQ-2.2** Habitas points (one per cell)
- **REQ-2.3** AZN nodes (with quantity)
- **REQ-2.4** Injection zones (rectangular areas with player assignment)

### REQ-3: Map Display
The editor must display maps such that:
- **REQ-3.1** Terrain is visible with sprites or fallback colors
- **REQ-3.2** Bloodstreams are shown as directional indicators
- **REQ-3.3** Elements are visually distinct (habitas, AZN, zones)
- **REQ-3.4** Grid structure is clear (tile boundaries visible)
- **REQ-3.5** Visual appearance is consistent with the simulator (same colors, sprites, layout understanding)

### REQ-4: Navigation for Large Maps
The editor must handle maps up to 80×80 tiles:
- **REQ-4.1** Zoom in/out (range 0.5x to 3.0x)
- **REQ-4.2** Pan view (scroll to see different parts)
- **REQ-4.3** Scrollbars visible when needed

### REQ-5: File Operations
The editor must support:
- **REQ-5.1** Load existing maps from res://maps/ directory
- **REQ-5.2** Save current map as JSON file
- **REQ-5.3** Clear map to start over

### REQ-6: Undo/History
The editor must support:
- **REQ-6.1** Undo last action
- **REQ-6.2** Undo works for all operations (painting, placement, fill)
- **REQ-6.3** Keep history of at least 20-50 states

### REQ-7: Data Format
The editor must:
- **REQ-7.1** Use same JSON format as existing maps
- **REQ-7.2** Save valid JSON that the simulator can load
- **REQ-7.3** Support round-trip (load → edit → save → load again)

### REQ-8: User Feedback
The editor must provide feedback:
- **REQ-8.1** Clear indication of what tool is active
- **REQ-8.2** Show what will happen before it happens
- **REQ-8.3** Confirmation for destructive operations (clear, load over unsaved)

---

## 4. Constraints

### Technical Constraints
- **CONST-1:** Built in Godot 4.6 with GDScript
- **CONST-2:** Tile size is fixed at 16 pixels
- **CONST-3:** Maps are 60×60 to 80×80 tiles (not larger)
- **CONST-4:** JSON format must match existing map structure exactly
- **CONST-5:** UI must work on 1024×768 minimum resolution (1920×1080 recommended)

### Scope Constraints
- **CONST-6:** Editor is for creating maps only (not playing games)
- **CONST-7:** No simulation or game mechanics in editor
- **CONST-8:** No network/multiplayer features
- **CONST-9:** Desktop only (not web)

### Design Constraints
- **CONST-10:** UI should be consistent with simulator visual style
- **CONST-11:** Maps created in editor must work exactly like hand-crafted maps
- **CONST-12:** No UI themes or complex styling (keep simple)

---

## 5. Data Model Requirements

### Map Structure (What Gets Saved)
```
Map:
  - name: string
  - width: integer (60-80)
  - height: integer (60-80)
  - default_density: "low"
  - cells: array of
    - x, y: position
    - density: "low" | "medium" | "high" | "bone"
    - stream: (optional) "north" | "south" | "east" | "west" | "ns" | "ew"
  - habitas_points: array of {x, y}
  - azn_nodes: array of {x, y, quantity}
  - injection_zones: array of {player: 0|1, x1, y1, x2, y2}
```

### Runtime State (What Editor Tracks)
- Current grid (terrain density for each cell)
- Current bloodstreams (position + direction)
- Current elements (habitas, AZN, zones)
- Current selection (what's active: terrain type, element type)
- History (previous states for undo)
- View state (zoom level, pan position)

---

## 6. User Workflows

### Workflow A: Create New Map
1. User opens editor (blank 60×60 map)
2. Selects terrain density
3. Clicks/drags to paint terrain
4. Switches to elements
5. Places bloodstreams, habitas points, AZN nodes
6. Creates injection zones
7. Saves map as JSON

### Workflow B: Edit Existing Map
1. User opens editor
2. Uses Load button to select map from list
3. Map displays with all elements
4. Modifies terrain and/or elements
5. Uses Undo if needed
6. Saves changes

### Workflow C: Iterate on Map Balance
1. User creates/loads map
2. Looks at it in simulator (to see how it plays)
3. Returns to editor to adjust
4. Repeats until satisfied

---

## 7. Key Questions (Must Answer Before Planning)

### Q1: UI Layout
What proportion should the map canvas take vs editing controls?
- Option A: 85/15 (canvas/panel) - simulator style
- Option B: 70/30 (canvas/controls) - standard editor style  
- Option C: 60/40 (canvas/controls) - balanced
- **Constraint:** Must feel consistent with simulator

### Q2: Element Editing
Can users modify elements after placing them (e.g., change AZN quantity, delete element)?
- If yes: Need selection, properties panel, delete capability
- If no: Can only place, not edit

### Q3: Validation
Should editor warn users about potential issues (e.g., "no habitas points placed")?
- If yes: What rules to enforce?
- If no: Let users save anything valid JSON

### Q4: Coordinate Display
Should editor show grid coordinates for precision placement?
- If yes: Display on hover or in status bar
- If no: Users place by visual inspection only

### Q5: Map Templates
Should editor offer starting templates (empty, sample layout, etc.)?
- If yes: Which templates?
- If no: Always start blank

---

## 8. Risks

| Risk | Severity | Mitigation |
|---|---|---|
| **Coordinate math errors** - clicks paint wrong cells | High | Thorough testing at various zoom/pan positions |
| **JSON format mismatch** - saved maps don't load in simulator | High | Validate against existing map structure, test round-trip |
| **Performance issues** - large maps lag | Medium | Profile with 80×80 maps, optimize if needed |
| **Undo state bloat** - history consumes too much memory | Low | Limit history to 50 states |
| **Confusing UI** - users don't understand how to use tools | Medium | Clear button labels, status feedback, help text |
| **Data loss** - user unsaved changes lost on crash | Low | Auto-save every N minutes |

---

## 9. Success Criteria

The editor is done when:
1. ✓ User can paint all four terrain densities
2. ✓ User can flood-fill regions with right-click
3. ✓ User can place all element types
4. ✓ User can load existing maps
5. ✓ User can save created maps
6. ✓ Saved maps load and work in simulator
7. ✓ Undo reverts changes correctly
8. ✓ Zoom/pan work smoothly
9. ✓ No crashes or data corruption
10. ✓ UI is consistent with simulator style
11. ✓ User can complete all workflows in under 5 minutes per map

---

## 10. Implementation Dependencies

These must be understood before planning:

| Item | Depends On | Notes |
|---|---|---|
| Terrain painting | Grid rendering, coordinate math | Core feature |
| Element placement | Grid rendering, element arrays | Requires each element type |
| Zoom/Pan | Canvas rendering, scrollbar math | Essential for large maps |
| Save/Load | JSON serialization, file system | Must match simulator format |
| Undo | State snapshots | Must preserve full grid + elements |
| File dialog | Directory listing, map loading | UX: user-friendly selection |

---

## 11. What's NOT in Scope

- ❌ Map validation (checking if map is playable)
- ❌ Import/export to other formats
- ❌ Multiplayer editing
- ❌ Map templates or wizards
- ❌ Terrain automation (procedural generation)
- ❌ Replay/playback of maps
- ❌ Detailed error messages (beyond "save failed")

---

## 12. Open Questions for Planning Phase

Before moving to `plan.md`, these need decisions:

1. **UI Layout Decision** - Which proportion (85/15, 70/30, 60/40)?
2. **Element Editing** - Can users modify after placing?
3. **Validation Rules** - What should editor warn about?
4. **Coordinate Display** - Show grid coords on hover?
5. **Starting State** - Blank only, or offer templates?
6. **Status Feedback** - What information is essential?
7. **Performance Target** - Acceptable FPS and load time?
8. **File Storage** - res://maps/ or user://maps/?


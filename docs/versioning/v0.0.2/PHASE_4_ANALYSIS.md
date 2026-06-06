# Phase 4: Element Placement - Analysis

**Status:** Analysis (requirements based on simulator code review)
**Date:** 2026-06-06

---

## 1. Element Data Structures (From Simulator)

### Habitas Points
```gdscript
habitas_points: Array[Vector2i] = []

# Example: [Vector2i(10, 20), Vector2i(15, 25)]
```

**JSON Format:**
```json
"habitas_points": [
  {"x": 10, "y": 20},
  {"x": 15, "y": 25}
]
```

**Data:** Just position (x, y)  
**Display:** Gold/orange marker on map  
**Usage:** Spawn/home points for nanobots

### AZN Nodes
```gdscript
azn_nodes: Array[Dictionary] = []
# Each: {position: Vector2i, quantity: int}

# Example: [
#   {"position": Vector2i(10, 20), "quantity": 30},
#   {"position": Vector2i(15, 25), "quantity": 50}
# ]
```

**JSON Format:**
```json
"azn_nodes": [
  {"x": 10, "y": 20, "quantity": 30},
  {"x": 15, "y": 25, "quantity": 50}
]
```

**Data:** Position (x, y) + quantity (resource amount)  
**Display:** Yellow circle marker with quantity label  
**Usage:** Resource nodes for collecting during gameplay  
**Default Quantity:** 10 (if not specified)

### Injection Zones
```gdscript
injection_zones: Array[Dictionary] = []
# Each: {player: int, rect: Rect2i}

# Example: [
#   {"player": 0, "rect": Rect2i(5, 5, 11, 11)},   # 5,5 to 15,15
#   {"player": 1, "rect": Rect2i(20, 20, 11, 11)}  # 20,20 to 30,30
# ]
```

**JSON Format:**
```json
"injection_zones": [
  {"x1": 5, "y1": 5, "x2": 15, "y2": 15, "player": 0},
  {"x1": 20, "y1": 20, "x2": 30, "y2": 30, "player": 1}
]
```

**Data:** Rectangle (x1,y1 to x2,y2) + player ID  
**Display:** Semi-transparent colored rectangle (color = player color)  
**Player Colors:** (from HUD.gd)
  - Player 0: Blue (0.25, 0.55, 1.00)
  - Player 1: Red (1.00, 0.30, 0.25)
  - Player 2: Green (0.20, 0.85, 0.40)
  - Player 3: Yellow (1.00, 0.85, 0.15)
**Usage:** Spawn zone for each player's starting nanobots

---

## 2. Design Questions for Phase 4

### HABITAS POINTS (Simplest)

**Current UI (in Phase 2):**
- "Place Habitas" button in Elements section
- Click map to place

**Questions:**
1. Click placement: Should each click place ONE habitas point?
2. Delete: Right-click to delete? Or select + delete button?
3. Feedback: Visual highlight when placing?
4. Multiple: Can place as many as needed?

### AZN NODES (Quantity Parameter)

**Current UI (in Phase 2):**
- "Place AZN" button in Elements section
- Click map to place

**Questions:**
1. Default quantity: Start with 10 (simulator default)?
2. Edit quantity: After placing, how to change it?
   - Option A: Right-click → popup to edit quantity
   - Option B: Click to select → spinner control in panel
   - Option C: Click → drag to set quantity (quantity increases/decreases)
3. Display: Show quantity on marker, or just marker?
4. Delete: Same as habitas (right-click or button)?

### INJECTION ZONES (Rectangle + Player)

**Current UI (in Phase 2):**
- "Place Zone" button in Elements section
- Says "drag to create rectangle"

**Questions:**
1. Player selection: Before or after placing rectangle?
   - Option A: Select player first, then drag rectangle
   - Option B: Drag rectangle first, then select player
2. Drag behavior: Click + drag from corner to corner?
3. Player selector: Dropdown with P0/P1/P2/P3?
4. Display: Colored rectangle overlay for each player?
5. Edit: After placing, can move/resize it?
   - Drag to move?
   - Drag corners to resize?
6. Delete: Right-click or button?

---

## 3. Element Rendering (Current State)

**Phase 2 Implementation:**
- Already displays habitas/AZN/zones during map load
- Uses marker textures: `habitas_neutral.png`, `azn_node.png`
- Uses semi-transparent colored rectangles for zones

**Rendering Code (from map_editor.gd _draw):**
```gdscript
# Draw habitas points
for hp in habitas_points:
    var screen_x = cx + (hp.x * CELL_SIZE * zoom) - scroll_x
    var screen_y = cy + (hp.y * CELL_SIZE * zoom) - scroll_y
    if habitas_texture:
        draw_texture_rect(habitas_texture, Rect2(...), false)

# Draw AZN nodes
for azn in azn_nodes:
    var pos = azn["position"]
    # Same positioning logic
    draw_texture_rect(azn_texture, Rect2(...), false)

# Draw injection zones
for zone in injection_zones:
    var color = Color(...) # based on zone["player"]
    draw_rect(Rect2(...), color)
```

**What Still Needed:**
- Placement UI (buttons/selectors)
- Click detection for placing
- Drag detection for zones
- Quantity editing for AZN
- Player selection for zones
- Delete functionality

---

## 4. Asset Files Available

```
res://assets/markers/habitas_neutral.png    ✓ Exists
res://assets/markers/azn_node.png           ✓ Exists
res://assets/markers/habitas_owned.png      ✓ Exists (unused currently)
```

---

## 5. Current Implementation State

**What Phase 2 Already Has:**
- ✅ Element arrays in memory (habitas_points, azn_nodes, injection_zones)
- ✅ Element rendering during map display
- ✅ Element loading from JSON
- ✅ Placeholder buttons ("Place Habitas", "Place AZN", "Place Zone")
- ✅ Tool mode system (can activate placement modes)

**What Phase 4 Must Add:**
- Input detection for element placement
- Habitas: Single-click placement
- AZN: Single-click placement + quantity management
- Zones: Rectangle drag + player selection
- Delete functionality
- Visual feedback (selection, highlighting)

---

## 6. Summary - Ready for Your Decisions

**Before we plan Phase 4, please decide:**

1. **Habitas:** One click = one point? Delete via right-click or button?
2. **AZN:** Quantity editor approach (popup, spinner, drag)?
3. **Zones:** Player selection before or after rectangle drag?
4. **Zones:** Can resize/move after placement?
5. **Delete:** Consistent method for all element types?
6. **Display:** Show quantity labels on AZN markers?

Once you decide, we'll design and implement Phase 4.

# Editor UI Design Analysis

**Purpose:** Proper analysis of simulator data + terrain selection before implementation
**Status:** Waiting for your design decisions

---

## 1. What We Know from Simulator Code

### Terrain Types and Movement Cost
From `map_data.gd`:

```
Density.LOW:    2 turns (salmon/light color)
Density.MEDIUM: 3 turns (purple color)
Density.HIGH:   4 turns (dark purple)
Density.BONE:   blocked (very dark/black)
```

**Tile Assets Available:**
- `tile_low.png` - Light texture
- `tile_medium.png` - Purple texture
- `tile_high.png` - Dark purple texture
- `tile_bone.png` - Black texture

### Stream Types
From `map_data.gd`:

```
StreamDir.NONE:  No stream
StreamDir.NORTH: Arrow pointing up
StreamDir.SOUTH: Arrow pointing down
StreamDir.EAST:  Arrow pointing right
StreamDir.WEST:  Arrow pointing left
```

Rendering (from `map_renderer.gd`):
- Uses `tile_stream_h.png` for EAST/WEST
- Uses `tile_stream_v.png` for NORTH/SOUTH
- Overlays procedural arrow: Color(0.70, 0.25, 0.25, 0.80)

### Elements
From `map_data.gd`:

```
habitas_points: Array[Vector2i]  # Just position
azn_nodes: Array[{position, quantity}]  # Position + resource amount
injection_zones: Array[{player, rect}]  # Rectangle + player ID
```

Assets:
- `habitas_neutral.png` - Gold/orange marker
- `habitas_owned.png` - Marker with color overlay
- `azn_node.png` - Yellow circle marker

---

## 2. Design Questions for Editor UI

### TERRAIN SELECTION

**Current (Wrong) Implementation:**
```
[LOW]    [MEDIUM]  [HIGH]   [BONE]
```
(Text buttons, no cost info)

**Option A: Visual Tiles + Cost (Recommended)**
```
[tile_image]  [tile_image]  [tile_image]  [tile_image]
  2 turns      3 turns      4 turns       blocked
```
- Button shows actual tile texture
- Label below shows movement cost
- Selected button highlighted

**Option B: Compact (Icon Only)**
```
[tile_16x16] [tile_16x16] [tile_16x16] [tile_16x16]
```
- Just tile icons, no labels
- Smaller UI footprint
- Must remember costs

**Option C: Text Labels (Current)**
```
[LOW] [MEDIUM] [HIGH] [BONE]
```
- Simple to implement
- Requires user memorization
- Less visual

**DECISION NEEDED:** Which terrain selection style do you prefer?

---

### STREAM PLACEMENT

**Current:** Not implemented

**How Should Users Place Streams?**

**Option A: Direction Selector + Click**
1. Select direction (N/S/E/W buttons)
2. Click cell to place stream
3. Visual feedback: arrow appears

**Option B: Click + Direction Menu**
1. Click cell
2. Popup menu for direction
3. Place selected direction

**Option C: Tool Mode**
1. Switch to "Stream Tool"
2. Direction selector visible
3. Click cells with selected direction

**DECISION NEEDED:** How should stream placement work?

---

### ELEMENT PLACEMENT

**Habitas Points:**
- Just click cell to place?
- Delete by right-click?

**AZN Nodes:**
- Click to place at default quantity (30)?
- Popup to set quantity?
- Spin control to adjust?

**Injection Zones:**
- Drag rectangle (current approach)?
- Click two corners?
- Click to place, popup for size?

**Player Assignment (zones):**
- Selector before placement?
- Toggle after placement?

**DECISION NEEDED:** For each element type, how should placement/editing work?

---

### OVERALL EDITOR LAYOUT

**Current:** 
- Left: Terrain buttons (stacked vertically)
- Right: Info panel (200px)
- Canvas: Everything else

**Questions:**
1. Should all terrain buttons fit in right panel, or move to left toolbar?
2. How much space for element selection tools?
3. Should we show element properties panel (select element → edit)?

**DECISION NEEDED:** Overall right panel layout?

---

### UNDO/HISTORY

**Current:** Not implemented

**Options:**
- Undo only (no redo)?
- Undo/Redo?
- Visual history (show recent states)?
- Max undo states (50, 100, unlimited)?

**DECISION NEEDED:** Undo behavior?

---

### VALIDATION WARNINGS

**Current:** Placeholder

**Which Should Trigger Warnings?**
- Missing habitas points?
- Missing AZN nodes?
- Missing injection zones?
- Disconnected terrain regions?
- No streams?

**How Show Warnings?**
- Status bar message?
- Dialog on save?
- Visual highlighting?

**DECISION NEEDED:** Which validation rules matter to you?

---

## 3. What I Did Wrong (Pattern Recognition)

1. **Bloodstreams:** Assumed "full tiles" → checked simulator → actually "texture + arrow"
2. **Input Priority:** Assumed "drag works fine" → checked user feedback → needs exclusive input
3. **Terrain UI:** Assumed "text labels OK" → checked simulator → actually should show tiles + costs

**Pattern:** I made assumptions without examining the simulator first.

**Going Forward:** Every design decision gets documented here with options BEFORE implementation.

---

## 4. Summary

**Before we fix Phase 2 implementation, please decide:**

1. **Terrain Selection Style:** Visual tiles + cost, compact icons, or text labels?
2. **Stream Placement:** Direction selector + click, click + popup, or tool mode?
3. **Element Placement:** Approach for habitas, AZN, zones?
4. **Right Panel Layout:** How to organize all selection tools?
5. **Undo:** Undo only, or undo/redo?
6. **Validation:** Which warnings matter?

**Then:** We'll update the plan, and I'll implement correctly (not patch after).

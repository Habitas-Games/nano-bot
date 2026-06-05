# Cell Types & Map Mechanics

> Complete reference for terrain, streams, and special locations in nano-bot maps.

---

## Cell Density

Every cell has a **density** that determines how many turns it takes a bot to traverse it.

| Density | Turns to cross | Color | Description |
|---------|---|---|---|
| **Low** | 2 | Pink/Light | Most of the map — living tissue |
| **Medium** | 3 | Purple | Denser connective tissue |
| **High** | 4 | Deep Purple | Fibrous, difficult tissue |
| **Bone** | ∞ | Dark/Black | Impassable — blocks all movement |

### Movement cost formula

```
base_cost = density_turns
if moving_with_stream:
    cost = max(1, base_cost - 2)   # −2 bonus, min 1
if moving_against_stream:
    cost = base_cost + 2            # +2 penalty
```

**Example:** Moving through a medium-density cell (3 turns) with an eastbound stream costs:
- With the stream: 1 turn (3 - 2)
- Against the stream: 5 turns (3 + 2)
- No stream: 3 turns

---

## Bloodstreams

Some cells carry a **directional current** that affects movement.

| Direction | Effect | Icon |
|-----------|--------|------|
| **North** | Current flows upward | ↑ |
| **South** | Current flows downward | ↓ |
| **East** | Current flows rightward | → |
| **West** | Current flows leftward | ← |
| **None** | No current | — |

### Strategic use

- **Route planning:** Always move **with** the stream when possible — you can cross 4-turn bone-adjacent cells in just 1 turn with a strong eastbound current.
- **Blocking:** Place static units (**NanoWall**, **NanoBlocker**, **NanoNeedle**) on stream cells to force enemies through slow, against-current paths.
- **Scout paths:** Use **NanoExplorer** (density-immune) to find stream corridors while your collectors use the slow routes.

---

## Special Locations

### Habitas Points

**Purpose:** Scoring objectives. Place a **NanoNeedle** on one to claim it.

- **Appearance:** Gold diamond marker
- **Ownership:** -1 = unoccupied, 0–3 = player ID
- **Scoring:** `20 + 2×azn_stored` per turn (or 5 if empty)
- **Building:** Only NanoAI can build, must be 1 cell away from the point
- **Defense:** Can be attacked and destroyed by enemy NanoCollectors

**Map example (simple_tissue.json):**
```json
{ "x": 12, "y": 12 },   // NE quadrant
{ "x": 37, "y": 37 },   // SW quadrant
{ "x": 25, "y": 5  },   // North
{ "x": 5,  "y": 37 }    // West
```

### AZN Nodes

**Purpose:** Energy sources. Collectors harvest these to fill the bank or feed needles.

- **Appearance:** Green orb
- **Quantity:** Fixed amount (depletes permanently when collected)
- **Collection:** Must be 0 cells away (on the same cell as the node)
- **Transfer limit:** 5 AZN per turn (for any bot using `transfer_to()`)

**Map example (simple_tissue.json):**
```json
{ "x": 8,  "y": 8,  "quantity": 40 },  // High value, near spawn
{ "x": 20, "y": 25, "quantity": 30 },  // Mid-map
{ "x": 35, "y": 15, "quantity": 25 },  // Enemy territory
{ "x": 42, "y": 42, "quantity": 35 }   // Near opponent spawn
```

### Injection Zones

**Purpose:** Player spawn areas and AZN bank access points.

- **Appearance:** Rectangular region (usually 5×5 in corners)
- **Spawning:** Only **NanoAI** spawns here (at the start of the match)
- **Banking:** Any bot can `transfer_to()` its AZN to the bank if inside the zone
- **New injection points:** **NanoIPCreator** can create new zones mid-map with `open_ip()`

**Map example (simple_tissue.json):**
```json
// Player 0 (top-left)
{ "player": 0, "x1": 0,  "y1": 0,  "x2": 4,  "y2": 4  }

// Player 1 (bottom-right)
{ "player": 1, "x1": 45, "y1": 45, "x2": 49, "y2": 49 }
```

---

## Map JSON Structure

```json
{
  "name": "Simple Tissue",
  "width": 50,
  "height": 50,
  "default_density": "low",           // Applied to all cells not in `cells` array
  "starting_azn": 150,                // Initial bank for each player
  
  "cells": [                          // Non-default terrain
    { "x": 10, "y": 5, "density": "high" },
    { "x": 20, "y": 10, "density": "medium", "stream": "east" },
    { "x": 30, "y": 30, "density": "bone" }
  ],
  
  "habitas_points": [                 // Scoring objectives
    { "x": 12, "y": 12 },
    { "x": 37, "y": 37 }
  ],
  
  "azn_nodes": [                      // Resource nodes
    { "x": 8, "y": 8, "quantity": 40 },
    { "x": 20, "y": 25, "quantity": 30 }
  ],
  
  "injection_zones": [                // Spawn areas
    { "player": 0, "x1": 0, "y1": 0, "x2": 4, "y2": 4 },
    { "player": 1, "x1": 45, "y1": 45, "x2": 49, "y2": 49 }
  ]
}
```

---

## Map Design Tips

### Balanced difficulty

- **Asymmetry:** Different terrain for each player creates interesting strategic challenges.
- **Stream advantage:** Offset high-density regions with helpful streams — a 4-turn bone region is passable (barely) if it has a strong east current.
- **AZN placement:** Put high-value nodes in contested mid-map territory to force fights, and easier nodes near spawn to reward early expansion.

### Strategic chokepoints

- **Single stream:** A bottleneck where a stream flows through a high-density zone becomes a speed race — move **with** the current or lose 2+ turns per cell.
- **Blockers:** Enemies can camp a stream cell with a **NanoBlocker** (+6 turns) to completely lock down that path.
- **Wall zones:** A 50-turn **NanoWall** on a high-density stream is nearly impossible to breach immediately.

### Example configurations

```json
// Fast path (reward early scouts)
"cells": [
  { "x": 25, "y": 10, "density": "medium", "stream": "east" },
  { "x": 26, "y": 10, "density": "medium", "stream": "east" }
]

// Slow barrier (defense incentive)
"cells": [
  { "x": 30, "y": 20, "density": "bone" },
  { "x": 30, "y": 21, "density": "bone" },
  { "x": 30, "y": 22, "density": "bone" }
]

// High-value target
"azn_nodes": [
  { "x": 25, "y": 25, "quantity": 50 }  // Center, hard to reach
]
```

---

## See also

- [Participant Guide](participant_guide.html) — bot types, scoring, full API
- [Requirements](requirements.md) — map format specification
- [`maps/simple_tissue.json`](../maps/simple_tissue.json) — default map example

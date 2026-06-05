# Map Design Guide

> Create biologically realistic and strategically interesting nano-bot maps.

---

## New Map: Vascular Network

A **60×60 map** designed to look and play like real tissue with interconnected bloodstreams.

### Layout

```
P0 Spawn        NORTH TISSUE        CENTRAL ARTERY        P1 Spawn
(0,0)────────────────────────────────────────────────────(59,59)
   │              Dense              Medium                │
   │         (High-density)         (Streams)              │
   │                                                        │
WEST          CAPILLARY  ┼  HABITAS POINT    HABITAS   EAST
CAP              │           (Central)        POINT     CAP
│               │                                        │
│         STREAM │         BONE BARRIER                 │
│               │               │                        │
│               │               ▼                        │
└───────────────┼─────────────────────────────────────┘
                │
              SOUTH TISSUE
           (High-density)
```

### Strategic features

**Bloodstream network:**
- **Central artery** (east-west): Fast route connecting both halves, heavily congested
- **North-south capillaries** (4 vertical flow zones): Bypasses for resource transit
- **Directional advantage**: Moving WITH streams saves 2 turns per cell

**Terrain complexity:**
- **High-density tissue clusters** near each spawn: Early-game bottlenecks
- **Bone barrier** mid-map (west side): Forces strategic route choices
- **Scattered medium-density pockets**: Micro-optimization opportunities

**Resource placement:**
- **2 northern AZN nodes** (35 qty each): Positioned above central artery
- **2 southern AZN nodes** (35 qty each): Below central artery
- **Central high-value node** (25 qty): Contested mid-map territory
- **4 Habitas Points**: Corners + diagonals, all equidistant from center

### Gameplay implications

**Early game (turns 1–300):**
- High-density clusters force explorers to clear paths or use streams
- Nearest AZN nodes are on opposite sides of the central artery
- First to claim a corner Habitas Point scores first

**Mid game (turns 300–900):**
- Control of stream corridors becomes critical
- Building NanoBlockers on streams creates hard chokepoints (+6 turns)
- Central AZN node draws both players into conflict

**Late game (turns 900–1500):**
- Accumulation of needles on multiple points
- Defending 2+ needles requires careful blocker placement
- Capable collectors can outmaneuver blockers via alternate streams

---

## Design Principles

### Biological realism

✓ **Arterial flow** — major highways with steady directional flow  
✓ **Capillary network** — smaller branching paths for circulation  
✓ **Fibrous tissue** — dense regions that feel organic, not random  
✓ **Asymmetry with balance** — looks different but plays fair  

### Strategic depth

✓ **Multiple routes** — no single "correct" path forces decision-making  
✓ **Chokepoints** — natural or buildable barriers create engagement  
✓ **Asymmetric resources** — same total value, different access times  
✓ **Escalation points** — zones where map advantages compound  

### Competitive fairness

✓ **Rotational symmetry** — 180° rotation of P0 spawn → P1 spawn  
✓ **Equidistant Habitas Points** — each player has equal claim opportunities  
✓ **Mirrored AZN distribution** — same per-player total, different geography  
✓ **Stream balance** — flowing toward both players equally  

---

## Creating your own map

### Step 1: Define the biological theme

Ask yourself:
- Is this **arterial tissue** (fast highways with flow)?
- Is this **connective tissue** (slow, dense, with obstacles)?
- Is this **neural tissue** (sparse, branching paths)?

### Step 2: Place terrain

```json
{
  "x": 10,
  "y": 20,
  "density": "low|medium|high|bone",
  "stream": "north|south|east|west"  // optional
}
```

**Density distribution rule:** ~70% low (default), ~20% medium, ~10% high, <5% bone.

### Step 3: Add bloodstreams

- Draw **main arteries** (long, unbroken streams) as highways
- Branch into **capillaries** (shorter segments) for navigation choices
- Alternate stream directions (east/west, then north/south) to prevent monotonic routing

### Step 4: Place resources

**AZN nodes:**
- High value (30–40) near difficulty chokes
- Mid value (20–25) in contested zones
- Low value (15) as early-game resources

**Habitas Points:**
- Corner placements: stable, defensible
- Mid-map placement: contested, interesting fights

**Injection zones:**
- 5×5 minimum for safe spawning and regrouping
- Opposite corners for 180° symmetry

### Step 5: Test balance

Simulate in your head:
1. Can P0 reach the nearest AZN node in <8 turns?
2. Does the central artery create natural conflict?
3. Are there 3+ viable routes from spawn to mid-map?
4. Do streams reward risk-taking without breaking the map?

---

## Example maps

| Map | Size | Theme | Difficulty |
|-----|------|-------|-----------|
| **simple_tissue** | 50×50 | Minimal test | Beginner |
| **vascular_network** | 60×60 | Biological arterial | Intermediate |
| **capillary_maze** | 70×70 | Dense, branching | Advanced |
| **cortex_layers** | 80×80 | Stratified tissue | Expert |

---

## Map JSON reference

```json
{
  "name": "Your Map Name",
  "width": 60,
  "height": 60,
  "default_density": "low",        // applied to all unlisted cells
  "starting_azn": 150,             // per-player starting bank
  
  "cells": [
    { "x": 10, "y": 10, "density": "high" },
    { "x": 20, "y": 20, "density": "medium", "stream": "east" },
    { "x": 30, "y": 30, "density": "bone" }
  ],
  
  "habitas_points": [
    { "x": 15, "y": 15 },
    { "x": 45, "y": 45 }
  ],
  
  "azn_nodes": [
    { "x": 20, "y": 30, "quantity": 35 }
  ],
  
  "injection_zones": [
    { "player": 0, "x1": 0,  "y1": 0,  "x2": 5,  "y2": 5  },
    { "player": 1, "x1": 54, "y1": 54, "x2": 59, "y2": 59 }
  ]
}
```

---

## See also

- [Cell Types](CELL_TYPES.md) — density, streams, special locations
- [`maps/vascular_network.json`](../maps/vascular_network.json) — example realistic map
- [`maps/simple_tissue.json`](../maps/simple_tissue.json) — minimal test map

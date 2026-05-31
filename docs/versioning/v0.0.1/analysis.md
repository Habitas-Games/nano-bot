# v0.0.1 — Implementation Analysis

**Status:** Analysis (pre-plan)
**Reference:** [requirements.md](../../requirements.md), [project_nanobot_reference.md](../../project_nanobot_reference.md)

---

## 1. Overview

This document analyses how each system defined in `requirements.md` maps onto Godot 4.x capabilities, identifies the key architectural decisions, and flags risks and open questions that must be resolved before writing `plan.md`.

The platform has three distinct runtime modes that must be supported:

| Mode | Description | Rendering |
|---|---|---|
| **Headless simulation** | Run a match as fast as possible, produce a log | None |
| **Visual playback** | Replay a match log with controls | Full 2D |
| **Tournament** | Run many headless matches, output leaderboard | Optional |

The most important architectural constraint is that the **simulation core must be completely decoupled from rendering**. This determines almost every other decision.

---

## 2. Godot 4 Capabilities Inventory

Before analysing subsystems, these are the engine features directly relevant to this project:

| Feature | Godot 4 API | Fit |
|---|---|---|
| 2D grid rendering | `TileMapLayer` | Good |
| Grid-based A* pathfinding | `AStarGrid2D` | Good — supports per-cell weights |
| Custom A* | `AStar2D` (node-graph) | Available if grid version is insufficient |
| Script loading at runtime | `load("res://path.gd")` → `Script` | Available, no sandbox |
| Threads | `Thread`, `Mutex`, `Semaphore` | Stable in Godot 4 |
| JSON | `JSON.parse_string()`, `JSON.stringify()` | Built-in |
| Timers / timeouts | `Time.get_ticks_msec()` | Available |
| Tweens (animation) | `Tween` | Reliable in Godot 4 |
| Resource system | `.tres` / `.res` files | Not needed for this project |
| Headless mode | `godot --headless` CLI flag | Supported |

---

## 3. Subsystem Analysis

### 3.1 Map System

**Requirements:** MAP-01 through MAP-07

#### Data model
Each cell needs: `density` (enum), `stream_direction` (enum + null), `is_bone` (bool). A flat `Array` of `Dictionary` objects indexed by `y * width + x` is sufficient and fast.

A dedicated `MapData` class (plain `RefCounted`, no Node) holds the grid and exposes helper methods (`get_cell`, `movement_cost_from`, etc.). This class is usable in both headless and visual modes.

#### Loading
Maps are JSON files. Godot's `FileAccess` + `JSON` handle this cleanly. A `MapLoader` singleton parses JSON into a `MapData` instance.

**Proposed JSON structure:**
```json
{
  "name": "Simple Tissue",
  "width": 50,
  "height": 50,
  "cells": [ { "x": 0, "y": 0, "density": "low", "stream": "east" }, ... ],
  "habitas_points": [ { "x": 10, "y": 10 }, ... ],
  "azn_nodes": [ { "x": 5, "y": 5, "quantity": 30 }, ... ],
  "injection_zones": [ { "x1": 0, "y1": 0, "x2": 5, "y2": 5 } ]
}
```

#### Rendering
`TileMapLayer` renders the grid. Each density type and bloodstream state maps to a tile in an atlas. The visual layer reads `MapData` and populates `TileMapLayer` — the simulation never touches `TileMapLayer`.

**Decision:** Cells not listed in JSON default to `density: low, stream: null`. This keeps map files small.

**Risk:** A 200×200 map has 40,000 cells. JSON with full cell listings becomes large (~2–3 MB). Mitigation: only list non-default cells (sparse encoding).

---

### 3.2 Nanobot System

**Requirements:** BOT-01 through BOT-10

#### Data model
Each bot is a `RefCounted` object (`NanoBotData`) with properties: `id`, `type`, `owner_id`, `position`, `hp`, `azn_carried`, `turns_until_move` (for multi-turn movement), `pending_action`.

No `Node` inheritance. This ensures bots exist in headless mode without a scene tree.

In visual mode, a separate `BotSprite` (`Node2D`) mirrors the `NanoBotData` position. The two are linked by `id` but managed independently.

#### Type registry
Bot stats (HP, scan, capacity, build cost in AZN) are defined in a `bot_types.json` data file rather than hard-coded. This satisfies NFR-02 (extensibility).

#### Multi-turn movement
Movement in Movement is not instant — traversing a cell takes 2–4 turns depending on density. The simulation tracks `turns_until_move` per bot. Each simulation tick decrements this counter; only when it reaches 0 does the bot advance one cell and start the next step.

**Decision:** Movement is broken into per-cell steps internally. The strategy API exposes only `move_to(target)` and the engine handles pathfinding and multi-turn execution transparently.

---

### 3.3 Strategy / AI System

**Requirements:** STR-01 through STR-07

This is the **highest-risk subsystem**. Godot 4 does not provide a true scripting sandbox for GDScript.

#### Strategy loading mechanism
```gdscript
var script: Script = load("res://strategies/player_a.gd")
var strategy = script.new()
```
This works and is simple. The loaded script has full access to Godot's engine APIs.

#### Sandboxing options

| Option | Complexity | Security | Feasibility for v1 |
|---|---|---|---|
| **No sandbox — trust participants** | None | None | Yes — acceptable for closed competitions |
| **Validate base class at load time** | Low | Superficial | Yes — catches accidents, not malice |
| **Run strategy in a separate `Thread`** | Medium | None (same process) | Yes — enables timeout enforcement |
| **Run strategy in a separate Godot process** | High | Process isolation | No for v1 |
| **Embed Lua / Wren via GDExtension** | Very high | Good | No for v1 |
| **Custom expression evaluator** | High | Good | No for v1 |

**Recommendation for v1:** Trust participants + base class validation + thread-based timeout. This covers the core use case (closed student competition) without requiring a second language or IPC layer. A comment in the codebase should mark this as the primary upgrade path for v2.

#### Load-time validation
```gdscript
# Check the script inherits NanoStrategy
if not script.get_base_script() == NanoStrategy:
    push_error("Strategy does not extend NanoStrategy")
    return null
```

#### Timeout enforcement
Each call to `what_to_do_next` runs in the main thread but is timed:
```gdscript
var t = Time.get_ticks_msec()
strategy.what_to_do_next(map_info, proxies)
if Time.get_ticks_msec() - t > 50:
    log_warning("Turn forfeited — strategy exceeded 50ms")
    revert_queued_actions(player_id)
```
True preemptive kill is not possible without a thread. A thread-based approach (`Thread.start` + `Semaphore` timeout) is the correct upgrade but adds complexity. For v1 the 50ms log + forfeit is acceptable.

#### BotProxy
`BotProxy` is a thin wrapper around `NanoBotData`. Its action methods push to an `action_queue: Array[ActionRequest]`. The simulation processes this queue after calling all strategies. Crucially, `BotProxy` holds no reference to the scene tree — it is pure data.

---

### 3.4 Simulation Engine

**Requirements:** SIM-01 through SIM-09

#### Architecture
```
SimulationCore (RefCounted)
├── MapData
├── Array[NanoBotData]  — all bots, all players
├── Array[PlayerRecord] — score, strategy ref, injection point
├── Array[MatchLogFrame] — one per turn
└── run_turn() → void
```

`SimulationCore` has no `Node` parent. It can be instantiated from any context.

#### Turn order (SIM-02)
```
for each turn (1..1500):
  1. Decrement turns_until_move for all bots
  2. Advance bots whose counter reached 0 (one cell step)
  3. Resolve AZN collection and transfer
  4. Resolve attacks (by Euclidean range)
  5. Call what_to_do_next on each player strategy
  6. Validate and queue new actions
  7. Append frame to match log
  8. Check end conditions
```

#### Pathfinding — critical analysis (SIM-03)

`AStarGrid2D` supports per-cell weights, which handles **tissue density** directly. Each cell's movement cost is set as its A* weight.

**Problem: bloodstreams.** The movement cost bonus/penalty for bloodstreams is **directional** — it depends on which direction the bot is traveling through the cell, not just the cell itself. Standard A* (including `AStarGrid2D`) assigns a cost to nodes, not to directed edges.

**Options:**

| Option | Accuracy | Complexity |
|---|---|---|
| **Ignore bloodstreams in pathfinding; apply cost correction post-hoc** | Low | Low |
| **Model bloodstream cells as directed edges in `AStar2D`** | High | Medium |
| **Custom A* over the grid with directional edge costs** | High | Medium |
| **Precompute 4 cost grids (one per direction)** | Approximate | Low |

**Recommendation:** Implement a custom `GridPathfinder` class using `AStar2D` (node-graph mode) where each directed edge has an explicit cost. The grid has at most 200×200 × 4 directed edges = 160,000 edges — well within A* performance limits. This is accurate and avoids a later rewrite.

#### Headless mode (SIM-05)
`SimulationCore` has no rendering dependencies, so `godot --headless project.godot -- run_match --strategy_a=foo.gd --strategy_b=bar.gd --map=simple.json` works natively. A dedicated `HeadlessRunner` autoload handles CLI argument parsing and exits with `quit()` after writing the match log.

#### Match log (SIM-06, SIM-07)
Each frame stores:
```gdscript
{
  "turn": int,
  "scores": { "player_id": int, ... },
  "bots": [
    { "id": int, "owner": int, "type": str, "pos": [x, y],
      "hp": int, "azn": int, "action": str }
  ],
  "azn_nodes": [ { "pos": [x, y], "qty": int } ],
  "habitas_points": [ { "pos": [x, y], "owner": int, "azn": int } ],
  "events": [ { "type": "bot_destroyed", "id": int }, ... ]
}
```
1500 turns × ~50 bots ≈ ~75,000 bot records per match. At ~200 bytes/record (JSON) this is ~15 MB uncompressed. For v1 this is acceptable. Delta encoding (storing only changes per turn) is a v2 optimisation.

---

### 3.5 Visual Playback

**Requirements:** VIS-01 through VIS-08

#### Decoupled rendering approach
The visual player does **not** run a live simulation. It reads a pre-recorded match log and steps through frames. This means:
- Playback is always deterministic.
- The visual code is completely decoupled from simulation logic.
- Any match (including headless tournament runs) can be watched later.

#### Scene structure
```
PlaybackScene (Node2D)
├── MapRenderer (Node2D)      ← renders TileMapLayer from MapData
├── BotLayer (Node2D)         ← one BotSprite per bot (pooled)
├── HUD (CanvasLayer)         ← scores, turn counter, bot inspector
└── PlaybackController        ← loads log, drives frame stepping
```

#### Animation
Between frames, bots move one cell at a time. `Tween` handles smooth position interpolation. Speed multiplier scales the tween duration.

At 1× speed, each turn takes ~0.2 seconds → full match plays back in ~5 minutes. At 4× it is ~75 seconds.

#### Bot sprites
Each bot type has a distinct 2D icon. Team color is applied as a `modulate` on the sprite. `BotSprite` nodes are pooled and reused as bots appear and disappear across frames.

---

### 3.6 Tournament Mode

**Requirements:** TRN-01 through TRN-05

#### Round-robin scheduler
For N strategies and M maps, total matches = `N*(N-1)/2 * M`. At N=10, M=3: 135 matches. At N=20, M=3: 570 matches.

Each match runs as a headless `SimulationCore` instance. They can be parallelized using Godot `Thread` objects, with one thread per logical CPU core (queried via `OS.get_processor_count()`).

#### Leaderboard data structure
```gdscript
{
  "strategy": "foo.gd",
  "wins": 5, "losses": 2, "draws": 1,
  "total_points": 1430,
  "avg_points_per_match": 178.75,
  "disqualified": false,
  "dq_reason": ""
}
```

#### DQ handling (TRN-04)
If `load()` fails or the script doesn't extend `NanoStrategy`, the strategy is registered with `disqualified: true` and excluded from matches. It still appears on the leaderboard so it is visible (not silently dropped).

---

## 4. Key Architectural Decisions

| Decision | Choice | Rationale |
|---|---|---|
| **Simulation/rendering split** | `SimulationCore` is pure `RefCounted`, no Node | Enables headless mode; testability |
| **Bot representation** | Data objects (`RefCounted`), not Nodes | Bots can exist without a scene tree |
| **Pathfinding** | Custom `GridPathfinder` over `AStar2D` with directed edge costs | Required for accurate bloodstream handling |
| **Strategy loading** | Runtime `load()` + base class check + timing | Simplest approach viable for closed competitions |
| **Match log** | Full snapshot per turn (JSON) | Simple to implement; delta encoding deferred to v2 |
| **Visual playback** | Log-replay only, not live simulation | Decoupling; any match can be replayed |
| **Tournament parallelism** | Thread pool, one match per thread | Uses multi-core hardware; Godot 4 threads are stable |

---

## 5. Risks

| # | Risk | Severity | Mitigation |
|---|---|---|---|
| R1 | **No real sandbox for GDScript** — a malicious strategy can call any engine API | High | Acceptable for closed competitions (trusted participants). Mark as v2 upgrade. |
| R2 | **Bloodstream directional pathfinding** — standard `AStarGrid2D` cannot model it correctly | High | Use `AStar2D` in directed-graph mode from the start |
| R3 | **Match log file size** — 15 MB per match becomes a problem in large tournaments | Medium | Delta encoding in v2; for v1 cap match log at 50×50 maps |
| R4 | **Strategy timeout enforcement** — 50ms wall-clock check is not preemptive | Medium | Acceptable for v1; thread-based preemption is the v2 path |
| R5 | **Performance on large maps** — 200×200 with many bots + A* per turn may be slow | Medium | Profile early with stress test; optimise hot paths if needed |
| R6 | **GDScript runtime errors in strategies** — uncaught errors propagate upward | Low | Wrap `what_to_do_next` in a `try/except`-equivalent; in GDScript use `call()` + error checking |

---

## 6. Open Questions for plan.md

These need to be decided before implementation begins:

1. **Map format:** Store cells as a flat array indexed by position, or as a 2D nested array? (Affects JSON size and GDScript indexing ergonomics.)

2. **Bot build cost:** Should AZN build costs be defined per map (allowing map designers to balance) or globally in `bot_types.json`?

3. **NanoAI death rule:** Requirements say "all bots skip actions." Does this mean they stop moving mid-path too, or only stop receiving new orders?

4. **Bloodstream scope:** Should bloodstreams affect allied and enemy bots equally, or only the moving player's bots?

5. **Scoring granularity:** Should partial AZN deposits (e.g., NanoNeedle with 3 AZN) score partial points, or only full deposits?

6. **Grid size for v1:** `requirements.md` says 50×50 default. Should v0.0.1 hard-code this to reduce scope, or implement the configurable loader from day one?

7. **Strategy API stability:** Once defined, the `NanoStrategy` base class API must not change between competition rounds (breaking participant code). Should this be locked before M1 or M2?

8. **Replay storage:** Should replays be auto-saved to `replays/` after every match, or only on explicit user request?

---

## 7. Recommended Implementation Order

Based on the dependency graph between subsystems:

```
1. MapData + MapLoader            (no dependencies)
2. GridPathfinder                 (depends on MapData)
3. NanoBotData + type registry    (no dependencies)
4. SimulationCore                 (depends on 1, 2, 3)
5. NanoStrategy base + BotProxy   (depends on 3, 4)
6. HeadlessRunner + match log     (depends on 4, 5)
7. MapRenderer + BotSprite        (depends on 1, 3)
8. PlaybackController             (depends on 6, 7)
9. HUD                            (depends on 8)
10. TournamentRunner              (depends on 5, 6)
11. LeaderboardUI                 (depends on 10)
```

Steps 1–6 are pure logic and can be developed and unit-tested without opening the Godot editor. Steps 7–11 are the visual layer.

# v0.0.1 — Implementation Plan

**Status:** Plan (pre-implementation)
**Depends on:** [analysis.md](analysis.md), [requirements.md](../../requirements.md)

---

## 1. Resolved Decisions

The following open questions from `analysis.md` §6 are resolved here before implementation begins.

| # | Question | Decision |
|---|---|---|
| OQ1 | Map cell storage format | Flat `Array` indexed by `y * width + x`. JSON uses **sparse encoding** — only non-default cells are listed; missing cells default to `{density: low, stream: null}`. |
| OQ2 | Bot build cost location | Defined globally in `data/bot_types.json`; per-map overrides allowed via an optional `"bot_costs"` key in the map JSON. |
| OQ3 | NanoAI death rule | Bots complete their current movement step (turn counter drains to zero) but receive **no new orders** for the rest of the match. |
| OQ4 | Bloodstream symmetry | Bloodstreams affect **all bots equally** — allied and enemy. Symmetric and fair. |
| OQ5 | Partial AZN scoring | Partial deposits **do score** — `20 + 2 × azn_stored` applies to any NanoNeedle with AZN > 0 on a Habitas Point. |
| OQ6 | Grid size scope | Configurable loader from day one; v0.0.1 ships with **50×50 as default**. Hard-coded size is not introduced. |
| OQ7 | Strategy API lock | API is locked (no breaking changes) after M2 is complete and validated with the example strategy. |
| OQ8 | Replay auto-save | Replays are **auto-saved** to `replays/` after every match with filename `match_YYYY-MM-DD_HH-MM-SS_<playerA>_vs_<playerB>.json`. |

---

## 2. Project Structure

```
nano-bot/
├── project.godot
├── docs/
│   ├── requirements.md
│   ├── project_nanobot_reference.md
│   └── versioning/
│       └── v0.0.1/
│           ├── analysis.md
│           └── plan.md              ← this file
│
├── data/
│   └── bot_types.json               ← stat budgets and build costs per type
│
├── maps/
│   ├── simple_tissue.json
│   ├── river_crossing.json
│   └── bone_maze.json
│
├── strategies/
│   └── example_strategy.gd          ← starter strategy for participants
│
├── replays/                          ← auto-saved match logs (gitignored)
│
├── assets/
│   └── sprites/
│       └── bots/                     ← one icon per bot type
│
└── src/
    ├── core/                         ← M1: pure simulation, no rendering
    │   ├── map_data.gd
    │   ├── map_loader.gd
    │   ├── grid_pathfinder.gd
    │   ├── nanobot_data.gd
    │   ├── bot_type_registry.gd
    │   ├── action_request.gd
    │   ├── match_log.gd
    │   └── simulation_core.gd
    │
    ├── api/                          ← M2: strategy-facing public interface
    │   ├── nano_strategy.gd
    │   ├── bot_proxy.gd
    │   ├── map_info.gd
    │   ├── cell_info.gd
    │   ├── habitas_point_info.gd
    │   └── azn_node_info.gd
    │
    ├── runner/                       ← M2: headless entry point
    │   └── headless_runner.gd
    │
    ├── ui/                           ← M3: visual playback
    │   ├── playback/
    │   │   ├── playback_scene.tscn
    │   │   ├── playback_controller.gd
    │   │   ├── map_renderer.gd
    │   │   ├── bot_sprite.gd
    │   │   └── hud.gd
    │   └── main_menu/
    │       ├── main_menu.tscn
    │       └── main_menu.gd
    │
    └── tournament/                   ← M4: tournament runner and leaderboard
        ├── tournament_runner.gd
        ├── leaderboard.gd
        └── ui/
            ├── tournament_ui.tscn
            └── tournament_ui.gd
```

---

## 3. Data Files

### `data/bot_types.json`
```json
{
  "NanoAI":        { "hp": 20, "scan": 5,  "capacity": 0,   "transfer": 0, "max_damage": 0,  "attack_range": 0,  "build_cost": 0   },
  "NanoExplorer":  { "hp": 20, "scan": 30, "capacity": 0,   "transfer": 0, "max_damage": 0,  "attack_range": 0,  "build_cost": 15,  "density_immune": true },
  "NanoCollector": { "hp": 50, "scan": 0,  "capacity": 20,  "transfer": 5, "max_damage": 5,  "attack_range": 12, "build_cost": 20  },
  "NanoContainer": { "hp": 60, "scan": 0,  "capacity": 60,  "transfer": 5, "max_damage": 0,  "attack_range": 0,  "build_cost": 25  },
  "NanoNeedle":    { "hp": 150,"scan": 0,  "capacity": 100, "transfer": 0, "max_damage": 0,  "attack_range": 0,  "build_cost": 40,  "stationary": true },
  "NanoIPCreator": { "hp": 20, "scan": 30, "capacity": 0,   "transfer": 0, "max_damage": 0,  "attack_range": 0,  "build_cost": 30,  "self_destruct_turns": 500 },
  "NanoBlocker":   { "hp": 90, "scan": 0,  "capacity": 0,   "transfer": 0, "max_damage": 0,  "attack_range": 0,  "build_cost": 20,  "traversal_penalty": 6 },
  "NanoWall":      { "hp": 100,"scan": 0,  "capacity": 0,   "transfer": 0, "max_damage": 0,  "attack_range": 0,  "build_cost": 25,  "auto_destruct_turns": 50 }
}
```

### Map JSON (sparse cell format)
```json
{
  "name": "Simple Tissue",
  "width": 50, "height": 50,
  "default_density": "low",
  "cells": [
    { "x": 10, "y": 5,  "density": "high" },
    { "x": 10, "y": 6,  "density": "high", "stream": "east" },
    { "x": 25, "y": 25, "density": "bone" }
  ],
  "habitas_points": [ { "x": 10, "y": 10 }, { "x": 40, "y": 40 } ],
  "azn_nodes":       [ { "x": 5,  "y": 5,  "quantity": 30 } ],
  "injection_zones": [
    { "player": 0, "x1": 0,  "y1": 0,  "x2": 5,  "y2": 5  },
    { "player": 1, "x1": 44, "y1": 44, "x2": 49, "y2": 49 }
  ]
}
```

---

## 4. Milestones

### M1 — Core Engine

**Goal:** A working headless simulation with no strategy input — bots do nothing, but the map loads, turns tick, and a valid match log is produced.

| Task | File | Notes |
|---|---|---|
| M1-T01 | `src/core/map_data.gd` | `RefCounted`. Holds flat `Array[Dictionary]` for cells. Methods: `get_cell(x,y)`, `movement_cost(from, to)` (accounts for density + bloodstream direction), `is_passable(x,y)`. |
| M1-T02 | `src/core/map_loader.gd` | `RefCounted`. `load_from_file(path) -> MapData`. Parses JSON, applies sparse cell format, validates required fields. Returns null on error with `push_error`. |
| M1-T03 | `src/core/grid_pathfinder.gd` | `RefCounted`. Wraps `AStar2D`. On construction from `MapData`, builds directed-edge graph: for each cell pair (N/S/E/W neighbors), adds edge with cost = `movement_cost(from, to)`. Method: `find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]`. |
| M1-T04 | `src/core/nanobot_data.gd` | `RefCounted`. Properties: `id`, `owner_id`, `type` (String), `position` (Vector2i), `hp`, `azn_carried`, `turns_until_move`, `path_remaining` (Array[Vector2i]), `is_alive`, `pending_action` (ActionRequest). |
| M1-T05 | `src/core/bot_type_registry.gd` | Autoload. Loads `data/bot_types.json` at startup. Method: `get_type(name: String) -> Dictionary`. |
| M1-T06 | `src/core/action_request.gd` | `RefCounted`. Properties: `action_type` (enum), `target_position`, `build_type`. Enum values: `MOVE`, `COLLECT`, `TRANSFER`, `DEFEND`, `BUILD`, `OPEN_IP`, `STOP`, `SELF_DESTRUCT`. |
| M1-T07 | `src/core/match_log.gd` | `RefCounted`. Holds `Array[Dictionary]` of frames. Methods: `record_frame(turn, bots, azn_nodes, habitas_points, scores, events)`, `save_to_file(path)`, `load_from_file(path) -> MatchLog`. |
| M1-T08 | `src/core/simulation_core.gd` | `RefCounted`. Constructor takes `MapData`, `Array[String]` strategy paths, optional seed. Method: `run() -> MatchLog`. Implements turn loop (§3.4 of analysis). For M1, strategies are null — bots take no actions. |

**M1 acceptance test:** Call `SimulationCore.new(map, [], 0).run()` from a test scene. Confirm a 1500-frame `MatchLog` is produced with two static NanoAI bots alive at turn 1500.

---

### M2 — Strategy API

**Goal:** Participants can write a `.gd` strategy file that controls bots. The example strategy runs, bots move, collect AZN, and place NanoNeedles. Match logs record correct scores.

| Task | File | Notes |
|---|---|---|
| M2-T01 | `src/api/cell_info.gd` | Read-only `RefCounted` wrapping one cell from `MapData`. Properties: `position`, `density`, `stream_direction`, `is_bone`. |
| M2-T02 | `src/api/map_info.gd` | Read-only view passed to the strategy each turn. Properties: `size`, `turn`, `habitas_points` (Array[HabitasPointInfo]), `azn_nodes` (Array[AZNNodeInfo]), `visible_enemies` (Array[Dictionary]). Method: `get_cell(x,y) -> CellInfo`. Built from current `SimulationCore` state each turn. |
| M2-T03 | `src/api/bot_proxy.gd` | Wraps `NanoBotData`. Exposes read-only properties + action methods. Each action method pushes an `ActionRequest` onto an internal queue. Multiple calls: last call wins (queue of 1). |
| M2-T04 | `src/api/nano_strategy.gd` | Base class (`RefCounted`). Two virtual methods: `choose_injection_point(map_info: MapInfo) -> Vector2i` and `what_to_do_next(map_info: MapInfo, my_bots: Array) -> void`. Default implementations return `Vector2i.ZERO` and do nothing. |
| M2-T05 | `src/core/simulation_core.gd` | Extend M1 implementation: load strategies via `load()`, validate base class, call `choose_injection_point` once, call `what_to_do_next` each turn with timing budget enforcement (50 ms wall clock). Process `ActionRequest` queues after all strategies run. |
| M2-T06 | `src/runner/headless_runner.gd` | Autoload active only in headless mode. Parses CLI args (`--map`, `--strategy_a`, `--strategy_b`). Runs `SimulationCore`, saves match log, calls `quit()`. |
| M2-T07 | `strategies/example_strategy.gd` | Demonstrates: choosing injection point, building a NanoExplorer, moving toward a Habitas Point, building a NanoNeedle, collecting and transferring AZN. Must be a valid v0.0.1 participant starting point. |

**Turn execution order inside `simulation_core.gd`:**
```
for turn in range(1, 1501):
    _decrement_move_timers()
    _advance_bots_one_step()       # bots whose timer hit 0
    _resolve_azn_transfers()
    _resolve_attacks()
    _call_strategies()             # timed; forfeit on timeout or error
    _apply_action_queues()
    _check_nano_ai_death()
    _update_scores()
    _match_log.record_frame(...)
    if _check_end_conditions():
        break
```

**M2 acceptance test:** Run `example_strategy.gd` vs itself on `simple_tissue.json`. Both bots must reach a Habitas Point and score > 0 by turn 1500. Match log must contain correct score history.

---

### M3 — Visual Playback

**Goal:** Load any match log and watch it play back in a 2D scene with controls and HUD.

| Task | File | Notes |
|---|---|---|
| M3-T01 | `src/ui/playback/map_renderer.gd` | Reads `MapData`, populates a `TileMapLayer` child. Density → tile type. Stream cells get an overlay arrow sprite (not a tile, to keep tile atlas simple). |
| M3-T02 | `src/ui/playback/bot_sprite.gd` | `Node2D` child. Properties: `bot_id`, `owner_color`, `bot_type`. Sets icon texture + modulate. `animate_to(cell: Vector2i, duration: float)` drives a `Tween`. |
| M3-T03 | `src/ui/playback/playback_controller.gd` | Owns the `MatchLog`. Methods: `play()`, `pause()`, `step_forward()`, `step_back()`, `set_speed(float)`. Each frame: diffs current vs next log entry, issues `animate_to` on affected `BotSprite` nodes, updates HUD. |
| M3-T04 | `src/ui/playback/hud.gd` | `CanvasLayer`. Shows: turn counter, score per player, bots alive per player. Bot inspector panel appears on click. |
| M3-T05 | `src/ui/playback/playback_scene.tscn` | Assembles `MapRenderer`, `BotLayer` (Node2D container), `HUD`, `PlaybackController`. |
| M3-T06 | `src/ui/main_menu/main_menu.tscn` | Simple launcher: "Run Match", "Load Replay", "Tournament". "Run Match" runs sim headlessly, auto-saves log, then opens `PlaybackScene` with the result. |

**Cell → pixel coordinate:**
```gdscript
const CELL_SIZE = 16  # pixels per cell
func cell_to_pixel(cell: Vector2i) -> Vector2:
    return Vector2(cell.x * CELL_SIZE + CELL_SIZE / 2,
                   cell.y * CELL_SIZE + CELL_SIZE / 2)
```

**Bot sprite pool:** Pre-instantiate a pool of `BotSprite` nodes at scene load. Assign from pool when a bot appears; return to pool when destroyed. Avoids mid-match `instance()` calls.

**M3 acceptance test:** Load the M2 match log. Press Play — bots animate across the map. HUD scores update each turn. Pause and step forward/back — both work correctly. Speed 4× completes the replay in reasonable time.

---

### M4 — Tournament Mode

**Goal:** Drop N `.gd` strategy files in `/strategies`. Press "Tournament" — all strategies play each other on all maps. Leaderboard exported.

| Task | File | Notes |
|---|---|---|
| M4-T01 | `src/tournament/tournament_runner.gd` | `RefCounted`. `run(strategy_paths: Array[String], map_paths: Array[String]) -> LeaderboardData`. Builds match schedule (round-robin × maps). Runs matches in a thread pool (`OS.get_processor_count()` threads). Collects results. |
| M4-T02 | `src/tournament/leaderboard.gd` | `RefCounted`. Accumulates `MatchResult` objects. Computes wins/losses/draws/total_points/avg_score per strategy. Marks DQ entries. `save_to_file(path)` exports JSON. |
| M4-T03 | `src/tournament/ui/tournament_ui.gd` | Launches `TournamentRunner` in a background thread. Shows progress bar (matches completed / total). On completion, renders leaderboard table and highlights top 3. "Watch Match" button opens `PlaybackScene` for any logged match. |

**Thread safety:** `SimulationCore` is a `RefCounted` with no shared mutable state except the `MatchLog` it owns. Each thread gets its own `SimulationCore` instance → no mutex needed during simulation. Leaderboard accumulation uses a `Mutex`.

**M4 acceptance test:** Place 4 strategy files (3 variants of `example_strategy`, 1 broken file) in `/strategies`. Run tournament on 2 maps. Confirm: 12 matches run (`C(3,2) × 2 maps + C(3,1) × 2 maps` for valid strategies), broken strategy appears on leaderboard as DQ, JSON exports correctly.

---

### M5 — Polish & Packaging

| Task | Notes |
|---|---|
| 3 shipped maps | `simple_tissue.json` (50×50, minimal obstacles), `river_crossing.json` (50×50, prominent bloodstreams), `bone_maze.json` (50×50, heavy bone walls) |
| Bot sprites | 8 distinct icons, one per bot type, 16×16px |
| Participant guide | `docs/participant_guide.md` — how to write a strategy, API reference, how to test locally |
| Error messages | All load-time strategy errors include the file name and line number |
| Godot export | Linux + Windows + macOS export presets configured |

---

## 5. Class Responsibility Summary

| Class | Layer | Responsibility |
|---|---|---|
| `MapData` | Core | Holds grid state; computes movement costs |
| `MapLoader` | Core | Parses JSON → `MapData` |
| `GridPathfinder` | Core | A* on directed cost graph built from `MapData` |
| `NanoBotData` | Core | All mutable bot state |
| `BotTypeRegistry` | Core | Loads and serves `bot_types.json` |
| `ActionRequest` | Core | Immutable action descriptor queued by `BotProxy` |
| `MatchLog` | Core | Frame recorder; serialise/deserialise JSON |
| `SimulationCore` | Core | Turn loop; owns map + bots; calls strategies |
| `NanoStrategy` | API | Base class participants extend |
| `BotProxy` | API | Read-only bot view + action queue for strategies |
| `MapInfo` | API | Read-only map view rebuilt each turn |
| `HeadlessRunner` | Runner | CLI entry point; orchestrates one match |
| `MapRenderer` | UI | `TileMapLayer` population from `MapData` |
| `BotSprite` | UI | Animated `Node2D` per bot |
| `PlaybackController` | UI | Steps through `MatchLog`; drives animation |
| `HUD` | UI | Scores, turn, bot inspector |
| `TournamentRunner` | Tournament | Thread pool; round-robin schedule |
| `Leaderboard` | Tournament | Accumulates results; exports JSON |

---

## 6. Implementation Rules

These apply to all code written in this version:

1. **No cross-layer imports.** `src/core/` files must never `load` or reference anything in `src/ui/` or `src/tournament/`.
2. **No Node in core.** Every class in `src/core/` and `src/api/` extends `RefCounted`. No `Node`, `Node2D`, or scene-tree dependencies.
3. **No magic numbers.** All tunable constants (cell size, turn limit, timeout budget) live in a single `const` block at the top of the owning class.
4. **Strategies are untrusted input.** Every call into a strategy is wrapped in error handling. A crash inside a strategy forfeits the turn; it never propagates to `SimulationCore`.
5. **Match log is the source of truth for playback.** The visual layer never re-runs simulation logic. It only reads frames from `MatchLog`.

---

## 7. Milestone Schedule

```
M1 — Core Engine          ████████░░░░░░░░░░░░
M2 — Strategy API                 ████████░░░░░░░░░░░░
M3 — Visual Playback                      ████████████░░░░
M4 — Tournament                                   ████████
M5 — Polish & Packaging                               ████
```

Each milestone begins only after the previous milestone's acceptance test passes. M1 and M2 are the critical path — everything else builds on them.

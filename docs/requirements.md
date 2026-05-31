# Nano-Bot Simulation Platform — Requirements

## 1. Overview

A Godot-based simulation platform inspired by Microsoft Imagine Cup's **nano-bot**. The platform allows participants to write AI strategies that control teams of nanobots navigating inside a human-body-themed grid world. Strategies compete head-to-head in a turn-based simulation, with a built-in viewer, scoring system, and tournament bracket to determine winners.

**Reference:** [project_nanobot_reference.md](project_nanobot_reference.md)

---

## 2. Goals

| # | Goal |
|---|---|
| G1 | Participants submit a GDScript strategy file — no game engine knowledge required. |
| G2 | Two or more strategies can battle simultaneously on the same map. |
| G3 | The simulation runs headlessly (no rendering) for fast batch evaluation. |
| G4 | A visual playback mode lets anyone watch a match replay step by step. |
| G5 | A tournament mode runs all submitted strategies against each other and produces a ranked leaderboard. |

---

## 3. Scope

**In scope:**
- Grid map engine with tissue density, bloodstreams, bones, and impassable cells
- All 8 nanobot types with their stat budgets and action sets
- Turn-based simulation engine (up to 1500 turns per match)
- GDScript-based strategy API for participants
- 2D top-down visual player with playback controls
- Scoring system per the original nano-bot rules
- 1v1 and multi-player tournament runner
- Match result export (JSON)

**Out of scope (v1):**
- 3D visualization
- Online/networked multiplayer
- Strategy editor / IDE
- Anti-cheat or full script sandboxing
- Mobile / web export

---

## 4. Functional Requirements

### 4.1 Map System

| ID | Requirement |
|---|---|
| MAP-01 | The map is a 2D grid. Default size is **50×50 cells**; configurable up to 200×200. |
| MAP-02 | Each cell has a **tissue density** type: Low (cost 2), Medium (cost 3), High (cost 4), or Bone (impassable). |
| MAP-03 | Each cell may belong to a **bloodstream** with a direction (N/S/E/W). Movement with the stream costs −2 turns (min 1); against costs +2. |
| MAP-04 | Maps are defined in external JSON files so new maps can be added without modifying engine code. |
| MAP-05 | Maps declare the positions of **Habitas Points** (scoring objectives) and **AZN Points** (resource nodes with a quantity). |
| MAP-06 | Maps declare one or more **injection zones** — valid areas where a player may choose their spawn point. |
| MAP-07 | The platform ships with at least **3 pre-built maps** of varying size and complexity. |

### 4.2 Nanobot Types

All nanobots share a base stat budget. Player-submitted characteristics must not exceed the budget for that type.

| ID | Requirement |
|---|---|
| BOT-01 | **NanoAI** — one per player, cannot be built. HP 20, Scan 5. If destroyed, all friendly bots skip their actions for the rest of the match. |
| BOT-02 | **NanoExplorer** — HP 20, Scan 30. Movement is not penalized by tissue density (bloodstreams still apply). |
| BOT-03 | **NanoCollector** — HP 50, AZN capacity 20, transfer rate 5/turn. Can attack (damage 5, range 12 Euclidean). |
| BOT-04 | **NanoContainer** — HP 60, AZN capacity 60, transfer rate 5/turn. Cannot attack. |
| BOT-05 | **NanoNeedle** — HP 150, AZN capacity 100. Stationary once placed on a Habitas Point. Scores points per §4.5. Cannot move after placement. |
| BOT-06 | **NanoIPCreator** — HP 20, Scan 30. Executes `OpenIP` to create a new injection point, then self-destructs after 500 turns. |
| BOT-07 | **NanoBlocker** — HP 90. Adds +6 turn traversal cost to any enemy bot passing through its cell. |
| BOT-08 | **NanoWall** — HP 100. Treated as impassable by enemies. Destroyed automatically after 50 turns. |
| BOT-09 | Players start each match with only their **NanoAI**. All other bots must be built using the `Build` action. |
| BOT-10 | Building a bot costs AZN (amount defined per type in the map config or a global defaults file). |

### 4.3 Strategy / AI System

| ID | Requirement |
|---|---|
| STR-01 | A strategy is a single `.gd` file that extends a base class `NanoStrategy`. |
| STR-02 | `NanoStrategy` exposes exactly two override methods: `choose_injection_point(map_info)` and `what_to_do_next(map_info, my_bots)`. |
| STR-03 | `map_info` provides read-only access to: cell density grid, bloodstream directions, Habitas Point positions, AZN node positions and quantities, all visible enemy bot positions (within Scan range of any friendly bot). |
| STR-04 | `my_bots` is a list of `BotProxy` objects. Each `BotProxy` exposes: type, position, HP, AZN carried, current action, and the action-queue methods (`move_to`, `collect_from`, `transfer_to`, `defend`, `build`, `open_ip`, `stop`, `self_destruct`). |
| STR-05 | Strategy code runs inside a per-turn time budget. If `what_to_do_next` exceeds **50 ms**, the turn is forfeited for that player and a warning is logged. |
| STR-06 | Strategy code may not call any Godot engine globals directly (no `get_tree()`, no `get_node()`, etc.). Violations are caught at load time and disqualify the strategy. |
| STR-07 | Strategies are loaded from a configurable `/strategies` directory. Any `.gd` file found there is treated as a candidate. |

### 4.4 Simulation Engine

| ID | Requirement |
|---|---|
| SIM-01 | A match runs for a maximum of **1500 turns**. |
| SIM-02 | Each turn processes all bots in this order: (1) resolve movement, (2) resolve collection/transfer, (3) resolve attacks, (4) call `what_to_do_next` for each player, (5) apply new actions. |
| SIM-03 | Movement uses **Manhattan pathfinding** (A*) accounting for density cost and bloodstream modifiers. |
| SIM-04 | Attack range uses **Euclidean distance**. |
| SIM-05 | The engine supports **headless mode**: runs the full simulation without rendering, completing a 50×50 match in under 5 seconds on typical hardware. |
| SIM-06 | Every turn's full state is recorded to a **match log** (array of snapshots) for replay. |
| SIM-07 | Match log is exportable to a JSON file: `match_YYYY-MM-DD_HH-MM-SS.json`. |
| SIM-08 | The engine supports 2–4 simultaneous players on the same map. |
| SIM-09 | At turn 1500 (or when all bots of a player are destroyed), the match ends and scores are calculated. |

### 4.5 Scoring

| ID | Requirement |
|---|---|
| SCO-01 | A NanoNeedle placed on a Habitas Point with **no AZN** scores **5 points**. |
| SCO-02 | A NanoNeedle placed on a Habitas Point with AZN scores **20 points + 2 points per AZN molecule** stored. |
| SCO-03 | Bonus points per map config (optional): e.g., first to occupy all Habitas Points gets +50. |
| SCO-04 | The player with the highest score at match end wins. Ties are broken by: (1) bots still alive, (2) AZN collected, (3) turns elapsed. |
| SCO-05 | Final scores and per-turn score history are included in the match log. |

### 4.6 Visual Playback

| ID | Requirement |
|---|---|
| VIS-01 | A visual player reads a match log and renders it as a 2D top-down animated scene. |
| VIS-02 | Cell density is color-coded: red (low), blue (medium), green (high), black (bone). |
| VIS-03 | Bloodstream cells show animated directional arrows. |
| VIS-04 | Each player's bots are color-coded by team. Bot type is indicated by a distinct icon. |
| VIS-05 | Playback controls: Play, Pause, Step Forward, Step Back, Speed (0.25×, 0.5×, 1×, 2×, 4×). |
| VIS-06 | A HUD panel shows: current turn, each player's score, AZN collected, and bots alive. |
| VIS-07 | Clicking a bot shows its current action and stats in a side panel. |
| VIS-08 | Habitas Points are highlighted; occupied ones show the owning team's color and current AZN stored. |

### 4.7 Tournament Mode

| ID | Requirement |
|---|---|
| TRN-01 | Tournament mode takes all strategies in `/strategies` and runs a **round-robin**: every strategy plays against every other on every available map. |
| TRN-02 | Tournament results are accumulated into a **leaderboard**: wins, losses, draws, total points. |
| TRN-03 | Leaderboard is displayed in-app and exported to `tournament_results.json`. |
| TRN-04 | Disqualified strategies (load error, timeout violation) are shown on the leaderboard with a DQ status rather than silently skipped. |
| TRN-05 | A tournament summary screen shows the top 3 strategies with their win rates and average scores. |

---

## 5. Non-Functional Requirements

| ID | Requirement |
|---|---|
| NFR-01 | **Performance** — headless simulation of a 50×50 map with 4 players completes in ≤5 seconds. |
| NFR-02 | **Extensibility** — new nanobot types, maps, and scoring rules can be added via data files without modifying core engine code. |
| NFR-03 | **Portability** — runs on Linux, Windows, and macOS via Godot 4.x export. |
| NFR-04 | **Error isolation** — a runtime error inside a strategy file must not crash the simulation; it forfeits that player's turn and logs the error. |
| NFR-05 | **Reproducibility** — given the same map, strategies, and random seed, two runs produce identical results. |
| NFR-06 | **Usability** — a participant with basic GDScript knowledge can write and test a strategy in under 30 minutes using only the API docs and example strategy. |

---

## 6. Strategy API Reference (Spec)

```gdscript
# Participants extend this class in their strategy file
class_name NanoStrategy

# Called once before the match starts.
# Return a Vector2i cell within the allowed injection zone.
func choose_injection_point(map_info: MapInfo) -> Vector2i:
    return Vector2i(0, 0)

# Called once per turn (up to 1500 times).
# Queue actions on bots via BotProxy methods.
func what_to_do_next(map_info: MapInfo, my_bots: Array[BotProxy]) -> void:
    pass
```

### MapInfo (read-only)

```gdscript
map_info.size                  # Vector2i grid dimensions
map_info.get_cell(x, y)        # CellInfo { density, stream_dir, is_bone }
map_info.habitas_points        # Array[HabitasPoint] { position, owner, azn_stored }
map_info.azn_nodes             # Array[AZNNode] { position, quantity }
map_info.visible_enemies       # Array[EnemyInfo] { position, type, hp } — only within scan range
map_info.turn                  # int, current turn number
```

### BotProxy (action queue)

```gdscript
bot.type                       # BotType enum
bot.position                   # Vector2i
bot.hp                         # int
bot.azn                        # int, AZN currently carried
bot.move_to(target: Vector2i)
bot.collect_from(node_position: Vector2i)
bot.transfer_to(target_position: Vector2i)
bot.defend(enemy_position: Vector2i)
bot.build(bot_type: BotType, position: Vector2i)
bot.open_ip()                  # NanoIPCreator only
bot.stop()
bot.self_destruct()
```

---

## 7. File & Folder Structure

```
nano-bot/
├── project.godot
├── docs/
│   ├── requirements.md          # this file
│   └── project_nanobot_reference.md
├── src/
│   ├── core/                    # simulation engine (no rendering)
│   │   ├── simulation.gd
│   │   ├── map.gd
│   │   ├── nanobot.gd
│   │   └── bot_proxy.gd
│   ├── ui/                      # visual playback & menus
│   │   ├── playback_player.gd
│   │   ├── hud.gd
│   │   └── leaderboard.gd
│   └── tournament/
│       └── tournament_runner.gd
├── maps/                        # JSON map definitions
│   ├── simple_tissue.json
│   ├── river_crossing.json
│   └── bone_maze.json
├── strategies/                  # participant strategy files go here
│   └── example_strategy.gd
└── replays/                     # auto-saved match JSON logs
```

---

## 8. Example Strategy (Starter File)

```gdscript
# strategies/example_strategy.gd
extends NanoStrategy

func choose_injection_point(map_info: MapInfo) -> Vector2i:
    # Inject near the centre of the map
    return map_info.size / 2

func what_to_do_next(map_info: MapInfo, my_bots: Array[BotProxy]) -> void:
    for bot in my_bots:
        # Move each bot toward the nearest Habitas Point
        if map_info.habitas_points.size() > 0:
            var target = map_info.habitas_points[0].position
            bot.move_to(target)
```

---

## 9. Milestones

| Milestone | Deliverables |
|---|---|
| **M1 — Core Engine** | Map loader, simulation loop, all 8 bot types, pathfinding, scoring |
| **M2 — Strategy API** | `NanoStrategy` base class, `MapInfo`, `BotProxy`, example strategy, load-time validation |
| **M3 — Visual Playback** | Match log recorder, 2D renderer, playback controls, HUD |
| **M4 — Tournament** | Round-robin runner, leaderboard, JSON export |
| **M5 — Polish** | 3 shipped maps, tutorial, onboarding docs, packaging |

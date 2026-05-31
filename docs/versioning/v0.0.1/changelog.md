# v0.0.1 Changelog

---

## Milestone M4 — Tournament Mode

### Added

#### Tournament runner (`src/tournament/tournament_runner.gd`)
- `TournamentRunner` — `RefCounted` with signals `progress_updated`, `match_finished`, `tournament_finished`.
- `start(strategy_paths, map_paths)` — builds a round-robin schedule (every strategy vs every other, on every map) and runs all matches in a background `Thread` so the UI stays responsive.
- Each match auto-saves its replay to `replays/tournament_NNN_A_vs_B.json`.
- DQ detection: a strategy that has no living bots before turn 10 is flagged as disqualified.
- `abort()` and `wait()` for clean teardown.

#### Leaderboard (`src/tournament/leaderboard.gd`)
- `Leaderboard` — accumulates `MatchResult` dictionaries from `TournamentRunner`.
- Tracks per-strategy: wins, losses, draws, total points, match count, DQ flag.
- `get_sorted()` — returns entries ranked by wins then points.
- `save_to_file(path)` — exports timestamped JSON to `replays/tournament_leaderboard.json`.

#### Tournament UI (`src/tournament/ui/tournament_ui.gd`)
- Full-screen `Control` built in GDScript — split-panel layout (leaderboard left, match log right).
- **Start Tournament** — discovers all `.gd` files in `res://strategies/`, builds schedule, runs `TournamentRunner`.
- Live-updating leaderboard table: rank, strategy name, W/L/D, points. Top-3 highlighted gold/silver/bronze; DQ entries shown in red.
- **Match log** — scrollable list of completed matches with scores, winner, turns, and a **▶** watch button per match that loads the replay in `PlaybackScene` via `GameState`.
- Progress bar during run.
- **Export** button — saves leaderboard JSON.
- **← Menu** back button.

#### Scenes & project wiring
- `scenes/tournament_scene.tscn` — minimal scene pointing to `tournament_ui.gd`.
- `src/ui/main_menu/main_menu.gd` — Tournament button enabled; navigates to `tournament_scene.tscn`.

### Fixed
- `project.godot` — Removed `"GDScript"` from `config/features` (caused "unsupported feature" warning in the mono Godot editor).

### Bugfixes (carried from testing)
- `src/core/simulation_core.gd` — `dist` and `bank` variables given explicit `int` type annotations (GDScript 4 type inference failure on arithmetic results).
- `src/core/simulation_core.gd` — Added `can_instantiate()` guard before `script.new()` so a parse-errored strategy is cleanly rejected instead of crashing with "Nonexistent function 'new'".
- `strategies/example_strategy.gd` — `candidate` loop variable and `_move_toward` target access fixed for strict type inference.

---

## Milestone M3 — Visual Playback

### Added

#### Scene entry point
- `scenes/main_menu.tscn` — Root scene registered as `run/main_scene`. Minimal tscn pointing to `main_menu.gd`.
- `scenes/playback_scene.tscn` — Playback scene pointing to `playback_scene.gd`.
- `project.godot` — Added `run/main_scene`, `window/size` (1280×800), and `GameState` autoload.

#### Autoload (`src/game_state.gd`)
- `GameState` singleton (Node autoload). Holds `pending_log: MatchLog` and `pending_log_path: String` to pass replay data between scene transitions without re-running the simulation.

#### Main menu (`src/ui/main_menu/main_menu.gd`)
- Dark-themed full-screen `Control` built entirely in GDScript.
- **"▶ Run Match"** — loads `simple_tissue.json`, runs `SimulationCore` with `example_strategy.gd` vs itself, auto-saves replay to `replays/`, transitions to `PlaybackScene`.
- **"📂 Load Replay"** — opens a `FileDialog` starting in `replays/`; on file selection, sets `GameState.pending_log_path` and transitions.
- **"🏆 Tournament"** — disabled stub (M4).
- Status label gives per-step feedback during match execution.

#### Map renderer (`src/ui/playback/map_renderer.gd`)
- `Node2D` using `_draw()` — zero external assets required.
- Color-codes cells: low (peach), medium (soft purple), high (deep purple), bone (near black).
- Thin grid lines at 10% opacity.
- Bloodstream arrows drawn with `draw_line()` per stream cell.
- Habitas Points drawn as gold diamonds; occupied points blend player color in.
- AZN nodes drawn as green circles; hidden when quantity is 0.
- `cell_to_pixel(cell)` / `pixel_to_cell(px)` conversion helpers.
- `update_overlay(habitas, azn)` refreshes per-frame state and triggers redraw.

#### Bot sprite (`src/ui/playback/bot_sprite.gd`)
- `Node2D` with `_draw()` circle (team color) and dark outline.
- `Label` child shows 2-letter bot-type abbreviation (AI, EX, CO, CN, NN, IP, BL, WA).
- `place_at(cell)` — instant repositioning.
- `animate_to(cell, duration)` — smooth `Tween` (EASE_IN_OUT, TRANS_SINE).
- `mark_dead()` — fades modulate alpha to 0 over 0.25 s then `queue_free`.

#### HUD (`src/ui/playback/hud.gd`)
- `CanvasLayer` built entirely in GDScript. Panel anchored to the right (x = 808, width = 464).
- **Match info strip**: map name, total turns.
- **Turn counter**: current turn / total.
- **Score rows** (one per player, colour-coded, auto-hidden if player absent): score in points, bots alive.
- **Bot inspector panel**: updates on click showing ID, type, owner, HP, AZN, position.
- **Map legend**: density colors, Habitas Point, AZN Node.
- **Turn slider** (`HSlider`): drag to jump to any frame; emits `jump_requested(turn)`.
- **Playback controls**: ◀ Step Back, ▶ Play / ⏸ Pause, ▶| Step Forward, – / + speed buttons.
- Speed steps: 0.25×, 0.5×, 1×, 2×, 4×. Emits `speed_changed(multiplier)`.
- All controls wired via signals — no direct coupling to `PlaybackScene`.

#### Playback scene (`src/ui/playback/playback_scene.gd`)
- `Node2D` scene root. Builds `MapRenderer`, bot-sprite `Node2D` layer, `HUD`, `Timer`, and a "← Menu" back button in `_ready()`.
- Reads `GameState.pending_log` or `GameState.pending_log_path` on arrival.
- `_apply_frame(idx, animate)` — syncs map overlay, creates/moves/removes `BotSprite` nodes from a `Dictionary` keyed by `bot_id`.
- `step_forward()` / `step_back()` / `jump_to(idx)` — frame navigation.
- At speed ≥ 4× animation is skipped (instant frame jump).
- `_input()` — left-click on map calls `_inspect_bot_at(cell)` → `HUD.show_bot_info()`.
- `_find_map(name)` — scans `res://maps/` for a JSON file whose `map_name` matches the log.
- Auto-stop playback when the last frame is reached.

### Changed
- `project.godot` — `run/main_scene`, window size 1280×800, `GameState` autoload registered.

---

## Milestone M2 — Strategy API

### Added

#### Strategy API layer (`src/api/`)
All classes extend `RefCounted` — no scene-tree dependency.

- **`nano_strategy.gd`** — Base class participants extend. Two virtual methods: `choose_injection_point(map_info)` called once before the match, and `what_to_do_next(map_info, my_bots)` called once per turn. Default implementations are no-ops.

- **`bot_proxy.gd`** — Read-only snapshot of one bot's state for the current turn, plus an action queue. Properties: `id`, `type`, `position`, `hp`, `max_hp`, `azn`, `is_alive`, `is_moving`, `has_path`. Action methods: `move_to`, `collect_from`, `transfer_to`, `defend`, `build`, `open_ip`, `stop`, `self_destruct`. Last call per turn wins. `flush_action()` is called by `SimulationCore` to commit the queued action.

- **`map_info.gd`** — Read-only map view rebuilt each turn. Properties: `size`, `turn`, `habitas_points` (`Array[HabitasPointInfo]`), `azn_nodes` (`Array[AZNNodeInfo]`), `visible_enemies` (all enemies visible — fog-of-war deferred to M3), `azn_bank` (player's current build budget). `get_cell(x, y)` returns a `CellInfo`.

- **`cell_info.gd`** — Read-only cell descriptor: `position`, `density`, `stream_direction`, `is_bone`. Static factory `from_map(map, x, y)`.

- **`habitas_point_info.gd`** — Read-only Habitas Point state: `position`, `owner_id` (−1 = unoccupied), `azn_stored`. Static factory `from_state(dict)`.

- **`azn_node_info.gd`** — Read-only AZN node state: `position`, `quantity`. Static factory `from_state(dict)`.

#### Runner (`src/runner/`)

- **`headless_runner.gd`** — Static CLI entry point. Parses `--map`, `--strategy_a/b/c/d`, `--seed`, `--out` arguments from `OS.get_cmdline_user_args()`. Runs `SimulationCore`, saves replay JSON, prints match summary. Returns exit code 0/1.

#### Strategies

- **`strategies/example_strategy.gd`** — Participant starter strategy demonstrating the full gameplay loop: inject near centre → move NanoAI to Habitas Point → build NanoCollector → collect AZN → bank AZN → build NanoNeedle → deliver AZN to NanoNeedle.

#### Data changes

- `maps/simple_tissue.json` — Added `"starting_azn": 50` field. Players begin each match with 50 AZN in their build bank.

### Changed

#### `src/core/simulation_core.gd` — full M2 rewrite

New fields:
- `_strategies: Array` — loaded `NanoStrategy` instances (null for no-strategy players).
- `_player_azn_bank: Dictionary` — per-player AZN available for building bots. Initialised from map `starting_azn` (default 50).

New turn loop order:
```
decrement_timers → advance_movement → call_strategies →
apply_action_queues → resolve_attacks → tick_auto_destruct →
check_nano_ai_deaths → update_scores → record_frame
```

New methods:
- `_load_strategies()` — loads each strategy path, validates `is NanoStrategy`, pads to `_player_count` with nulls.
- `_choose_injection_point(pid)` — calls `strategy.choose_injection_point()` at turn 0, validates result is inside the player's injection zone.
- `_call_strategies(turn)` — builds `MapInfo` + `Array[BotProxy]` per player, calls `what_to_do_next`, enforces 50 ms timeout; forfeits turn if exceeded.
- `_apply_action_queues(events)` — dispatches each bot's `pending_action` to the appropriate handler.
- `_execute_action(bot, action, events)` — routes to specific handlers by action type.
- `_action_move` — A* pathfind to target, set `path_remaining` (skips current cell).
- `_action_collect` — bot must be ON the AZN node; transfers up to `transfer_rate` AZN per turn.
- `_action_transfer` — transfers AZN from bot to (a) friendly NanoNeedle on same cell, or (b) player AZN bank if bot is in injection zone.
- `_action_build` — NanoAI only; target cell must be adjacent and passable; deducts AZN from bank; spawns bot.
- `_action_open_ip` — NanoIPCreator only; records event; auto-destruct countdown already running.
- `_update_scores()` — rewritten: derives habitas ownership from alive NanoNeedle bots; recalculates `_scores` from scratch each turn.
- `_check_nano_ai_deaths()` — updates `_nano_ai_alive` when a NanoAI is destroyed; subsequent turns skip `what_to_do_next` for that player.
- Dynamic obstacle checks in `_advance_movement`: enemy NanoWalls block movement, enemy NanoBlockers add traversal penalty.

### M2 Acceptance Test

Run `example_strategy.gd` vs itself on `simple_tissue.json` (two players, same strategy). Expected:
- Both players build a NanoCollector within the first ~30 turns.
- At least one player occupies a Habitas Point and scores > 0 before turn 1500.
- Match log contains correct per-turn score history.
- `replays/` directory receives an auto-saved JSON file.

---

## Milestone M1 — Core Engine

### Added

#### Data files
- `data/bot_types.json` — Stat definitions for all 8 nanobot types.
- `maps/simple_tissue.json` — First playable map (50×50) with varied density, bloodstreams, bone walls, 4 Habitas Points, 4 AZN nodes, two injection zones.

#### Core simulation layer (`src/core/`)

- **`action_request.gd`** — Immutable action descriptor with `Type` enum and static factory methods.
- **`map_data.gd`** — Grid data model with `movement_cost(from, to)` accounting for density and bloodstream direction.
- **`map_loader.gd`** — JSON → `MapData` parser with sparse cell support and error reporting.
- **`grid_pathfinder.gd`** — Custom A* with directed edge costs for accurate bloodstream handling.
- **`nanobot_data.gd`** — Full mutable bot state and `to_log_dict()` serialiser.
- **`bot_type_registry.gd`** — Static singleton loading `data/bot_types.json`.
- **`match_log.gd`** — Per-turn frame recorder; JSON save/load.
- **`simulation_core.gd`** — 1500-turn simulation loop skeleton (fully replaced by M2).

#### Project structure
- `replays/` with `.gdignore` — auto-save directory, excluded from git.
- `.gitignore` — added `/replays/`.

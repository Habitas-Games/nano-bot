# v0.0.3 Changelog

**Version:** 0.0.3
**Status:** Complete
**Depends on:** [analysis.md](analysis.md), [plan.md](plan.md)

---

## Summary

Cleanup-only version, no new features. Fixes the parse-breaking duplicate-function bug found in `map_editor.gd` (v0.0.2 commit `952623e`), splits the 1374-line monolith into the module structure `plan.md` §2 specified, fixes an undo-coverage bug discovered while moving the history code, and implements two things that were specified back in Phase 2/4 but never actually built (zone placement, AZN/edit cursor feedback). Verified by actually loading and driving the editor headlessly at each step — not by reading the diff — per `analysis.md` §6's finding that inspection-only verification is exactly what let the original bug ship undetected.

---

## Pre-refactor baseline (Step 1)

Loading `map_editor.gd` headlessly (`godot4 --headless --script` against a throwaway `SceneTree` that calls `load()` then `.new()` on the script) produced:

```
SCRIPT ERROR: Parse Error: Function "_density_to_string" has the same name as a previously declared function.
ERROR: Failed to load script "res://src/ui/map_editor/map_editor.gd" with error "Parse error".
```

**The editor could not be instantiated at all.** This had been true since commit `952623e` and was never caught. There is no "baseline behavior" to record beyond this — the manual click-through checklist from `plan.md` §3 Step 1 could not be run because there was nothing to click through.

---

## Bugs fixed

1. **Duplicate function definitions** (analysis.md §2) — `_load_map_from_file`, `_density_to_string`, `_string_to_density` were each defined twice; `_string_to_stream_dir`/`_stream_to_string` and `_stream_dir_to_string`/`_string_to_stream` were duplicated under different names. Resolved by construction: each now has exactly one home in `map_io.gd`.

2. **Undo never covered habitas/AZN/zones** (analysis.md §4a, found while extracting `MapHistory`) — `_save_state()` only ever snapshotted `cells`, even though it was called before every element mutation too. Clicking Undo after placing/moving/deleting a habitas point, AZN node, or zone did nothing to that element. Fixed: `MapDocument.snapshot()`/`restore()` now cover all four arrays, and `MapHistory` snapshots the whole document.

3. **Loading a map with missing `width`/`height` silently guessed a size** — neither of the two pre-refactor defaults (60×60 from `_init_blank_map`, 80×80 from the duplicate Phase-5 loader) matched the simulator: `src/core/map_loader.gd` treats both fields as required and refuses to load if either is missing. `MapIO.load_from_file()` now does the same instead of guessing.

4. **Zone placement tool was a no-op** (analysis.md §4) — the "Place Zone" button activated a tool whose press handler was a literal `pass`. Implemented per the original `PHASE_2_SPEC.md` wording ("drag rectangle to place"); new zones default to player 0 (a player-selector UI for zone *creation* was an open question in `PHASE_4_ANALYSIS.md` that was never resolved, and is explicitly left unresolved here too — see `tools/zone_tool.gd`'s header comment).

5. **Edit tool's cursor was never implemented** — `PHASE_4_SPEC.md` specified a pen-like cursor (naming `CURSOR_POINTING_HAND` as the concrete fallback) but the input handler's cursor-update branch only ever distinguished Pan from "everything else." `EditTool.get_cursor()` now returns `CURSOR_POINTING_HAND` as speced. Delete tool's cursor was also specced ("eraser") but with no concrete Godot enum named — left as the default rather than inventing one.

## Dead code removed

- `edit_drag_offset` — declared, assigned once, never read.
- `azn_hover_time` / `AZN_HOVER_DELAY` — implied a 0.5s hover delay (per `PHASE_4_SPEC.md` §8) that was never wired up; the hover was always instant. Decided to keep it instant and drop the unused state rather than implement the delay, since this is a cleanup pass — a real delay is a one-line `Timer` addition if ever wanted.
- Raw keycode `4194309` (a workaround for `KEY_RETURN`/`KEY.RETURN` not resolving) replaced with `KEY_ENTER`, which is the correct global-scope constant in Godot 4.6.1.

## Structural changes

Split `src/ui/map_editor/map_editor.gd` (1374 lines, one `Control` class) into:

| File | Responsibility |
|---|---|
| `map_document.gd` | Cell/element data + mutation (paint, fill, delete, move, resize, snapshot/restore) |
| `map_io.gd` | JSON ↔ `MapDocument`, validation, enum↔string conversion |
| `map_history.gd` | Undo stack |
| `map_canvas_renderer.gd` | All `draw_*` calls |
| `map_editor_sidebar.gd` | Right-panel UI construction, exposed as signals |
| `tools/editor_tool.gd` + 8 subclasses | One class per tool (terrain, stream, habitas, azn, zone, pan, edit, delete), replacing three separate `match active_tool:` blocks that used to live inside `_input()` |
| `map_editor.gd` | Now ~300 lines: owns the above, wires signals, forwards `_input`/`_draw` |

## Verification performed

Headless, by actually instantiating the classes and the real scene (not by reading the diff):

- Loaded `map_editor.gd` and every new file via `godot4 --headless --script` against throwaway `SceneTree` checks; zero parse errors project-wide after the refactor (confirmed via `godot4 --headless --editor --quit`, which rescans every script).
- Instantiated `MapEditor`, let `_ready()` run, confirmed the default map loads (80×80, 6 habitas, 6 AZN, 2 zones — from `maps/simple_tissue.json`).
- Exercised tool switching (`terrain` → `delete` → `edit` → `zone`).
- Placed a habitas point via `HabitasTool`, confirmed the duplicate-position guard blocks a second placement on the same cell, then confirmed **Undo now actually removes it** (this specifically exercises bug fix #2 above — before the fix, this was a no-op).
- Drove `ZoneTool` end-to-end (press → drag → release) and confirmed a new zone is created with the correct rectangle and default player.
- Selected that zone with `EditTool`, clicked its top-left corner, confirmed corner detection returns `"tl"` and a drag resizes from that corner only.
- Selected an AZN node, sent a synthetic `KEY_ENTER` event through `EditTool.handle_key()`, confirmed the quantity dialog opens (and that `KEY_ENTER` itself resolves with no parse error — bug fix in dead-code section above).
- Round-tripped save → load through `MapIO` and confirmed habitas/AZN/zone counts and map dimensions match exactly.
- Confirmed a map JSON missing `width`/`height` now fails to load with a clear error, matching `src/core/map_loader.gd`'s own required-field behavior (bug fix #3).
- Loaded the actual `res://scenes/map_editor_scene.tscn` that `main_menu.gd` switches to (not just the bare script) to confirm the real launch path works end to end.

## Documentation

- Reconciled the duplicate `changelog.md`/`CHANGELOG.md` fork in `docs/versioning/v0.0.2/` into one `changelog.md` (lowercase, matching v0.0.1's convention).
- Left the `PHASE_*` satellite docs under `v0.0.2/` in place as historical record — not deleting completed-phase design history — but no new satellite docs were created for v0.0.3. This file, `plan.md`, and `analysis.md` are the only three.

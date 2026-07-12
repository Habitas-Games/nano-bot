# v0.0.3 — Implementation Plan

**Status:** Plan (pre-implementation)
**Depends on:** [analysis.md](analysis.md)

---

## 1. Scope

This version does **not** add features. Every step below is a fix to something `map_editor.gd` or `docs/versioning/v0.0.2/` already has, diagnosed in `analysis.md`. No new tool, no new UI element, no new map-format field is introduced. If a step in this plan starts to look like a feature addition, stop and cut it — that's scope creep into v0.0.4.

Order matters: steps 2–4 (module split) are foundational — doing the bug fix (step 5+) after the split means fixing it once, in the right file, instead of fixing it in the monolith and then having to re-locate it during the split.

---

## 2. Target File Structure

```
src/ui/map_editor/
├── map_editor.gd              ← Control root: owns child nodes, wires signals, _draw() delegates
├── map_document.gd            ← RefCounted: cells/habitas/azn/zones + mutation (paint, fill, delete, move, resize)
├── map_io.gd                  ← RefCounted: JSON <-> MapDocument (load, save, validate, enum<->string)
├── map_history.gd             ← RefCounted: undo stack (currently inline in map_editor.gd)
├── map_canvas_renderer.gd     ← RefCounted or static funcs: all draw_* calls, given a MapDocument + view state
├── map_editor_sidebar.gd      ← Control: builds the right-hand panel, emits signals (tool_selected, density_selected, ...)
└── tools/
    ├── editor_tool.gd          ← base class: handle_press(grid_pos), handle_drag(grid_pos), handle_release()
    ├── terrain_tool.gd
    ├── stream_tool.gd
    ├── habitas_tool.gd
    ├── azn_tool.gd
    ├── zone_tool.gd
    ├── pan_tool.gd
    ├── edit_tool.gd
    └── delete_tool.gd
```

This mirrors the seams that already exist implicitly in the current file (§3 of analysis.md) — it is a mechanical split, not a redesign. `map_editor.gd` after the split is reduced to: own a `MapDocument`, own a `MapHistory`, own the active `EditorTool`, forward `_input`/`_draw` to the right one, and run `_setup_ui()` (or delegate that to `map_editor_sidebar.gd` too — see step 6, since the sidebar's buttons exist to activate tools and naturally move together with the tool-class split).

---

## 3. Step-by-step

### Step 1 — Freeze behavior with a manual checklist before touching code

Before any refactor, run the editor once and record actual current behavior for: load default map on open, paint terrain (click + drag), flood fill, place stream (click + drag), place habitas, place AZN, pan, edit (move habitas/AZN/zone, resize zone corner, AZN quantity dialog), delete (drag), undo, save, load a saved map back.

This is the regression baseline. The refactor in steps 2–4 must reproduce every one of these exactly (bugs included, e.g. the no-op zone tool — that gets fixed in step 6, not silently during the split). Write the checklist results into `changelog.md` as "Pre-refactor baseline" so there's a record of what "unchanged" means.

### Step 2 — Extract `MapDocument`

Move into `map_document.gd` (`extends RefCounted`):
- State: `map_width`, `map_height`, `cells`, `habitas_points`, `azn_nodes`, `injection_zones`, the `Density`/`StreamDir` enums.
- Mutation methods currently free-floating in `map_editor.gd`: `_paint_cell`, `_flood_fill`, `_clear_map`, `_delete_at_position`, `_find_element_at`, `_move_habitas`, `_move_azn`, `_move_zone`, `_detect_zone_corner`, `_resize_zone`.
- **No `_save_state()` calls move with them** — undo is the caller's responsibility (`MapHistory`), not the document's. Mutation methods become pure data operations.

`map_editor.gd` holds one `var doc: MapDocument` and calls through it. This is the only step that touches the duplicate-placement guard (analysis.md §4, habitas/AZN stacking) — add the dedup check here, in `_paint_cell`'s siblings, while the placement methods are already being moved and re-read line by line.

### Step 3 — Extract `MapIO`

Move into `map_io.gd` (`extends RefCounted`, takes a `MapDocument` as a parameter, not a member, so it has no lifecycle of its own):
- `_create_map_json`, `_validate_map`, `_density_to_string`, `_stream_to_string`, `_string_to_density`, `_string_to_stream` (one copy each — this is where the duplicate-function bug from analysis.md §2 gets resolved, by construction: there is physically one place left to put each function).
- `load_from_file(path) -> MapDocument` and `save_to_file(doc, path)`, merged from the two colliding implementations:
  - Keep Phase 1's behavior: apply `default_density` to every cell before overlaying explicit ones, reset zoom/scroll on load, seed one undo state after load.
  - Keep Phase 5's behavior: bounds-checking on loaded `x`/`y`, `_show_error()` dialogs on bad file/JSON. **Correction to the original analysis:** neither 60×60 nor 80×80 is right as a silent default — `src/core/map_loader.gd:32-35` treats `width`/`height` as **required** fields and refuses to load the map (`push_error`, returns `null`) if either is missing. The editor's loader should match: treat a missing `width`/`height` as a load error via `_show_error()`, not silently substitute a guessed size that the simulator itself would never accept.
- Delete the now-empty originals from `map_editor.gd`. Grep the file for `_load_map_from_file`, `_density_to_string`, `_string_to_density`, `_stream_dir_to_string`, `_string_to_stream_dir`, `_stream_to_string`, `_string_to_stream` after this step — there must be exactly one definition of each surviving name, zero of the others.

### Step 4 — Extract `MapHistory`, and fix undo to actually cover elements

Move `history`, `history_index`, `MAX_HISTORY`, `_save_state`, `_undo` into `map_history.gd`. **Confirmed during analysis (analysis.md §4a), not speculative:** the current implementation snapshots `cells` only, even though `_save_state()` is called before habitas/AZN/zone mutations too — so Undo has never actually restored those three element types, in any commit since Phase 2. This is a correctness bug in something already shipped and already exposed to users via the Undo button, not a new feature — fix it in this pass: `MapHistory.save_state()` takes a full snapshot dict (`{cells, habitas_points, azn_nodes, injection_zones}`, via a new `MapDocument.snapshot()`/`restore()` pair), and `undo()` restores all four. Note the fix in `changelog.md` as a bug found and fixed during the refactor, not a new feature.

### Step 5 — Extract rendering

Move `_draw`, `_draw_stream_cell`, `_stream_to_vec` into `map_canvas_renderer.gd` as either a small `RefCounted` holding texture refs, or static functions taking `(doc, view_state, canvas_rect)` and a `CanvasItem` to draw onto. `map_editor.gd`'s own `_draw()` becomes one call out.

While moving this, fix analysis.md §5's layout duplication: `canvas_rect` should be computed from the sidebar's actual `size.x`, not a hardcoded `250`. The sidebar already exists as a node by the time `_draw()` runs — read its real width.

### Step 6 — Replace the tool dispatch

Build `tools/editor_tool.gd` as a minimal base (`handle_press(grid_pos, button)`, `handle_drag(grid_pos)`, `handle_release()`, `get_status_text()`), and one subclass per existing tool, moving the matching logic out of `_input()`'s three scattered switches. `map_editor.gd._input()` becomes: compute `grid_pos`, delegate to `current_tool`, handle the genuinely tool-independent bits (zoom, AZN hover-for-tooltip, Enter-key-for-AZN-dialog if it stays global rather than becoming part of `edit_tool.gd` — prefer moving it into `edit_tool.gd` since it only fires when that tool is active).

This is also where the zone-tool stub from analysis.md §4 gets resolved — but **resolved, not silently extended**. `zone_tool.gd`'s `handle_press`/`handle_drag` should implement exactly what `PHASE_2_SPEC.md` already specified ("drag rectangle to place, drag later to move") since that was speced and never built, not a new design. If after writing it it turns out to need a player-selector UI that doesn't exist yet, stop and flag it rather than inventing one — that crosses into feature work and belongs in a future version, not this cleanup.

### Step 7 — Remove dead state

- Delete `edit_drag_offset` (unused).
- Either wire up `azn_hover_time`/`AZN_HOVER_DELAY` to actually delay the tooltip per the original spec, or delete both and update `PHASE_4_SPEC.md`'s §7 claim to match reality. Given this is a cleanup pass, prefer deleting the unused delay logic and noting in `changelog.md` that the hover is intentionally instant — re-adding a real delay is a one-line `Timer` addition if ever wanted, not worth the state for now.

### Step 8 — Fix the two patch-shaped issues from analysis.md §5

- Replace the raw `4194309` keycode with `KEY_ENTER` (verify this resolves cleanly in Godot 4.6.1 — confirm in the running editor, not just by reading docs, since this exact class of mistake is what caused the keycode hack in the first place).
- Already covered by step 5's `canvas_rect` fix.

### Step 9 — Re-run the Step 1 checklist

Every item must behave identically to the pre-refactor baseline, except the two items deliberately fixed (zone tool now works; habitas/AZN no longer stack duplicates at one cell). Run this **in the actual Godot editor**, not by re-reading the diff — analysis.md §6 exists precisely because the previous verification passes didn't do this and missed a parse-breaking duplicate function.

### Step 10 — Documentation consolidation

- Delete `docs/versioning/v0.0.2/CHANGELOG.md` and `docs/versioning/v0.0.2/changelog.md`'s stale pre-implementation content; merge anything from `CHANGELOG.md` still worth keeping as history into a single `docs/versioning/v0.0.2/changelog.md` (lowercase, matching v0.0.1's convention), then leave v0.0.2 alone — it's a closed version, don't rewrite history further than reconciling the fork.
- Fold `EDITOR_UI_ANALYSIS.md`, `UI_DESIGN_DECISIONS.md`, `PHASE_2_SPEC.md`, `PHASE_4_ANALYSIS.md`, `PHASE_4_SPEC.md`, `PHASE_4_PLAN.md`, `PHASE_4_POLISH.md`, `PHASE_5_ANALYSIS.md`, `PHASE_5_SPEC.md` into nothing further — they stay as historical record under v0.0.2 (don't delete completed phase docs, that erases real design history), but **no new satellite docs get created for v0.0.3 or beyond**. This plan and `analysis.md` are the only two pre-implementation docs; a single `changelog.md` is the only post-implementation doc. That's the convention going forward, full stop.

---

## 4. Explicit non-goals

- No new tools, no new map fields, no UI redesign.
- No change to the on-disk JSON format — `MapIO`'s merged loader must stay byte-compatible with what the simulator's `MapLoader` (`src/core/map_loader.gd`) expects. If step 3's merge changes any default (e.g. 60×60 vs 80×80), confirm against `src/core/map_loader.gd`'s own default before picking one — don't just prefer "the older number," prefer whichever the simulator actually assumes when a field is missing.
- No attempt to add automated test coverage in this pass. Step 9's manual checklist is the verification mechanism for v0.0.3; a real headless test harness for a Godot `Control` is a bigger, separate undertaking and would itself be scope creep here.

---

## 5. Sequencing summary

| Step | Depends on | Output |
|---|---|---|
| 1. Baseline checklist | — | Recorded current behavior in `changelog.md` |
| 2. Extract `MapDocument` | 1 | Data + mutation isolated; dedup guard added |
| 3. Extract `MapIO` | 2 | Duplicate functions resolved to one each |
| 4. Extract `MapHistory` | 2 | Undo isolated |
| 5. Extract renderer | 2 | `_draw()` delegates; layout magic number fixed |
| 6. Tool dispatch split | 2, 4 | One class per tool; zone tool implemented |
| 7. Remove dead state | 6 | `edit_drag_offset` gone; hover delay resolved |
| 8. Fix keycode | 6 | `KEY_ENTER` replaces magic number |
| 9. Re-verify | 2–8 | Checklist re-run in running editor |
| 10. Docs consolidation | 9 | Single `changelog.md`, no new satellite docs |

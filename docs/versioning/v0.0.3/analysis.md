# v0.0.3 — Diagnosis & Cleanup Analysis

**Status:** Analysis (pre-plan)
**Reference:** [map_editor.gd](../../../src/ui/map_editor/map_editor.gd), [v0.0.2/analysis.md](../v0.0.2/analysis.md), [v0.0.2/plan.md](../v0.0.2/plan.md)
**Model used for v0.0.2 work:** Claude Sonnet 4.6 (`claude-sonnet-4-6`) — same model as this analysis.

---

## 1. Why this document exists

v0.0.2 was built by repeatedly patching `map_editor.gd` in place, phase by phase (terrain → streams → elements → delete/edit → polish → file I/O), with a `analysis.md` / `plan.md` / `CHANGELOG.md` update after almost every commit. The documentation discipline was followed on paper, but each new phase was written **additively** without re-reading what already existed in the file. That is the root cause of every issue below: not lack of process, but process applied to the wrong unit (the diff) instead of the whole file.

This document is the diagnosis. A `plan.md` with the actual refactor steps follows once the diagnosis is agreed.

---

## 2. Critical bug: duplicate function definitions

`map_editor.gd` currently defines the same function **twice**, under the same name, in two different places:

| Function | First definition | Second definition | Status |
|---|---|---|---|
| `_load_map_from_file()` | line 384 (Phase 1) | line 1294 (Phase 5) | **Duplicate signature** |
| `_string_to_density()` | line 450 | line 1276 | **Duplicate signature** |
| `_density_to_string()` | line 458 | line 1258 | **Duplicate signature** |

GDScript does not allow two functions with the same name in one class — this is either a parse error or undefined-behavior shadowing depending on engine version. Either way, the script is broken or running on luck, and this was never caught because **verification so far has been code-inspection only** (see §6) — nobody actually launched the editor and clicked "Load" after Phase 5 landed.

There is a second, quieter version of the same mistake: two more pairs of functions that do the *same job* but were given *different names* in Phase 5, so they don't collide at parse time but are pure duplication:

| Phase 1 name | Phase 5 name | Same logic? |
|---|---|---|
| `_string_to_stream_dir()` (line 466) | `_string_to_stream()` (line 1285) | Yes, identical |
| `_stream_dir_to_string()` (line 474) | `_stream_to_string()` (line 1267) | Yes, identical |

**Root cause:** Phase 5 ("File I/O") was analyzed and specified (`PHASE_5_ANALYSIS.md`, `PHASE_5_SPEC.md`) by reading the *simulator's* JSON format, which was the right call — but never cross-checked against what `map_editor.gd` itself already had. Phase 1 already loaded JSON maps (it has to, to show a default map on editor open). Phase 5 re-implemented loading from scratch instead of extending the Phase 1 implementation.

**Confirmed, not theoretical:** this was verified directly rather than inferred from reading the source. Loading the script headlessly (`load("res://src/ui/map_editor/map_editor.gd")` from a throwaway `SceneTree` script run via `godot4 --headless --script`) produces:

```
SCRIPT ERROR: Parse Error: Function "_density_to_string" has the same name as a previously declared function.
          at: GDScript::reload (res://src/ui/map_editor/map_editor.gd:1258)
ERROR: Failed to load script "res://src/ui/map_editor/map_editor.gd" with error "Parse error".
```

and a subsequent `.new()` on the loaded script fails with `Invalid call. Nonexistent function 'new' in base 'GDScript'` — i.e. the class never compiled. **The map editor cannot currently be instantiated at all.** This has been true since commit `952623e` (Phase 5.1), and went undetected through the Phase 5 "verify" pass because that pass was code-inspection only (§6) — nobody actually launched the editor after that commit landed.

**Functional regressions introduced by the duplicate:** even setting aside the parse problem, the Phase 5 version is worse than the one it collided with:

| Behavior | Phase 1 original (line 384) | Phase 5 duplicate (line 1294) |
|---|---|---|
| Default map size if `width`/`height` missing | 60×60 | 80×80 |
| `default_density` field | Applied to every cell before overlaying explicit cells | **Ignored** — always inits to LOW |
| Zoom/scroll on load | Reset to 1.0 / 0 / 0 | Untouched (stale view persists) |
| Undo history after load | Seeded with one `_save_state()` so Undo has a baseline | Cleared, no baseline state |

---

## 3. Architecture: one 1374-line file, no separation of concerns

`map_editor.gd` is a single `Control` subclass containing, in one file:

- UI construction (`_setup_ui`, ~220 lines of imperative node-building)
- Rendering (`_draw`, `_draw_stream_cell`)
- All input handling (`_input`, ~190 lines)
- The undo/redo stack
- File I/O (load, save, JSON conversion)
- Map-data mutation (paint, flood fill, delete, move, resize)
- Validation

Nothing here is reused elsewhere, so there's no encapsulation boundary forcing a clean interface between these concerns. The practical consequence is exactly the bug in §2: it's easy to add a new "load map" code path without noticing one already exists 900 lines above, because there's no `MapIO` class to look inside — it's just more functions in the same flat list.

**Tool dispatch is stringly-typed and triplicated.** `active_tool` is a bare `String` ("terrain", "stream", "habitas", "azn", "zone", "pan", "edit", "delete"), and the behavior for each tool is spread across three separate `match active_tool:` blocks inside `_input()`: one for mouse-down, one for mouse-drag, one implicitly for cursor update. Tracing "what does the Edit tool do" means reading three non-adjacent switch statements. This is the same shape of problem that caused the earlier "stream and terrain both active at once" bug from v0.0.2 (already fixed once) — the fix added an `_activate_tool()` gate, but the underlying scattering of per-tool logic across multiple switches was never consolidated, so the next tool-related bug (the duplicate loader) had the same growing conditions.

---

## 4. Dead code and unfinished stubs left in place

| Symbol | State |
|---|---|
| `"zone"` tool branch in mouse-down handler (line 733) | `pass` — literal no-op. The "Place Zone" button exists, is wired to `_activate_tool("zone")`, updates the status bar text ("Drag to create rectangle"), and then does nothing when used. |
| `edit_drag_offset` (line 51) | Declared, assigned once to `Vector2i.ZERO`, never read anywhere. |
| `azn_hover_time` / `AZN_HOVER_DELAY` (lines 56–57) | Declared to implement a hover delay; `azn_hover_time` is reset to `0.0` on every hover-enter and never incremented or compared against `AZN_HOVER_DELAY`. The tooltip actually shows instantly. The delay was speced (`PHASE_4_SPEC.md` §8: "Show for 0.5 seconds") but not built — the variables give the false impression that it was. |
| Habitas / AZN placement (lines 688–699) | No dedup check. Clicking the same cell twice with the Habitas or AZN tool stacks two entries at identical coordinates. `_delete_at_position` filters cleanly by position, but placement never checked for an existing entry first. |

---

## 4a. Second confirmed bug: Undo does not cover elements

`_save_state()` (line 1031) only snapshots `cells`:

```gdscript
func _save_state() -> void:
	...
	var state: Array = []
	for row in cells:
		state.append(row.duplicate())
	history.append(state)
```

and `_undo()` (line 1048) only restores `cells`. But `_save_state()` is called before *every* mutating action in the file, including habitas placement, AZN placement, edit-mode moves/resizes, and delete — actions that mutate `habitas_points`, `azn_nodes`, or `injection_zones`, **not** `cells`. The practical effect: clicking Undo after placing a Habitas point, moving an AZN node, or resizing a zone does nothing to that element — it silently undoes the most recent *terrain* change instead (or nothing, if there wasn't one), while still consuming a slot in the 50-entry history ring buffer with a snapshot that was identical to the one before it.

This is not a hypothetical edge case — it is the *only* path for those three element types, since none of them ever touch `cells`. Undo for habitas/AZN/zones has never worked in any commit since Phase 2. The Undo button gives no indication of this (it just looks disabled/enabled based on history depth, same as for terrain).

---

## 5. Patch-shaped fixes that should have been root-fixes

| Symptom | What was actually done | Why it's fragile |
|---|---|---|
| `KEY_RETURN` didn't resolve in Godot 4.6 | Changed to `KEY.RETURN` (also wrong), then to **raw integer `4194309`** with a comment explaining it's Enter | Godot 4 exposes `KEY_ENTER` directly in global scope — that's the actual fix. The magic number works but is unreadable and silently wrong if Godot ever renumbers the enum. |
| Canvas layout needs to know panel width/status bar height | `_draw()` hardcodes `Rect2(0, 30, get_size().x - 250, get_size().y - 45)` | The `250` duplicates the right panel's `custom_minimum_size = Vector2(250, 0)` set independently in `_setup_ui()`. The two numbers are not derived from each other — resizing the panel in one place silently desyncs the canvas in the other. |

Neither of these is wrong today, but both are exactly the kind of thing that turns into the next "why is this broken" session.

---

## 6. Verification gap

The Phase 4 and Phase 5 "verify" passes in this session were code-inspection only — reading the diff and confirming it matched the spec — because there is no `verifier-*` skill for this repo and no headless way to drive a Godot `Control` GUI from the sandbox. That's a legitimate constraint, not a process failure on its own. But it means **the duplicate-function bug in §2 was never going to be caught** by the verification method actually used, because static reading of a diff doesn't reveal that the *base* file already contained a function with the same name 900 lines away. A correctness check that doesn't run the script can't catch a parse error.

---

## 7. Documentation sprawl

v0.0.1 used a clean three-file convention:

```
docs/versioning/v0.0.1/
  analysis.md
  changelog.md
  plan.md
```

v0.0.2 has **twelve files**, including two changelogs that disagree with each other:

```
docs/versioning/v0.0.2/
  analysis.md
  changelog.md        ← stale: written before implementation started, says
                         "Status: Analysis Complete, Ready for Implementation"
  CHANGELOG.md         ← active: actually tracks the commits, different case,
                         different content, never reconciled with changelog.md
  EDITOR_UI_ANALYSIS.md
  UI_DESIGN_DECISIONS.md
  PHASE_2_SPEC.md
  PHASE_4_ANALYSIS.md
  PHASE_4_SPEC.md
  PHASE_4_PLAN.md
  PHASE_4_POLISH.md
  PHASE_5_ANALYSIS.md
  PHASE_5_SPEC.md
  plan.md
```

Per-phase satellite docs (`PHASE_4_*`, `PHASE_5_*`) were created instead of extending the existing `analysis.md` / `plan.md`, which is why there are nine extra files instead of edits to two. On a case-insensitive filesystem `changelog.md` and `CHANGELOG.md` would have collided outright; on this Linux filesystem they coexist and silently diverge instead, which is arguably worse since nothing ever errors.

---

## 8. Summary of root causes

Every issue above traces back to one habit: **adding before reading.** Specifically:

1. New phases were specified by reading the *simulator* and the *spec doc*, but not by reading the *current state of `map_editor.gd`* — hence the duplicate loader and duplicate conversion functions.
2. New tool behaviors were added to `_input()` by finding the right `match` arm and appending a case, not by asking whether the three-switch structure was still the right shape — hence the dispatch sprawl.
3. New planning docs were created per-phase by default, rather than asking whether the existing `analysis.md`/`plan.md` should simply grow — hence twelve files instead of three, and a forked changelog.
4. Quick syntax fixes (`KEY_RETURN` → magic number) closed the error message in front of the model without asking whether a one-line correct fix existed — hence the unreadable keycode.

None of this requires more process — v0.0.2 had plenty of documentation. It requires reading the target file fully before extending it, and treating "does a similar function already exist" as a mandatory question before writing a new one.

---

## 9. What v0.0.3 needs to fix (input to plan.md)

1. **Resolve the duplicate functions.** Keep one implementation each of `_load_map_from_file`, `_string_to_density`/`_density_to_string`, `_string_to_stream_dir`/`_stream_dir_to_string` — merged to keep the correct behavior from both (Phase 1's default-density/zoom-reset/history-seed behavior + Phase 5's bounds-checking and error dialogs).
2. **Split the file** along the seams already implicit in it: map data + mutation, rendering, input/tool dispatch, UI construction, file I/O. Exact module boundaries to be decided in `plan.md`.
3. **Replace the tool system's three-switch spread** with one place per tool that owns its mouse-down/drag/release behavior.
4. **Finish or remove the zone-placement stub** — currently a button that does nothing is worse than no button.
5. **Remove dead state** (`edit_drag_offset`, the unused half of the AZN hover delay) or actually implement what it implies.
6. **Replace the magic keycode** with `KEY_ENTER`; derive the canvas rect from the actual panel size instead of a second hardcoded `250`.
7. **Add a duplicate-placement guard** for habitas/AZN, consistent with how delete already dedupes by position.
8. **Consolidate documentation** back to the three-file convention (`analysis.md`, `changelog.md`, `plan.md`), retire `CHANGELOG.md` and the `PHASE_*` satellite docs by folding anything still relevant into the two canonical files, and delete the stale pre-implementation `changelog.md` content rather than leaving it to contradict the real one.
9. **Establish an actual run-it-and-click verification step** before any future phase is marked done — even a manual checklist run in the Godot editor is better than inspection-only sign-off, given §6.

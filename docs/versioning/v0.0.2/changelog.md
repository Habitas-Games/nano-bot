# v0.0.2 Changelog

**Version:** 0.0.2
**Status:** Superseded by v0.0.3 (see [../v0.0.3/analysis.md](../v0.0.3/analysis.md))
**Date range:** 2026-06-05 to 2026-06-09

---

## Note on this file

This repo briefly had two changelogs for v0.0.2: this file (`changelog.md`, lowercase, matching v0.0.1's convention) and a second `CHANGELOG.md` that diverged from it once real implementation started. This is the reconciled version — it replaces both. The original lowercase file's content was a pre-implementation status note ("Analysis Complete, Ready for Implementation") that never got updated once work actually began, so it isn't reproduced here; the commit history below is what actually shipped. See `docs/versioning/v0.0.3/analysis.md` §7 for why the fork happened.

---

## Commits This Version

### Phase 2: Terrain Editing (Foundation)

**Commit 444b4ba:** Phase 2: Full implementation per locked specification
- Implemented terrain painting (left-click), drag painting, flood fill (right-click)
- Implemented clear map and add border buttons, undo system (50 state limit)
- Added brush indicator (white outline on painted cell)
- **Issues found:** stream and terrain modes both active simultaneously; scrollbars broken; element/stream placement partially implemented

### Bug Fixes & Refactoring

- **bda2cce:** Fixed GDScript 4.6 dictionary literal syntax (`{key: value}` → `{"key": value}`)
- **a327c40:** Moved Load/Save into the Tools section in the right panel
- **13981e5:** Removed broken scrollbars, added hand cursor for panning

### Architecture: Exclusive Tool Mode

**38ee586:** One tool active at a time. Root cause was no `active_tool` concept — input handlers checked all modes independently, so terrain and stream could both respond to the same click.

### Feature: Pan Tool

**ff741be:** Pan made an explicit tool (button + left-drag) instead of an implicit middle-click, so it could participate in the new exclusive-tool-mode model.

### Bug Fixes

- **7ada7a4:** Stream texture rendering fallback (dark red placeholder if texture fails to load, instead of solid black)
- **5fe14fe:** Tool deactivation made global (`_deactivate_all_tools()`); removed middle-click panning entirely so Pan tool is the only way to pan
- **27b8174:** Stream placement got drag-to-place, matching terrain's behavior
- **9c27c8c:** Clear Map fixed to actually clear streams and elements (previously only cleared terrain density); removed the "Add Border" feature (misunderstood requirement carried over from an earlier prototype)

### Phase 4: Element Editing (Delete & Edit Tools)

- **0a268ed:** Delete tool — drag to erase terrain, streams, and elements in one pass
- **428e0d4:** Edit tool — click to select a habitas/AZN/zone, drag to move it
- **6e0afc9:** Visual selection highlights (yellow for habitas/AZN, white for zones)
- **2238e02:** AZN hover tooltip showing quantity
- **2ca8fd7 / 45c8e4d / 9ddc127:** Zone corner resize, AZN quantity edit dialog, and the `KEY_RETURN` → `KEY.RETURN` → raw keycode `4194309` saga (see v0.0.3 analysis §5 — the raw keycode was a workaround, not the real fix)

### Phase 5: File I/O

- **952623e (Phase 5.1):** Implemented save/load JSON, validation, and enum↔string conversion functions in `map_editor.gd`.
  **This commit introduced a parse-breaking bug**: `_load_map_from_file`, `_density_to_string`, and `_string_to_density` were each defined a second time under the same name as functions Phase 1 already had 900 lines earlier in the file. GDScript does not allow duplicate function names — the script could not be instantiated from this commit until it was fixed in v0.0.3. This went undetected because the verification pass after this commit was code-inspection only, not an actual run of the editor. Full diagnosis: `docs/versioning/v0.0.3/analysis.md` §2.

---

## End-of-version status

Phase 2 (terrain/stream editing) and Phase 4 (element edit/delete) were functionally complete and had been manually tested through the UI before Phase 5 landed. Phase 5 (file I/O) was implemented but **broke the editor's ability to load at all**, and was not caught before this version closed out. v0.0.3 is a dedicated cleanup version to fix that and the structural issues that allowed it to happen.

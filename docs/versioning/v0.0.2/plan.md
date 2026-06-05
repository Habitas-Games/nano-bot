# v0.0.2 Implementation Plan

## Goals
1. ✅ Complete requirements analysis
2. ✅ Define exact specifications matching simulator
3. ✅ Plan phased implementation approach
4. ❌ Implement Phase 1 (planned for v0.1)

## What Was Done in v0.0.2
- Analyzed all previous failures
- Created `analysis.md` with comprehensive requirements
- Documented simulator as ground truth
- Defined visual specifications
- Established 4-phase development plan
- Created testing checklist

## Key Specifications Locked

### Layout (EXACT)
```
┌─────────────────────────┬──────────┐
│                         │          │
│   Canvas (85%)          │ Panel    │
│   Map Grid              │ (15%)    │
│                         │          │
│   Scrollbars at edges   │          │
└─────────────────────────┴──────────┘
```

### Bloodstream Display (CRITICAL)
- Red/brown directional arrows (NOT cyan)
- Arrow size scales with zoom
- No background tile color
- Overlaid on terrain

### Implementation Phases
**Phase 1**: Canvas & Grid
- Proper 85/15 layout
- Grid rendering
- Map loading
- Zoom/pan

**Phase 2**: Terrain Tools
- Click to paint
- Drag to paint multiple
- Right-click flood fill
- Save/load

**Phase 3**: Elements
- Bloodstreams (arrows)
- Habitas points (diamonds)
- AZN nodes (circles)
- Injection zones (rectangles)

**Phase 4**: Polish
- Scrollbar rendering
- Status display
- History/undo
- Error handling

## Why This Approach
Previous attempts failed because:
1. No clear requirements - just coded
2. Tried to do everything at once
3. Didn't match simulator layout
4. Bloodstreams were completely wrong
5. No testing baseline

**v0.0.2 fixes this by**:
- Locking requirements first
- Phased implementation
- Simulator as reference
- Detailed testing checklist

## Files to Update
- `src/ui/map_editor/map_editor.gd` - Full rewrite (next version)
- `scenes/map_editor_scene.tscn` - Layout only (next version)

## Success Criteria
- [ ] Analysis accepted by user
- [ ] All requirements locked
- [ ] Ready to start Phase 1 implementation

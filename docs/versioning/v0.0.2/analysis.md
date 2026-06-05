# Map Editor - Requirements Analysis (v0.0.2)

## Current State
The map editor is **not working properly**. Multiple implementation attempts have failed because of:
- Rushing to code without understanding simulator layout
- UI layout mismatches with simulator
- Incomplete/broken drawing and input handling
- No clear requirements document

## Simulator Reference (Ground Truth)
The simulator shows:
- **Left side (85% width)**: Map canvas with terrain grid
- **Right side (15% width)**: Control panel with stats, legend, controls
- **Top of canvas**: Status bar with controls info
- **Bottom of canvas**: Jump to turn slider + horizontal scrollbar
- **Bloodstreams**: Rendered as **colored directional arrows** overlaid on terrain
  - Red/brown colored arrows (not cyan)
  - Direction indicated by arrow pointing
  - No full-tile background color
- **Habitas Points**: Gold/orange diamond shapes
- **AZN Nodes**: Yellow circles with quantity label
- **Injection Zones**: Colored rectangular overlays (green/red)
- **Terrain**: Visible as tiles beneath all elements

## Map Editor Requirements (v0.1)

### Visual Design
- **Layout**: 85% canvas (left) + 15% panel (right) - EXACTLY matching simulator
- **Canvas**: Display terrain grid with proper tile coloring
- **Panel**: Right sidebar with controls organized by section
- **Colors and styling**: Match simulator color scheme exactly
- **Scrollbars**: Visible and functional at bottom/right of canvas

### Functionality Needed
1. **Terrain Editing**
   - Select density (low, medium, high, bone)
   - Click to paint single cell
   - Drag to paint multiple cells
   - Right-click to flood-fill

2. **Bloodstream Editing** 
   - Display as directional arrows (not full tiles)
   - Select direction (N, S, E, W, N-S, E-W)
   - Click to place arrow
   - Arrow color: match simulator (red/brown)

3. **Element Placement**
   - Habitas Points: click to place gold diamonds
   - AZN Nodes: click to place yellow circles
   - Injection Zones: click-drag to create colored rectangles with player assignment

4. **Map Controls**
   - Load existing maps from maps/ directory
   - Clear map
   - Undo/Redo with full history
   - Save map as JSON (preserving all elements)

5. **Canvas Controls**
   - Scroll wheel to zoom (0.5x - 3.0x)
   - Middle-click drag to pan
   - Scrollbars at bottom/right edges

### Key Differences from v0.0.1 Attempt
- ❌ Bloodstreams were full cyan tiles - should be arrows only
- ❌ Arrow colors were cyan/light - should match simulator red/brown
- ❌ UI layout didn't match simulator proportions
- ❌ Missing proper scrollbar implementation
- ❌ Input handling not properly accounting for canvas offset

## Implementation Strategy

### Phase 1: Core Canvas (Do First)
1. Create proper layout: 85% left (canvas) + 15% right (panel)
2. Draw grid with proper colors
3. Load and display map data
4. Implement zoom/pan

### Phase 2: Editing Tools
1. Terrain painting (click + drag)
2. Flood fill (right-click)
3. Save/Load maps

### Phase 3: Elements
1. Bloodstreams as directional arrows
2. Habitas points
3. AZN nodes
4. Injection zones with drag-to-create

### Phase 4: Polish
1. Scrollbar rendering
2. Status display
3. Keyboard shortcuts
4. Better error handling

## Critical Success Factors
- **Match simulator layout exactly** - no approximations
- **Arrow-only bloodstreams** - not full tiles with arrows
- **Proper canvas offset calculations** - all input math must be exact
- **Persistent history** - undo/redo with full state preservation
- **Valid JSON export** - must match existing map format

## Files to Create/Modify
- `src/ui/map_editor/map_editor.gd` - Complete rewrite
- `src/ui/map_editor/canvas_renderer.gd` - Optional: separate drawing logic
- `scenes/map_editor_scene.tscn` - Update layout
- Update main menu to launch editor

## Testing Checklist
- [ ] Load simple_tissue map - displays correctly
- [ ] Paint terrain - appears on canvas
- [ ] Flood fill - works across regions
- [ ] Place bloodstreams - shows as arrows
- [ ] Place all elements - display correctly
- [ ] Zoom/pan - controls work
- [ ] Save map - JSON is valid
- [ ] Layout matches simulator proportions

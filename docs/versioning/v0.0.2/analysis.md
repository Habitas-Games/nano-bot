# Map Editor v0.1 - Requirements Analysis

## 1. PROBLEM STATEMENT

### Current Situation
The nano-bot game needs a way to create game maps. Currently, maps are:
- Hand-crafted JSON files
- Difficult to visualize during creation
- Error-prone (invalid coordinates, missing elements)
- Time-consuming to modify
- Impossible to preview without loading the simulator

### Why Previous Editor Attempts Failed
1. **Copied game UI into editor** - The simulator is for playing, not editing. Different tools have different interaction patterns.
2. **Over-engineered complexity** - Tried to include everything, resulting in confusing, non-functional buttons.
3. **No clear interaction model** - Users couldn't understand what buttons did or how to use them.
4. **Mismatch between layout and purpose** - 85/15 split was arbitrary, not based on editing patterns.
5. **Bloodstream display wrong** - Showed as tiles with arrows, but needed as arrows only.
6. **Mixed concerns** - Tried to make it look like the simulator instead of being a good editor.

### Root Cause
**Designing by committee/feedback instead of designing for a purpose.** The editor wasn't built to solve the actual problem of "create maps efficiently" - it was built to "look like the simulator."

---

## 2. WHAT WE ACTUALLY NEED

### Core Problem to Solve
A human needs to create game maps by:
1. Defining terrain layout (which cells are passable, cost to cross)
2. Placing game elements (resources, spawn points, scoring locations, flows)
3. Saving the result so the game can use it

### Minimum Viable Product (MVP)
The editor MUST support:

#### Must Have (Core Features)
1. **Terrain painting** - Select density, click to paint cells
2. **Flood fill** - Fill large regions quickly
3. **Element placement** - Place bloodstreams, habitas, AZN, zones
4. **Visualization** - See what you're creating (sprites, colors, layout)
5. **Load/save** - Persist maps as JSON
6. **Undo** - Revert mistakes

#### Should Have (Important for Usability)
1. **Zoom/pan** - Navigate large maps
2. **Multiple maps** - Load existing maps to edit
3. **Map info** - See what's on the map (statistics)
4. **Clear feedback** - Know what tool is active
5. **Scrollbars** - Navigate without middle-click drag

#### Nice to Have (Polish)
1. Keyboard shortcuts
2. Map validation warnings
3. Element deletion/editing
4. Redo functionality
5. Recent maps list

### What's NOT Needed
- ❌ Match simulator appearance exactly (different tools)
- ❌ Complex UI themes or styles
- ❌ Game mechanics (simulation, units, scoring)
- ❌ Export to multiple formats
- ❌ Network/multiplayer features

---

## 3. HOW WE SHOULD BUILD IT

### Design Principle: Editor Pattern vs Game Pattern

**Game Pattern** (Simulator):
- Information-dense right panel showing game state
- Viewer focus (watch what's happening)
- Minimal interaction (play or observe)
- Example: showing turn counter, scores, bot status

**Editor Pattern** (What We Need):
- Tool panel showing available actions
- Creator focus (I am making something)
- Maximum interactivity (I control everything)
- Example: showing paint options, element types, creation tools

**Why this matters:** The simulator shows "what the game looks like." The editor shows "how to make the game." Completely different purposes.

### Layout Strategy: Industry-Proven Pattern

Professional editors (Unity, Unreal, Godot) use:
```
TOOLS          CANVAS         PROPERTIES
(20% width)    (60% width)    (20% width)
```

**Why this layout works:**
- Tools on left: Contextual (only show relevant options)
- Canvas center: Main focus (where work happens)
- Properties right: Reference/feedback (what you created)
- Proportions: Optimized through decades of UI design

**Why NOT simulator's 85/15:**
- Simulator needs 85% for game view, 15% for stats (game pattern)
- Editor needs balanced space (tool pattern)
- Arbitrary choice doesn't match editor workflows

### Navigation Strategy: Multiple Methods

Users navigate maps in different ways:

**Method 1: Zoom**
- Scroll wheel: Most common, intuitive
- Range: 0.5x to 3.0x (zoomed out to zoomed in)
- Center on mouse: Zoom toward what user is looking at

**Method 2: Pan**
- Middle-click drag: Second mouse button is natural for panning
- Arrow keys: For keyboard-focused users (optional Phase 5)
- Scrollbars: Precise control, visual indicator of position

**Why three methods?** Users have different preferences. Forcing one method is frustrating.

### Interaction Strategy: Mode-Based Editing

User workflow:
1. **Select what to do** (terrain, elements)
2. **Configure how** (which density, which direction)
3. **Do it** (click/drag on canvas)
4. **Feedback** (properties panel updates)

**Why mode-based?**
- Clear: User knows what's active
- Safe: Can't accidentally place something wrong
- Consistent: Same pattern for all operations

**Why NOT free-form buttons?**
- Confusing: Click "LOW" button - then what?
- Ambiguous: Did I select or place?
- Unreliable: Easy to forget what mode you're in

---

## 4. WHY THIS ARCHITECTURE

### Canvas Rendering (Direct _draw())

**Choice:** Use Control._draw() for custom rendering instead of scene nodes

**Why:**
- Single draw call = fast
- Full control over rendering order
- Easier coordinate math
- Simpler zoom/pan (just change variables, redraw)

**Alternative rejected:** Scene nodes for each tile
- Much slower (thousands of nodes)
- Complex coordinate updates on pan
- Harder to manage overlapping elements

### Separate Data Arrays (Not Grid-Based)

**Choice:** Grid stores terrain, separate arrays for bloodstreams/elements

**Why:**
- Terrain is dense (every cell has one)
- Elements are sparse (few cells have them)
- Memory efficient
- Easy to iterate elements only
- Matches JSON export format

**Alternative rejected:** Grid stores all data
- Wastes memory (most cells have no elements)
- Complex data structure
- Harder to query "all bloodstreams"

### History with Snapshots

**Choice:** Array of full grid snapshots for undo/redo

**Why:**
- Reliable (full state, can't get corrupted)
- Simple implementation
- Works for all operations
- Intuitive to users

**Limitation:** 50 states = ~2MB for 80x80 maps
- Acceptable for desktop editor
- Could optimize if needed (future)

### JSON Format (Simulator Compatible)

**Choice:** Save in exact same format as existing maps

**Why:**
- Maps are immediately playable
- No conversion step needed
- Validation against existing maps
- Users can mix hand-crafted and editor-created maps

---

## 5. CRITICAL DECISIONS & TRADE-OFFS

### Decision 1: Bloodstream Display

**Options:**
- A) Full cyan tile with arrow overlay (old approach)
- B) Arrow only, no background color
- C) Special visual treatment (glow, animation)

**Choice:** B (Arrow only)

**Why:**
- Matches simulator display
- Doesn't obscure terrain
- Simple to implement
- Clear directional indicator

**Trade-off:** Arrows are small, hard to see at low zoom
- Acceptable: Zoom in to place them precisely
- Acceptable: Makes deliberate placement (not accidental)

### Decision 2: UI Layout Proportions

**Options:**
- A) 85/15 (canvas/panel) - simulator style
- B) 70/30 (canvas/tools) - game development style
- C) 20/60/20 (tools/canvas/properties) - professional style

**Choice:** C (20/60/20)

**Why:**
- Both tools AND properties are important
- Balanced for editing work
- Industry standard (proven through use)
- Tools on left = discoverable
- Properties on right = feedback

**Trade-off:** Canvas is smaller (60% vs 85%)
- Acceptable: Zoom solves this
- Acceptable: Real estate for tools is essential
- Benefit: Can see properties while editing

### Decision 3: Element Placement Method

**Options:**
- A) Toolbar buttons at top
- B) Left panel grouped tools
- C) Context menu on right-click
- D) Keyboard shortcuts only

**Choice:** B (Left panel grouped)

**Why:**
- Discoverable (all options visible)
- Contextual (expandable groups)
- No accidental activations
- Room for options per element type

**Alternative considered:** A + B hybrid
- Top toolbar for quick access (save, undo)
- Left panel for detailed options (terrain, elements)

**Trade-off:** Requires scrolling in left panel
- Acceptable: Panels are designed for scrolling
- Benefit: Organized, not overwhelming

### Decision 4: Save Location

**Choice:** user://custom_map.json (user home directory)

**Why:**
- User controls files
- Not in game asset directory (doesn't clutter)
- Persistent across game updates
- Shareable by users

**Alternative rejected:** res://maps/
- Would clutter asset directory
- Hard to backup user work
- Not ideal for user-created content

---

## 6. REQUIREMENTS BY PRIORITY

### MUST HAVE (Non-negotiable)

**R1: Core Terrain Painting**
- User can select density
- User can paint by clicking/dragging
- Happens immediately (no confirmation)
- ONE history state per interaction

*Why:* Without this, the editor doesn't solve the core problem

**R2: Terrain Visualization**
- Tiles display with sprites or colors
- Grid lines visible
- Current selection highlighted
- Layout matches simulator (for familiarity)

*Why:* User must see what they're creating

**R3: Element Placement**
- All four element types placeable (bloodstreams, habitas, AZN, zones)
- Visually distinct (colors, shapes)
- Correct data format (matches simulator)

*Why:* Maps are incomplete without elements

**R4: Save/Load JSON**
- Maps save in valid JSON
- Format matches simulator exactly
- Can be played without editor

*Why:* Editor is useless if maps don't work in game

**R5: Undo Function**
- Reverts last action
- Works for all operations
- Shows in UI (button visible)

*Why:* Users will make mistakes; undo is essential

### SHOULD HAVE (Important but could workaround)

**R6: Zoom and Pan**
- Zoom: 0.5x to 3.0x via scroll wheel
- Pan: Middle-click drag or scrollbars
- Handles 80x80+ maps

*Why:* Large maps are unusable without navigation

**R7: Flood Fill**
- Right-click fills connected region
- Works with any density
- Includes in history

*Why:* Much faster than clicking each cell for large areas

**R8: Map Information**
- Shows map size
- Lists element counts
- Color legend (like simulator)

*Why:* User should understand what they created

### NICE TO HAVE (Polish, can add later)

**R9: Clear Map Button**
- Reset to blank state (all "low")
- Confirmation dialog

**R10: Add Border Button**
- Auto-fill edge cells with bone
- One history state

**R11: Status Bar**
- Show current tool
- Show coordinates on hover
- Show messages

**R12: Keyboard Shortcuts**
- Ctrl+S: Save
- Ctrl+Z: Undo
- Arrow keys: Pan (alternative to middle-click)

---

## 7. RISKS & MITIGATION

### Risk 1: Coordinate Math Errors
**Problem:** Click in wrong position, paint wrong cell
**Likelihood:** High (common in previous attempts)
**Impact:** High (unusable)

**Mitigation:**
- Careful testing of screen→grid conversion
- Visual feedback (highlight cell before painting)
- Status bar shows coordinates
- Test at various zoom/pan positions

### Risk 2: Performance Issues
**Problem:** Large maps lag or stutter
**Likelihood:** Medium (complex rendering)
**Impact:** Medium (frustrating, not broken)

**Mitigation:**
- Single _draw() call (not thousands of nodes)
- Only draw visible tiles (cull off-screen)
- Test with 80x80 maps
- Profile rendering performance

### Risk 3: JSON Format Incompatibility
**Problem:** Saved maps don't load in simulator
**Likelihood:** Medium (easy to get wrong)
**Impact:** High (maps are broken)

**Mitigation:**
- Validate against existing map structure
- Test load→save→load cycle
- Round-trip testing with multiple maps
- Parser same as simulator uses

### Risk 4: Undo State Bloat
**Problem:** History consumes too much memory
**Likelihood:** Low (50 states at 800KB each = 40MB max)
**Impact:** Low (editor just uses more RAM)

**Mitigation:**
- Limit history to 50 states (configurable)
- Document memory usage
- Could optimize later (delta compression)

---

## 8. SUCCESS METRICS

### Functional Success (Must Work)
- ✓ Paint terrain in all four densities
- ✓ Fill regions with right-click
- ✓ Place all element types
- ✓ Undo reverts changes
- ✓ Save creates valid JSON
- ✓ Load displays saved maps correctly
- ✓ Zoom/pan work smoothly
- ✓ No crashes or corrupted data

### Usability Success (Makes Sense)
- ✓ User understands what each tool does
- ✓ No confusing buttons (every button has clear purpose)
- ✓ Interactions feel natural (click to paint, drag to fill region)
- ✓ Feedback is immediate (see changes right away)
- ✓ Layout matches other editors (not surprising)

### Quality Success (Feels Good)
- ✓ 60+ FPS even with pan/zoom
- ✓ No lag when painting
- ✓ Scrollbars are smooth
- ✓ UI is responsive (no hanging)
- ✓ Error messages are helpful

---

## 9. WHAT THIS ANALYSIS MEANS

### Summary
We're building an **editor**, not a game UI. Editors have:
- Tool panels (left)
- Working area (center)
- Properties/feedback (right)

We're NOT copying the simulator. The simulator is for playing, the editor is for creating.

### Key Principles
1. **Purpose-driven** - Every element solves a problem
2. **Discoverable** - Tools are obvious, not hidden
3. **Feedback-rich** - User sees what they created
4. **Reliable** - No confusing states or hidden behaviors
5. **Familiar** - Follows editor patterns users know

### Success Looks Like
A user can:
1. Open the editor
2. Paint terrain in under 30 seconds
3. Place elements correctly
4. Save a working map
5. Load it in the simulator
6. Have it work perfectly

That's the goal. Everything else is noise.


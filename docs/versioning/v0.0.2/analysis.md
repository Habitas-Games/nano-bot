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

## 9. COMPONENT ANALYSIS

### What is a Component?
A discrete UI/functional element that serves one specific purpose. Each component must be justified.

---

### COMPONENT 1: Canvas (Map Drawing Area)

**What it is:** Central area where user paints/places elements. Shows grid of tiles.

**Purpose:** 
- Display the map being edited
- Receive all primary user input (painting, placing)
- Show visual feedback (selected cells, hover highlights)

**Responsibilities:**
- Render terrain grid with sprites
- Render bloodstream arrows
- Render element positions (habitas, AZN, zones)
- Draw grid lines
- Highlight selected cell
- Convert screen coords to grid coords
- Accept left-click, right-click, middle-click input

**Dependencies:**
- Grid data (terrain density array)
- Bloodstreams array
- Elements arrays (habitas, AZN, zones)
- Sprite assets
- Zoom/scroll state

**Does it make sense?** ✓ YES
- Without canvas, there's no map editing
- Essential, non-negotiable

**What it needs:**
- Coordinate system (screen → grid conversion)
- Collision detection (which cell am I clicking?)
- Rendering order (terrain, then elements, then highlight)
- Visual feedback on hover (show coordinates)

---

### COMPONENT 2: Left Panel - Tool Groups

**What it is:** Vertical panel with expandable sections (Terrain, Elements, Zones, etc.)

**Purpose:**
- Show available tools in one place
- Let user select what to do
- Show configuration options for each tool

**Responsibilities:**
- Display terrain density options (LOW, MEDIUM, HIGH, BONE)
- Display element type options (Habitas, AZN, Streams, Zones)
- Show element-specific options (stream direction, zone player)
- Show action buttons (Add Border)
- Visual feedback for selected option

**Dependencies:**
- Selected tool state
- Selected density state
- Selected element type state
- Selected element config (direction, player, quantity)

**Does it make sense?** ✓ YES
- User needs to select what to do before doing it
- Centralizes all options
- Standard pattern (left toolbar)
- Essential for discoverability

**What it needs:**
- Clear visual feedback (what's selected)
- Organized grouping (so it's not overwhelming)
- Expandable sections (hides non-essential options)
- Tooltips (explain what each button does)

---

### COMPONENT 3: Right Panel - Legend & Info

**What it is:** Display panel showing map information and reference guide.

**Purpose:**
- Show what user created (statistics)
- Provide color reference (like simulator legend)
- Show details of selected element
- Feedback on what's on the map

**Responsibilities:**
- Display map name, dimensions
- Show color legend (terrain types)
- Show element legend (symbols)
- Display statistics (cell counts, element counts)
- Show selected element details (if any)
- Live-update as user edits

**Dependencies:**
- Map data (to calculate statistics)
- Current selection (to show details)
- Grid state (to count cells)

**Does it make sense?** ✓ YES
- User should know what they created
- Statistics reveal problems (e.g., "no habitas points")
- Reference guide helps remember colors
- Feedback closes the loop (I painted, I can see the result)

**What it needs:**
- Live updating (whenever grid changes)
- Accurate counting algorithm
- Clear formatting (easy to scan)
- Selection details when element selected

---

### COMPONENT 4: Top Toolbar

**What it is:** Horizontal bar with quick-access buttons for file and history operations.

**Purpose:**
- Provide quick access to common operations
- Standard location for file operations
- Minimize visits to dialogs

**Responsibilities:**
- Load Map button (opens file picker)
- Save button (exports JSON)
- Clear button (reset map)
- Undo button (revert last action)
- Zoom info (show current level, presets)
- Pan help (keyboard shortcut hint)

**Dependencies:**
- File system (to load/save)
- History state (for undo enabled/disabled)
- Zoom state
- Map data

**Does it make sense?** ✓ MOSTLY
- Load/Save are essential (file operations belong in toolbar)
- Undo is frequent, deserves quick access
- Clear is destructive (should be visible but not prominent)

**What it needs:**
- Confirmation dialogs (for destructive ops)
- Clear visual hierarchy (Save prominent, Clear less so)
- State feedback (Undo disabled if nothing to undo)

**Question:** Does Zoom belong here or in right panel?
- Current choice: Quick access (toolbar) + info display (right)
- Reasonable but could be debated

---

### COMPONENT 5: Scrollbars

**What it is:** Horizontal and vertical bars for navigation.

**Purpose:**
- Allow precise navigation without middle-click
- Visual indicator of scroll position
- Accessibility (some users prefer scrollbars)

**Responsibilities:**
- Display current scroll position
- Allow clicking to jump
- Allow dragging for smooth scroll
- Update on zoom/pan changes
- Calculate thumb size based on visible ratio

**Dependencies:**
- Scroll state (scroll_x, scroll_y)
- Map size
- Visible canvas size
- Zoom level

**Does it make sense?** ✓ YES
- Navigation is essential for large maps
- Scrollbars are standard UI element
- Provides accessibility alternative to middle-click
- Visual feedback of position

**What it needs:**
- Proper range calculation (based on map size * zoom)
- Thumb size reflects visible ratio
- Smooth interaction (no stuttering)
- Visual styling (clear appearance)

---

### COMPONENT 6: Status Bar / Coordinate Display

**What it is:** Text area showing useful information.

**Purpose:**
- Show user what's happening
- Display grid coordinates on hover
- Show error messages
- Display hints

**Current state in analysis:** NOT INCLUDED

**Should it exist?** ✓ YES
- Coordinates are useful for precision placement
- Messages inform user (no action taken, too many cells, etc.)
- Hints guide first-time users

**Why it's missing:** Oversight in analysis. Should be added.

**What it needs:**
- Coordinate display (X, Y when hovering)
- Message queue (temporary status messages)
- Hint text (e.g., "Right-click to flood fill")

---

### COMPONENT 7: File Load Dialog

**What it is:** UI for selecting which map to load.

**Purpose:**
- Let user browse available maps
- Select one to open in editor

**Responsibilities:**
- List all .json files in maps/
- Show map name (filename without extension)
- On selection: load map, clear history, reset view
- On cancel: close dialog, return to editor

**Dependencies:**
- File system access
- JSON parsing
- Map data structure

**Does it make sense?** ✓ YES
- Can't edit maps without loading them
- Necessary for iterative editing

**What it needs:**
- File list from res://maps/ directory
- Error handling (file not found, invalid JSON)
- Feedback (loading... spinner, loaded successfully)

---

### COMPONENT 8: Undo/History System

**What it is:** Mechanism to store and revert map states.

**Purpose:**
- Allow user to undo mistakes
- Provide confidence to experiment

**Responsibilities:**
- Save state before each action
- Maintain array of states (max 50)
- Revert to previous state on undo
- Track history position
- Disable undo when at oldest state

**Dependencies:**
- Full grid state
- Element arrays state
- History array
- History index

**Does it make sense?** ✓ YES
- Users will make mistakes
- Undo is expected feature
- Essential for usability

**What it needs:**
- Proper state copying (not references)
- Memory management (max 50 states)
- Clear disabled state (button greyed out)

---

### COMPONENT 9: Mode/Tool Selection System

**What it is:** Mechanism to track what the user is currently doing.

**Purpose:**
- Ensure user knows their active tool
- Prevent confusion (am I painting terrain or placing habitas?)
- Route input to correct handler

**Current state:** Described as left panel with groups

**Does it make sense?** ✓ YES
- Mode prevents accidents
- Clear state reduces confusion
- Essential for complex interactions

**What it needs:**
- Single active mode at a time
- Visual feedback of current mode
- Mode-specific options shown/hidden
- Transitions are clear (old mode hidden, new shown)

---

## 10. MISSING COMPONENTS ANALYSIS

### Missing Component A: Confirmation Dialogs

**What:** Dialogs asking "Are you sure?" for destructive operations

**Operations that need it:**
- Clear map (deletes everything)
- Load map (discards unsaved changes)

**Why it's missing:** Oversight in analysis

**Should it exist?** ✓ YES
- Destructive operations should have safety net
- Users accidentally click things
- Standard UX pattern

**What it needs:**
- "Are you sure?" message
- Cancel button (safe default)
- Confirm button (red/warning color)
- List what will happen

---

### Missing Component B: Error Display

**What:** Show errors when something fails

**Scenarios:**
- Load fails (file not found, invalid JSON)
- Save fails (permission denied, disk full)
- Paint fails (unexpected condition)

**Why it's missing:** Assumed it wouldn't fail, but it will

**Should it exist?** ✓ YES
- Users need to know when something went wrong
- Prevents silent failures
- Helps debugging

**What it needs:**
- Error message display (temporary popup or panel)
- Clear explanation (not technical jargon)
- Action to take (retry, check file, etc.)

---

### Missing Component C: Selection Highlighting

**What:** Visual indication of what's selected on canvas

**Examples:**
- Current cell (yellow border, different color)
- Selected element (outline, glow, highlight)
- Brush preview (before clicking)

**Why it's missing:** Assumed but not fully described

**Should it exist?** ✓ YES (CRITICAL)
- Shows what will happen before it happens
- Prevents mistakes
- Provides visual feedback
- Essential for usability

**What it needs:**
- Cell under cursor: highlight it
- Element selected: show details in right panel
- Before paint: show which cell will change
- Visual style: distinct but not garish

---

### Missing Component D: Zoom Indicator

**What:** Show current zoom level (e.g., "1.5x" or "150%")

**Where:** In toolbar or corner

**Why it's missing:** Described as part of toolbar but not detailed

**Should it exist?** ✓ YES (NICE-TO-HAVE)
- User should know their zoom level
- Useful for reporting bugs
- Helps understand why things look small/large

**What it needs:**
- Current zoom display
- Zoom presets (0.5x, 1.0x, 2.0x, 3.0x)
- Zoom slider (optional)

---

### Missing Component E: Input Validation

**What:** Check if user actions make sense

**Examples:**
- "You placed 0 habitas points - game requires at least 2"
- "No injection zones defined - game won't start"
- "AZN node in unreachable cell - game will ignore it"

**Why it's missing:** Not considered in analysis

**Should it exist?** ✓ MAYBE (Phase 5 - Polish)
- Prevents broken maps
- Educates user about requirements
- But: Could be annoying (warnings for everything)

**Trade-off:**
- Include basic validation (at least 1 habitas)
- Skip nitpicky validation (reachability analysis)

**What it needs:**
- Rule list (minimum requirements)
- Warning display (doesn't block save)
- Clear explanation (why is this a problem?)

---

### Missing Component F: Keyboard Shortcuts

**What:** Direct keyboard commands for common operations

**Examples:**
- Ctrl+S: Save
- Ctrl+Z: Undo
- Arrow keys: Pan
- 1-4: Select terrain density (LOW-BONE)

**Why it's missing:** Listed as "Phase 5 Polish" but not detailed

**Should it exist?** ✓ YES (Phase 2 minimum)
- Power users expect shortcuts
- Essential for efficiency
- Standard patterns (Ctrl+S for save)

**What it needs:**
- Map of shortcut → action
- Display in UI (tooltip or help)
- Help/About showing all shortcuts

---

## 11. COMPONENT DEPENDENCY MAP

```
Canvas (Core)
├── requires: Grid data, Sprites, Zoom state, Scroll state
├── provides: Visual feedback, Click locations
└── updates: Selection highlight, Coordinate display

Left Panel
├── requires: Tool list, Element list
├── provides: Selected tool, Selected density, Selected element
└── updates: Based on user clicks

Right Panel
├── requires: Map data, Statistics calculator
├── provides: Reference information
└── updates: Live as grid changes

Toolbar
├── requires: File system, History state
├── provides: File operations, Undo trigger
└── updates: Undo button enabled/disabled

Scrollbars
├── requires: Scroll state, Canvas size, Map size
├── provides: Visual scroll position, Jump locations
└── updates: When zoom/pan changes

History System (Core)
├── requires: Full map state
├── provides: Previous state
└── updates: On every action

Input Handler
├── requires: All components
├── provides: Coordinated input handling
└── updates: Tool-specific behavior
```

---

## 12. SUMMARY: WHAT MAKES SENSE

### Essential (Must Have)
- ✓ Canvas (map display and painting)
- ✓ Left panel (tool selection)
- ✓ History system (undo)
- ✓ File operations (load/save)
- ✓ Input handler (coordinate math)

### Important (Should Have)
- ✓ Right panel (feedback and reference)
- ✓ Scrollbars (large map navigation)
- ~ Status bar (coordinates and messages)
- ~ Selection highlighting (visual feedback)

### Missing Critical
- ✗ Confirmation dialogs (safety)
- ✗ Error display (debugging)
- ✗ Selection highlighting (usability)

### Should Add Later (Phase 2+)
- Keyboard shortcuts
- Validation warnings
- Zoom indicator
- Help/About dialog



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


# Editor UI Design - Your Decisions + My Layout Proposals

**Status:** Design locked, ready for implementation planning

---

## Your Design Decisions (Locked)

✅ **Terrain Selection:** Tile images as buttons + hover text (cost)
✅ **Stream Direction:** One row with 4 direction icons + title label
✅ **Element Placement:** Click to place, drag to move objects
✅ **Terrain Brush:** When dragging paint, show brush effect over tiles
✅ **Undo:** Undo only (no redo)
✅ **Validation:** Defer to Phase 5 (after other features done)
✅ **Map Pan:** Hand cursor when middle-click dragging map

---

## Drag Interactions (Need Clarity)

**What we have:**
- Left-click drag: Paint terrain with brush
- Right-click: Flood fill
- Middle-click drag: Pan map with hand cursor
- Element drag: Move placed objects

**Questions:**

### 1. Brush Appearance
When dragging to paint, should we show:

**Option A: Highlight the cell being painted**
```
Live preview of what will be painted as cursor moves
```

**Option B: Brush circle/square around cursor**
```
Visual indicator of brush size/shape
```

**Option C: Trail of painted tiles**
```
Show all tiles that will be painted (already doing this)
```

**Which do you prefer for brush feedback?**

---

### 2. Element Dragging
When dragging a placed element (habitas, AZN, zone):

**Option A: Drag while placing**
```
Click cell → start drag → move to new position → release
```

**Option B: Place first, then edit**
```
Click to place
Right-click (or select + drag) to move
```

**Which approach for element movement?**

---

### 3. Stream Direction Editing
Once a stream is placed, should user be able to:

**Option A: Delete + re-place with new direction**
```
Right-click stream to delete, place again with new direction
```

**Option B: Click stream + change direction**
```
Select stream, direction selector updates
Change direction, stream updates
```

**Option C: Click stream to rotate**
```
Left-click rotates through directions (N→S→E→W→N)
```

**Which for stream editing?**

---

## Layout Proposals

### Layout Option 1: Expandable Sections (Recommended)

**Pros:**
- All tools visible/accessible
- Clean grouping
- Familiar (like most editors)
- Scalable for future additions

**Cons:**
- Uses more vertical space
- More visual clutter

```
┌─────────────────────────────┐
│ Map Editor                  │
├─────────────────────────────┤
│ [▼] Terrain                 │
│   [tile] [tile] [tile] [tile]│
│   (hover: "LOW 2", etc)     │
│                             │
│ [▼] Streams                 │
│   [↑] [↓] [→] [←]          │
│   (title: "Stream Direction")│
│                             │
│ [▼] Elements                │
│   [Place Habitas]           │
│   [Place AZN]               │
│   [Place Zone]              │
│                             │
│ [▼] Tools                   │
│   [Clear] [Border] [Undo]   │
│                             │
└─────────────────────────────┘
```

### Layout Option 2: Tab System

**Pros:**
- Minimal footprint
- Clean switching
- Professional look

**Cons:**
- Need to switch tabs to access different tools
- Not all tools visible at once

```
┌─────────────────────────────┐
│ Map Editor                  │
│ [Terrain] [Streams] [Elem.] │
├─────────────────────────────┤
│ [tile] [tile] [tile] [tile] │
│                             │
│                             │
└─────────────────────────────┘
```

### Layout Option 3: Tool Buttons (Top) + Properties (Below)

**Pros:**
- Always shows current tool options
- Clear tool switching
- One tool at a time

**Cons:**
- More switching between tools
- Less discovery

```
┌─────────────────────────────┐
│ Map Editor                  │
├─────────────────────────────┤
│ Tool: [Terrain] [Streams]   │
│       [Elements] [Tools]    │
├─────────────────────────────┤
│                             │
│ Current Tool: Terrain       │
│ [tile] [tile] [tile] [tile] │
│                             │
│                             │
└─────────────────────────────┘
```

### Layout Option 4: Single Column - Everything Stacked

**Pros:**
- Simplest layout
- Everything visible
- Mobile-friendly proportions

**Cons:**
- Tall panel
- May scroll off-screen

```
┌─────────────────────────────┐
│ Map Editor                  │
├─────────────────────────────┤
│ Terrain                     │
│ [tile] [tile] [tile] [tile] │
│                             │
│ Streams                     │
│ [↑] [↓] [→] [←]            │
│                             │
│ Elements                    │
│ [Habitas] [AZN] [Zone]      │
│                             │
│ [Clear] [Border]            │
│ [Undo]                      │
│                             │
│ (scrollable if needed)      │
└─────────────────────────────┘
```

---

## Cursor Feedback

**Your decision: Hand cursor for map panning**

**Additional cursors suggested:**
- Default arrow: Normal state
- Crosshair: In paint mode (terrain selected)
- Hand: When hovering map while middle-button available
- Pipette/eyedropper: When placing elements?
- Eraser: When in delete mode?

**Or keep it simple:** Just hand for panning, default for everything else?

---

## Summary - Ready for Your Answers

1. **Brush feedback:** Highlight? Circle? Trail? (or current approach?)
2. **Element dragging:** During placement or after?
3. **Stream editing:** Delete+replace, select+change, or rotate-click?
4. **Right panel layout:** Which of the 4 options?
5. **Cursor feedback:** Just hand for pan, or more cursors?

Once you decide, we have a complete design spec and can implement Phase 2 properly.

# Phase 5: File I/O - Analysis

**Status:** Analysis (requirements from simulator code)
**Date:** 2026-06-08

---

## JSON Map Format (From Simulator)

### Complete Structure

```json
{
  "name": "Simple Tissue",
  "width": 80,
  "height": 80,
  "default_density": "low",
  "starting_azn": 150,
  "cells": [
    { "x": 5, "y": 8, "density": "high" },
    { "x": 10, "y": 20, "density": "medium", "stream": "east" },
    { "x": 15, "y": 25, "density": "low" }
  ],
  "habitas_points": [
    { "x": 6, "y": 9 },
    { "x": 31, "y": 6 }
  ],
  "azn_nodes": [
    { "x": 6, "y": 20, "quantity": 30 },
    { "x": 31, "y": 20, "quantity": 35 }
  ],
  "injection_zones": [
    { "player": 0, "x1": 0, "y1": 0, "x2": 4, "y2": 4 },
    { "player": 1, "x1": 75, "y1": 75, "x2": 79, "y2": 79 }
  ]
}
```

### Field Details

**Top-level:**
- `name` (string) - Map name
- `width` (int) - Map width in cells
- `height` (int) - Map height in cells
- `default_density` (string) - Default terrain when not specified
- `starting_azn` (int) - Starting resource amount for players

**Cells Array:**
- Each cell: `{ "x": int, "y": int, "density": string, "stream"?: string }`
- `x`, `y` - Grid coordinates
- `density` - "low" | "medium" | "high" | "bone"
- `stream` - (optional) "north" | "south" | "east" | "west"
- Only non-default density cells need to be listed (sparse format)

**Habitas Points Array:**
- Each point: `{ "x": int, "y": int }`
- Simple position array

**AZN Nodes Array:**
- Each node: `{ "x": int, "y": int, "quantity": int }`
- Position + resource quantity

**Injection Zones Array:**
- Each zone: `{ "player": int, "x1": int, "y1": int, "x2": int, "y2": int }`
- Two corners (inclusive) + player ID
- x1,y1 to x2,y2 format (not position + size)

---

## Enum Mapping

**Density (Code → JSON):**
```
Density.LOW = 0     → "low"
Density.MEDIUM = 1  → "medium"
Density.HIGH = 2    → "high"
Density.BONE = 3    → "bone"
```

**Stream Direction (Code → JSON):**
```
StreamDir.NONE = 0   → (not included in JSON)
StreamDir.NORTH = 1  → "north"
StreamDir.SOUTH = 2  → "south"
StreamDir.EAST = 3   → "east"
StreamDir.WEST = 4   → "west"
```

---

## Load/Save Operations

### Load
1. Open file dialog → browse res://maps/
2. Select .json file
3. Parse JSON
4. Create new MapData
5. Populate cells (default_density for unspecified cells)
6. Load elements (habitas, AZN, zones)
7. Display on map

### Save
1. Prompt for filename (or use existing)
2. Convert current state to JSON:
   - Only include non-default-density cells
   - Only include streams where stream_dir != NONE
   - Convert enums to JSON strings
3. Create zones from Rect2i (convert to x1, y1, x2, y2)
4. Write to res://maps/filename.json
5. Show confirmation

---

## Validation Requirements

**Before allowing save:**
- ✅ At least 1 habitas point
- ✅ At least 1 AZN node
- ✅ At least 1 injection zone
- ✅ Map dimensions match (width/height)

**Warnings:**
- Show warning dialog if validation fails
- "Map incomplete: needs X more habitas" etc.
- Allow override to save anyway (for testing)

---

## UI Workflow

### Load
1. Click "Load" button
2. FileDialog appears → select map from res://maps/
3. Map loads into editor
4. Status shows "Loaded: simple_tissue.json"

### Save
1. Click "Save" button
2. If first save: dialog asks for filename
3. If already named: saves directly (or "Save As...")
4. Validation dialog if issues
5. Status shows "Saved: map_name.json"

---

## Current Editor State

**What exists:**
- Cell array with density + stream_dir
- Habitas points array
- AZN nodes array with quantity
- Injection zones array with player + rect
- Load/Save buttons already in UI
- Default map loading in _load_default_map()

**What's missing:**
- Save to JSON function
- File dialog for save
- Load dialog implementation
- Enum to string conversion functions
- Validation logic
- Error handling

---

## Implementation Strategy

1. **Conversion functions:**
   - `_density_to_string(int)` → "low" | "medium" | "high" | "bone"
   - `_stream_to_string(int)` → "north" | "south" | "east" | "west"
   - `_string_to_density(string)` → int
   - `_string_to_stream(string)` → int

2. **Export function:**
   - `_create_map_json()` → Dictionary
   - Convert current state to JSON structure
   - Handle sparse cell array (only non-default)
   - Handle optional stream field

3. **Validation function:**
   - `_validate_map()` → Array of error strings
   - Check minimum requirements
   - Return empty array if valid

4. **Save function:**
   - `_show_save_dialog()` → shows FileDialog
   - `_save_map(filename)` → writes JSON to file

5. **Load function:**
   - `_show_load_dialog()` → shows FileDialog
   - `_load_map(filepath)` → parses JSON, loads into editor

---

## Files to Modify

**src/ui/map_editor/map_editor.gd:**
- Add conversion functions
- Add _create_map_json()
- Add _validate_map()
- Add _save_map()
- Update _show_load_dialog()
- Update _show_save_dialog()

---

## Ready for Implementation

All requirements documented. JSON format locked. Conversion paths clear.

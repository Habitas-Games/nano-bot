# Phase 5: File I/O - Specification

**Status:** Design locked, ready for implementation
**Date:** 2026-06-08

---

## Design Decisions (Final)

### Load
- **Dialog:** File browser to res://maps/ directory
- **Format:** JSON only
- **Behavior:** Load replaces current map, clears undo history
- **Validation:** Maps must be valid (simulator-compatible)

### Save
- **Dialog:** File name input (defaults to "map_name")
- **Location:** res://maps/ directory
- **Format:** JSON matching simulator format exactly
- **Validation:** Required before save (with override option)
- **Sparse Format:** Only non-default density cells in JSON
- **Stream Format:** Only cells with streams included

### Validation
- **Required:** 1+ habitas, 1+ AZN, 1+ zones
- **Enforcement:** Soft - warn but allow override
- **Scope:** Client-side only (simulator validates on load)

---

## Implementation Details

### Conversion Functions

```gdscript
# String to int (load)
func _string_to_density(s: String) -> int:
    match s.to_lower():
        "low": return Density.LOW
        "medium": return Density.MEDIUM
        "high": return Density.HIGH
        "bone": return Density.BONE
    return Density.LOW

func _string_to_stream(s: String) -> int:
    match s.to_lower():
        "north": return StreamDir.NORTH
        "south": return StreamDir.SOUTH
        "east": return StreamDir.EAST
        "west": return StreamDir.WEST
    return StreamDir.NONE

# Int to string (save)
func _density_to_string(d: int) -> String:
    match d:
        Density.LOW: return "low"
        Density.MEDIUM: return "medium"
        Density.HIGH: return "high"
        Density.BONE: return "bone"
    return "low"

func _stream_to_string(s: int) -> String:
    match s:
        StreamDir.NORTH: return "north"
        StreamDir.SOUTH: return "south"
        StreamDir.EAST: return "east"
        StreamDir.WEST: return "west"
    return ""
```

### Export Function

```gdscript
func _create_map_json() -> Dictionary:
    var json = {
        "name": "Untitled Map",
        "width": map_width,
        "height": map_height,
        "default_density": "low",
        "starting_azn": 150,
        "cells": [],
        "habitas_points": [],
        "azn_nodes": [],
        "injection_zones": []
    }
    
    # Only include non-default cells
    for i in range(cells.size()):
        var cell = cells[i]
        if cell["density"] != Density.LOW or cell["stream_dir"] != StreamDir.NONE:
            var x = i % map_width
            var y = i / map_width
            var cell_obj = {
                "x": x,
                "y": y,
                "density": _density_to_string(cell["density"])
            }
            if cell["stream_dir"] != StreamDir.NONE:
                cell_obj["stream"] = _stream_to_string(cell["stream_dir"])
            json["cells"].append(cell_obj)
    
    # Habitas
    for hp in habitas_points:
        json["habitas_points"].append({"x": hp.x, "y": hp.y})
    
    # AZN
    for azn in azn_nodes:
        json["azn_nodes"].append({
            "x": azn["position"].x,
            "y": azn["position"].y,
            "quantity": azn["quantity"]
        })
    
    # Zones
    for zone in injection_zones:
        var rect = zone["rect"]
        json["injection_zones"].append({
            "player": zone["player"],
            "x1": rect.position.x,
            "y1": rect.position.y,
            "x2": rect.position.x + rect.size.x - 1,
            "y2": rect.position.y + rect.size.y - 1
        })
    
    return json
```

### Validation Function

```gdscript
func _validate_map() -> Array:
    var errors = []
    
    if habitas_points.size() == 0:
        errors.append("Need at least 1 habitas point")
    
    if azn_nodes.size() == 0:
        errors.append("Need at least 1 AZN node")
    
    if injection_zones.size() == 0:
        errors.append("Need at least 1 injection zone")
    
    return errors
```

### Save Function

```gdscript
func _save_map(filepath: String) -> void:
    var json = _create_map_json()
    var json_string = JSON.stringify(json)
    
    var file = FileAccess.open(filepath, FileAccess.WRITE)
    if file:
        file.store_string(json_string)
        _show_notification("Map saved: " + filepath.get_file())
    else:
        _show_error("Failed to save map")
```

### Load Function

```gdscript
func _load_map(filepath: String) -> void:
    var file = FileAccess.open(filepath, FileAccess.READ)
    if not file:
        _show_error("Failed to load map")
        return
    
    var json_string = file.get_as_text()
    var json = JSON.parse_string(json_string)
    
    if json == null:
        _show_error("Invalid JSON format")
        return
    
    # Load map data
    _clear_map()
    map_width = json["width"]
    map_height = json["height"]
    
    # Resize cells array
    cells.clear()
    for i in range(map_width * map_height):
        cells.append({"density": Density.LOW, "stream_dir": StreamDir.NONE})
    
    # Load cells
    for cell_data in json.get("cells", []):
        var x = cell_data["x"]
        var y = cell_data["y"]
        var idx = y * map_width + x
        cells[idx]["density"] = _string_to_density(cell_data["density"])
        if cell_data.has("stream"):
            cells[idx]["stream_dir"] = _string_to_stream(cell_data["stream"])
    
    # Load elements
    habitas_points.clear()
    for hp in json.get("habitas_points", []):
        habitas_points.append(Vector2i(hp["x"], hp["y"]))
    
    azn_nodes.clear()
    for azn in json.get("azn_nodes", []):
        azn_nodes.append({
            "position": Vector2i(azn["x"], azn["y"]),
            "quantity": azn.get("quantity", 10)
        })
    
    injection_zones.clear()
    for zone in json.get("injection_zones", []):
        injection_zones.append({
            "player": zone["player"],
            "rect": Rect2i(
                zone["x1"], zone["y1"],
                zone["x2"] - zone["x1"] + 1,
                zone["y2"] - zone["y1"] + 1
            )
        })
    
    # Clear undo history
    history.clear()
    history_index = -1
    
    queue_redraw()
    _show_notification("Map loaded: " + filepath.get_file())
```

---

## UI Flow

### Load
1. User clicks "Load" button
2. FileDialog opens to res://maps/
3. User selects .json file
4. Map loads, editor updates
5. Status bar shows "Loaded: filename.json"

### Save
1. User clicks "Save" button
2. Validation runs:
   - If errors: warning dialog with override option
   - If valid: skip to save
3. FileDialog for filename
4. Save JSON to res://maps/filename.json
5. Status bar shows "Saved: filename.json"

---

## Testing Checklist

### Load
- [ ] Load existing map (simple_tissue.json)
- [ ] Map displays correctly
- [ ] All elements visible (terrain, streams, habitas, AZN, zones)
- [ ] Zoom/pan work on loaded map
- [ ] Can edit loaded map
- [ ] Undo history cleared after load

### Save
- [ ] Save new map
- [ ] File created in res://maps/
- [ ] JSON format matches simulator
- [ ] Can load saved map back
- [ ] Round-trip: load → edit → save → load = same

### Validation
- [ ] Warn if no habitas
- [ ] Warn if no AZN
- [ ] Warn if no zones
- [ ] Can override warnings
- [ ] Valid maps save without warning

### Round-trip
- [ ] Load map A
- [ ] Save as map B
- [ ] Load map B
- [ ] Compare: should be identical
- [ ] Edit map B
- [ ] Save as map C
- [ ] Load map C
- [ ] Compare: should have edits

---

## Code Changes

**File:** src/ui/map_editor/map_editor.gd

**Add:**
- `_string_to_density(s: String) -> int`
- `_string_to_stream(s: String) -> int`
- `_density_to_string(d: int) -> String`
- `_stream_to_string(s: int) -> String`
- `_create_map_json() -> Dictionary`
- `_validate_map() -> Array`
- `_save_map(filepath: String) -> void`
- `_load_map(filepath: String) -> void`
- Update `_show_load_dialog()` → implement load logic
- Update `_show_save_dialog()` → implement save logic
- `_show_notification(msg: String) -> void` (helper)
- `_show_error(msg: String) -> void` (helper)

---

## Ready for Implementation

Design is locked. JSON format verified. Code structure clear.
Implementation can begin immediately.

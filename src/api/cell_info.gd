class_name CellInfo
extends RefCounted

var position: Vector2i
var density: MapData.Density
var stream_direction: MapData.StreamDir
var is_bone: bool

static func from_map(map: MapData, x: int, y: int) -> CellInfo:
	var ci  := CellInfo.new()
	ci.position         = Vector2i(x, y)
	var cell            := map.get_cell(x, y)
	ci.density          = cell["density"] as MapData.Density
	ci.stream_direction = cell["stream_dir"] as MapData.StreamDir
	ci.is_bone          = (ci.density == MapData.Density.BONE)
	return ci

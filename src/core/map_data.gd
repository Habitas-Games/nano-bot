class_name MapData
extends RefCounted

enum Density { LOW, MEDIUM, HIGH, BONE }
enum StreamDir { NONE, NORTH, SOUTH, EAST, WEST }

const DENSITY_COST: Dictionary = {
	Density.LOW:    2,
	Density.MEDIUM: 3,
	Density.HIGH:   4,
}
const STREAM_BONUS    := 2
const STREAM_PENALTY  := 2
const MIN_MOVE_COST   := 1

var map_name: String = ""
var width: int = 0
var height: int = 0

var habitas_points: Array[Vector2i] = []
var azn_nodes: Array[Dictionary]    = []  # { position: Vector2i, quantity: int }
var injection_zones: Array[Dictionary] = [] # { player: int, rect: Rect2i }

# Flat array indexed by y * width + x.
# Each element: { density: Density, stream_dir: StreamDir }
var _cells: Array[Dictionary] = []

func _init(w: int, h: int) -> void:
	width  = w
	height = h
	_cells.resize(w * h)
	for i in w * h:
		_cells[i] = { "density": Density.LOW, "stream_dir": StreamDir.NONE }

func get_cell(x: int, y: int) -> Dictionary:
	return _cells[y * width + x]

func set_cell(x: int, y: int, density: int, stream_dir: int) -> void:
	_cells[y * width + x] = { "density": density, "stream_dir": stream_dir }

func is_in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height

func is_passable(x: int, y: int) -> bool:
	if not is_in_bounds(x, y):
		return false
	return _cells[y * width + x]["density"] != Density.BONE

# Returns the number of turns it costs to move from `from` into `to`.
# Returns -1 if `to` is impassable.
func movement_cost(from: Vector2i, to: Vector2i) -> int:
	if not is_passable(to.x, to.y):
		return -1
	var cell: Dictionary = _cells[to.y * width + to.x]
	var cost: int = DENSITY_COST[cell["density"]]
	var stream: int = cell["stream_dir"]
	if stream != StreamDir.NONE:
		var move_dir := to - from
		var stream_vec := _stream_to_vec(stream)
		if move_dir == stream_vec:
			cost -= STREAM_BONUS   # moving with current
		elif move_dir == -stream_vec:
			cost += STREAM_PENALTY # moving against current
	return maxi(cost, MIN_MOVE_COST)

static func _stream_to_vec(dir: int) -> Vector2i:
	match dir:
		StreamDir.NORTH: return Vector2i( 0, -1)
		StreamDir.SOUTH: return Vector2i( 0,  1)
		StreamDir.EAST:  return Vector2i( 1,  0)
		StreamDir.WEST:  return Vector2i(-1,  0)
	return Vector2i.ZERO

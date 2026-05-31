class_name GridPathfinder
extends RefCounted

# Custom A* over the grid using directed edge costs.
# Required because bloodstream bonuses/penalties depend on the direction
# of traversal through a cell, which standard AStarGrid2D cannot model.
#
# Performance note: the open set uses a linear scan for the minimum.
# For a 50x50 grid this is fast enough. If scaling to 200x200 with many
# bots, replace _open_pop with a binary min-heap.

var _map: MapData

func _init(map: MapData) -> void:
	_map = map

# Returns the path as Array[Vector2i] from `from` to `to`, both inclusive.
# Returns [] if no path exists or `to` is impassable.
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if not _map.is_passable(to.x, to.y):
		return []
	if from == to:
		return [from]

	# open entries: [f_cost: int, g_cost: int, pos: Vector2i]
	var open: Array        = []
	var g_cost: Dictionary = {}    # Vector2i -> int
	var came_from: Dictionary = {} # Vector2i -> Variant (Vector2i | null)

	g_cost[from]    = 0
	came_from[from] = null
	_open_push(open, [_h(from, to), 0, from])

	while open.size() > 0:
		var entry: Array  = _open_pop(open)
		var cur: Vector2i = entry[2]
		var cur_g: int    = entry[1]

		if g_cost.has(cur) and cur_g > g_cost[cur]:
			continue  # stale entry

		if cur == to:
			return _reconstruct(came_from, to)

		for dir: Vector2i in [Vector2i(0,-1), Vector2i(0,1), Vector2i(-1,0), Vector2i(1,0)]:
			var nb: Vector2i = cur + dir
			if not _map.is_passable(nb.x, nb.y):
				continue
			var edge_cost := _map.movement_cost(cur, nb)
			var new_g     := cur_g + edge_cost
			if not g_cost.has(nb) or new_g < g_cost[nb]:
				g_cost[nb]    = new_g
				came_from[nb] = cur
				_open_push(open, [new_g + _h(nb, to), new_g, nb])

	return []

# Total turn cost for a path produced by find_path.
static func path_cost(path: Array[Vector2i], map: MapData) -> int:
	var total := 0
	for i in range(1, path.size()):
		total += map.movement_cost(path[i - 1], path[i])
	return total

# --- private helpers ---

func _h(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func _open_push(open: Array, entry: Array) -> void:
	open.append(entry)

func _open_pop(open: Array) -> Array:
	var best := 0
	for i in range(1, open.size()):
		if open[i][0] < open[best][0]:
			best = i
	var entry: Array = open[best]
	open.remove_at(best)
	return entry

func _reconstruct(came_from: Dictionary, to: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var cur: Variant = to
	while cur != null:
		path.push_front(cur as Vector2i)
		cur = came_from.get(cur, null)
	return path

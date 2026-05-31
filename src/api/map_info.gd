class_name MapInfo
extends RefCounted

var size: Vector2i
var turn: int
var habitas_points: Array  # Array[HabitasPointInfo]
var azn_nodes: Array       # Array[AZNNodeInfo]
var visible_enemies: Array # Array[Dictionary] { id, type, position, hp }
var azn_bank: int          # this player's current AZN bank balance

var _map: MapData

# Built by SimulationCore each turn — participants receive this read-only.
static func build(
	map: MapData,
	turn_number: int,
	habitas_state: Array,
	azn_state: Array,
	all_bots: Array,
	friendly_owner: int,
	bank: int
) -> MapInfo:
	var mi            := MapInfo.new()
	mi._map           = map
	mi.size           = Vector2i(map.width, map.height)
	mi.turn           = turn_number
	mi.azn_bank       = bank

	mi.habitas_points = habitas_state.map(
		func(s: Dictionary) -> HabitasPointInfo: return HabitasPointInfo.from_state(s)
	)
	mi.azn_nodes = azn_state.map(
		func(s: Dictionary) -> AZNNodeInfo: return AZNNodeInfo.from_state(s)
	)

	# Visibility: all enemies visible for now (fog-of-war added in M3).
	mi.visible_enemies = []
	for bot: NanoBotData in all_bots:
		if bot.owner_id != friendly_owner and bot.is_alive:
			mi.visible_enemies.append({
				"id":       bot.id,
				"type":     bot.type,
				"position": bot.position,
				"hp":       bot.hp,
			})

	return mi

func get_cell(x: int, y: int) -> CellInfo:
	if not _map.is_in_bounds(x, y):
		return null
	return CellInfo.from_map(_map, x, y)

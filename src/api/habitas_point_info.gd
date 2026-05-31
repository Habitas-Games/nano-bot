class_name HabitasPointInfo
extends RefCounted

var position: Vector2i
var owner_id: int      # -1 = unoccupied
var azn_stored: int

static func from_state(state: Dictionary) -> HabitasPointInfo:
	var hp      := HabitasPointInfo.new()
	hp.position  = state["position"]
	hp.owner_id  = state["owner"]
	hp.azn_stored = state["azn_stored"]
	return hp

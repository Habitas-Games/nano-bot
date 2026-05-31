class_name AZNNodeInfo
extends RefCounted

var position: Vector2i
var quantity: int

static func from_state(state: Dictionary) -> AZNNodeInfo:
	var n      := AZNNodeInfo.new()
	n.position  = state["position"]
	n.quantity  = state["quantity"]
	return n

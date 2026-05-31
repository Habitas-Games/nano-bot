class_name NanoBotData
extends RefCounted

var id: int
var owner_id: int
var type: String
var position: Vector2i
var hp: int
var max_hp: int
var azn_carried: int           = 0
var turns_until_move: int      = 0
var path_remaining: Array[Vector2i] = []
var cached_target: Vector2i    = Vector2i(-1, -1)  # last move_to target
var is_alive: bool             = true
var pending_action: ActionRequest   = null
var auto_destruct_countdown: int    = -1  # -1 = disabled
var is_stationary: bool        = false
var density_immune: bool       = false    # NanoExplorer: ignores density cost
var traversal_penalty: int     = 0        # NanoBlocker: extra cost added to enemies

func _init(
	p_id: int,
	p_owner: int,
	p_type: String,
	p_pos: Vector2i,
	stats: Dictionary
) -> void:
	id         = p_id
	owner_id   = p_owner
	type       = p_type
	position   = p_pos
	hp         = stats.get("hp", 20)
	max_hp     = hp
	is_stationary   = stats.get("stationary", false)
	density_immune  = stats.get("density_immune", false)
	traversal_penalty = stats.get("traversal_penalty", 0)
	if stats.has("auto_destruct_turns"):
		auto_destruct_countdown = int(stats["auto_destruct_turns"])

func take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)
	if hp == 0:
		is_alive = false

func to_log_dict() -> Dictionary:
	return {
		"id":     id,
		"owner":  owner_id,
		"type":   type,
		"pos":    [position.x, position.y],
		"hp":     hp,
		"azn":    azn_carried,
		"alive":  is_alive,
		"action": pending_action.type_name() if pending_action != null else "none",
	}

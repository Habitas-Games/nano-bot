class_name ActionRequest
extends RefCounted

enum Type {
	NONE,
	MOVE,
	COLLECT,
	TRANSFER,
	DEFEND,
	BUILD,
	OPEN_IP,
	STOP,
	SELF_DESTRUCT,
}

var action_type: Type = Type.NONE
var target_position: Vector2i = Vector2i(-1, -1)
var build_type: String = ""

static func move(target: Vector2i) -> ActionRequest:
	var r := ActionRequest.new()
	r.action_type = Type.MOVE
	r.target_position = target
	return r

static func collect(source: Vector2i) -> ActionRequest:
	var r := ActionRequest.new()
	r.action_type = Type.COLLECT
	r.target_position = source
	return r

static func transfer(dest: Vector2i) -> ActionRequest:
	var r := ActionRequest.new()
	r.action_type = Type.TRANSFER
	r.target_position = dest
	return r

static func defend(enemy_pos: Vector2i) -> ActionRequest:
	var r := ActionRequest.new()
	r.action_type = Type.DEFEND
	r.target_position = enemy_pos
	return r

static func build(bot_type: String, pos: Vector2i) -> ActionRequest:
	var r := ActionRequest.new()
	r.action_type = Type.BUILD
	r.target_position = pos
	r.build_type = bot_type
	return r

static func open_ip() -> ActionRequest:
	var r := ActionRequest.new()
	r.action_type = Type.OPEN_IP
	return r

static func stop() -> ActionRequest:
	var r := ActionRequest.new()
	r.action_type = Type.STOP
	return r

static func self_destruct() -> ActionRequest:
	var r := ActionRequest.new()
	r.action_type = Type.SELF_DESTRUCT
	return r

func type_name() -> String:
	match action_type:
		Type.MOVE:          return "move"
		Type.COLLECT:       return "collect"
		Type.TRANSFER:      return "transfer"
		Type.DEFEND:        return "defend"
		Type.BUILD:         return "build"
		Type.OPEN_IP:       return "open_ip"
		Type.STOP:          return "stop"
		Type.SELF_DESTRUCT: return "self_destruct"
	return "none"

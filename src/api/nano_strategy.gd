class_name NanoStrategy
extends RefCounted

# Override to pick where your NanoAI enters the map.
# `map_info.turn` is 0 here (pre-match).
# Must return a cell within the injection zone assigned to your player.
# Returning an invalid cell falls back to the zone's top-left corner.
func choose_injection_point(_map_info: MapInfo) -> Vector2i:
	return Vector2i.ZERO

# Called once per turn (up to 1500 times).
# Queue actions on your bots via the BotProxy methods.
# Each bot accepts only its last-queued action; earlier calls are discarded.
# Budget: 50 ms wall-clock. Exceeding it forfeits your turn.
func what_to_do_next(_map_info: MapInfo, _my_bots: Array) -> void:
	pass

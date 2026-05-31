extends NanoStrategy

# Gameplay loop:
#   1. Build a NanoCollector immediately (bank = 150, cost = 20).
#   2. Move NanoAI to a cell adjacent to the nearest Habitas Point.
#   3. Build NanoNeedle directly ON the Habitas Point (NanoAI is 1 cell away).
#   4. Collector collects AZN and delivers it to the NanoNeedle.

const BUILD_COLLECTOR_COST := 20
const BUILD_NEEDLE_COST    := 40

func choose_injection_point(_map_info: MapInfo) -> Vector2i:
	return Vector2i.ZERO

func what_to_do_next(map_info: MapInfo, my_bots: Array) -> void:
	var nano_ai   := _find_bot(my_bots, "NanoAI")
	var collector := _find_bot(my_bots, "NanoCollector")
	var needle    := _find_bot(my_bots, "NanoNeedle")

	if nano_ai == null:
		return

	var target_hp := _nearest_unoccupied_hp(map_info)

	# ── NanoAI ────────────────────────────────────────────────────────────────

	if collector == null and map_info.azn_bank >= BUILD_COLLECTOR_COST:
		# Step 1: build collector on adjacent free cell.
		var adj := _adjacent_free(nano_ai.position, map_info)
		if adj != Vector2i(-1, -1):
			nano_ai.build("NanoCollector", adj)

	elif needle == null and target_hp != null:
		# Step 2: move NanoAI to be exactly 1 cell from the target HP.
		var stand_pos := _approach_pos(target_hp.position, nano_ai.position, map_info)
		var dist_to_hp: int = _manhattan(nano_ai.position, target_hp.position)

		if dist_to_hp == 1 and map_info.azn_bank >= BUILD_NEEDLE_COST:
			# Step 3: build needle ON the HP.
			nano_ai.build("NanoNeedle", target_hp.position)
		elif nano_ai.position != stand_pos:
			nano_ai.move_to(stand_pos)
		else:
			nano_ai.stop()  # waiting for enough AZN

	else:
		nano_ai.stop()

	# ── NanoCollector ─────────────────────────────────────────────────────────

	if collector == null:
		return

	var nearest_azn := _nearest_azn(map_info, collector.position)

	if needle != null and collector.azn > 0 and (nearest_azn == null or collector.azn >= 10):
		# Deliver AZN to the NanoNeedle (immediately if no AZN left to collect).
		if collector.position == needle.position:
			collector.transfer_to(needle.position)
		else:
			collector.move_to(needle.position)
	elif nearest_azn != null:
		if collector.position == nearest_azn.position:
			collector.collect_from(nearest_azn.position)
		else:
			collector.move_to(nearest_azn.position)
	else:
		collector.stop()  # all AZN depleted and nothing to deliver

# ─── helpers ─────────────────────────────────────────────────────────────────

func _find_bot(bots: Array, type_name: String) -> BotProxy:
	for bot: BotProxy in bots:
		if bot.type == type_name and bot.is_alive:
			return bot
	return null

func _nearest_unoccupied_hp(map_info: MapInfo) -> HabitasPointInfo:
	var best: HabitasPointInfo = null
	var best_dist := INF
	for hp: HabitasPointInfo in map_info.habitas_points:
		if hp.owner_id != -1:
			continue
		var d := float(abs(hp.position.x) + abs(hp.position.y))
		if d < best_dist:
			best_dist = d
			best = hp
	return best

func _nearest_azn(map_info: MapInfo, from: Vector2i) -> AZNNodeInfo:
	var best: AZNNodeInfo = null
	var best_dist := INF
	for node: AZNNodeInfo in map_info.azn_nodes:
		if node.quantity == 0:
			continue
		var d := float(abs(node.position.x - from.x) + abs(node.position.y - from.y))
		if d < best_dist:
			best_dist = d
			best = node
	return best

# Return a cell 1 step from `target` that is closest to `from`.
func _approach_pos(target: Vector2i, from: Vector2i, map_info: MapInfo) -> Vector2i:
	var best := from
	var best_dist := INF
	for dir: Vector2i in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		var c: Vector2i = target + dir
		if c.x < 0 or c.y < 0 or c.x >= map_info.size.x or c.y >= map_info.size.y:
			continue
		var cell := map_info.get_cell(c.x, c.y)
		if cell == null or cell.is_bone:
			continue
		var d := float(_manhattan(c, from))
		if d < best_dist:
			best_dist = d
			best = c
	return best

func _adjacent_free(pos: Vector2i, map_info: MapInfo) -> Vector2i:
	for dir: Vector2i in [Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0), Vector2i(0,-1)]:
		var c: Vector2i = pos + dir
		if c.x < 0 or c.y < 0 or c.x >= map_info.size.x or c.y >= map_info.size.y:
			continue
		var cell := map_info.get_cell(c.x, c.y)
		if cell != null and not cell.is_bone:
			return c
	return Vector2i(-1, -1)

static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

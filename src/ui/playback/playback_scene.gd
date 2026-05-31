class_name PlaybackScene
extends Node2D

const SPEED_STEPS: Array = [0.25, 0.5, 1.0, 2.0, 4.0]

const ZOOM_MIN  := 0.25
const ZOOM_MAX  := 10.0
const ZOOM_STEP := 1.15

# ── FX texture banks (preloaded once) ─────────────────────────────────────────
const FX_AZN_COLLECT: Array = [
	preload("res://assets/fx/fx_azn_collect_00.png"),
	preload("res://assets/fx/fx_azn_collect_01.png"),
	preload("res://assets/fx/fx_azn_collect_02.png"),
	preload("res://assets/fx/fx_azn_collect_03.png"),
	preload("res://assets/fx/fx_azn_collect_04.png"),
	preload("res://assets/fx/fx_azn_collect_05.png"),
	preload("res://assets/fx/fx_azn_collect_06.png"),
]
const FX_BOT_BUILT: Array = [
	preload("res://assets/fx/fx_bot_built_00.png"),
	preload("res://assets/fx/fx_bot_built_01.png"),
	preload("res://assets/fx/fx_bot_built_02.png"),
	preload("res://assets/fx/fx_bot_built_03.png"),
	preload("res://assets/fx/fx_bot_built_04.png"),
	preload("res://assets/fx/fx_bot_built_05.png"),
]
const FX_ATTACK: Array = [
	preload("res://assets/fx/fx_attack_00.png"),
	preload("res://assets/fx/fx_attack_01.png"),
	preload("res://assets/fx/fx_attack_02.png"),
	preload("res://assets/fx/fx_attack_03.png"),
	preload("res://assets/fx/fx_attack_04.png"),
]
const FX_DESTRUCT: Array = [
	preload("res://assets/fx/fx_destruct_00.png"),
	preload("res://assets/fx/fx_destruct_01.png"),
	preload("res://assets/fx/fx_destruct_02.png"),
	preload("res://assets/fx/fx_destruct_03.png"),
	preload("res://assets/fx/fx_destruct_04.png"),
	preload("res://assets/fx/fx_destruct_05.png"),
]

var _log: MatchLog        = null
var _map: MapData         = null
var _current_frame: int   = 0
var _is_playing: bool     = false
var _speed: float         = 1.0
var _elapsed: float       = 0.0

# Child nodes (built in _ready)
var _map_renderer: MapRenderer
var _bot_sprites: Dictionary = {}   # bot_id -> BotSprite
var _bot_layer: Node2D
var _fx_layer: Node2D               # FxFlash nodes live here
var _camera: Camera2D
var _hud: HUD
var _back_btn: Button
var _end_overlay: Control

# Pan state
var _panning: bool       = false
var _pan_origin: Vector2 = Vector2.ZERO
var _cam_origin: Vector2 = Vector2.ZERO

func _ready() -> void:
	_build_scene()
	_connect_hud()

	if GameState.pending_log != null:
		var log: MatchLog = GameState.pending_log
		GameState.pending_log = null
		load_log_data(log)
	elif GameState.pending_log_path != "":
		var path: String = GameState.pending_log_path
		GameState.pending_log_path = ""
		load_log_file(path)

# ─── _process drives playback ─────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not _is_playing or _log == null:
		return
	_elapsed += delta
	var interval: float = 0.2 / _speed
	while _elapsed >= interval:
		_elapsed -= interval
		if _current_frame >= _log.frames.size() - 1:
			_stop_playback()
			return
		_current_frame += 1
		_apply_frame(_current_frame)

# ─── build & connect ─────────────────────────────────────────────────────────

func _build_scene() -> void:
	_map_renderer = MapRenderer.new()
	add_child(_map_renderer)

	_bot_layer = Node2D.new()
	add_child(_bot_layer)

	_fx_layer = Node2D.new()
	add_child(_fx_layer)

	_camera          = Camera2D.new()
	_camera.position = Vector2(640, 400)   # matches default viewport, overridden in load_log_data
	add_child(_camera)

	_hud = HUD.new()
	add_child(_hud)

	var ui_layer := CanvasLayer.new()
	add_child(ui_layer)

	_back_btn          = Button.new()
	_back_btn.text     = "< Menu"
	_back_btn.position = Vector2(8, 8)
	_back_btn.pressed.connect(_go_to_menu)
	ui_layer.add_child(_back_btn)

	_end_overlay = _build_end_overlay(ui_layer)
	_end_overlay.visible = false

func _connect_hud() -> void:
	_hud.play_pressed.connect(_start_playback)
	_hud.pause_pressed.connect(_stop_playback)
	_hud.step_forward_pressed.connect(step_forward)
	_hud.step_back_pressed.connect(step_back)
	_hud.speed_changed.connect(_on_speed_changed)
	_hud.jump_requested.connect(jump_to)

# ─── public API ───────────────────────────────────────────────────────────────

func load_log_file(path: String) -> void:
	var log: MatchLog = MatchLog.load_from_file(path)
	if log == null:
		push_error("PlaybackScene: could not load: %s" % path)
		return
	load_log_data(log)

func load_log_data(log: MatchLog) -> void:
	_log = log
	_map = _find_map(log.map_name)
	if _map == null:
		push_error("PlaybackScene: map '%s' not found" % log.map_name)
		return
	_map_renderer.setup(_map)
	_hud.setup_for_log(log)
	_clear_bots()
	_current_frame = 0
	_apply_frame(0)
	# Centre camera on the map with default zoom
	var map_px := _map_renderer.map_pixel_size()
	_camera.position = map_px * 0.5
	_camera.zoom     = Vector2.ONE

# ─── frame stepping ───────────────────────────────────────────────────────────

func step_forward() -> void:
	if _log == null or _current_frame >= _log.frames.size() - 1:
		return
	_current_frame += 1
	_elapsed = 0.0
	_apply_frame(_current_frame)

func step_back() -> void:
	if _log == null or _current_frame <= 0:
		return
	_current_frame -= 1
	_elapsed = 0.0
	_apply_frame(_current_frame)

func jump_to(frame_index: int) -> void:
	if _log == null:
		return
	_clear_fx()
	_current_frame = clamp(frame_index, 0, _log.frames.size() - 1)
	_elapsed = 0.0
	_apply_frame(_current_frame)

# ─── apply a frame ────────────────────────────────────────────────────────────

func _apply_frame(idx: int) -> void:
	if _log == null or idx < 0 or idx >= _log.frames.size():
		return
	var frame: Dictionary = _log.frames[idx]

	_map_renderer.update_overlay(
		frame.get("habitas_points", []),
		frame.get("azn_nodes", [])
	)

	var frame_bots: Array = frame.get("bots", [])
	var seen_ids: Dictionary = {}

	for bot_data: Dictionary in frame_bots:
		var bid: int       = int(bot_data["id"])
		var raw_pos: Array = bot_data["pos"]
		var cell           := Vector2i(int(raw_pos[0]), int(raw_pos[1]))
		var alive: bool    = bot_data.get("alive", true)
		seen_ids[bid]      = true

		if not alive:
			if _bot_sprites.has(bid):
				_bot_sprites[bid].queue_free()
				_bot_sprites.erase(bid)
			continue

		if not _bot_sprites.has(bid):
			var sprite := _make_sprite(bot_data)
			_bot_sprites[bid] = sprite

		_bot_sprites[bid].place_at(cell)

	for bid: int in _bot_sprites.keys():
		if not seen_ids.has(bid):
			_bot_sprites[bid].queue_free()
			_bot_sprites.erase(bid)

	_apply_events(frame.get("events", []), frame)
	_hud.update_frame(frame, _log)

# ─── event VFX ───────────────────────────────────────────────────────────────

func _apply_events(events: Array, frame: Dictionary) -> void:
	for event: Dictionary in events:
		_spawn_event_fx(event, frame)

func _spawn_event_fx(event: Dictionary, frame: Dictionary) -> void:
	var etype: String = event.get("type", "")
	var textures: Array
	var cell: Vector2i

	match etype:
		"azn_collected":
			textures = FX_AZN_COLLECT
			var p: Array = event.get("node", [0, 0])
			cell = Vector2i(int(p[0]), int(p[1]))
		"azn_transferred":
			textures = FX_AZN_COLLECT
			cell = _bot_cell(int(event.get("to", 0)), frame)
		"bot_built":
			textures = FX_BOT_BUILT
			cell = _bot_cell(int(event.get("new_bot", 0)), frame)
		"attack":
			textures = FX_ATTACK
			cell = _bot_cell(int(event.get("target", 0)), frame)
		"self_destruct", "auto_destruct":
			textures = FX_DESTRUCT
			cell = _bot_cell(int(event.get("bot_id", 0)), frame)
		_:
			return

	var flash := FxFlash.new()
	_fx_layer.add_child(flash)
	flash.play(textures, _map_renderer.cell_to_pixel(cell))

func _bot_cell(bot_id: int, frame: Dictionary) -> Vector2i:
	for bot: Dictionary in frame.get("bots", []):
		if int(bot.get("id", -1)) == bot_id:
			var p: Array = bot.get("pos", [0, 0])
			return Vector2i(int(p[0]), int(p[1]))
	return Vector2i.ZERO

func _clear_fx() -> void:
	for child in _fx_layer.get_children():
		child.queue_free()

# ─── playback control ────────────────────────────────────────────────────────

func _start_playback() -> void:
	if _log == null:
		return
	_elapsed    = 0.0
	_is_playing = true
	_hud.set_playing(true)

func _stop_playback() -> void:
	_is_playing = false
	_hud.set_playing(false)
	if _log != null and _current_frame >= _log.frames.size() - 1:
		_show_end_overlay()

func _on_speed_changed(multiplier: float) -> void:
	_speed = multiplier

# ─── input: pan, zoom, click-to-inspect ──────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

		# Pan: left-mouse or middle-mouse drag
		if mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
			_panning = mb.pressed
			if mb.pressed:
				_pan_origin = mb.position
				_cam_origin = _camera.position
			return

		# Zoom: scroll wheel (zoom toward the mouse cursor)
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(mb.position, ZOOM_STEP)
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(mb.position, 1.0 / ZOOM_STEP)
			return

		# Right click: inspect bot
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed \
				and _log != null and _map != null:
			var local_pos := _map_renderer.to_local(get_global_mouse_position())
			var cell      := _map_renderer.pixel_to_cell(local_pos)
			_inspect_bot_at(cell)

	elif event is InputEventMouseMotion and _panning:
		# Translate camera in world space, accounting for current zoom
		_camera.position = _cam_origin - (event.position - _pan_origin) / _camera.zoom.x

func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var old_zoom  := _camera.zoom.x
	var new_zoom  := clampf(old_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	if new_zoom == old_zoom:
		return
	# World position currently under the mouse
	var vp_half   := get_viewport().get_visible_rect().size * 0.5
	var mouse_world := _camera.position + (screen_pos - vp_half) / old_zoom
	_camera.zoom     = Vector2(new_zoom, new_zoom)
	# Reposition so the same world point stays under the mouse
	_camera.position = mouse_world - (screen_pos - vp_half) / new_zoom

func _inspect_bot_at(cell: Vector2i) -> void:
	if _log == null or _current_frame >= _log.frames.size():
		return
	var frame: Dictionary = _log.frames[_current_frame]
	for bot: Dictionary in frame.get("bots", []):
		var pos: Array = bot.get("pos", [])
		if pos.size() >= 2 and int(pos[0]) == cell.x and int(pos[1]) == cell.y:
			_hud.show_bot_info(bot)
			return

# ─── helpers ─────────────────────────────────────────────────────────────────

func _make_sprite(bot_data: Dictionary) -> BotSprite:
	var sprite := BotSprite.new()
	_bot_layer.add_child(sprite)
	sprite.setup(int(bot_data["id"]), str(bot_data["type"]), int(bot_data["owner"]))
	return sprite

func _clear_bots() -> void:
	for sprite: BotSprite in _bot_sprites.values():
		sprite.queue_free()
	_bot_sprites.clear()

func _find_map(map_name: String) -> MapData:
	var dir := DirAccess.open("res://maps")
	if dir == null:
		return null
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			var candidate: MapData = MapLoader.load_from_file("res://maps/" + fname)
			if candidate != null and candidate.map_name == map_name:
				return candidate
		fname = dir.get_next()
	return null

func _go_to_menu() -> void:
	_stop_playback()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _show_end_overlay() -> void:
	if _log == null or _end_overlay == null:
		return
	var scores := _log.final_scores
	var lines: Array = ["Match Complete — %d turns" % _log.total_turns, ""]
	for i in scores.size():
		var pts: int = int(scores.get(str(i), scores.get(i, 0)))
		var win  := "  ← WINNER" if i == _log.winner_id else ""
		lines.append("Player %d:  %d pts%s" % [i, pts, win])
	var lbl: Label = _end_overlay.get_child(0).get_child(0)
	lbl.text = "\n".join(lines)
	_end_overlay.visible = true

func _build_end_overlay(parent: CanvasLayer) -> Control:
	var overlay := PanelContainer.new()
	overlay.set_anchors_preset(Control.PRESET_CENTER)
	overlay.position = Vector2(250, 200)
	overlay.size     = Vector2(300, 200)
	parent.add_child(overlay)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	overlay.add_child(vbox)

	var lbl := Label.new()
	lbl.text = ""
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(lbl)

	var btn_row := HBoxContainer.new()
	vbox.add_child(btn_row)

	var restart_btn := Button.new()
	restart_btn.text = "↺ Replay"
	restart_btn.pressed.connect(func():
		_end_overlay.visible = false
		jump_to(0)
	)
	btn_row.add_child(restart_btn)

	var menu_btn := Button.new()
	menu_btn.text = "← Menu"
	menu_btn.pressed.connect(_go_to_menu)
	btn_row.add_child(menu_btn)

	return overlay

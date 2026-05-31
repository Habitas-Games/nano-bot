class_name HUD
extends CanvasLayer

const ICON_PLAY:      Texture2D = preload("res://assets/ui/icon_play.png")
const ICON_PAUSE:     Texture2D = preload("res://assets/ui/icon_pause.png")
const ICON_STEP_FWD:  Texture2D = preload("res://assets/ui/icon_step_fwd.png")
const ICON_STEP_BACK: Texture2D = preload("res://assets/ui/icon_step_back.png")
const PANEL_BG_TEX:   Texture2D = preload("res://assets/ui/panel_bg.png")

const PLAYER_COLORS: Array = [
	Color(0.25, 0.55, 1.00),
	Color(1.00, 0.30, 0.25),
	Color(0.20, 0.85, 0.40),
	Color(1.00, 0.85, 0.15),
]

const PANEL_X     := 808
const PANEL_WIDTH := 464
const MARGIN      := 10

# Signals for playback controls
signal play_pressed
signal pause_pressed
signal step_forward_pressed
signal step_back_pressed
signal speed_changed(multiplier: float)
signal jump_requested(turn: int)

var _turn_label: Label
var _score_labels: Array     = []
var _alive_labels: Array     = []
var _inspector_panel: PanelContainer
var _inspector_label: Label
var _play_btn: Button
var _is_playing: bool = false
var _speed_label: Label
var _turn_slider: HSlider
var _log_info_label: Label

var _speed_steps: Array       = [0.25, 0.5, 1.0, 2.0, 4.0]
var _speed_index: int         = 2  # default 1×
var _slider_updating: bool    = false

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# ── Side panel background ──────────────────────────────────────────────
	var panel      := PanelContainer.new()
	panel.position  = Vector2(PANEL_X, 0)
	panel.size      = Vector2(PANEL_WIDTH, 800)
	add_child(panel)

	var vbox       := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# Tiled texture background for the side panel
	var sb := StyleBoxTexture.new()
	sb.texture = PANEL_BG_TEX
	sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	sb.axis_stretch_vertical   = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	panel.add_theme_stylebox_override("panel", sb)

	# ── Match info ────────────────────────────────────────────────────────
	_log_info_label = _label("nano-bot simulation", 13, true)
	vbox.add_child(_log_info_label)

	vbox.add_child(HSeparator.new())

	_turn_label = _label("Turn: —", 14, true)
	vbox.add_child(_turn_label)

	vbox.add_child(_label("Scores", 12, true))

	# Placeholder score rows (filled when log loads)
	for i in 4:
		var row := HBoxContainer.new()
		var col_dot := ColorRect.new()
		col_dot.custom_minimum_size = Vector2(12, 12)
		col_dot.color = PLAYER_COLORS[i]
		row.add_child(col_dot)
		var sc := _label("  Player %d: —" % i, 12)
		_score_labels.append(sc)
		row.add_child(sc)
		var al := _label("  (— bots)", 11)
		_alive_labels.append(al)
		row.add_child(al)
		row.visible = false
		vbox.add_child(row)

	vbox.add_child(HSeparator.new())

	# ── Bot inspector ─────────────────────────────────────────────────────
	vbox.add_child(_label("Bot Inspector", 12, true))
	_inspector_panel        = PanelContainer.new()
	_inspector_panel.custom_minimum_size = Vector2(0, 80)
	_inspector_label        = _label("Click a bot on the map.", 11)
	_inspector_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspector_panel.add_child(_inspector_label)
	vbox.add_child(_inspector_panel)

	vbox.add_child(HSeparator.new())

	# ── Legend ─────────────────────────────────────────────────────────────
	vbox.add_child(_label("Map Legend", 12, true))
	var legend_entries: Array = [
		["res://assets/tiles/tile_low.png",             "Low density (2 turns)"],
		["res://assets/tiles/tile_medium.png",          "Medium density (3 turns)"],
		["res://assets/tiles/tile_high.png",            "High density (4 turns)"],
		["res://assets/tiles/tile_bone.png",            "Bone (impassable)"],
		["res://assets/tiles/tile_stream_h.png",        "Bloodstream"],
		["res://assets/markers/habitas_neutral.png",    "Habitas Point"],
		["res://assets/markers/azn_node.png",           "AZN Node"],
	]
	for entry: Array in legend_entries:
		var row  := HBoxContainer.new()
		var icon := TextureRect.new()
		icon.texture                = load(entry[0])
		icon.custom_minimum_size    = Vector2(12, 12)
		icon.stretch_mode           = TextureRect.STRETCH_SCALE
		icon.texture_filter         = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(icon)
		row.add_child(_label("  " + entry[1], 10))
		vbox.add_child(row)

	# ── Spacer pushes controls to bottom ─────────────────────────────────
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	vbox.add_child(HSeparator.new())

	# ── Turn slider ───────────────────────────────────────────────────────
	vbox.add_child(_label("Jump to turn:", 11))
	_turn_slider                     = HSlider.new()
	_turn_slider.min_value           = 0
	_turn_slider.max_value           = 0
	_turn_slider.step                = 1
	_turn_slider.custom_minimum_size = Vector2(0, 20)
	_turn_slider.value_changed.connect(_on_slider_changed)
	vbox.add_child(_turn_slider)

	# ── Playback controls ─────────────────────────────────────────────────
	var ctrl_row := HBoxContainer.new()
	ctrl_row.add_theme_constant_override("separation", 4)
	vbox.add_child(ctrl_row)

	var back_btn := Button.new()
	back_btn.icon             = ICON_STEP_BACK
	back_btn.expand_icon      = true
	back_btn.custom_minimum_size = Vector2(28, 28)
	back_btn.tooltip_text     = "Step back"
	back_btn.pressed.connect(func(): step_back_pressed.emit())
	ctrl_row.add_child(back_btn)

	_play_btn                  = Button.new()
	_play_btn.icon             = ICON_PLAY
	_play_btn.expand_icon      = true
	_play_btn.custom_minimum_size = Vector2(36, 28)
	_play_btn.pressed.connect(_on_play_pause)
	ctrl_row.add_child(_play_btn)

	var fwd_btn                := Button.new()
	fwd_btn.icon               = ICON_STEP_FWD
	fwd_btn.expand_icon        = true
	fwd_btn.custom_minimum_size = Vector2(28, 28)
	fwd_btn.tooltip_text       = "Step forward"
	fwd_btn.pressed.connect(func(): step_forward_pressed.emit())
	ctrl_row.add_child(fwd_btn)

	var sp_row := HBoxContainer.new()
	sp_row.add_theme_constant_override("separation", 4)
	vbox.add_child(sp_row)

	var sp_down := Button.new()
	sp_down.text    = "–"
	sp_down.tooltip_text = "Slower"
	sp_down.pressed.connect(_on_speed_down)
	sp_row.add_child(sp_down)

	_speed_label      = _label("1.0×", 11, true)
	sp_row.add_child(_speed_label)

	var sp_up := Button.new()
	sp_up.text    = "+"
	sp_up.tooltip_text = "Faster"
	sp_up.pressed.connect(_on_speed_up)
	sp_row.add_child(sp_up)

# ─── public update API ────────────────────────────────────────────────────────

func setup_for_log(log: MatchLog) -> void:
	_log_info_label.text     = "Map: %s  |  %d turns" % [log.map_name, log.total_turns]
	_turn_slider.max_value   = log.frames.size() - 1
	var strats: Array        = log.player_strategies
	for i in 4:
		var row: Node = _score_labels[i].get_parent()
		row.visible   = i < strats.size()
		if i < strats.size():
			_score_labels[i].text = "  P%d: 0" % i

func update_frame(frame: Dictionary, log: MatchLog) -> void:
	var turn: int = frame.get("turn", 0)
	_turn_label.text = "Turn: %d / %d" % [turn, log.total_turns]

	_slider_updating = true
	_turn_slider.value = turn - 1
	_slider_updating   = false

	var scores: Dictionary = frame.get("scores", {})
	var bots: Array        = frame.get("bots", [])
	for i in 4:
		if not _score_labels[i].get_parent().visible:
			continue
		var score: int  = int(scores.get(str(i), scores.get(i, 0)))
		var alive: int  = bots.filter(func(b): return int(b.get("owner", -1)) == i and b.get("alive", false)).size()
		_score_labels[i].text = "  P%d: %d pts" % [i, score]
		_alive_labels[i].text = "  (%d bots)" % alive

func set_playing(playing: bool) -> void:
	_is_playing     = playing
	_play_btn.icon  = ICON_PAUSE if playing else ICON_PLAY

func show_bot_info(bot: Dictionary) -> void:
	_inspector_label.text = \
		"ID: %d\nType: %s\nOwner: P%d\nHP: %d\nAZN: %d\nPos: %s" % [
			int(bot.get("id", 0)),
			str(bot.get("type", "?")),
			int(bot.get("owner", 0)),
			int(bot.get("hp", 0)),
			int(bot.get("azn", 0)),
			str(bot.get("pos", [])),
		]

# ─── private handlers ─────────────────────────────────────────────────────────

func _on_play_pause() -> void:
	if _is_playing:
		pause_pressed.emit()
	else:
		play_pressed.emit()

func _on_speed_down() -> void:
	_speed_index = maxi(_speed_index - 1, 0)
	_update_speed()

func _on_speed_up() -> void:
	_speed_index = mini(_speed_index + 1, _speed_steps.size() - 1)
	_update_speed()

func _update_speed() -> void:
	var s: float   = _speed_steps[_speed_index]
	_speed_label.text = "%.2g×" % s
	speed_changed.emit(s)

func _on_slider_changed(value: float) -> void:
	if _slider_updating:
		return
	jump_requested.emit(int(value))

func current_speed() -> float:
	return _speed_steps[_speed_index]

# ─── helpers ──────────────────────────────────────────────────────────────────

static func _label(text: String, size: int, bold: bool = false) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	if bold:
		lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	return lbl

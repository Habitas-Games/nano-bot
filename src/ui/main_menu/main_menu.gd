class_name MainMenu
extends Control

const DEFAULT_MAP         := "res://maps/simple_tissue.json"
const DEFAULT_STRATEGY    := "res://strategies/example_strategy.gd"
const PLAYBACK_SCENE      := "res://scenes/playback_scene.tscn"
const TOURNAMENT_SCENE    := "res://scenes/tournament_scene.tscn"

var _status_label: Label
var _run_btn: Button
var _load_btn: Button
var _file_dialog: FileDialog
var _sim_thread: Thread    = null
var _pending_log: MatchLog = null

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Full-screen background image
	var bg := TextureRect.new()
	bg.texture        = preload("res://assets/menu/bg_menu.png")
	bg.stretch_mode   = TextureRect.STRETCH_SCALE
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Centred content container
	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.custom_minimum_size = Vector2(420, 0)
	center.position            = Vector2(-210, -160)
	center.add_theme_constant_override("separation", 14)
	add_child(center)

	# Title logo
	var title := TextureRect.new()
	title.texture               = preload("res://assets/menu/title_logo.png")
	title.stretch_mode          = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title.custom_minimum_size   = Vector2(320, 80)
	title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title.texture_filter        = CanvasItem.TEXTURE_FILTER_LINEAR
	center.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Simulation Platform"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.65, 0.65, 0.70))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(subtitle)

	center.add_child(_spacer(12))

	# Run Match button
	_run_btn = _make_button("▶  Run Match", Color(0.22, 0.90, 0.44))
	_run_btn.tooltip_text = "Run example_strategy vs itself on Simple Tissue and watch the replay."
	_run_btn.pressed.connect(_on_run_match)
	center.add_child(_run_btn)

	# Load Replay button
	_load_btn = _make_button("📂  Load Replay", Color(0.25, 0.55, 1.00))
	_load_btn.tooltip_text = "Open a saved match JSON file from the replays/ folder."
	_load_btn.pressed.connect(_on_load_replay)
	center.add_child(_load_btn)

	# Tournament
	var tourn_btn := _make_button("🏆  Tournament", Color(1.00, 0.85, 0.15))
	tourn_btn.tooltip_text = "Run a round-robin tournament between all strategies in res://strategies/."
	tourn_btn.pressed.connect(func(): get_tree().change_scene_to_file(TOURNAMENT_SCENE))
	center.add_child(tourn_btn)

	center.add_child(_spacer(6))

	# Status label
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.78))
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(_status_label)

	# File dialog for loading replays
	_file_dialog                = FileDialog.new()
	_file_dialog.file_mode      = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access         = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.filters        = PackedStringArray(["*.json ; Match replay files"])
	_file_dialog.current_dir    = ProjectSettings.globalize_path("res://replays")
	_file_dialog.file_selected.connect(_on_file_selected)
	add_child(_file_dialog)

# ─── button handlers ─────────────────────────────────────────────────────────

func _on_run_match() -> void:
	_set_status("Loading map…")
	_run_btn.disabled  = true
	_load_btn.disabled = true
	await get_tree().process_frame

	var map := MapLoader.load_from_file(DEFAULT_MAP)
	if map == null:
		_set_status("Error: could not load map at %s" % DEFAULT_MAP)
		_run_btn.disabled  = false
		_load_btn.disabled = false
		return

	# Build sim and pre-load strategies on the main thread (load() is not thread-safe).
	var sim := SimulationCore.new(map, [DEFAULT_STRATEGY, DEFAULT_STRATEGY], 0)
	sim.preload_strategies()

	_set_status("Simulating 1500 turns in background…")
	await get_tree().process_frame

	# Run the heavy computation on a background thread so the UI stays alive.
	_sim_thread = Thread.new()
	_sim_thread.start(func() -> void:
		_pending_log = sim.run()
		call_deferred("_on_sim_done")
	)

func _on_sim_done() -> void:
	if _sim_thread != null:
		_sim_thread.wait_to_finish()
		_sim_thread = null
	var log: MatchLog = _pending_log
	_pending_log = null
	var out_path := _auto_replay_path()
	log.save_to_file(out_path)
	_set_status("Match complete — %d turns." % log.total_turns)
	GameState.pending_log = log
	get_tree().change_scene_to_file(PLAYBACK_SCENE)

func _on_load_replay() -> void:
	_file_dialog.popup_centered_ratio(0.6)

func _on_file_selected(path: String) -> void:
	_set_status("Loading replay…")
	GameState.pending_log_path = path
	GameState.pending_log      = null
	get_tree().change_scene_to_file(PLAYBACK_SCENE)

# ─── helpers ─────────────────────────────────────────────────────────────────

func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text

func _auto_replay_path() -> String:
	var stamp := Time.get_datetime_string_from_system() \
				.replace(":", "-").replace("T", "_")
	return "res://replays/match_%s_example_vs_example.json" % stamp

static func _make_button(label: String, col: Color) -> Button:
	var btn := Button.new()
	btn.text                       = label
	btn.custom_minimum_size        = Vector2(0, 46)
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color", col)
	return btn

static func _spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s

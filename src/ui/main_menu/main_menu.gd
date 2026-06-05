class_name MainMenu
extends Control

const PLAYBACK_SCENE      := "res://scenes/playback_scene.tscn"
const TOURNAMENT_SCENE    := "res://scenes/tournament_scene.tscn"

var _status_label: Label
var _run_btn: Button
var _load_btn: Button
var _file_dialog: FileDialog
var _map_dropdown: OptionButton
var _strat_p0_dropdown: OptionButton
var _strat_p1_dropdown: OptionButton
var _sim_thread: Thread    = null
var _pending_log: MatchLog = null

var _available_maps: Array = []       # Array[String] paths
var _available_strategies: Array = [] # Array[String] paths

func _ready() -> void:
	_scan_maps_and_strategies()
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
	center.custom_minimum_size = Vector2(480, 0)
	center.position            = Vector2(-240, -200)
	center.add_theme_constant_override("separation", 12)
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

	center.add_child(_spacer(10))

	# ── Map selection ──
	var map_label := Label.new()
	map_label.text = "Select Map:"
	map_label.add_theme_font_size_override("font_size", 11)
	map_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.78))
	center.add_child(map_label)

	_map_dropdown = OptionButton.new()
	_map_dropdown.custom_minimum_size = Vector2(0, 32)
	for idx: int in range(_available_maps.size()):
		var map_path: String = _available_maps[idx]
		var map_name: String = map_path.split("/")[-1].trim_suffix(".json")
		_map_dropdown.add_item(map_name, idx)
	center.add_child(_map_dropdown)

	# ── Strategy selection ──
	var strat_label := Label.new()
	strat_label.text = "Player 1 Strategy:"
	strat_label.add_theme_font_size_override("font_size", 11)
	strat_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.78))
	center.add_child(strat_label)

	_strat_p0_dropdown = OptionButton.new()
	_strat_p0_dropdown.custom_minimum_size = Vector2(0, 32)
	for idx: int in range(_available_strategies.size()):
		var strat_path: String = _available_strategies[idx]
		var strat_name: String = strat_path.split("/")[-1].trim_suffix(".gd")
		_strat_p0_dropdown.add_item(strat_name, idx)
	center.add_child(_strat_p0_dropdown)

	var strat_p1_label := Label.new()
	strat_p1_label.text = "Player 2 Strategy:"
	strat_p1_label.add_theme_font_size_override("font_size", 11)
	strat_p1_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.78))
	center.add_child(strat_p1_label)

	_strat_p1_dropdown = OptionButton.new()
	_strat_p1_dropdown.custom_minimum_size = Vector2(0, 32)
	for idx: int in range(_available_strategies.size()):
		var strat_path: String = _available_strategies[idx]
		var strat_name: String = strat_path.split("/")[-1].trim_suffix(".gd")
		_strat_p1_dropdown.add_item(strat_name, idx)
	center.add_child(_strat_p1_dropdown)

	center.add_child(_spacer(8))

	# Run Match button
	_run_btn = _make_button("▶  Run Match", Color(0.22, 0.90, 0.44))
	_run_btn.tooltip_text = "Simulate a match with selected map and strategies."
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

	# Map Editor
	var editor_btn := _make_button("🗺️  Map Editor", Color(0.80, 0.60, 0.20))
	editor_btn.tooltip_text = "Create and edit maps visually. Paint terrain, bloodstreams, and resources."
	editor_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/map_editor_scene.tscn"))
	center.add_child(editor_btn)

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

# ─── scanning ────────────────────────────────────────────────────────────────

func _scan_maps_and_strategies() -> void:
	_available_maps.clear()
	_available_strategies.clear()

	# Scan maps/
	var map_dir := DirAccess.open("res://maps")
	if map_dir != null:
		map_dir.list_dir_begin()
		var fname := map_dir.get_next()
		while fname != "":
			if fname.ends_with(".json"):
				_available_maps.append("res://maps/" + fname)
			fname = map_dir.get_next()
		_available_maps.sort()

	# Scan strategies/
	var strat_dir := DirAccess.open("res://strategies")
	if strat_dir != null:
		strat_dir.list_dir_begin()
		var fname := strat_dir.get_next()
		while fname != "":
			if fname.ends_with(".gd"):
				_available_strategies.append("res://strategies/" + fname)
			fname = strat_dir.get_next()
		_available_strategies.sort()

# ─── button handlers ────────────────────────────────────────────────────────

func _on_run_match() -> void:
	if _available_maps.is_empty():
		_set_status("Error: no maps found in res://maps/")
		return
	if _available_strategies.size() < 2:
		_set_status("Error: need at least 2 strategies in res://strategies/")
		return

	var selected_map_idx: int = _map_dropdown.get_selected_id()
	var selected_p0_idx: int = _strat_p0_dropdown.get_selected_id()
	var selected_p1_idx: int = _strat_p1_dropdown.get_selected_id()

	if selected_map_idx < 0 or selected_p0_idx < 0 or selected_p1_idx < 0:
		_set_status("Error: please select map and strategies")
		return

	var map_path: String = _available_maps[selected_map_idx]
	var strat_p0: String = _available_strategies[selected_p0_idx]
	var strat_p1: String = _available_strategies[selected_p1_idx]

	_set_status("Loading map…")
	_run_btn.disabled  = true
	_load_btn.disabled = true
	await get_tree().process_frame

	var map := MapLoader.load_from_file(map_path)
	if map == null:
		_set_status("Error: could not load map at %s" % map_path)
		_run_btn.disabled  = false
		_load_btn.disabled = false
		return

	# Build sim and pre-load strategies on the main thread (load() is not thread-safe).
	var sim := SimulationCore.new(map, [strat_p0, strat_p1], 0)
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
	_run_btn.disabled  = false
	_load_btn.disabled = false

func _on_load_replay() -> void:
	_file_dialog.popup_centered_ratio(0.6)

func _on_file_selected(path: String) -> void:
	_set_status("Loading replay…")
	GameState.pending_log_path = path
	GameState.pending_log      = null
	get_tree().change_scene_to_file(PLAYBACK_SCENE)

# ─── helpers ────────────────────────────────────────────────────────────────

func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text

func _auto_replay_path() -> String:
	var map_name: String = _available_maps[_map_dropdown.get_selected_id()].split("/")[-1].trim_suffix(".json")
	var strat_p0: String = _available_strategies[_strat_p0_dropdown.get_selected_id()].split("/")[-1].trim_suffix(".gd")
	var strat_p1: String = _available_strategies[_strat_p1_dropdown.get_selected_id()].split("/")[-1].trim_suffix(".gd")
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	return "res://replays/match_%s_%s_vs_%s.json" % [stamp, strat_p0, strat_p1]

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

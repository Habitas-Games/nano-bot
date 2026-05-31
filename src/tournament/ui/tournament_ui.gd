class_name TournamentUI
extends Control

const MENU_SCENE       := "res://scenes/main_menu.tscn"
const PLAYBACK_SCENE   := "res://scenes/playback_scene.tscn"
const DEFAULT_MAP      := "res://maps/simple_tissue.json"
const STRATEGIES_DIR   := "res://strategies"
const LEADERBOARD_PATH := "res://replays/tournament_leaderboard.json"

const PLAYER_COLORS: Array = [
	Color(0.25, 0.55, 1.00),
	Color(1.00, 0.30, 0.25),
	Color(0.20, 0.85, 0.40),
	Color(1.00, 0.85, 0.15),
]

var _runner: TournamentRunner       = null
var _board:  Leaderboard            = null

# UI refs
var _status_label: Label
var _progress_bar: ProgressBar
var _start_btn: Button
var _export_btn: Button
var _back_btn: Button
var _table_root: VBoxContainer
var _match_list: VBoxContainer

func _ready() -> void:
	_build_ui()

# ─── build UI ─────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.09, 0.12)
	add_child(bg)

	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# ── Left panel: controls + leaderboard ──────────────────────────────────
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(560, 0)
	left.add_theme_constant_override("separation", 8)
	left.set_h_size_flags(Control.SIZE_SHRINK_BEGIN)
	root.add_child(left)

	# Title
	var title := Label.new()
	title.text = "Tournament"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.15))
	left.add_child(title)

	# Strategies info
	_status_label = Label.new()
	_status_label.text = _strategies_summary()
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.70))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_status_label)

	# Progress bar
	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0
	_progress_bar.max_value = 1
	_progress_bar.value     = 0
	_progress_bar.custom_minimum_size = Vector2(0, 22)
	_progress_bar.visible   = false
	left.add_child(_progress_bar)

	# Buttons row
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	left.add_child(btn_row)

	_start_btn = Button.new()
	_start_btn.text = "▶  Start Tournament"
	_start_btn.add_theme_font_size_override("font_size", 14)
	_start_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.15))
	_start_btn.custom_minimum_size = Vector2(0, 40)
	_start_btn.pressed.connect(_on_start)
	btn_row.add_child(_start_btn)

	_export_btn = Button.new()
	_export_btn.text    = "💾  Export"
	_export_btn.disabled = true
	_export_btn.pressed.connect(_on_export)
	btn_row.add_child(_export_btn)

	_back_btn = Button.new()
	_back_btn.text = "← Menu"
	_back_btn.pressed.connect(func(): get_tree().change_scene_to_file(MENU_SCENE))
	btn_row.add_child(_back_btn)

	left.add_child(HSeparator.new())

	# Leaderboard table header
	left.add_child(_lbl("Leaderboard", 13, true))

	var header := _table_row(["Strategy", "W", "L", "D", "Pts", ""], Color(0.95, 0.95, 0.95))
	left.add_child(header)
	left.add_child(HSeparator.new())

	_table_root = VBoxContainer.new()
	_table_root.add_theme_constant_override("separation", 2)
	left.add_child(_table_root)

	# ── Right panel: match log ───────────────────────────────────────────────
	var right := VBoxContainer.new()
	right.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	right.add_theme_constant_override("separation", 4)
	root.add_child(right)

	var scroll := ScrollContainer.new()
	scroll.set_v_size_flags(Control.SIZE_EXPAND_FILL)
	right.add_child(scroll)

	_match_list = VBoxContainer.new()
	_match_list.add_theme_constant_override("separation", 2)
	_match_list.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	scroll.add_child(_match_list)

	right.add_child(_lbl("Match Results", 13, true))

# ─── tournament control ───────────────────────────────────────────────────────

func _on_start() -> void:
	var strategies := _discover_strategies()
	if strategies.size() < 2:
		_status_label.text = "Need at least 2 strategy files in res://strategies/ to run a tournament."
		return

	var maps := [DEFAULT_MAP]

	_board  = Leaderboard.new()
	_runner = TournamentRunner.new()
	_runner.progress_updated.connect(_on_progress)
	_runner.match_finished.connect(_on_match_finished)
	_runner.tournament_finished.connect(_on_finished)

	var total := _runner.schedule.size()
	# Build schedule first to know total
	_runner.schedule = TournamentRunner._build_schedule(strategies, maps)
	total = _runner.schedule.size()

	_progress_bar.max_value = total
	_progress_bar.value     = 0
	_progress_bar.visible   = true
	_start_btn.disabled     = true
	_status_label.text      = "Running %d matches…" % total

	_runner.start(strategies, maps)

func _on_progress(completed: int, total: int) -> void:
	_progress_bar.value  = completed
	_status_label.text   = "Match %d / %d…" % [completed, total]

func _on_match_finished(result: Dictionary) -> void:
	_board.add_result(result)
	_refresh_table()
	_add_match_row(result)

func _on_finished() -> void:
	_runner.wait()
	_status_label.text  = "Tournament complete — %d matches." % _runner.results.size()
	_start_btn.disabled = false
	_export_btn.disabled = false
	_progress_bar.visible = false
	_refresh_table()

func _on_export() -> void:
	if _board == null:
		return
	_board.save_to_file(ProjectSettings.globalize_path(LEADERBOARD_PATH))
	_status_label.text = "Leaderboard saved to replays/tournament_leaderboard.json"

# ─── leaderboard table ────────────────────────────────────────────────────────

func _refresh_table() -> void:
	for child in _table_root.get_children():
		child.queue_free()
	if _board == null:
		return
	var entries := _board.get_sorted()
	var rank := 1
	for entry: Dictionary in entries:
		var color := Color(0.80, 0.80, 0.80)
		if rank == 1: color = Color(1.00, 0.85, 0.15)
		elif rank == 2: color = Color(0.75, 0.75, 0.80)
		elif rank == 3: color = Color(0.80, 0.55, 0.25)
		if entry.get("dq", false): color = Color(0.65, 0.30, 0.30)

		var name_str: String = "#%d  %s%s" % [rank, entry["name"], "  [DQ]" if entry.get("dq") else ""]
		var row := _table_row([
			name_str,
			str(entry["wins"]),
			str(entry["losses"]),
			str(entry["draws"]),
			str(entry["points"]),
			"",
		], color)
		_table_root.add_child(row)
		rank += 1

# ─── match result log ─────────────────────────────────────────────────────────

func _add_match_row(result: Dictionary) -> void:
	var a := (result["player_a"] as String).get_file().get_basename()
	var b := (result["player_b"] as String).get_file().get_basename()
	var scores: Dictionary = result.get("final_scores", {})
	var sc_a: int = scores.get("0", scores.get(0, 0))
	var sc_b: int = scores.get("1", scores.get(1, 0))
	var wid: int  = int(result.get("winner_id", -1))
	var winner_str := (a if wid == 0 else b) if wid >= 0 else "Draw"

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var txt := "%s %d – %d %s  →  %s  (%d turns)" % [
		a, sc_a, sc_b, b, winner_str, int(result.get("total_turns", 0))
	]
	var lbl := _lbl(txt, 10)
	lbl.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	row.add_child(lbl)

	if result.has("replay_path"):
		var watch := Button.new()
		watch.text = "▶"
		watch.add_theme_font_size_override("font_size", 9)
		var rpath: String = result["replay_path"]
		watch.pressed.connect(func(): _watch_replay(rpath))
		row.add_child(watch)

	_match_list.add_child(row)

func _watch_replay(path: String) -> void:
	GameState.pending_log      = null
	GameState.pending_log_path = ProjectSettings.globalize_path(path)
	get_tree().change_scene_to_file(PLAYBACK_SCENE)

# ─── helpers ─────────────────────────────────────────────────────────────────

func _discover_strategies() -> Array:
	var paths: Array = []
	var dir := DirAccess.open(STRATEGIES_DIR)
	if dir == null:
		return paths
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".gd") and not fname.begins_with("_"):
			paths.append(STRATEGIES_DIR + "/" + fname)
		fname = dir.get_next()
	return paths

func _strategies_summary() -> String:
	var strats := _discover_strategies()
	if strats.is_empty():
		return "No strategy files found in res://strategies/. Add .gd files there to compete."
	var names := strats.map(func(p: String) -> String: return p.get_file().get_basename())
	return "%d strategies found: %s" % [strats.size(), ", ".join(names)]

static func _table_row(cols: Array, color: Color) -> HBoxContainer:
	var widths := [260, 40, 40, 40, 60, 0]
	var row    := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	for i in cols.size():
		var cell := Label.new()
		cell.text = str(cols[i])
		cell.add_theme_font_size_override("font_size", 11)
		cell.add_theme_color_override("font_color", color)
		if widths[i] > 0:
			cell.custom_minimum_size = Vector2(widths[i], 0)
		else:
			cell.set_h_size_flags(Control.SIZE_EXPAND_FILL)
		row.add_child(cell)
	return row

static func _lbl(text: String, size: int, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if bold:
		l.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	return l

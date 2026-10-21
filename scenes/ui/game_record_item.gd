class_name GameRecordItem
extends PanelContainer

## Reusable GameRecordItem Component
## Swiss Editorial list item component for History and Saved Games.
## Replaces heavy card borders with clean hairline-divided rows, high data density,
## and refined typography.

const ThemeManager = preload("res://scripts/services/theme_manager.gd")
const LocalizationManager = preload("res://scripts/services/localization_manager.gd")
const GameTimer = preload("res://scripts/gameplay/game_timer.gd")

signal replay_pressed(seed_val: int, difficulty: String)
signal play_pressed(game_id: String)
signal share_pressed(game_id: String, btn: Button)
signal delete_pressed(game_id: String)

enum Mode { HISTORY, SAVED_GAME }
var current_mode: Mode = Mode.HISTORY

# UI Elements
var root_container: Container
var diff_label: Label
var score_label: Label
var best_score_label: Label
var replay_badge: Label
var progress_label: Label
var time_label: Label
var mistakes_label: Label
var hints_label: Label
var secondary_labels: Array[Label] = []

# Action Buttons
var replay_btn: Button
var resume_btn: Button
var share_btn: Button
var delete_btn: Button

# Stored metadata
var current_data: Dictionary = {}

func _init() -> void:
	size_flags_horizontal = SIZE_EXPAND_FILL
	mouse_filter = MOUSE_FILTER_PASS
	ThemeManager.add_listener(_apply_theme)

func _exit_tree() -> void:
	ThemeManager.remove_listener(_apply_theme)

func setup_history(record: Dictionary, best_record: Dictionary = {}) -> void:
	current_mode = Mode.HISTORY
	current_data = record
	_clear_children()

	# Direct child 0 is an HBoxContainer to preserve test compatibility and horizontal layout
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.size_flags_horizontal = SIZE_EXPAND_FILL
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(hbox)
	root_container = hbox

	var is_tr := (LocalizationManager.get_locale() == LocalizationManager.LOCALE_TR)
	var raw_diff: String = record.get("difficulty", "Medium")
	var diff_text := LocalizationManager.get_difficulty_name(raw_diff)
	var score: int = int(record.get("score", 0))
	var time_s: float = float(record.get("time", 0.0))
	var mistakes: int = int(record.get("mistakes", 0))
	var hints: int = int(record.get("hints", 0))
	var is_replay: bool = bool(record.get("is_replay", false))
	var seed_val: int = int(record.get("seed", 0))
	var best_score: int = int(best_record.get("score", score)) if not best_record.is_empty() else score

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	info_vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(info_vbox)

	# Row 1: Difficulty, Replay badge, Score, Best comparison
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	row1.alignment = BoxContainer.ALIGNMENT_BEGIN
	info_vbox.add_child(row1)

	diff_label = Label.new()
	diff_label.text = diff_text
	diff_label.theme_type_variation = "Body"
	diff_label.add_theme_font_size_override("font_size", 15)
	row1.add_child(diff_label)

	if is_replay:
		replay_badge = Label.new()
		replay_badge.text = "[Replay]"
		replay_badge.theme_type_variation = "TechnicalLabel"
		replay_badge.add_theme_font_size_override("font_size", 11)
		secondary_labels.append(replay_badge)
		row1.add_child(replay_badge)

	score_label = Label.new()
	score_label.text = LocalizationManager.translate("RECORD_SCORE") % score
	score_label.theme_type_variation = "Body"
	score_label.add_theme_font_size_override("font_size", 14)
	row1.add_child(score_label)

	if best_score > score:
		best_score_label = Label.new()
		best_score_label.text = LocalizationManager.translate("RECORD_BEST_SCORE") % best_score
		best_score_label.theme_type_variation = "Caption"
		best_score_label.add_theme_font_size_override("font_size", 11)
		secondary_labels.append(best_score_label)
		row1.add_child(best_score_label)

	# Row 2: Secondary stats (Time, Mistakes, Hints separated by middot)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	row2.alignment = BoxContainer.ALIGNMENT_BEGIN
	info_vbox.add_child(row2)

	time_label = Label.new()
	time_label.text = LocalizationManager.translate("RECORD_TIME") % GameTimer.format_seconds(time_s)
	time_label.theme_type_variation = "Caption"
	time_label.add_theme_font_size_override("font_size", 12)
	secondary_labels.append(time_label)
	row2.add_child(time_label)

	var dot1 := Label.new()
	dot1.text = "•"
	dot1.theme_type_variation = "Caption"
	dot1.add_theme_font_size_override("font_size", 12)
	secondary_labels.append(dot1)
	row2.add_child(dot1)

	mistakes_label = Label.new()
	mistakes_label.text = LocalizationManager.translate("RECORD_MISTAKES") % mistakes
	mistakes_label.theme_type_variation = "Caption"
	mistakes_label.add_theme_font_size_override("font_size", 12)
	secondary_labels.append(mistakes_label)
	row2.add_child(mistakes_label)

	var dot2 := Label.new()
	dot2.text = "•"
	dot2.theme_type_variation = "Caption"
	dot2.add_theme_font_size_override("font_size", 12)
	secondary_labels.append(dot2)
	row2.add_child(dot2)

	hints_label = Label.new()
	hints_label.text = LocalizationManager.translate("RECORD_HINTS") % hints
	hints_label.theme_type_variation = "Caption"
	hints_label.add_theme_font_size_override("font_size", 12)
	secondary_labels.append(hints_label)
	row2.add_child(hints_label)

	# Replay Action Button (icon-only circular control, 44x44 on mobile)
	replay_btn = Button.new()
	replay_btn.name = "ReplayButton"
	replay_btn.text = ""
	replay_btn.tooltip_text = LocalizationManager.translate("BTN_REPLAY_ACTION")
	replay_btn.custom_minimum_size = Vector2(44, 44)
	replay_btn.theme_type_variation = "IconButton"
	replay_btn.icon = ThemeManager.get_icon("rotate-ccw")
	replay_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	replay_btn.add_theme_constant_override("icon_max_width", 20)
	replay_btn.size_flags_vertical = SIZE_SHRINK_CENTER
	replay_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	replay_btn.pressed.connect(func(): replay_pressed.emit(seed_val, raw_diff))
	hbox.add_child(replay_btn)

	_apply_theme()

func setup_saved_game(game_data: Dictionary) -> void:
	current_mode = Mode.SAVED_GAME
	current_data = game_data
	_clear_children()

	var is_tr := (LocalizationManager.get_locale() == LocalizationManager.LOCALE_TR)
	var raw_diff: String = game_data.get("difficulty", "Medium")
	var diff_name := LocalizationManager.get_difficulty_name(raw_diff)
	var pct_int: int = int(game_data.get("progress_percentage", 0))
	var pct_str := LocalizationManager.format_percentage(pct_int)
	var time_str := GameTimer.format_seconds(game_data.get("elapsed_time", 0.0))
	var gid: String = game_data.get("game_id", "")

	var item_vbox := VBoxContainer.new()
	item_vbox.add_theme_constant_override("separation", 6)
	item_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(item_vbox)
	root_container = item_vbox

	# Row 1: Difficulty, Progress, and Primary action (Oyna / Play)
	var row1 := HBoxContainer.new()
	row1.alignment = BoxContainer.ALIGNMENT_CENTER
	row1.size_flags_horizontal = SIZE_EXPAND_FILL
	row1.add_theme_constant_override("separation", 8)
	item_vbox.add_child(row1)

	diff_label = Label.new()
	diff_label.text = diff_name
	diff_label.theme_type_variation = "Body"
	diff_label.add_theme_font_size_override("font_size", 15)
	row1.add_child(diff_label)

	var dot_lbl := Label.new()
	dot_lbl.text = "•"
	dot_lbl.theme_type_variation = "Caption"
	dot_lbl.add_theme_font_size_override("font_size", 12)
	secondary_labels.append(dot_lbl)
	row1.add_child(dot_lbl)

	progress_label = Label.new()
	progress_label.text = LocalizationManager.translate("PROGRESS_LABEL") % pct_str
	progress_label.theme_type_variation = "Caption"
	progress_label.add_theme_font_size_override("font_size", 12)
	progress_label.size_flags_horizontal = SIZE_EXPAND_FILL
	secondary_labels.append(progress_label)
	row1.add_child(progress_label)

	resume_btn = Button.new()
	resume_btn.text = LocalizationManager.translate("BTN_PLAY")
	resume_btn.custom_minimum_size = Vector2(80, 36)
	resume_btn.theme_type_variation = "CompactPrimaryButton"
	resume_btn.icon = ThemeManager.get_icon("play")
	resume_btn.add_theme_constant_override("icon_max_width", 16)
	resume_btn.add_theme_font_size_override("font_size", 13)
	resume_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resume_btn.pressed.connect(func(): play_pressed.emit(gid))
	row1.add_child(resume_btn)

	# Row 2: Elapsed time & secondary actions (Share, Delete)
	var row2 := HBoxContainer.new()
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	row2.size_flags_horizontal = SIZE_EXPAND_FILL
	row2.add_theme_constant_override("separation", 6)
	item_vbox.add_child(row2)

	time_label = Label.new()
	time_label.text = LocalizationManager.translate("RECORD_TIME") % time_str
	time_label.theme_type_variation = "Caption"
	time_label.add_theme_font_size_override("font_size", 12)
	time_label.size_flags_horizontal = SIZE_EXPAND_FILL
	secondary_labels.append(time_label)
	row2.add_child(time_label)

	share_btn = Button.new()
	share_btn.text = LocalizationManager.translate("BTN_SHARE")
	share_btn.custom_minimum_size = Vector2(76, 34)
	share_btn.theme_type_variation = "CompactSecondaryButton"
	share_btn.icon = ThemeManager.get_icon("upload")
	share_btn.add_theme_constant_override("icon_max_width", 16)
	share_btn.add_theme_font_size_override("font_size", 13)
	share_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	share_btn.pressed.connect(func(): share_pressed.emit(gid, share_btn))
	row2.add_child(share_btn)

	delete_btn = Button.new()
	delete_btn.text = LocalizationManager.translate("BTN_DELETE")
	delete_btn.custom_minimum_size = Vector2(50, 34)
	delete_btn.theme_type_variation = "GhostButton"
	delete_btn.icon = ThemeManager.get_icon("x")
	delete_btn.add_theme_constant_override("icon_max_width", 16)
	delete_btn.add_theme_font_size_override("font_size", 13)
	delete_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	delete_btn.pressed.connect(func(): delete_pressed.emit(gid))
	row2.add_child(delete_btn)

	_apply_theme()

func _clear_children() -> void:
	secondary_labels.clear()
	for c in get_children():
		c.queue_free()

func _apply_theme() -> void:
	# Clean editorial hairline row separator: 1px bottom border
	var border_col: Color = ThemeManager.get_color("border_subtle")
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.TRANSPARENT
	sb.border_width_bottom = 1
	sb.border_color = border_col
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	add_theme_stylebox_override("panel", sb)

	var sec_col := ThemeManager.get_color("text_secondary")
	for lbl in secondary_labels:
		if is_instance_valid(lbl):
			lbl.add_theme_color_override("font_color", sec_col)
	if diff_label != null and is_instance_valid(diff_label):
		diff_label.add_theme_color_override("font_color", ThemeManager.get_color("text_given"))
	if score_label != null and is_instance_valid(score_label):
		score_label.add_theme_color_override("font_color", ThemeManager.get_color("text_user"))

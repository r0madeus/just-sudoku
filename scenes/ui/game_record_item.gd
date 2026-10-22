class_name GameRecordItem
extends PanelContainer

## One row of a game list (Saved games, History), built the same way everywhere:
## a thumbnail of the board, a title line (level, score), a quiet detail line, and a single
## round primary action on the right. Rows sit together in one card (see ListCard); each row
## draws the hairline that separates it from the row above.
## Saved games keep Share and Delete one tap away behind "⋯", so the row has one main action.

const ThemeManager = preload("res://scripts/services/theme_manager.gd")
const LocalizationManager = preload("res://scripts/services/localization_manager.gd")
const GameTimer = preload("res://scripts/gameplay/game_timer.gd")
const MiniBoard = preload("res://scenes/ui/mini_board.gd")
const AppModal = preload("res://scenes/ui/app_modal.gd")

signal replay_pressed(seed_val: int, difficulty: String)
signal play_pressed(game_id: String)
signal share_pressed(game_id: String, btn: Button)
signal delete_pressed(game_id: String)

enum Mode { HISTORY, SAVED_GAME }
var current_mode: Mode = Mode.HISTORY

const THUMB_SIZE: float = 52.0
const ACTION_SIZE: float = 44.0

# UI Elements
var root_container: Container
var thumbnail: MiniBoard
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
var more_btn: Button
## Live only while the actions sheet ("⋯") is open
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

func _notification(what: int) -> void:
	# The divider depends on the position in the list
	if what == NOTIFICATION_PARENTED or what == NOTIFICATION_MOVED_IN_PARENT:
		queue_redraw()

func _draw() -> void:
	if get_index() > 0:
		draw_line(Vector2(0, 0), Vector2(size.x, 0), ThemeManager.get_color("border_subtle"), 1.0)

## Row skeleton: [thumbnail] [title line / detail line] ... actions are appended by the caller
func _build_row() -> Array:
	_clear_children()
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.size_flags_horizontal = SIZE_EXPAND_FILL
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(hbox)
	root_container = hbox

	thumbnail = MiniBoard.new()
	thumbnail.custom_minimum_size = Vector2(THUMB_SIZE, THUMB_SIZE)
	thumbnail.size_flags_vertical = SIZE_SHRINK_CENTER
	hbox.add_child(thumbnail)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 3)
	hbox.add_child(info)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	info.add_child(title_row)

	var detail_row := HBoxContainer.new()
	detail_row.add_theme_constant_override("separation", 6)
	info.add_child(detail_row)

	diff_label = Label.new()
	diff_label.theme_type_variation = "Body"
	diff_label.add_theme_font_size_override("font_size", 15)
	title_row.add_child(diff_label)
	return [hbox, title_row, detail_row]

func _caption(text: String, parent: Container, expand: bool = false) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.theme_type_variation = "Caption"
	lbl.add_theme_font_size_override("font_size", 12)
	if expand:
		# Only the last label of a line may shorten; an ellipsis label has no minimum width,
		# so on the others it would let the line squeeze them away entirely
		lbl.size_flags_horizontal = SIZE_EXPAND_FILL
		lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	secondary_labels.append(lbl)
	parent.add_child(lbl)
	return lbl

func _round_action(icon_name: String, tooltip: String, primary: bool) -> Button:
	var btn := Button.new()
	btn.text = ""
	btn.tooltip_text = tooltip
	btn.custom_minimum_size = Vector2(ACTION_SIZE, ACTION_SIZE)
	btn.theme_type_variation = "IconButton"
	btn.icon = ThemeManager.get_icon(icon_name)
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.add_theme_constant_override("icon_max_width", 20)
	btn.size_flags_vertical = SIZE_SHRINK_CENTER
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.set_meta("primary", primary)
	return btn

func setup_history(record: Dictionary, best_record: Dictionary = {}) -> void:
	current_mode = Mode.HISTORY
	current_data = record
	var parts := _build_row()
	var hbox: HBoxContainer = parts[0]
	var title_row: HBoxContainer = parts[1]
	var detail_row: HBoxContainer = parts[2]

	var raw_diff: String = record.get("difficulty", "Medium")
	var score: int = int(record.get("score", 0))
	var seed_val: int = int(record.get("seed", 0))
	var best_score: int = int(best_record.get("score", score)) if not best_record.is_empty() else score
	thumbnail.set_strings(String(record.get("puzzle", "")))

	diff_label.text = LocalizationManager.get_difficulty_name(raw_diff)
	if bool(record.get("is_replay", false)):
		replay_badge = Label.new()
		replay_badge.text = LocalizationManager.translate("BADGE_REPLAY")
		replay_badge.theme_type_variation = "TechnicalLabel"
		replay_badge.add_theme_font_size_override("font_size", 11)
		replay_badge.size_flags_vertical = SIZE_SHRINK_CENTER
		secondary_labels.append(replay_badge)
		title_row.add_child(replay_badge)

	score_label = Label.new()
	score_label.text = LocalizationManager.translate("RECORD_SCORE") % score
	score_label.theme_type_variation = "Body"
	score_label.add_theme_font_size_override("font_size", 14)
	title_row.add_child(score_label)
	if best_score > score:
		best_score_label = _caption(LocalizationManager.translate("RECORD_BEST_SCORE") % best_score, title_row)

	time_label = _caption(GameTimer.format_seconds(float(record.get("time", 0.0))), detail_row)
	_caption("•", detail_row)
	mistakes_label = _caption(LocalizationManager.translate("RECORD_MISTAKES") % int(record.get("mistakes", 0)), detail_row)
	_caption("•", detail_row)
	hints_label = _caption(LocalizationManager.translate("RECORD_HINTS") % int(record.get("hints", 0)), detail_row, true)

	replay_btn = _round_action("rotate-ccw", LocalizationManager.translate("BTN_REPLAY_ACTION"), true)
	replay_btn.name = "ReplayButton"
	replay_btn.pressed.connect(func(): replay_pressed.emit(seed_val, raw_diff))
	hbox.add_child(replay_btn)
	_apply_theme()

func setup_saved_game(game_data: Dictionary) -> void:
	current_mode = Mode.SAVED_GAME
	current_data = game_data
	var parts := _build_row()
	var hbox: HBoxContainer = parts[0]
	var detail_row: HBoxContainer = parts[2]
	var gid: String = game_data.get("game_id", "")
	thumbnail.set_strings(String(game_data.get("current", "")), String(game_data.get("initial", "")))

	diff_label.text = LocalizationManager.get_difficulty_name(game_data.get("difficulty", "Medium"))
	var pct := LocalizationManager.format_percentage(int(game_data.get("progress_percentage", 0)))
	progress_label = _caption(LocalizationManager.translate("PROGRESS_LABEL") % pct, detail_row)
	_caption("•", detail_row)
	time_label = _caption(GameTimer.format_seconds(float(game_data.get("elapsed_time", 0.0))), detail_row, true)

	more_btn = _round_action("more-horizontal", LocalizationManager.translate("BTN_MORE_ACTIONS"), false)
	more_btn.custom_minimum_size = Vector2(36, ACTION_SIZE)
	more_btn.pressed.connect(open_actions)
	hbox.add_child(more_btn)

	resume_btn = _round_action("play", LocalizationManager.translate("BTN_PLAY"), true)
	resume_btn.pressed.connect(func(): play_pressed.emit(gid))
	hbox.add_child(resume_btn)
	_apply_theme()

## Share / Delete for a saved game, in a small sheet over the screen. Returns the sheet.
func open_actions() -> AppModal:
	var gid: String = current_data.get("game_id", "")
	var sheet := AppModal.new()
	sheet.title = "%s • %s" % [diff_label.text, progress_label.text if progress_label != null else ""]
	sheet.dismissible_backdrop = true
	sheet.primary_btn.visible = false
	sheet.cancel_button_text = LocalizationManager.translate("BTN_CANCEL")
	share_btn = sheet.add_button(LocalizationManager.translate("BTN_SHARE_PUZZLE"), true, "share")
	share_btn.icon = ThemeManager.get_icon("upload")
	share_btn.add_theme_constant_override("icon_max_width", 18)
	delete_btn = sheet.add_button(LocalizationManager.translate("BTN_DELETE"), true, "delete")
	delete_btn.add_theme_color_override("font_color", ThemeManager.get_color("text_conflict"))
	sheet.custom_action.connect(func(action: String):
		if action == "share":
			# Stays open so the button can show "Copied"
			share_pressed.emit(gid, share_btn)
		elif action == "delete":
			sheet.close_modal()
			delete_pressed.emit(gid)
	)
	sheet.visibility_changed.connect(func():
		if not sheet.visible:
			sheet.queue_free()
	)
	_modal_host().add_child(sheet)
	sheet.open_modal()
	return sheet

## Modals belong to the outermost Control (the app root), so they cover the whole screen and
## pick up the app theme
func _modal_host() -> Node:
	var host: Node = self
	while host.get_parent() is Control:
		host = host.get_parent()
	return host

func _clear_children() -> void:
	secondary_labels.clear()
	replay_badge = null
	best_score_label = null
	progress_label = null
	for c in get_children():
		remove_child(c)
		c.queue_free()

func _apply_theme() -> void:
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = 4
	sb.content_margin_right = 0
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	add_theme_stylebox_override("panel", sb)

	var sec_col := ThemeManager.get_color("text_secondary")
	for lbl in secondary_labels:
		if is_instance_valid(lbl):
			lbl.add_theme_color_override("font_color", sec_col)
	if diff_label != null and is_instance_valid(diff_label):
		diff_label.add_theme_color_override("font_color", ThemeManager.get_color("text_given"))
	if score_label != null and is_instance_valid(score_label):
		score_label.add_theme_color_override("font_color", ThemeManager.get_color("accent"))
	for btn in [replay_btn, resume_btn, more_btn]:
		if btn == null or not is_instance_valid(btn):
			continue
		if btn.get_meta("primary", false):
			# The row's one main action: a filled accent circle
			var sb_btn := ThemeManager.create_flat_stylebox(ThemeManager.get_color("accent"), int(ACTION_SIZE / 2))
			for state in ["normal", "hover", "pressed", "focus"]:
				btn.add_theme_stylebox_override(state, sb_btn)
			btn.add_theme_color_override("icon_normal_color", Color.WHITE)
			btn.add_theme_color_override("icon_hover_color", Color.WHITE)
			btn.add_theme_color_override("icon_pressed_color", Color.WHITE)
	queue_redraw()

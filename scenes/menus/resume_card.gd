class_name ResumeCard
extends "res://scenes/ui/glass_panel.gd"

## Home-screen hero: a live miniature of the unfinished game with difficulty, time and progress.
## Without an active game it shows a quiet decorative board and an invitation instead.
## Tapping it while a game exists emits `pressed` (same as Continue).

const LocalizationManager = preload("res://scripts/services/localization_manager.gd")
const MiniBoard = preload("res://scenes/ui/mini_board.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")

signal pressed()

var mini_board: MiniBoard
var title_label: Label
var meta_label: Label
var progress_bar: ProgressBar
var progress_label: Label
var body_label: Label

var has_game: bool = false

func _init() -> void:
	super()
	elevated = true
	corner_radius = 24.0
	pad_h = 16
	pad_v = 16
	shadow_size = 16
	shadow_offset = Vector2(0, 6)
	size_flags_horizontal = SIZE_EXPAND_FILL
	mouse_filter = MOUSE_FILTER_STOP

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(row)

	mini_board = MiniBoard.new()
	row.add_child(mini_board)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = SIZE_EXPAND_FILL
	info.size_flags_vertical = SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 6)
	info.mouse_filter = MOUSE_FILTER_IGNORE
	row.add_child(info)

	title_label = Label.new()
	title_label.theme_type_variation = "Header"
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# The empty-state title is a short phrase; let it take a second line instead of an ellipsis
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.max_lines_visible = 2
	title_label.mouse_filter = MOUSE_FILTER_IGNORE
	info.add_child(title_label)

	meta_label = Label.new()
	meta_label.theme_type_variation = "TechnicalLabel"
	meta_label.add_theme_font_size_override("font_size", 12)
	meta_label.mouse_filter = MOUSE_FILTER_IGNORE
	info.add_child(meta_label)

	body_label = Label.new()
	body_label.theme_type_variation = "Caption"
	body_label.add_theme_font_size_override("font_size", 12)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.custom_minimum_size.x = 140.0
	body_label.mouse_filter = MOUSE_FILTER_IGNORE
	info.add_child(body_label)

	progress_bar = ProgressBar.new()
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size = Vector2(0, 6)
	progress_bar.size_flags_vertical = SIZE_SHRINK_CENTER
	progress_bar.mouse_filter = MOUSE_FILTER_IGNORE
	info.add_child(progress_bar)

	progress_label = Label.new()
	progress_label.theme_type_variation = "Caption"
	progress_label.add_theme_font_size_override("font_size", 11)
	progress_label.mouse_filter = MOUSE_FILTER_IGNORE
	info.add_child(progress_label)

	set_game(null)

func _enter_tree() -> void:
	super()
	LocalizationManager.add_listener(_refresh_texts)
	ThemeManager.add_listener(_apply_card_theme)
	_apply_card_theme()

func _exit_tree() -> void:
	super()
	LocalizationManager.remove_listener(_refresh_texts)
	ThemeManager.remove_listener(_apply_card_theme)

func _gui_input(event: InputEvent) -> void:
	if not has_game:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		pressed.emit()
		accept_event()

## Short screens: smaller miniature and padding so the home screen fits without scrolling
func set_compact(compact: bool) -> void:
	mini_board.custom_minimum_size = Vector2(108, 108) if compact else Vector2(148, 148)
	pad_v = 12 if compact else 16
	pad_h = 14 if compact else 16
	title_label.add_theme_font_size_override("font_size", 18 if compact else 20)

## Shows `state` (or the empty invitation when null)
func set_game(state: GameState) -> void:
	has_game = state != null
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if has_game else Control.CURSOR_ARROW
	if has_game:
		mini_board.set_board(state.current_board, state.initial_puzzle)
		var empty_total: int = state.initial_puzzle.get_empty_cell_count()
		var empty_now: int = state.current_board.get_empty_cell_count()
		var filled_pct: int = 100 if empty_total <= 0 else int(round(100.0 * float(empty_total - empty_now) / float(empty_total)))
		progress_bar.value = filled_pct
		title_label.text = LocalizationManager.get_difficulty_name(state.difficulty)
		meta_label.text = LocalizationManager.format_duration(state.elapsed_time)
		body_label.text = ""
		progress_label.text = LocalizationManager.translate("RESUME_PROGRESS") % filled_pct
	else:
		mini_board.set_decorative()
		progress_bar.value = 0
		title_label.text = LocalizationManager.translate("RESUME_EMPTY_TITLE")
		meta_label.text = ""
		body_label.text = LocalizationManager.translate("RESUME_EMPTY_BODY")
		progress_label.text = ""
	meta_label.visible = has_game
	body_label.visible = not has_game
	progress_bar.visible = has_game
	progress_label.visible = has_game
	_apply_card_theme()

func _refresh_texts() -> void:
	# Texts depend on the game being shown; the owner refreshes the card on language change
	if not has_game:
		title_label.text = LocalizationManager.translate("RESUME_EMPTY_TITLE")
		body_label.text = LocalizationManager.translate("RESUME_EMPTY_BODY")

func _apply_card_theme() -> void:
	if title_label == null:
		return
	title_label.add_theme_color_override("font_color", ThemeManager.get_color("text_given"))
	meta_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	body_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	progress_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))

	var track := StyleBoxFlat.new()
	track.bg_color = Color(ThemeManager.get_color("border_subtle"), 0.6)
	track.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = ThemeManager.get_color("accent_blue", ThemeManager.get_color("accent"))
	fill.set_corner_radius_all(3)
	progress_bar.add_theme_stylebox_override("background", track)
	progress_bar.add_theme_stylebox_override("fill", fill)
	mini_board.queue_redraw()

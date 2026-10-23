class_name TechniquesScreen
extends Control

const LocalizationManager = preload("res://scripts/services/localization_manager.gd")
const ThemeManager = preload("res://scripts/services/theme_manager.gd")
const ResponsiveManager = preload("res://scripts/services/responsive_manager.gd")
const AmbientBackdrop = preload("res://scenes/ui/ambient_backdrop.gd")
const GlassPanel = preload("res://scenes/ui/glass_panel.gd")
const AdaptiveColumns = preload("res://scenes/ui/adaptive_columns.gd")
const TechniqueLibrary = preload("res://scripts/data/technique_library.gd")

## Techniques guide (tutorial + practice). The list shows every technique the solver knows, easiest
## first, with a plain-language description and the level it starts to matter at. A lesson opens
## in the same screen: a real position from the precomputed examples (assets/techniques), the
## pattern highlighted and the notes the technique removes struck through, the solver's own
## explanation for it (found again here, so it reads in the language on screen), a button to play
## the move, one for the next example, and one that starts a real game that needs the technique.

signal back_requested()
## Practice: a puzzle whose solution path uses the technique, to be played like a new game
signal practice_requested(gen: SudokuGenerator.GeneratedPuzzle)

## Shortest side the lesson board is drawn at, even on a short screen
const MIN_BOARD_SIDE: float = 240.0
## Share of the screen height a phone's lesson board may take, so the explanation and the buttons
## below it stay close to the board
const PHONE_BOARD_HEIGHT_SHARE: float = 0.42

var bg: ColorRect
var margin: MarginContainer
var back_btn: Button
var title: Label

# --- List ---
var list_scroll: ScrollContainer
var intro_label: Label
var list_card: PanelContainer
var list_grid: GridContainer
## Technique name -> the row's button, in list order
var row_buttons: Dictionary = {}

# --- Lesson ---
var lesson_scroll: ScrollContainer
var lesson_cols: AdaptiveColumns
var board_holder: Control
var lesson_grid: SudokuGrid
var level_label: Label
var example_label: Label
var description_label: Label
var explanation_label: Label
var legend_label: Label
var show_move_btn: Button
var next_example_btn: Button
var practice_btn: Button
var practice_note: Label

## Technique of the open lesson, "" while the list is shown
var current_technique: String = ""
var example_index: int = 0
## The step the lesson is about, found on the example position
var current_step: SudokuSolver.SolveStep = null
## True once "Show the move" has played the step on the board
var move_shown: bool = false

var _lesson_state: GameState = null
var _start_board: SudokuBoard = null
var _rng := RandomNumberGenerator.new()
var _last_practice: String = ""

func _init() -> void:
	set_anchors_preset(PRESET_FULL_RECT)

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_rng.randomize()
	_build_ui()
	_apply_responsive_layout()
	_update_locale_texts()
	LocalizationManager.add_listener(_update_locale_texts)
	ThemeManager.add_listener(_on_theme_changed)

func _exit_tree() -> void:
	LocalizationManager.remove_listener(_update_locale_texts)
	ThemeManager.remove_listener(_on_theme_changed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_responsive_layout()

# ---------------------------------------------------------------------------------------------
# Layout
# ---------------------------------------------------------------------------------------------

func _apply_responsive_layout() -> void:
	if margin == null:
		return
	ResponsiveManager.apply_content_margins(self, margin, ResponsiveManager.MAX_CONTENT_WIDTH, true)
	var vp := ResponsiveManager.get_viewport_size(self)
	var columns := ResponsiveManager.content_columns(vp)
	list_grid.columns = columns
	lesson_cols.columns = columns
	var side := _board_side(vp, columns)
	board_holder.custom_minimum_size = Vector2(side, side)

## Edge of the lesson board: the width of its column, capped like the game board, and on a phone
## no more than a share of the height
func _board_side(vp: Vector2, columns: int) -> float:
	var room: float = vp.x - margin.get_theme_constant("margin_left") - margin.get_theme_constant("margin_right")
	if columns == 2:
		room = (room - lesson_cols.separation) * 0.5
	var side: float = minf(room, ResponsiveManager.MAX_BOARD_WIDTH * ResponsiveManager.tablet_factor(vp))
	if columns == 1:
		side = minf(side, maxf(MIN_BOARD_SIDE, vp.y * PHONE_BOARD_HEIGHT_SHARE))
	else:
		side = minf(side, maxf(MIN_BOARD_SIDE, vp.y - 160.0))
	return maxf(side, 120.0)

func _build_ui() -> void:
	var ambient_bg := AmbientBackdrop.new()
	ambient_bg.intensity = 0.7
	ambient_bg.color = ThemeManager.get_color("bg")
	bg = ambient_bg
	add_child(bg)

	margin = MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 14)
	margin.add_child(root_vbox)

	# --- Header: back, title ---
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(header)

	back_btn = Button.new()
	back_btn.text = ""
	back_btn.theme_type_variation = "IconButton"
	back_btn.icon = ThemeManager.get_icon("chevron-left")
	back_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_btn.add_theme_constant_override("icon_max_width", 20)
	back_btn.custom_minimum_size = Vector2(44, 44)
	back_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back_btn.pressed.connect(handle_back)
	header.add_child(back_btn)

	title = Label.new()
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.theme_type_variation = "Header"
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(44, 0)
	header.add_child(spacer)

	root_vbox.add_child(HSeparator.new())

	_build_list(root_vbox)
	_build_lesson(root_vbox)

func _build_list(root_vbox: VBoxContainer) -> void:
	list_scroll = ScrollContainer.new()
	list_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	root_vbox.add_child(list_scroll)

	var pad := MarginContainer.new()
	pad.size_flags_horizontal = SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_bottom", 16)
	list_scroll.add_child(pad)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	pad.add_child(column)

	intro_label = Label.new()
	intro_label.theme_type_variation = "Caption"
	ThemeManager.set_font_size(intro_label, 13)
	intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(intro_label)

	# The rows sit together in one card, like the groups in Settings and the rows of History
	list_card = GlassPanel.card(20.0, 14, 4)
	list_card.size_flags_vertical = SIZE_SHRINK_BEGIN
	column.add_child(list_card)

	list_grid = GridContainer.new()
	list_grid.columns = 1
	list_grid.size_flags_horizontal = SIZE_EXPAND_FILL
	list_grid.add_theme_constant_override("h_separation", 24)
	list_grid.add_theme_constant_override("v_separation", 0)
	list_card.add_child(list_grid)

func _build_lesson(root_vbox: VBoxContainer) -> void:
	lesson_scroll = ScrollContainer.new()
	lesson_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	lesson_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lesson_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	lesson_scroll.visible = false
	root_vbox.add_child(lesson_scroll)

	var pad := MarginContainer.new()
	pad.size_flags_horizontal = SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_bottom", 16)
	lesson_scroll.add_child(pad)

	lesson_cols = AdaptiveColumns.new()
	lesson_cols.size_flags_horizontal = SIZE_EXPAND_FILL
	lesson_cols.separation = 16
	pad.add_child(lesson_cols)

	# 1. Level, example counter and what the technique is (column 2 on a wide screen)
	var intro := VBoxContainer.new()
	intro.add_theme_constant_override("separation", 8)
	AdaptiveColumns.set_column(intro, 1)
	lesson_cols.add_child(intro)

	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 12)
	intro.add_child(meta)
	level_label = Label.new()
	level_label.theme_type_variation = "Caption"
	ThemeManager.set_font_size(level_label, 11)
	level_label.size_flags_horizontal = SIZE_EXPAND_FILL
	meta.add_child(level_label)
	example_label = Label.new()
	example_label.theme_type_variation = "Caption"
	ThemeManager.set_font_size(example_label, 11)
	meta.add_child(example_label)

	description_label = Label.new()
	description_label.theme_type_variation = "Caption"
	ThemeManager.set_font_size(description_label, 13)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_child(description_label)

	# 2. The example position. It reads nothing: the board is for looking at.
	board_holder = Control.new()
	board_holder.mouse_filter = MOUSE_FILTER_IGNORE
	lesson_cols.add_child(board_holder)
	_lesson_state = GameState.new()
	lesson_grid = SudokuGrid.new()
	lesson_grid.set_anchors_preset(PRESET_FULL_RECT)
	lesson_grid.mouse_filter = MOUSE_FILTER_IGNORE
	lesson_grid.focus_mode = FOCUS_NONE
	lesson_grid.multi_select_enabled = false
	board_holder.add_child(lesson_grid)
	lesson_grid.bind_game_state(_lesson_state)

	# 3. What happens here, and the buttons
	var rest := VBoxContainer.new()
	rest.add_theme_constant_override("separation", 12)
	AdaptiveColumns.set_column(rest, 1)
	lesson_cols.add_child(rest)

	var explain_card := GlassPanel.card(16.0, 14, 12)
	rest.add_child(explain_card)
	var explain_box := VBoxContainer.new()
	explain_box.add_theme_constant_override("separation", 8)
	explain_card.add_child(explain_box)
	explanation_label = Label.new()
	explanation_label.theme_type_variation = "Body"
	ThemeManager.set_font_size(explanation_label, 14)
	explanation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explain_box.add_child(explanation_label)
	legend_label = Label.new()
	legend_label.theme_type_variation = "Caption"
	ThemeManager.set_font_size(legend_label, 12)
	legend_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explain_box.add_child(legend_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	rest.add_child(buttons)
	show_move_btn = _lesson_button("SecondaryButton", ResponsiveManager.HEIGHT_BUTTON_SECONDARY)
	show_move_btn.pressed.connect(toggle_move)
	buttons.add_child(show_move_btn)
	next_example_btn = _lesson_button("SecondaryButton", ResponsiveManager.HEIGHT_BUTTON_SECONDARY)
	next_example_btn.pressed.connect(next_example)
	buttons.add_child(next_example_btn)

	practice_btn = _lesson_button("PrimaryButton", ResponsiveManager.HEIGHT_BUTTON_PRIMARY)
	practice_btn.pressed.connect(start_practice)
	rest.add_child(practice_btn)
	practice_note = Label.new()
	practice_note.theme_type_variation = "Caption"
	ThemeManager.set_font_size(practice_note, 11)
	practice_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	practice_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rest.add_child(practice_note)

func _lesson_button(variation: String, height: float) -> Button:
	var btn := Button.new()
	btn.theme_type_variation = variation
	btn.size_flags_horizontal = SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, height)
	btn.clip_text = true
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ThemeManager.set_font_size(btn, 14)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return btn

# ---------------------------------------------------------------------------------------------
# List
# ---------------------------------------------------------------------------------------------

func _rebuild_list() -> void:
	for c in list_grid.get_children():
		list_grid.remove_child(c)
		c.free()
	row_buttons.clear()
	for tech in TechniqueLibrary.ORDER:
		list_grid.add_child(_make_row(tech))

## One technique: its name and the level it starts at, what it is, and a chevron. A button
## behind the text takes the taps (and the keyboard focus), so the whole row is the target.
func _make_row(tech: String) -> Control:
	var row := TechniqueRow.new()
	row.name = "Row_" + tech.replace(" ", "_")
	row.size_flags_horizontal = SIZE_EXPAND_FILL

	var open_btn := Button.new()
	open_btn.name = "Open"
	open_btn.flat = true
	open_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(ThemeManager.get_color("accent"), 0.10)
	hover.set_corner_radius_all(ThemeManager.RADIUS_SM)
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(ThemeManager.get_color("accent"), 0.18)
	open_btn.add_theme_stylebox_override("hover", hover)
	open_btn.add_theme_stylebox_override("pressed", pressed)
	open_btn.add_theme_stylebox_override("focus", hover)
	open_btn.pressed.connect(open_lesson.bind(tech))
	open_btn.tooltip_text = LocalizationManager.get_technique_title(tech)
	row.add_child(open_btn)
	row_buttons[tech] = open_btn

	var content := MarginContainer.new()
	content.add_theme_constant_override("margin_top", 12)
	content.add_theme_constant_override("margin_bottom", 12)
	row.add_child(content)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	content.add_child(hbox)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 3)
	hbox.add_child(text_col)

	var title_row := HFlowContainer.new()
	title_row.add_theme_constant_override("h_separation", 10)
	title_row.add_theme_constant_override("v_separation", 0)
	text_col.add_child(title_row)
	var name_lbl := Label.new()
	name_lbl.name = "Name"
	name_lbl.text = LocalizationManager.get_technique_title(tech)
	name_lbl.theme_type_variation = "Subheader"
	ThemeManager.set_font_size(name_lbl, 15)
	name_lbl.add_theme_color_override("font_color", ThemeManager.get_color("text_given"))
	title_row.add_child(name_lbl)
	var level_lbl := Label.new()
	level_lbl.name = "Level"
	level_lbl.text = _first_level_text(tech)
	level_lbl.theme_type_variation = "Caption"
	ThemeManager.set_font_size(level_lbl, 11)
	level_lbl.size_flags_vertical = SIZE_SHRINK_CENTER
	level_lbl.add_theme_color_override("font_color", ThemeManager.get_color("accent"))
	title_row.add_child(level_lbl)

	var desc_lbl := Label.new()
	desc_lbl.name = "Description"
	desc_lbl.text = LocalizationManager.translate(TechniqueLibrary.description_key(tech))
	desc_lbl.theme_type_variation = "Caption"
	ThemeManager.set_font_size(desc_lbl, 12)
	desc_lbl.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_col.add_child(desc_lbl)

	var chevron := TextureRect.new()
	chevron.texture = ThemeManager.get_icon("chevron-right")
	chevron.custom_minimum_size = Vector2(18, 18)
	chevron.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chevron.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chevron.size_flags_vertical = SIZE_SHRINK_CENTER
	chevron.modulate = ThemeManager.get_color("text_secondary")
	hbox.add_child(chevron)

	_ignore_mouse(content)
	return row

func _ignore_mouse(node: Node) -> void:
	if node is Control:
		node.mouse_filter = MOUSE_FILTER_IGNORE
	for c in node.get_children():
		_ignore_mouse(c)

func _first_level_text(tech: String) -> String:
	var level := LocalizationManager.get_difficulty_name(TechniqueLibrary.first_level(tech))
	return LocalizationManager.upper(LocalizationManager.translate("TECHS_FIRST_LEVEL") % level)

## A list row; draws the hairline between it and the row above, and keeps the tap button under
## the text
class TechniqueRow extends PanelContainer:
	func _init() -> void:
		var empty := StyleBoxEmpty.new()
		add_theme_stylebox_override("panel", empty)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PARENTED or what == NOTIFICATION_MOVED_IN_PARENT:
			queue_redraw()

	func _draw() -> void:
		var columns: int = get_parent().columns if get_parent() is GridContainer else 1
		if get_index() >= columns:
			draw_line(Vector2(0, 0), Vector2(size.x, 0), ThemeManager.get_color("border_subtle"), 1.0)

# ---------------------------------------------------------------------------------------------
# Lesson
# ---------------------------------------------------------------------------------------------

## Shows the list again (the way in from the menu, and back from a lesson)
func show_list() -> void:
	current_technique = ""
	current_step = null
	list_scroll.visible = true
	lesson_scroll.visible = false
	list_scroll.scroll_vertical = 0
	_update_header()

## Opens the lesson of a technique at an example. False when there is nothing to show for it.
func open_lesson(tech: String, example: int = 0) -> bool:
	var examples := TechniqueLibrary.examples(tech)
	if examples.is_empty():
		return false
	current_technique = tech
	example_index = posmod(example, examples.size())
	list_scroll.visible = false
	lesson_scroll.visible = true
	lesson_scroll.scroll_vertical = 0
	_load_example()
	_update_header()
	_update_lesson_texts()
	return true

## The next example of the open lesson, from the last round to the first
func next_example() -> void:
	if current_technique.is_empty():
		return
	var count := TechniqueLibrary.examples(current_technique).size()
	if count < 2:
		return
	example_index = (example_index + 1) % count
	_load_example()
	_update_lesson_texts()

## Plays the move on the board; pressed again, puts the position back
func toggle_move() -> void:
	if current_step == null:
		return
	move_shown = not move_shown
	_show_position()
	_update_lesson_texts()

## A real game from one of the technique's practice puzzles
func start_practice() -> void:
	var puzzles := TechniqueLibrary.practice(current_technique)
	if puzzles.is_empty():
		return
	var pick: Dictionary = puzzles[_rng.randi() % puzzles.size()]
	if puzzles.size() > 1 and String(pick["puzzle"]) == _last_practice:
		pick = puzzles[(puzzles.find(pick) + 1) % puzzles.size()]
	_last_practice = pick["puzzle"]
	var gen := SudokuGenerator.from_grid(pick["puzzle"], SudokuGenerator.generate_new_seed())
	if gen != null:
		practice_requested.emit(gen)

## Back one level: a lesson to the list, the list to the menu
func handle_back() -> void:
	if current_technique.is_empty():
		back_requested.emit()
	else:
		show_list()

func _load_example() -> void:
	var example: Dictionary = TechniqueLibrary.examples(current_technique)[example_index]
	_start_board = TechniqueLibrary.board_of(example)
	var puzzle := SudokuBoard.new()
	puzzle.from_string_flat(String(example["puzzle"]), true)
	_lesson_state.initial_puzzle = puzzle
	# The step is found again on the position, so its explanation is in the language on screen
	current_step = SudokuSolver.find_next_step(_start_board.clone())
	move_shown = false
	_show_position()

## The board as the lesson stands: the position or the position after the move, with the step's
## cells marked and, before the move, the notes it removes struck through
func _show_position() -> void:
	var board := _start_board.clone()
	if move_shown and current_step != null:
		TechniqueLibrary.apply_step(board, current_step)
	_lesson_state.current_board = board

	var strikes: Dictionary = {}
	var pattern: Array[int] = []
	var digit: int = 0
	var unit: int = -1
	if current_step != null:
		pattern = current_step.cells.duplicate()
		if not move_shown:
			for idx_key in current_step.eliminations.keys():
				var mask: int = 0
				for d in current_step.eliminations[idx_key]:
					mask |= 1 << int(d)
				strikes[int(idx_key)] = mask
		if current_step.digit != 0:
			digit = current_step.digit
		unit = current_step.focus_unit

	lesson_grid.selected_idx = pattern[0] if not pattern.is_empty() else -1
	lesson_grid.multi_cells = pattern if pattern.size() > 1 else ([] as Array[int])
	lesson_grid.highlight_digit = digit
	lesson_grid.strike_marks = strikes
	lesson_grid.set_hint_focus(unit)
	lesson_grid.refresh_highlights()

# ---------------------------------------------------------------------------------------------
# Texts and theme
# ---------------------------------------------------------------------------------------------

func _on_theme_changed() -> void:
	if bg != null:
		bg.color = ThemeManager.get_color("bg")
	if list_grid == null:
		return
	_rebuild_list()
	_style_lesson()
	lesson_grid.refresh_highlights()

func _update_locale_texts() -> void:
	if list_grid == null:
		return
	back_btn.tooltip_text = LocalizationManager.translate("BTN_MENU")
	back_btn.icon = ThemeManager.get_icon("chevron-left")
	_rebuild_list()
	intro_label.text = LocalizationManager.translate("TECHS_INTRO")
	_update_header()
	if not current_technique.is_empty():
		_update_lesson_texts()
	_style_lesson()

## The screen's title: its own name over the list, the technique's over a lesson
func _update_header() -> void:
	if current_technique.is_empty():
		title.text = LocalizationManager.translate("TECHS_TITLE")
	else:
		title.text = LocalizationManager.get_technique_title(current_technique)

func _update_lesson_texts() -> void:
	var tech := current_technique
	level_label.text = _first_level_text(tech)
	var count := TechniqueLibrary.examples(tech).size()
	example_label.text = LocalizationManager.translate("TECHS_EXAMPLE_OF") % [example_index + 1, count]
	description_label.text = LocalizationManager.translate(TechniqueLibrary.description_key(tech))
	if current_step != null:
		explanation_label.text = current_step.explanation
		var legend_key := "TECHS_LEGEND_PLACE" if current_step.digit != 0 else "TECHS_LEGEND_ELIMINATE"
		legend_label.text = LocalizationManager.translate(legend_key)
	show_move_btn.text = LocalizationManager.translate("TECHS_BTN_RESET" if move_shown else "TECHS_BTN_SHOW_MOVE")
	next_example_btn.text = LocalizationManager.translate("TECHS_BTN_NEXT_EXAMPLE")
	next_example_btn.disabled = count < 2
	practice_btn.text = LocalizationManager.translate("TECHS_BTN_PRACTICE")
	practice_btn.disabled = TechniqueLibrary.practice(tech).is_empty()
	practice_note.text = LocalizationManager.translate("TECHS_PRACTICE_NOTE")

func _style_lesson() -> void:
	var text_sec := ThemeManager.get_color("text_secondary")
	level_label.add_theme_color_override("font_color", ThemeManager.get_color("accent"))
	example_label.add_theme_color_override("font_color", text_sec)
	description_label.add_theme_color_override("font_color", text_sec)
	explanation_label.add_theme_color_override("font_color", ThemeManager.get_color("text_given"))
	legend_label.add_theme_color_override("font_color", text_sec)
	practice_note.add_theme_color_override("font_color", text_sec)
	intro_label.add_theme_color_override("font_color", text_sec)

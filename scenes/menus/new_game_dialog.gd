class_name NewGameDialog
extends "res://scenes/ui/app_modal.gd"

const AsyncPuzzleGenerator = preload("res://scripts/services/async_puzzle_generator.gd")
const PuzzleShareService = preload("res://scripts/services/puzzle_share_service.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const PuzzlePrefetcher = preload("res://scripts/services/puzzle_prefetcher.gd")
const SegmentedControl = preload("res://scenes/ui/segmented_control.gd")

## New Game Selection & Difficulty Preview Modal (GDD §13, §44)
## Clean, focused, calm modal adhering to the Global Design System & AppModal.

signal start_game_requested(generated_puzzle: SudokuGenerator.GeneratedPuzzle)
signal import_puzzle_requested()

var current_difficulty: String = DifficultyAnalyzer.LEVEL_MEDIUM
var current_seed: int = 0
var current_generated: SudokuGenerator.GeneratedPuzzle = null
var active_req_id: int = 0
var is_generating: bool = false
## True once the previewed puzzle has been started, so it must not go back to the prefetch cache
var _current_started: bool = false

# Difficulty & Segmented Control
var diff_lbl: Label
var diff_segmented: SegmentedControl
var seg_card: PanelContainer
var diff_container: HBoxContainer
var diff_buttons: Array[Button] = []

# Preview Elements
var preview_panel: PanelContainer
var loading_box: VBoxContainer
var loading_label: Label
var preview_content: VBoxContainer
var preview_diff_label: Label
var preview_time_label: Label
var preview_techs_label: Label

# Compatibility aliases
var start_btn: Button :
	get:
		return primary_btn
var cancel_btn_ref: Button :
	get:
		return cancel_btn

# Internal compatibility fields
var preview_seed_label: Label
var copy_seed_btn: Button
var regen_btn: Button
var import_btn: Button

func _init() -> void:
	super()
	max_modal_width = 380.0
	_build_new_game_ui()
	_update_locale_texts()
	LocalizationManager.add_listener(_update_locale_texts)
	ThemeManager.add_listener(_apply_theme_colors)

func _exit_tree() -> void:
	LocalizationManager.remove_listener(_update_locale_texts)
	ThemeManager.remove_listener(_apply_theme_colors)

func _build_new_game_ui() -> void:
	# 1. Segmented Difficulty Control
	diff_segmented = SegmentedControl.new()
	var diffs := [
		DifficultyAnalyzer.LEVEL_EASY,
		DifficultyAnalyzer.LEVEL_MEDIUM,
		DifficultyAnalyzer.LEVEL_HARD,
		DifficultyAnalyzer.LEVEL_EXPERT
	]
	for d in diffs:
		diff_segmented.add_segment(d, LocalizationManager.get_difficulty_name(d))
	diff_segmented.item_selected.connect(func(d, _idx): _select_difficulty(d))
	body_vbox.add_child(diff_segmented)

	# Compatibility proxies
	seg_card = diff_segmented
	diff_container = diff_segmented.hbox
	diff_buttons = diff_segmented.buttons

	# 2. Focused Difficulty Preview
	preview_panel = PanelContainer.new()
	preview_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	preview_panel.custom_minimum_size = Vector2(0, 114)
	body_vbox.add_child(preview_panel)

	loading_box = VBoxContainer.new()
	loading_box.size_flags_horizontal = SIZE_EXPAND_FILL
	loading_box.size_flags_vertical = SIZE_EXPAND_FILL
	loading_box.alignment = BoxContainer.ALIGNMENT_CENTER
	loading_box.visible = false
	preview_panel.add_child(loading_box)

	loading_label = Label.new()
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.theme_type_variation = "Subtitle"
	loading_label.add_theme_font_size_override("font_size", 13)
	loading_box.add_child(loading_label)

	preview_content = VBoxContainer.new()
	preview_content.size_flags_horizontal = SIZE_EXPAND_FILL
	preview_content.size_flags_vertical = SIZE_EXPAND_FILL
	preview_content.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_content.add_theme_constant_override("separation", 5)
	preview_panel.add_child(preview_content)

	preview_diff_label = Label.new()
	preview_diff_label.theme_type_variation = "Header"
	preview_diff_label.add_theme_font_size_override("font_size", 20)
	preview_content.add_child(preview_diff_label)

	preview_time_label = Label.new()
	preview_time_label.theme_type_variation = "Subtitle"
	preview_time_label.add_theme_font_size_override("font_size", 13)
	preview_content.add_child(preview_time_label)

	preview_techs_label = Label.new()
	preview_techs_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	preview_techs_label.theme_type_variation = "Body"
	preview_techs_label.add_theme_font_size_override("font_size", 12)
	preview_content.add_child(preview_techs_label)

	preview_seed_label = Label.new()
	preview_seed_label.theme_type_variation = "TechnicalLabel"
	# Left, like the level, time and techniques above it
	preview_seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	preview_seed_label.add_theme_font_size_override("font_size", 11)
	preview_seed_label.visible = true
	preview_content.add_child(preview_seed_label)

	# Compatibility stubs
	diff_lbl = Label.new()
	copy_seed_btn = Button.new()
	copy_seed_btn.pressed.connect(_on_copy_seed_pressed)
	regen_btn = Button.new()
	regen_btn.pressed.connect(func(): _generate_preview(true))
	primary_btn.icon = ThemeManager.get_icon("play")
	primary_btn.add_theme_constant_override("icon_max_width", 18)
	import_btn = Button.new()
	import_btn.icon = ThemeManager.get_icon("download")
	import_btn.add_theme_constant_override("icon_max_width", 18)
	import_btn.pressed.connect(func(): import_puzzle_requested.emit())

	_apply_theme_colors()

func _apply_theme_colors() -> void:
	if preview_panel != null:
		var border_col: Color = ThemeManager.get_color("border_subtle")
		var surf_col: Color = ThemeManager.get_color("surface")
		var sb_prev := ThemeManager.create_flat_stylebox(
			surf_col,
			ThemeManager.RADIUS_SM,
			ThemeManager.BORDER_HAIRLINE,
			border_col,
			14, 10
		)
		preview_panel.add_theme_stylebox_override("panel", sb_prev)
	if preview_diff_label != null:
		preview_diff_label.add_theme_color_override("font_color", ThemeManager.get_color("text_given"))
	if preview_time_label != null:
		preview_time_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	if preview_techs_label != null:
		preview_techs_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	if preview_seed_label != null:
		preview_seed_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	if loading_label != null:
		loading_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	_update_diff_buttons_state()

func open_dialog(initial_diff: String = DifficultyAnalyzer.LEVEL_MEDIUM) -> void:
	current_difficulty = initial_diff
	_update_diff_buttons_state()
	_generate_preview()
	open_modal()

func _select_difficulty(d: String) -> void:
	if current_difficulty == d and not is_generating:
		return
	current_difficulty = d
	if diff_segmented != null and diff_segmented.get_selected_id() != d:
		diff_segmented.select_id(d)
	_update_diff_buttons_state()
	_generate_preview()

func _update_diff_buttons_state() -> void:
	if diff_segmented != null and diff_segmented.get_selected_id() != current_difficulty:
		diff_segmented.select_id(current_difficulty)
	for btn in diff_buttons:
		var d: String = btn.get_meta("diff", "")
		var is_cur := (d == current_difficulty)
		if is_cur:
			btn.theme_type_variation = "PrimaryButton"
			btn.add_theme_color_override("font_color", Color.WHITE)
		else:
			btn.theme_type_variation = "SegmentButton"
			btn.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
		btn.disabled = false

func _generate_preview(force_new_seed: bool = false) -> void:
	if active_req_id != 0:
		AsyncPuzzleGenerator.cancel_request(active_req_id)
		active_req_id = 0

	# A previewed puzzle that was never started stays useful for later: give it back
	if current_generated != null and not _current_started and not force_new_seed:
		PuzzlePrefetcher.put_back(current_generated)
	current_generated = null
	_current_started = false

	var prepared: SudokuGenerator.GeneratedPuzzle = PuzzlePrefetcher.take(current_difficulty)
	if prepared != null:
		current_seed = prepared.seed_value
		_on_puzzle_generated(prepared)
		return

	is_generating = true
	if primary_btn != null:
		primary_btn.disabled = true
	if regen_btn != null:
		regen_btn.disabled = true

	loading_box.visible = true
	preview_content.visible = false
	var diff_name := LocalizationManager.get_difficulty_name(current_difficulty)
	loading_label.text = LocalizationManager.translate("LOADING_PUZZLE") % diff_name

	current_seed = SudokuGenerator.generate_new_seed()
	active_req_id = AsyncPuzzleGenerator.request_puzzle_async(
		current_seed,
		current_difficulty,
		_on_puzzle_generated
	)

func _on_puzzle_generated(generated: SudokuGenerator.GeneratedPuzzle) -> void:
	if generated == null:
		return

	current_generated = generated
	is_generating = false
	active_req_id = 0

	loading_box.visible = false
	preview_content.visible = true

	_update_preview_display()

	if primary_btn != null:
		primary_btn.disabled = false
	if regen_btn != null:
		regen_btn.disabled = false

func _update_preview_display() -> void:
	if current_generated == null:
		return

	var diff_name := LocalizationManager.get_difficulty_name(current_generated.difficulty)
	preview_diff_label.text = diff_name
	var est_mins: int = int(round(float(current_generated.estimated_seconds) / 60.0))
	preview_time_label.text = LocalizationManager.translate("ESTIMATED_TIME") % est_mins

	var tech_names: Array[String] = []
	var count: int = 0
	for t in current_generated.top_techniques:
		if count >= 3:
			break
		tech_names.append(LocalizationManager.translate(t))
		count += 1
	if tech_names.is_empty():
		tech_names.append(LocalizationManager.translate("TECH_NAKED_SINGLE"))
	var tech_str: String = " · ".join(tech_names)
	preview_techs_label.text = LocalizationManager.translate("KEY_TECHNIQUES") % tech_str
	if preview_seed_label != null:
		preview_seed_label.text = LocalizationManager.translate("SEED_LABEL") % current_generated.seed_value

func _on_confirmed() -> void:
	if current_generated != null and not is_generating:
		var gen := current_generated
		_current_started = true
		close_modal()
		confirmed.emit()
		start_game_requested.emit(gen)

func _on_copy_seed_pressed() -> void:
	if current_seed != 0:
		PuzzleShareService.copy_to_clipboard(str(current_seed))
		copy_seed_btn.text = LocalizationManager.translate("COPIED_FEEDBACK")
		var t := create_tween()
		if t != null:
			t.tween_interval(1.5)
			t.tween_callback(func():
				if is_instance_valid(copy_seed_btn):
					copy_seed_btn.text = LocalizationManager.translate("BTN_COPY_SEED")
			)

func _update_locale_texts() -> void:
	title = LocalizationManager.translate("NEW_GAME_TITLE")
	ok_button_text = LocalizationManager.translate("BTN_START")
	cancel_button_text = LocalizationManager.translate("BTN_CANCEL")
	if diff_lbl != null:
		diff_lbl.text = LocalizationManager.translate("DIFF_SELECT_PROMPT")
	for btn in diff_buttons:
		var d: String = btn.get_meta("diff", "")
		var d_name := LocalizationManager.get_difficulty_name(d)
		btn.text = d_name
		if diff_segmented != null:
			diff_segmented.set_segment_text(d, d_name)
	_update_diff_buttons_state()
	if copy_seed_btn != null:
		copy_seed_btn.text = LocalizationManager.translate("BTN_COPY_SEED")
	if regen_btn != null:
		regen_btn.text = LocalizationManager.translate("BTN_REGEN_SEED")
	if import_btn != null:
		import_btn.text = LocalizationManager.translate("BTN_IMPORT_NEW_GAME")
	if current_generated != null:
		_update_preview_display()
	elif is_generating:
		var diff_name := LocalizationManager.get_difficulty_name(current_difficulty)
		loading_label.text = LocalizationManager.translate("LOADING_PUZZLE") % diff_name

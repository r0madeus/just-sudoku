class_name ImportPuzzleDialog
extends "res://scenes/ui/app_modal.gd"

const GameState = preload("res://scripts/gameplay/game_state.gd")
const PuzzleShareService = preload("res://scripts/services/puzzle_share_service.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")

## Dialog to import puzzles from Seed, 81-character puzzle string, or Save JSON (GDD §31, §44)
## Powered by unified AppModal architecture.

signal puzzle_imported(game_state: GameState)

var info_lbl: Label
var input_edit: TextEdit
var paste_btn: Button
var clear_btn: Button
var diff_row: HBoxContainer
var d_lbl: Label
var diff_option: OptionButton
var status_card: PanelContainer
var status_label: Label

var _parsed_state: GameState = null
var _last_parse_result: Dictionary = {}

func _init() -> void:
	super()
	max_modal_width = 420.0
	_build_import_ui()
	_update_locale_texts()
	confirmed.connect(_on_import_confirmed)
	LocalizationManager.add_listener(_update_locale_texts)
	ThemeManager.add_listener(_apply_import_theme_polish)

func _exit_tree() -> void:
	LocalizationManager.remove_listener(_update_locale_texts)
	ThemeManager.remove_listener(_apply_import_theme_polish)

func _build_import_ui() -> void:
	primary_btn.icon = ThemeManager.get_icon("play")
	primary_btn.add_theme_constant_override("icon_max_width", 16)
	info_lbl = Label.new()
	info_lbl.theme_type_variation = "Caption"
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	info_lbl.add_theme_font_size_override("font_size", 13)
	body_vbox.add_child(info_lbl)

	# Text input area
	input_edit = TextEdit.new()
	input_edit.custom_minimum_size = Vector2(0, 76)
	input_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	input_edit.text_changed.connect(_on_input_changed)
	body_vbox.add_child(input_edit)

	# Utility button row
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 6)
	body_vbox.add_child(action_row)

	paste_btn = Button.new()
	paste_btn.theme_type_variation = "SecondaryButton"
	paste_btn.icon = ThemeManager.get_icon("download")
	paste_btn.add_theme_constant_override("icon_max_width", 16)
	paste_btn.add_theme_font_size_override("font_size", 13)
	paste_btn.custom_minimum_size = Vector2(0, 34)
	paste_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	paste_btn.pressed.connect(_on_paste_pressed)
	action_row.add_child(paste_btn)

	clear_btn = Button.new()
	clear_btn.theme_type_variation = "GhostButton"
	clear_btn.icon = ThemeManager.get_icon("x")
	clear_btn.add_theme_constant_override("icon_max_width", 14)
	clear_btn.add_theme_font_size_override("font_size", 13)
	clear_btn.custom_minimum_size = Vector2(0, 34)
	clear_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clear_btn.pressed.connect(func(): input_edit.text = ""; _validate_input())
	action_row.add_child(clear_btn)

	var row_spacer := Control.new()
	row_spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	action_row.add_child(row_spacer)

	diff_row = HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 6)
	action_row.add_child(diff_row)

	d_lbl = Label.new()
	d_lbl.theme_type_variation = "Caption"
	d_lbl.add_theme_font_size_override("font_size", 12)
	diff_row.add_child(d_lbl)

	diff_option = OptionButton.new()
	diff_option.add_item(DifficultyAnalyzer.LEVEL_EASY)
	diff_option.add_item(DifficultyAnalyzer.LEVEL_MEDIUM)
	diff_option.add_item(DifficultyAnalyzer.LEVEL_HARD)
	diff_option.add_item(DifficultyAnalyzer.LEVEL_EXPERT)
	diff_option.selected = 1 # Medium default
	diff_option.theme_type_variation = "SecondaryButton"
	diff_option.add_theme_font_size_override("font_size", 12)
	diff_option.custom_minimum_size = Vector2(0, 34)
	diff_option.item_selected.connect(func(_i): _validate_input())
	diff_row.add_child(diff_option)

	# Validation Status Card
	status_card = PanelContainer.new()
	status_card.theme_type_variation = "SurfacePanel"
	body_vbox.add_child(status_card)

	status_label = Label.new()
	status_label.theme_type_variation = "Body"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", ThemeManager.get_color("text_notes"))
	status_card.add_child(status_label)

	_apply_import_theme_polish()

func _apply_import_theme_polish() -> void:
	if info_lbl != null:
		info_lbl.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	if d_lbl != null:
		d_lbl.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))

func open_dialog() -> void:
	if input_edit != null:
		input_edit.text = ""
	_parsed_state = null
	_validate_input()
	open_modal()

func _on_paste_pressed() -> void:
	var clip_text := PuzzleShareService.get_clipboard_text()
	if not clip_text.is_empty():
		input_edit.text = clip_text
		_validate_input()

func _on_input_changed() -> void:
	_validate_input()

func _validate_input() -> void:
	if input_edit == null:
		return
	var text: String = input_edit.text.strip_edges()
	var selected_diff: String = DifficultyAnalyzer.LEVEL_MEDIUM
	if diff_option != null:
		match diff_option.selected:
			0: selected_diff = DifficultyAnalyzer.LEVEL_EASY
			1: selected_diff = DifficultyAnalyzer.LEVEL_MEDIUM
			2: selected_diff = DifficultyAnalyzer.LEVEL_HARD
			3: selected_diff = DifficultyAnalyzer.LEVEL_EXPERT

	var ok_btn := get_ok_button()

	if text.is_empty():
		_parsed_state = null
		if status_label != null:
			status_label.text = LocalizationManager.translate("ERROR_EMPTY_INPUT")
			status_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
		if diff_row != null:
			diff_row.visible = true
		if ok_btn != null:
			ok_btn.disabled = true
		return

	var result := PuzzleShareService.parse_import_string(text, selected_diff)
	_last_parse_result = result

	if result.get("success", false) == true:
		_parsed_state = result["game_state"]
		if diff_row != null:
			diff_row.visible = (result["type"] == "seed")
		if status_label != null:
			status_label.text = result.get("info", "OK")
			status_label.theme_type_variation = "TechnicalLabel" if result.get("type", "") == "seed" else "Body"
			status_label.add_theme_color_override("font_color", ThemeManager.get_color("accent"))
		if ok_btn != null:
			ok_btn.disabled = false
	else:
		_parsed_state = null
		if diff_row != null:
			diff_row.visible = true
		if status_label != null:
			status_label.text = result.get("error", LocalizationManager.translate("ERROR_INVALID_INPUT"))
			status_label.add_theme_color_override("font_color", ThemeManager.get_color("text_conflict"))
		if ok_btn != null:
			ok_btn.disabled = true

func _on_import_confirmed() -> void:
	if _parsed_state != null:
		puzzle_imported.emit(_parsed_state)

func _update_locale_texts() -> void:
	title = LocalizationManager.translate("IMPORT_DIALOG_TITLE")
	ok_button_text = LocalizationManager.translate("BTN_START_IMPORTED")
	cancel_button_text = LocalizationManager.translate("BTN_CANCEL")
	if info_lbl != null:
		info_lbl.text = LocalizationManager.translate("IMPORT_INSTRUCTION")
	if input_edit != null:
		input_edit.placeholder_text = LocalizationManager.translate("IMPORT_PLACEHOLDER")
	if paste_btn != null:
		paste_btn.text = LocalizationManager.translate("BTN_PASTE")
	if clear_btn != null:
		clear_btn.text = LocalizationManager.translate("BTN_CLEAR")
	if d_lbl != null:
		d_lbl.text = LocalizationManager.translate("HISTORY_DIFF_FILTER")
	if diff_option != null:
		diff_option.set_item_text(0, LocalizationManager.get_difficulty_name(DifficultyAnalyzer.LEVEL_EASY))
		diff_option.set_item_text(1, LocalizationManager.get_difficulty_name(DifficultyAnalyzer.LEVEL_MEDIUM))
		diff_option.set_item_text(2, LocalizationManager.get_difficulty_name(DifficultyAnalyzer.LEVEL_HARD))
		diff_option.set_item_text(3, LocalizationManager.get_difficulty_name(DifficultyAnalyzer.LEVEL_EXPERT))
	if is_inside_tree() or input_edit != null:
		_validate_input()

class_name SmartNumpad
extends Control

## Smart Numpad with valid candidate filtering, Notes mode toggle, and Erase (GDD §16, §17)

signal number_pressed(num: int)
signal erase_pressed()
signal notes_toggled(is_notes: bool)

const SettingsScreen = preload("res://scenes/menus/settings_screen.gd")

var is_notes_mode: bool = false
var smart_enabled: bool = true

var num_buttons: Array[Button] = []
var notes_toggle_btn: Button
var erase_btn: Button
var main_container: Container
var grid_container: GridContainer
var selected_digit: int = 0
var is_compact_mode: bool = false

func _init() -> void:
	custom_minimum_size = Vector2(0, 242)
	_build_ui()

# Registered on enter (not _init) so re-parenting, which fires _exit_tree, keeps the listener
func _enter_tree() -> void:
	ThemeManager.add_listener(_on_theme_changed)

func _exit_tree() -> void:
	ThemeManager.remove_listener(_on_theme_changed)

func _on_theme_changed() -> void:
	_update_selected_visuals()

func set_selected_digit(val: int) -> void:
	if selected_digit == val:
		return
	selected_digit = val
	_update_selected_visuals()

func set_compact_mode(compact: bool) -> void:
	if is_compact_mode == compact:
		return
	is_compact_mode = compact
	var btn_size := Vector2(62, 62) if is_compact_mode else Vector2(74, 74)
	var separation := 6 if is_compact_mode else 10
	var total_h := (btn_size.y * 3.0) + (float(separation) * 2.0)
	custom_minimum_size = Vector2(0, total_h)
	if grid_container != null:
		grid_container.custom_minimum_size = Vector2(total_h, total_h)
		grid_container.add_theme_constant_override("h_separation", separation)
		grid_container.add_theme_constant_override("v_separation", separation)
	for btn in num_buttons:
		btn.custom_minimum_size = btn_size
	_update_selected_visuals()

func _update_selected_visuals() -> void:
	var font_sz: int = 21 if is_compact_mode else 25
	for d in range(1, 10):
		if d - 1 < num_buttons.size():
			var btn: Button = num_buttons[d - 1]
			var is_sel: bool = (d == selected_digit)
			ThemeManager.apply_numpad_button_style(btn, -1, is_sel)
			btn.add_theme_font_size_override("font_size", font_sz)
			var font_inter := ThemeManager.get_font_inter()
			if font_inter != null:
				btn.add_theme_font_override("font", font_inter)

func _ready() -> void:
	pass

func _build_ui() -> void:
	var center_box := CenterContainer.new()
	center_box.set_anchors_preset(PRESET_FULL_RECT)
	center_box.mouse_filter = MOUSE_FILTER_PASS
	add_child(center_box)

	# 3x3 square numpad layout (1 2 3 / 4 5 6 / 7 8 9) - Substantial 74x74 square buttons with 10px gaps
	grid_container = GridContainer.new()
	grid_container.columns = 3
	grid_container.custom_minimum_size = Vector2(242, 242)
	grid_container.add_theme_constant_override("h_separation", 10)
	grid_container.add_theme_constant_override("v_separation", 10)
	center_box.add_child(grid_container)
	main_container = grid_container

	for d in range(1, 10):
		var btn := Button.new()
		btn.text = str(d)
		btn.size_flags_horizontal = SIZE_EXPAND_FILL
		btn.size_flags_vertical = SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(74, 74)
		btn.add_theme_font_size_override("font_size", 25)
		var font_inter := ThemeManager.get_font_inter()
		if font_inter != null:
			btn.add_theme_font_override("font", font_inter)
		ThemeManager.apply_numpad_button_style(btn)
		btn.pressed.connect(func():
			if SettingsScreen.animations_enabled and btn.is_inside_tree():
				btn.pivot_offset = btn.size * 0.5
				var bt := btn.create_tween()
				if bt != null:
					bt.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.04).set_trans(Tween.TRANS_SINE)
					bt.tween_property(btn, "scale", Vector2.ONE, 0.06).set_trans(Tween.TRANS_SINE)
			set_selected_digit(d)
			number_pressed.emit(d)
		)
		grid_container.add_child(btn)
		num_buttons.append(btn)

func set_notes_mode(active: bool) -> void:
	is_notes_mode = active
	notes_toggled.emit(is_notes_mode)

func toggle_notes_mode() -> void:
	set_notes_mode(not is_notes_mode)

## Updates disabled states of buttons based on selected cell and board rules (GDD §16)
func update_smart_states(board: SudokuBoard, selected_idx: int) -> void:
	if board == null:
		return

	# Count total occurrences of each number on the grid
	var digit_counts: Dictionary = {}
	for d in range(1, 10):
		digit_counts[d] = 0
	for idx in range(SudokuBoard.CELL_COUNT):
		var val: int = board.get_cell(idx)
		if val >= 1 and val <= 9:
			digit_counts[val] += 1

	var is_smart: bool = smart_enabled and SettingsScreen.smart_numpad_enabled

	for d in range(1, 10):
		var btn: Button = num_buttons[d - 1]
		var is_completed_digit: bool = (digit_counts[d] >= 9)

		if not is_smart:
			# Smart Numpad disabled: all 1..9 digits are fully usable and unlocked
			btn.disabled = false
		elif is_notes_mode or selected_idx == -1:
			# Notes mode or no cell selected: digits enabled unless completed on board
			btn.disabled = is_completed_digit
		else:
			# Smart mode: if digit conflicts with existing peers, disable
			var can_place: bool = SudokuValidator.is_valid_placement(board, selected_idx, d)
			btn.disabled = is_completed_digit or not can_place

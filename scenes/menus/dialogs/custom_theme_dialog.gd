class_name CustomThemeDialog
extends "res://scenes/ui/app_modal.gd"

## Custom Theme Editor Dialog (GDD §37, §38)
## Features live 3x3 mini-grid preview, grouped color pickers, and compact preset base buttons.
## Powered by unified AppModal architecture.

signal theme_saved()

var _working_palette: Dictionary = {}

# UI Controls
var preview_card: PanelContainer
var preview_bg: ColorRect
var preview_cells: Array[Dictionary] = []
var preview_grid_lines: Control
var picker_buttons: Dictionary = {}
var field_labels: Dictionary = {}
var preset_prompt_label: Label
var preset_buttons: Array[Button] = []
var picker_scroll: ScrollContainer
var picker_list: VBoxContainer
var group_board_lbl: Label
var group_numbers_lbl: Label

const CUSTOM_KEYS: Array[String] = [
	"bg",
	"grid_major",
	"cell_bg",
	"cell_selected",
	"text_given",
	"text_user",
	"accent_blue",
	"text_conflict",
	"text_notes"
]

const KEYS_BOARD: Array[String] = [
	"bg",
	"grid_major",
	"cell_bg",
	"cell_selected"
]

const KEYS_NUMBERS: Array[String] = [
	"text_given",
	"text_user",
	"accent_blue",
	"text_conflict",
	"text_notes"
]

const KEY_LABELS: Dictionary = {
	"bg": "COLOR_BG",
	"grid_major": "COLOR_GRID",
	"cell_bg": "COLOR_CELL",
	"cell_selected": "COLOR_SELECTED",
	"text_given": "COLOR_TEXT_GIVEN",
	"text_user": "COLOR_TEXT_USER",
	"accent_blue": "COLOR_ACCENT",
	"text_conflict": "COLOR_ERROR",
	"text_notes": "COLOR_NOTES"
}

func _init() -> void:
	super()
	max_modal_width = 440.0
	_init_working_palette()
	_build_ui()
	_update_locale_texts()
	LocalizationManager.add_listener(_update_locale_texts)

func _exit_tree() -> void:
	LocalizationManager.remove_listener(_update_locale_texts)

func _init_working_palette() -> void:
	_working_palette = ThemeManager.PALETTES[ThemeManager.current_theme_name].duplicate() if ThemeManager.PALETTES.has(ThemeManager.current_theme_name) else ThemeManager.PALETTES[ThemeManager.THEME_DARK].duplicate()

func _build_ui() -> void:
	primary_btn.icon = ThemeManager.get_icon("save")
	primary_btn.add_theme_constant_override("icon_max_width", 16)
	body_vbox.add_theme_constant_override("separation", 10)

	# 1. Live Mini-Grid Preview Card
	preview_card = PanelContainer.new()
	preview_card.custom_minimum_size = Vector2(0, 126)
	preview_card.theme_type_variation = "SurfacePanel"
	body_vbox.add_child(preview_card)

	var preview_inner := CenterContainer.new()
	preview_inner.custom_minimum_size = Vector2(0, 116)
	preview_card.add_child(preview_inner)

	var grid_frame := Control.new()
	grid_frame.custom_minimum_size = Vector2(116, 116)
	preview_inner.add_child(grid_frame)

	preview_bg = ColorRect.new()
	preview_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid_frame.add_child(preview_bg)

	# 3x3 sample cells inside preview
	var sample_grid := GridContainer.new()
	sample_grid.columns = 3
	sample_grid.add_theme_constant_override("h_separation", 2)
	sample_grid.add_theme_constant_override("v_separation", 2)
	sample_grid.position = Vector2(2, 2)
	sample_grid.size = Vector2(112, 112)
	grid_frame.add_child(sample_grid)

	preview_cells.clear()
	var cell_sb := ThemeManager.create_flat_stylebox(Color.TRANSPARENT, 0, 0, Color.TRANSPARENT, 0, 0)
	for i in range(9):
		var cell_panel := PanelContainer.new()
		cell_panel.custom_minimum_size = Vector2(36, 36)
		cell_panel.add_theme_stylebox_override("panel", cell_sb)
		sample_grid.add_child(cell_panel)

		var bg_rect := ColorRect.new()
		bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		cell_panel.add_child(bg_rect)

		var lbl := Label.new()
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ThemeManager.set_font_size(lbl, 15)
		cell_panel.add_child(lbl)

		var notes_lbl := Label.new()
		notes_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		notes_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		notes_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ThemeManager.set_font_size(notes_lbl, 8)
		cell_panel.add_child(notes_lbl)

		preview_cells.append({
			"panel": cell_panel,
			"bg": bg_rect,
			"label": lbl,
			"notes": notes_lbl
		})

	# 2. Preset Base Copy Row
	var preset_vbox := VBoxContainer.new()
	preset_vbox.add_theme_constant_override("separation", 4)
	body_vbox.add_child(preset_vbox)

	preset_prompt_label = Label.new()
	preset_prompt_label.theme_type_variation = "Caption"
	preset_vbox.add_child(preset_prompt_label)

	# Wraps to a second line when the names do not fit, so each preset stays a full-size target
	var preset_row := HFlowContainer.new()
	preset_row.add_theme_constant_override("h_separation", 6)
	preset_row.add_theme_constant_override("v_separation", 6)
	preset_vbox.add_child(preset_row)

	preset_buttons.clear()
	var presets := [
		ThemeManager.THEME_DARK,
		ThemeManager.THEME_LIGHT,
		ThemeManager.THEME_SEPIA,
		ThemeManager.THEME_FOREST,
		ThemeManager.THEME_AMOLED
	]
	for p_name in presets:
		var btn := Button.new()
		btn.text = p_name
		btn.set_meta("preset", p_name)
		btn.size_flags_horizontal = SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, ResponsiveManager.TOUCH_TARGET_MIN)
		btn.theme_type_variation = "SegmentButton"
		ThemeManager.set_font_size(btn, ThemeManager.FONT_SIZE_SUBTITLE)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(func(): _copy_preset(p_name))
		preset_row.add_child(btn)
		preset_buttons.append(btn)

	# 3. Grouped Color Pickers in Scroll Area
	var scroll := ScrollContainer.new()
	TouchScroll.attach(scroll)
	scroll.custom_minimum_size = Vector2(0, 160)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	picker_scroll = scroll
	body_vbox.add_child(scroll)

	var pickers_vbox := VBoxContainer.new()
	pickers_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pickers_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(pickers_vbox)
	picker_list = pickers_vbox
	pickers_vbox.minimum_size_changed.connect(_fit_picker_scroll)

	# Group 1: Board & Surfaces
	group_board_lbl = Label.new()
	group_board_lbl.theme_type_variation = "Caption"
	pickers_vbox.add_child(group_board_lbl)

	var grid_board := GridContainer.new()
	grid_board.columns = 2
	grid_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_board.add_theme_constant_override("h_separation", 14)
	grid_board.add_theme_constant_override("v_separation", 6)
	pickers_vbox.add_child(grid_board)

	for key in KEYS_BOARD:
		_add_picker_row(grid_board, key)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 2)
	pickers_vbox.add_child(sep)

	# Group 2: Numbers & Accents
	group_numbers_lbl = Label.new()
	group_numbers_lbl.theme_type_variation = "Caption"
	pickers_vbox.add_child(group_numbers_lbl)

	var grid_numbers := GridContainer.new()
	grid_numbers.columns = 2
	grid_numbers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_numbers.add_theme_constant_override("h_separation", 14)
	grid_numbers.add_theme_constant_override("v_separation", 6)
	pickers_vbox.add_child(grid_numbers)

	for key in KEYS_NUMBERS:
		_add_picker_row(grid_numbers, key)

	_refresh_preview()

func _add_picker_row(parent: Control, key: String) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)

	var lbl := Label.new()
	lbl.theme_type_variation = "Body"
	ThemeManager.set_font_size(lbl, 12)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(lbl)
	field_labels[key] = lbl

	var cpb := ColorPickerButton.new()
	cpb.custom_minimum_size = Vector2(52, ResponsiveManager.TOUCH_TARGET_MIN)
	cpb.edit_alpha = false
	# The swatch is drawn inside the stylebox margins; the theme's pill buttons have wide ones,
	# which squeezed the colour into a thin bar. A small rounded frame shows it whole.
	for state in ["normal", "hover", "pressed", "focus"]:
		var frame := ThemeManager.create_flat_stylebox(ThemeManager.get_color("surface"), ThemeManager.RADIUS_SM,
			ThemeManager.BORDER_HAIRLINE, ThemeManager.get_color("border_focus" if state == "hover" else "border_subtle"), 3, 3)
		cpb.add_theme_stylebox_override(state, frame)
	cpb.color = _working_palette.get(key, Color.WHITE)
	cpb.color_changed.connect(func(c: Color): _on_color_changed(key, c))
	row.add_child(cpb)
	picker_buttons[key] = cpb

func open_dialog() -> void:
	_init_working_palette()
	for key in CUSTOM_KEYS:
		if picker_buttons.has(key):
			picker_buttons[key].color = _working_palette.get(key, Color.WHITE)
	_refresh_preview()
	open_modal()
	_fit_picker_scroll.call_deferred()

func _apply_responsive_layout() -> void:
	super()
	_fit_picker_scroll.call_deferred()

## Tall enough for every picker, so the last row is never cut off by a scroll edge, but never
## taller than the room the rest of the dialog leaves on screen; on a short phone it scrolls
func _fit_picker_scroll() -> void:
	if picker_scroll == null or picker_list == null or modal_panel == null:
		return
	var vp_h: float = get_viewport_rect().size.y if is_inside_tree() else ResponsiveManager.BASE_HEIGHT
	var others: float = modal_panel.get_combined_minimum_size().y - picker_scroll.custom_minimum_size.y
	var room: float = vp_h - 2.0 * ThemeManager.SPACE_LG - others
	picker_scroll.custom_minimum_size.y = minf(picker_list.get_combined_minimum_size().y, maxf(120.0, room))

func _copy_preset(preset_name: String) -> void:
	if ThemeManager.PALETTES.has(preset_name):
		_working_palette = ThemeManager.PALETTES[preset_name].duplicate()
		for key in CUSTOM_KEYS:
			if picker_buttons.has(key):
				picker_buttons[key].color = _working_palette.get(key, Color.WHITE)
		_refresh_preview()

func _on_color_changed(key: String, color: Color) -> void:
	_working_palette[key] = color
	_refresh_preview()

func _refresh_preview() -> void:
	if preview_bg == null or preview_cells.size() < 9:
		return

	var bg_col: Color = _working_palette.get("bg", Color("#0e1117"))
	var grid_col: Color = _working_palette.get("grid_major", Color("#484f58"))
	var cell_bg_col: Color = _working_palette.get("cell_bg", Color("#12161f"))
	var sel_col: Color = _working_palette.get("cell_selected", Color("#1f3b64"))
	var given_col: Color = _working_palette.get("text_given", Color("#f0f6fc"))
	var user_col: Color = _working_palette.get("text_user", Color("#58a6ff"))
	var conflict_col: Color = _working_palette.get("text_conflict", Color("#f85149"))
	var notes_col: Color = _working_palette.get("text_notes", Color("#8b949e"))
	var peer_col: Color = sel_col.lerp(cell_bg_col, 0.65)

	preview_bg.color = grid_col
	if preview_card != null:
		var sb := ThemeManager.create_flat_stylebox(bg_col, 10, 1, grid_col, 8, 8)
		preview_card.add_theme_stylebox_override("panel", sb)

	# Cell 0: Given number 5
	_set_preview_cell(0, "5", given_col, cell_bg_col, "")
	# Cell 1: Selected cell 3
	_set_preview_cell(1, "3", user_col, sel_col, "")
	# Cell 2: Peer cell with candidate notes 1 2 4
	_set_preview_cell(2, "", given_col, peer_col, "1 2 4", notes_col)
	# Cell 3: Conflict cell 5 (duplicate in box)
	_set_preview_cell(3, "5", conflict_col, Color(conflict_col, 0.28), "")
	# Cell 4: Given number 7
	_set_preview_cell(4, "7", given_col, cell_bg_col, "")
	# Cell 5: Empty cell
	_set_preview_cell(5, "", given_col, cell_bg_col, "")
	# Cell 6: User entered number 9
	_set_preview_cell(6, "9", user_col, cell_bg_col, "")
	# Cell 7: Candidate notes 6 8
	_set_preview_cell(7, "", given_col, cell_bg_col, "6 8", notes_col)
	# Cell 8: Given number 1
	_set_preview_cell(8, "1", given_col, cell_bg_col, "")

func _set_preview_cell(idx: int, text: String, text_color: Color, bg_color: Color, notes_text: String, notes_color: Color = Color.WHITE) -> void:
	if idx < 0 or idx >= preview_cells.size():
		return
	var c: Dictionary = preview_cells[idx]
	c["bg"].color = bg_color
	if text.is_empty():
		c["label"].visible = false
		c["notes"].visible = not notes_text.is_empty()
		c["notes"].text = notes_text
		c["notes"].add_theme_color_override("font_color", notes_color)
	else:
		c["label"].visible = true
		c["notes"].visible = false
		c["label"].text = text
		c["label"].add_theme_color_override("font_color", text_color)

func _on_confirmed() -> void:
	close_modal()
	ThemeManager.apply_custom_palette(_working_palette)
	theme_saved.emit()
	confirmed.emit()

func _update_locale_texts() -> void:
	title = LocalizationManager.translate("CUSTOM_THEME_TITLE")
	ok_button_text = LocalizationManager.translate("BTN_SAVE_APPLY")
	cancel_button_text = LocalizationManager.translate("BTN_CANCEL")
	if preset_prompt_label != null:
		preset_prompt_label.text = LocalizationManager.translate("PRESET_BASE_PROMPT")
	for btn in preset_buttons:
		# The palette ids ("Dark", "Sepia") are names in code, not in the UI
		btn.text = LocalizationManager.translate("THEME_" + String(btn.get_meta("preset")).to_upper())

	if group_board_lbl != null:
		group_board_lbl.text = LocalizationManager.translate("THEME_GROUP_BOARD")
	if group_numbers_lbl != null:
		group_numbers_lbl.text = LocalizationManager.translate("THEME_GROUP_NUMBERS")

	for key in CUSTOM_KEYS:
		if field_labels.has(key):
			var l_key: String = KEY_LABELS.get(key, "")
			field_labels[key].text = LocalizationManager.translate(l_key)

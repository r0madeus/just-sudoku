class_name SudokuCell
extends Control

## Single 9x9 Sudoku cell UI component
## Handles number display, 3x3 candidate notes, and highlight states (GDD §15, §17, §18)

signal cell_clicked(idx: int)

var cell_index: int = 0
var value: int = 0
var is_given: bool = false
var is_selected: bool = false
var is_peer: bool = false
var is_same_number: bool = false
var is_conflict: bool = false
var is_wrong: bool = false
var candidates_mask: int = 0

var bg_panel: PanelContainer
var bg_style: StyleBoxFlat
var num_label: Label
var notes_view: NotesView

var _shake_tween: Tween = null
var _scale_tween: Tween = null
var _flash_rect: ColorRect = null
var _flash_tween: Tween = null
var _original_pos_x: float = 0.0
var _is_shaking: bool = false

# What is on screen now. The grid refreshes all 81 cells on every tap, and each theme override
# makes Godot re-shape the label's text, so only what actually changed is applied.
var _shown_text_col: Color = Color(0, 0, 0, 0)
var _shown_font_h: float = -1.0

## The candidate notes, drawn in one go. Nine Labels in a GridContainer per cell made the board
## 729 note labels (over 1,000 nodes with the rest), which made the game screen slow to build.
class NotesView extends Control:
	var mask: int = 0
	var color: Color = Color.WHITE
	var font_size: int = 10

	func _notification(what: int) -> void:
		# A new font (Settings) arrives as a theme change
		if what == NOTIFICATION_THEME_CHANGED:
			queue_redraw()

	func _draw() -> void:
		if mask == 0 or size.x <= 0.0:
			return
		var font: Font = get_theme_font("font", "Label")
		var cw: float = size.x / 3.0
		var ch: float = size.y / 3.0
		var ascent: float = font.get_ascent(font_size)
		var line_h: float = ascent + font.get_descent(font_size)
		for d in range(1, 10):
			if mask & (1 << d) == 0:
				continue
			var col: int = (d - 1) % 3
			var row: int = (d - 1) / 3
			# Centred in its third of the cell the way a Label centres its line
			var baseline := Vector2(col * cw, row * ch + (ch - line_h) * 0.5 + ascent)
			draw_string(font, baseline, str(d), HORIZONTAL_ALIGNMENT_CENTER, cw, font_size, color)

func _exit_tree() -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_PASS
	custom_minimum_size = Vector2.ZERO

	bg_panel = PanelContainer.new()
	bg_panel.set_anchors_preset(PRESET_FULL_RECT)
	bg_panel.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg_panel)

	bg_style = StyleBoxFlat.new()
	bg_style.draw_center = true
	bg_style.border_width_left = 0
	bg_style.border_width_top = 0
	bg_style.border_width_right = 0
	bg_style.border_width_bottom = 0

	# Apply corner radius ONLY to the 4 outer corner cells of the 9x9 grid
	if cell_index == 0:
		bg_style.corner_radius_top_left = ThemeManager.RADIUS_MD
	elif cell_index == 8:
		bg_style.corner_radius_top_right = ThemeManager.RADIUS_MD
	elif cell_index == 72:
		bg_style.corner_radius_bottom_left = ThemeManager.RADIUS_MD
	elif cell_index == 80:
		bg_style.corner_radius_bottom_right = ThemeManager.RADIUS_MD

	bg_panel.add_theme_stylebox_override("panel", bg_style)

	num_label = Label.new()
	num_label.set_anchors_preset(PRESET_FULL_RECT)
	num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num_label.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(num_label)

	notes_view = NotesView.new()
	notes_view.set_anchors_preset(PRESET_FULL_RECT)
	notes_view.mouse_filter = MOUSE_FILTER_IGNORE
	notes_view.visible = false
	add_child(notes_view)

	_update_visuals()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			cell_clicked.emit(cell_index)
			accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed:
			cell_clicked.emit(cell_index)
			accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and num_label != null:
		_update_font_sizes()

func set_cell_data(
	p_val: int,
	p_given: bool,
	p_cands: int,
	p_selected: bool,
	p_peer: bool,
	p_same_num: bool,
	p_conflict: bool,
	p_wrong: bool
) -> void:
	var was_empty := (value == 0)
	var was_selected := is_selected
	var was_conflict := is_conflict
	var was_wrong := is_wrong

	value = p_val
	is_given = p_given
	candidates_mask = p_cands
	is_selected = p_selected
	is_peer = p_peer
	is_same_number = p_same_num
	is_conflict = p_conflict
	is_wrong = p_wrong
	_update_visuals()

	if was_empty and value != 0:
		animate_pop()
	elif not was_selected and is_selected:
		animate_select()

	if (not was_conflict and is_conflict) or (not was_wrong and is_wrong):
		animate_shake()

func animate_pop() -> void:
	if not SettingsScreen.animations_enabled:
		scale = Vector2.ONE
		return
	pivot_offset = size * 0.5
	scale = Vector2(1.15, 1.15)
	if not is_inside_tree():
		return
	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween()
	if _scale_tween != null:
		_scale_tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func animate_select() -> void:
	if not SettingsScreen.animations_enabled:
		scale = Vector2.ONE
		return
	pivot_offset = size * 0.5
	scale = Vector2(1.05, 1.05)
	if not is_inside_tree():
		return
	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween()
	if _scale_tween != null:
		_scale_tween.tween_property(self, "scale", Vector2.ONE, 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func animate_shake() -> void:
	if not SettingsScreen.animations_enabled:
		return
	_original_pos_x = position.x
	_is_shaking = true
	if not is_inside_tree():
		return
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()

	_shake_tween = create_tween()
	if _shake_tween == null:
		_is_shaking = false
		return

	_shake_tween.tween_property(self, "position:x", _original_pos_x + 3.0, 0.03).set_trans(Tween.TRANS_SINE)
	_shake_tween.tween_property(self, "position:x", _original_pos_x - 3.0, 0.04).set_trans(Tween.TRANS_SINE)
	_shake_tween.tween_property(self, "position:x", _original_pos_x + 1.5, 0.03).set_trans(Tween.TRANS_SINE)
	_shake_tween.tween_property(self, "position:x", _original_pos_x, 0.03).set_trans(Tween.TRANS_SINE)
	_shake_tween.tween_callback(func():
		position.x = _original_pos_x
		_is_shaking = false
	)

func animate_wave(delay: float) -> void:
	if not SettingsScreen.animations_enabled:
		scale = Vector2.ONE
		return
	pivot_offset = size * 0.5
	scale = Vector2(1.10, 1.10)
	if not is_inside_tree():
		return
	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween()
	if _scale_tween == null:
		return
	if delay > 0.0:
		_scale_tween.tween_interval(delay)
	_scale_tween.tween_property(self, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

## Accent wash that fades in and out, used when this cell's row, column or box is completed
func animate_unit_completed(delay: float = 0.0) -> void:
	if not SettingsScreen.animations_enabled or not is_inside_tree() or bg_panel == null:
		return
	if _flash_rect == null:
		_flash_rect = ColorRect.new()
		_flash_rect.set_anchors_preset(PRESET_FULL_RECT)
		_flash_rect.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(_flash_rect)
		# Above the cell background, below the digit and notes
		move_child(_flash_rect, bg_panel.get_index() + 1)
	_flash_rect.color = Color(ThemeManager.get_color("accent"), 0.0)
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	if _flash_tween == null:
		return
	if delay > 0.0:
		_flash_tween.tween_interval(delay)
	_flash_tween.tween_property(_flash_rect, "color:a", 0.32, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_property(_flash_rect, "color:a", 0.0, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func animate_digit_completed(delay: float = 0.0) -> void:
	if not SettingsScreen.animations_enabled:
		scale = Vector2.ONE
		return
	pivot_offset = size * 0.5
	if not is_inside_tree():
		return
	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()

	_scale_tween = create_tween()
	if _scale_tween == null:
		return
	if delay > 0.0:
		_scale_tween.tween_interval(delay)
	_scale_tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	if num_label != null:
		var tint_tween := create_tween()
		if tint_tween != null:
			if delay > 0.0:
				tint_tween.tween_interval(delay)
			tint_tween.tween_property(num_label, "modulate", Color(1.25, 1.25, 1.45), 0.10).set_trans(Tween.TRANS_SINE)
			tint_tween.tween_property(num_label, "modulate", Color.WHITE, 0.14).set_trans(Tween.TRANS_SINE)

func _update_font_sizes() -> void:
	var h: float = size.y
	if h > 10.0 and h != _shown_font_h:
		_shown_font_h = h
		num_label.add_theme_font_size_override("font_size", maxi(8, int(h * 0.62)))
		notes_view.font_size = maxi(9, int(h * 0.22))
		notes_view.queue_redraw()

func _update_visuals() -> void:
	if bg_panel == null or bg_style == null:
		return

	# 1. Background color hierarchy: Selected > Same Number > Conflict > Peer > Base
	var bg_col: Color = ThemeManager.get_color("cell_bg")
	if is_selected:
		bg_col = ThemeManager.get_color("cell_selected")
		_set_border(2, ThemeManager.get_color("border_focus"))
	elif is_conflict:
		bg_col = Color(ThemeManager.get_color("text_conflict"), 0.22)
		_set_border(1, ThemeManager.get_color("text_conflict"))
	elif is_wrong:
		bg_col = Color(ThemeManager.get_color("text_wrong"), 0.28)
		_set_border(1, ThemeManager.get_color("text_wrong"))
	elif is_same_number and value != 0:
		bg_col = ThemeManager.get_color("cell_same_num")
		_set_border(0, Color.TRANSPARENT)
	elif is_peer:
		bg_col = ThemeManager.get_color("cell_peer")
		_set_border(0, Color.TRANSPARENT)
	else:
		_set_border(0, Color.TRANSPARENT)

	if bg_style.bg_color != bg_col:
		bg_style.bg_color = bg_col
		bg_panel.queue_redraw()

	# 2. Main Number vs Notes
	if value != 0:
		num_label.visible = true
		notes_view.visible = false
		var digit := str(value)
		if num_label.text != digit:
			num_label.text = digit

		var text_col: Color = ThemeManager.get_color("text_user")
		if is_given:
			text_col = ThemeManager.get_color("text_given")
		if is_conflict:
			text_col = ThemeManager.get_color("text_conflict")
		elif is_wrong:
			text_col = ThemeManager.get_color("text_wrong")

		if text_col != _shown_text_col:
			_shown_text_col = text_col
			num_label.add_theme_color_override("font_color", text_col)
	else:
		num_label.visible = false
		if num_label.text != "":
			num_label.text = ""
		notes_view.visible = (candidates_mask != 0)
		var note_col: Color = ThemeManager.get_color("text_notes")
		if notes_view.mask != candidates_mask or notes_view.color != note_col:
			notes_view.mask = candidates_mask
			notes_view.color = note_col
			notes_view.queue_redraw()

	_update_font_sizes()

func _set_border(width: int, color: Color) -> void:
	if bg_style.border_width_top != width or bg_style.border_color != color:
		bg_style.set_border_width_all(width)
		bg_style.border_color = color
		bg_panel.queue_redraw()

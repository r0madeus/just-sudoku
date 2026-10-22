class_name GameActionDock
extends "res://scenes/ui/glass_panel.gd"

## Unified GameActionDock Component
## Houses Undo, Redo, Notes, and Hint action buttons with consistent theme integration,
## state-driven styling, and decoupled signal emissions.

const LocalizationManager = preload("res://scripts/services/localization_manager.gd")

signal undo_pressed()
signal redo_pressed()
signal notes_toggled(active: bool)
signal hint_pressed()
signal fill_notes_pressed()

var action_bar: HBoxContainer
var undo_btn: Button
var redo_btn: Button
var notes_btn: Button
var hint_btn: Button
## Icon button next to Notes, shown only in notes mode
var fill_notes_btn: Button

var is_notes_mode: bool = false
var is_compact: bool = false
## Tablet scale (1 on phones, see ResponsiveManager.tablet_factor)
var size_scale: float = 1.0
var _available_width: float = 0.0

func _init() -> void:
	super()
	# Light chrome glass: capsule, soft shadow, tight padding
	elevated = false
	corner_radius = 26.0
	pad_h = 12
	pad_v = 4
	shadow_size = 10
	shadow_offset = Vector2(0, 3)
	custom_minimum_size = Vector2(310, ResponsiveManager.HEIGHT_ACTION_DOCK)
	size_flags_horizontal = SIZE_SHRINK_CENTER
	_build_ui()
	_update_locale_texts()

# Registered on enter (not _init) so re-parenting, which fires _exit_tree, keeps the listeners
func _enter_tree() -> void:
	super()
	ThemeManager.add_listener(_on_theme_changed)
	LocalizationManager.add_listener(_update_locale_texts)

func _exit_tree() -> void:
	super()
	ThemeManager.remove_listener(_on_theme_changed)
	LocalizationManager.remove_listener(_update_locale_texts)

func _build_ui() -> void:
	action_bar = HBoxContainer.new()
	action_bar.custom_minimum_size = Vector2(0, ResponsiveManager.TOUCH_TARGET_MIN)
	action_bar.size_flags_horizontal = SIZE_EXPAND_FILL
	action_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	action_bar.add_theme_constant_override("separation", ThemeManager.SPACE_SM)
	add_child(action_bar)

	# 1. Undo Button
	undo_btn = Button.new()
	undo_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	undo_btn.size_flags_vertical = SIZE_EXPAND_FILL
	undo_btn.custom_minimum_size = Vector2(64, ResponsiveManager.TOUCH_TARGET_MIN)
	undo_btn.theme_type_variation = "GhostButton"
	undo_btn.icon = ThemeManager.get_icon("undo")
	undo_btn.add_theme_constant_override("icon_max_width", 18)
	undo_btn.add_theme_font_size_override("font_size", 14)
	undo_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	undo_btn.pressed.connect(func(): undo_pressed.emit())
	action_bar.add_child(undo_btn)

	# 2. Redo Button
	redo_btn = Button.new()
	redo_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	redo_btn.size_flags_vertical = SIZE_EXPAND_FILL
	redo_btn.custom_minimum_size = Vector2(64, ResponsiveManager.TOUCH_TARGET_MIN)
	redo_btn.theme_type_variation = "GhostButton"
	redo_btn.icon = ThemeManager.get_icon("redo")
	redo_btn.add_theme_constant_override("icon_max_width", 18)
	redo_btn.add_theme_font_size_override("font_size", 14)
	redo_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	redo_btn.pressed.connect(func(): redo_pressed.emit())
	action_bar.add_child(redo_btn)

	# 3. Notes Button
	notes_btn = Button.new()
	notes_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	notes_btn.size_flags_vertical = SIZE_EXPAND_FILL
	notes_btn.custom_minimum_size = Vector2(68, ResponsiveManager.TOUCH_TARGET_MIN)
	notes_btn.theme_type_variation = "GhostButton"
	notes_btn.add_theme_font_size_override("font_size", 14)
	notes_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	notes_btn.pressed.connect(func():
		set_notes_active(not is_notes_mode)
		notes_toggled.emit(is_notes_mode)
	)
	action_bar.add_child(notes_btn)

	# 3b. Fill Notes (notes mode only)
	fill_notes_btn = Button.new()
	fill_notes_btn.size_flags_vertical = SIZE_EXPAND_FILL
	fill_notes_btn.custom_minimum_size = Vector2(ResponsiveManager.TOUCH_TARGET_MIN, ResponsiveManager.TOUCH_TARGET_MIN)
	fill_notes_btn.theme_type_variation = "GhostButton"
	fill_notes_btn.icon = ThemeManager.get_icon("grid-3x3")
	fill_notes_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fill_notes_btn.add_theme_constant_override("icon_max_width", 18)
	fill_notes_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	fill_notes_btn.visible = false
	fill_notes_btn.pressed.connect(func(): fill_notes_pressed.emit())
	action_bar.add_child(fill_notes_btn)

	# 4. Hint Button
	hint_btn = Button.new()
	hint_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	hint_btn.size_flags_vertical = SIZE_EXPAND_FILL
	hint_btn.custom_minimum_size = Vector2(64, ResponsiveManager.TOUCH_TARGET_MIN)
	hint_btn.theme_type_variation = "GhostButton"
	hint_btn.icon = ThemeManager.get_icon("lightbulb")
	hint_btn.add_theme_constant_override("icon_max_width", 18)
	hint_btn.add_theme_font_size_override("font_size", 14)
	hint_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hint_btn.pressed.connect(func(): hint_pressed.emit())
	action_bar.add_child(hint_btn)

## Narrow screens: Undo / Redo / Hint become icon-only (tooltips keep the names) when the
## labelled dock would not fit `available_width`
func fit_to_width(available_width: float) -> void:
	_available_width = available_width
	_apply_compact(false)
	var natural: float = get_combined_minimum_size().x
	_apply_compact(natural > available_width)

func _apply_compact(compact: bool) -> void:
	is_compact = compact
	for btn in [undo_btn, redo_btn, hint_btn]:
		if btn == null:
			continue
		btn.text = "" if compact else _label_for(btn)
		btn.custom_minimum_size.x = (ResponsiveManager.TOUCH_TARGET_MIN if compact else 64.0) * size_scale
		btn.tooltip_text = _label_for(btn)
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER if compact else HORIZONTAL_ALIGNMENT_LEFT
	custom_minimum_size.x = 0.0 if compact else 310.0 * size_scale

## Grows the buttons, their text and icons, and the capsule around them on a tablet
func set_size_scale(scale: float) -> void:
	if is_equal_approx(size_scale, scale):
		return
	size_scale = scale
	var h: float = roundf(ResponsiveManager.TOUCH_TARGET_MIN * scale)
	var dock_h: float = h + float(pad_v * 2)
	corner_radius = dock_h * 0.5
	custom_minimum_size.y = dock_h
	action_bar.custom_minimum_size.y = h
	for btn in [undo_btn, redo_btn, notes_btn, hint_btn, fill_notes_btn]:
		btn.custom_minimum_size.y = h
		btn.add_theme_font_size_override("font_size", roundi(14.0 * scale))
		btn.add_theme_constant_override("icon_max_width", roundi(18.0 * scale))
	notes_btn.custom_minimum_size.x = 68.0 * scale
	fill_notes_btn.custom_minimum_size.x = h
	if _available_width > 0.0:
		fit_to_width(_available_width)
	else:
		_apply_compact(is_compact)

func _label_for(btn: Button) -> String:
	if btn == undo_btn:
		return LocalizationManager.translate("BTN_UNDO")
	if btn == redo_btn:
		return LocalizationManager.translate("BTN_REDO")
	return LocalizationManager.translate("BTN_HINT")

func set_can_undo(enabled: bool) -> void:
	if undo_btn != null:
		undo_btn.disabled = not enabled

func set_can_redo(enabled: bool) -> void:
	if redo_btn != null:
		redo_btn.disabled = not enabled

func set_notes_active(active: bool) -> void:
	is_notes_mode = active
	_update_notes_visuals()
	if fill_notes_btn != null and fill_notes_btn.visible != active:
		fill_notes_btn.visible = active
		# The extra button changes the dock's width
		if _available_width > 0.0:
			fit_to_width(_available_width)

func set_hint_enabled(enabled: bool) -> void:
	if hint_btn != null:
		hint_btn.disabled = not enabled

func _update_notes_visuals() -> void:
	if notes_btn == null:
		return
	notes_btn.text = LocalizationManager.translate("BTN_NOTES_ON") if is_notes_mode else LocalizationManager.translate("BTN_NOTES")
	if is_notes_mode:
		var is_dark := ThemeManager.get_color("bg").get_luminance() < 0.5
		var highlight_border := Color(1.0, 1.0, 1.0, 0.22 if is_dark else 0.40)
		var sb_act := ThemeManager.create_flat_stylebox(
			ThemeManager.get_color("accent_blue", ThemeManager.get_color("accent")),
			ThemeManager.RADIUS_PILL_SM,
			ThemeManager.BORDER_HAIRLINE,
			highlight_border,
			10, 4,
			ThemeManager.get_shadow_color(0.12),
			3, Vector2(0, 1)
		)
		notes_btn.add_theme_stylebox_override("normal", sb_act)
		notes_btn.add_theme_stylebox_override("hover", sb_act)
		notes_btn.add_theme_stylebox_override("pressed", sb_act)
		notes_btn.add_theme_color_override("font_color", Color.WHITE)
	else:
		# Off state: outlined pill, so it reads as a toggle next to the plain action buttons
		var sb_off := ThemeManager.create_flat_stylebox(
			Color.TRANSPARENT,
			ThemeManager.RADIUS_PILL_SM,
			ThemeManager.BORDER_HAIRLINE,
			ThemeManager.get_color("border_subtle"),
			10, 4
		)
		notes_btn.add_theme_stylebox_override("normal", sb_off)
		notes_btn.remove_theme_stylebox_override("hover")
		notes_btn.remove_theme_stylebox_override("pressed")
		notes_btn.remove_theme_color_override("font_color")

func _update_locale_texts() -> void:
	if undo_btn != null:
		undo_btn.text = "" if is_compact else LocalizationManager.translate("BTN_UNDO")
		undo_btn.tooltip_text = LocalizationManager.translate("BTN_UNDO")
	if redo_btn != null:
		redo_btn.text = "" if is_compact else LocalizationManager.translate("BTN_REDO")
		redo_btn.tooltip_text = LocalizationManager.translate("BTN_REDO")
	if hint_btn != null:
		hint_btn.text = "" if is_compact else LocalizationManager.translate("BTN_HINT")
		hint_btn.tooltip_text = LocalizationManager.translate("BTN_HINT")
	if fill_notes_btn != null:
		fill_notes_btn.tooltip_text = LocalizationManager.translate("BTN_FILL_NOTES")
	_update_notes_visuals()
	# Other languages have other label lengths, so re-check the fit
	if _available_width > 0.0:
		fit_to_width(_available_width)

func _apply_theme_style() -> void:
	# The glass surface itself is GlassPanel's job; only the Notes toggle depends on the theme here
	_update_notes_visuals()

func _on_theme_changed() -> void:
	_apply_theme_style()

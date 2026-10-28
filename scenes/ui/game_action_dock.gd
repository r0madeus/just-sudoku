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
signal colors_toggled(active: bool)

var action_bar: HBoxContainer
var undo_btn: Button
var redo_btn: Button
var notes_btn: Button
var hint_btn: Button
## Icon button next to Notes, shown only in notes mode
var fill_notes_btn: Button
## On while every empty cell has notes: the button is a toggle, pressing it then takes them off
var fill_notes_on: bool = false
## Icon button that turns the keys into cell colours
var colors_btn: Button

var is_notes_mode: bool = false
var is_color_mode: bool = false
var is_compact: bool = false
## Tablet scale (1 on phones, see ResponsiveManager.tablet_factor)
var size_scale: float = 1.0
var _available_width: float = 0.0
## The dock's minimum width as the last fit left it, to tell when something changed it since
var _fitted_min_x: float = -1.0

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
	_apply_theme_style()
	minimum_size_changed.connect(_on_minimum_size_changed)
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
	ThemeManager.set_font_size(undo_btn, 14)
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
	ThemeManager.set_font_size(redo_btn, 14)
	redo_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	redo_btn.pressed.connect(func(): redo_pressed.emit())
	action_bar.add_child(redo_btn)

	# 3. Notes Button
	notes_btn = Button.new()
	# Square, so the filled look is a circle
	notes_btn.size_flags_vertical = SIZE_SHRINK_CENTER
	notes_btn.size_flags_horizontal = SIZE_FILL
	notes_btn.custom_minimum_size = Vector2(ResponsiveManager.TOUCH_TARGET_MIN, ResponsiveManager.TOUCH_TARGET_MIN)
	notes_btn.theme_type_variation = "GhostButton"
	# An icon, like Colours next to it: the pencil is what players know notes by, and the state
	# shows as the filled button
	notes_btn.icon = ThemeManager.get_icon("pencil")
	notes_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notes_btn.add_theme_constant_override("icon_max_width", 18)
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

	# 3c. Colours
	colors_btn = Button.new()
	colors_btn.size_flags_vertical = SIZE_SHRINK_CENTER
	colors_btn.custom_minimum_size = Vector2(ResponsiveManager.TOUCH_TARGET_MIN, ResponsiveManager.TOUCH_TARGET_MIN)
	colors_btn.theme_type_variation = "GhostButton"
	colors_btn.icon = ThemeManager.get_icon("palette")
	colors_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	colors_btn.add_theme_constant_override("icon_max_width", 18)
	colors_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	colors_btn.pressed.connect(func():
		set_color_active(not is_color_mode)
		colors_toggled.emit(is_color_mode)
	)
	action_bar.add_child(colors_btn)

	# 4. Hint Button
	hint_btn = Button.new()
	hint_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	hint_btn.size_flags_vertical = SIZE_EXPAND_FILL
	hint_btn.custom_minimum_size = Vector2(64, ResponsiveManager.TOUCH_TARGET_MIN)
	hint_btn.theme_type_variation = "GhostButton"
	hint_btn.icon = ThemeManager.get_icon("lightbulb")
	hint_btn.add_theme_constant_override("icon_max_width", 18)
	ThemeManager.set_font_size(hint_btn, 14)
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
	_fitted_min_x = get_combined_minimum_size().x

## The labels measure what the fonts and the theme say at the moment of the fit; when they say
## something else later (a font that arrives late, a theme applied after the screen was built, a
## new language), the labelled dock may no longer fit. Whatever changes its size, it is fitted again.
func _on_minimum_size_changed() -> void:
	if _available_width > 0.0 and absf(get_combined_minimum_size().x - _fitted_min_x) > 0.5:
		fit_to_width.call_deferred(_available_width)

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
	for btn in [undo_btn, redo_btn, notes_btn, hint_btn, fill_notes_btn, colors_btn]:
		btn.custom_minimum_size.y = h
		ThemeManager.set_font_size(btn, 14.0 * scale)
		btn.add_theme_constant_override("icon_max_width", roundi(18.0 * scale))
	notes_btn.custom_minimum_size.x = h
	fill_notes_btn.custom_minimum_size.x = h
	colors_btn.custom_minimum_size.x = h
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
		# Colours and notes exclude each other, so Fill notes takes the Colours button's place
		colors_btn.visible = not active
		# The extra button changes the dock's width
		if _available_width > 0.0:
			fit_to_width(_available_width)

func set_fill_notes_on(on: bool) -> void:
	fill_notes_on = on
	if fill_notes_btn != null:
		_set_toggled_look(fill_notes_btn, on)
		fill_notes_btn.tooltip_text = LocalizationManager.translate("BTN_CLEAR_NOTES" if on else "BTN_FILL_NOTES")

func set_color_active(active: bool) -> void:
	is_color_mode = active
	_update_colors_visuals()

func _update_colors_visuals() -> void:
	if colors_btn == null:
		return
	_set_toggled_look(colors_btn, is_color_mode)

func set_hint_enabled(enabled: bool) -> void:
	if hint_btn != null:
		hint_btn.disabled = not enabled

func _update_notes_visuals() -> void:
	if notes_btn == null:
		return
	notes_btn.tooltip_text = LocalizationManager.translate("BTN_NOTES_ON") if is_notes_mode else LocalizationManager.translate("BTN_NOTES")
	if is_notes_mode:
		_set_toggled_look(notes_btn, true)
	else:
		# Off: the same plain button as the others, no outline (the outline was the odd one out)
		_set_toggled_look(notes_btn, false)

## A toggle that is on is a filled circle in the accent colour with a white icon; off, it is the
## plain button. No border: a border over the anti-aliased edge of the fill shows as a ring.
## Both looks have the same padding, so switching one on or off does not change the button's
## width: the dock chooses between labels and icons by its width, and a 2 px change flipped it.
func _set_toggled_look(btn: Button, on: bool) -> void:
	var accent: Color = ThemeManager.get_color("accent_blue", ThemeManager.get_color("accent"))
	var fills: Array[Color] = []
	if on:
		fills.assign([accent, accent, accent])
	else:
		fills.assign([
			Color.TRANSPARENT,
			_with_alpha(ThemeManager.get_color("button_hover"), 0.45),
			_with_alpha(ThemeManager.get_color("button_pressed"), 0.65),
		])
	var states: Array[String] = ["normal", "hover", "pressed"]
	for i in states.size():
		btn.add_theme_stylebox_override(states[i], ThemeManager.create_flat_stylebox(
			fills[i], ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_NONE, Color.TRANSPARENT, 4, 4))
	for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
		if on:
			btn.add_theme_color_override(c, Color.WHITE)
		else:
			btn.remove_theme_color_override(c)

func _with_alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)

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
		fill_notes_btn.tooltip_text = LocalizationManager.translate("BTN_CLEAR_NOTES" if fill_notes_on else "BTN_FILL_NOTES")
	if colors_btn != null:
		colors_btn.tooltip_text = LocalizationManager.translate("BTN_COLORS_TIP")
	_update_notes_visuals()
	# Other languages have other label lengths, so re-check the fit
	if _available_width > 0.0:
		fit_to_width(_available_width)

## Larger or smaller labels may change whether they fit beside the icons
func _on_text_size_changed() -> void:
	if _available_width > 0.0:
		fit_to_width(_available_width)

func _apply_theme_style() -> void:
	# The glass surface itself is GlassPanel's job; only the toggles depend on the theme here
	_update_notes_visuals()
	_update_colors_visuals()
	_set_toggled_look(fill_notes_btn, fill_notes_on)

func _on_theme_changed() -> void:
	_apply_theme_style()
	# Text is measured with the new theme's fonts once it has been applied
	if _available_width > 0.0:
		fit_to_width.call_deferred(_available_width)

class_name GameActionDock
extends PanelContainer

## Unified GameActionDock Component
## Houses Undo, Redo, Notes, and Hint action buttons with consistent theme integration,
## state-driven styling, and decoupled signal emissions.

const ThemeManager = preload("res://scripts/services/theme_manager.gd")
const LocalizationManager = preload("res://scripts/services/localization_manager.gd")

signal undo_pressed()
signal redo_pressed()
signal notes_toggled(active: bool)
signal hint_pressed()

var action_bar: HBoxContainer
var undo_btn: Button
var redo_btn: Button
var notes_btn: Button
var hint_btn: Button
var blur_rect: ColorRect

var is_notes_mode: bool = false

func _init() -> void:
	custom_minimum_size = Vector2(310, 46)
	size_flags_horizontal = SIZE_SHRINK_CENTER
	_build_ui()
	_update_locale_texts()
	_apply_theme_style()
	ThemeManager.add_listener(_on_theme_changed)
	LocalizationManager.add_listener(_update_locale_texts)

func _exit_tree() -> void:
	ThemeManager.remove_listener(_on_theme_changed)
	LocalizationManager.remove_listener(_update_locale_texts)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_blur_params()

func _update_blur_params() -> void:
	if blur_rect != null and blur_rect.material is ShaderMaterial:
		var sm := blur_rect.material as ShaderMaterial
		var sz := size if size.x > 0 else custom_minimum_size
		sm.set_shader_parameter("rect_size", sz)
		sm.set_shader_parameter("corner_radius", minf(23.0, sz.y * 0.5))

func _build_ui() -> void:
	# 1. Optical Backdrop Blur Filter (authentic physical glass refraction with SDF capsule mask)
	var shader_code: String = """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 8.0) = 2.5;
uniform vec2 rect_size = vec2(310.0, 46.0);
uniform float corner_radius = 23.0;

float rounded_rect_alpha(vec2 uv, vec2 sz, float r) {
	vec2 pos = uv * sz;
	vec2 center = sz * 0.5;
	vec2 p = abs(pos - center) - (center - vec2(r));
	float d = length(max(p, vec2(0.0))) - r;
	return 1.0 - smoothstep(-0.5, 0.5, d);
}

void fragment() {
	float a = rounded_rect_alpha(UV, rect_size, corner_radius);
	vec4 col = textureLod(screen_texture, SCREEN_UV, blur_amount);
	COLOR = vec4(col.rgb, a);
}
"""
	var shader := Shader.new()
	shader.code = shader_code
	var smat := ShaderMaterial.new()
	smat.shader = shader

	blur_rect = ColorRect.new()
	blur_rect.material = smat
	blur_rect.mouse_filter = MOUSE_FILTER_IGNORE
	blur_rect.show_behind_parent = true
	blur_rect.set_anchors_preset(PRESET_FULL_RECT)
	add_child(blur_rect)

	action_bar = HBoxContainer.new()
	action_bar.custom_minimum_size = Vector2(0, 36)
	action_bar.size_flags_horizontal = SIZE_EXPAND_FILL
	action_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	action_bar.add_theme_constant_override("separation", ThemeManager.SPACE_SM)
	add_child(action_bar)

	# 1. Undo Button
	undo_btn = Button.new()
	undo_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	undo_btn.size_flags_vertical = SIZE_EXPAND_FILL
	undo_btn.custom_minimum_size = Vector2(64, 36)
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
	redo_btn.custom_minimum_size = Vector2(64, 36)
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
	notes_btn.custom_minimum_size = Vector2(68, 36)
	notes_btn.theme_type_variation = "GhostButton"
	notes_btn.add_theme_font_size_override("font_size", 14)
	notes_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	notes_btn.pressed.connect(func():
		set_notes_active(not is_notes_mode)
		notes_toggled.emit(is_notes_mode)
	)
	action_bar.add_child(notes_btn)

	# 4. Hint Button
	hint_btn = Button.new()
	hint_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	hint_btn.size_flags_vertical = SIZE_EXPAND_FILL
	hint_btn.custom_minimum_size = Vector2(64, 36)
	hint_btn.theme_type_variation = "GhostButton"
	hint_btn.icon = ThemeManager.get_icon("lightbulb")
	hint_btn.add_theme_constant_override("icon_max_width", 18)
	hint_btn.add_theme_font_size_override("font_size", 14)
	hint_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hint_btn.pressed.connect(func(): hint_pressed.emit())
	action_bar.add_child(hint_btn)

func set_can_undo(enabled: bool) -> void:
	if undo_btn != null:
		undo_btn.disabled = not enabled

func set_can_redo(enabled: bool) -> void:
	if redo_btn != null:
		redo_btn.disabled = not enabled

func set_notes_active(active: bool) -> void:
	is_notes_mode = active
	_update_notes_visuals()

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
		notes_btn.remove_theme_stylebox_override("normal")
		notes_btn.remove_theme_stylebox_override("hover")
		notes_btn.remove_theme_stylebox_override("pressed")
		notes_btn.remove_theme_color_override("font_color")

func _update_locale_texts() -> void:
	if undo_btn != null:
		undo_btn.text = LocalizationManager.translate("BTN_UNDO")
	if redo_btn != null:
		redo_btn.text = LocalizationManager.translate("BTN_REDO")
	if hint_btn != null:
		hint_btn.text = LocalizationManager.translate("BTN_HINT")
	_update_notes_visuals()

func _apply_theme_style() -> void:
	# Floating functional dock: genuine restrained liquid glass surface with specular highlight and ambient depth shadow
	var surface_col := ThemeManager.get_color("surface")
	var is_dark := ThemeManager.get_color("bg").get_luminance() < 0.5

	var glass_bg: Color = Color(surface_col.r, surface_col.g, surface_col.b, 0.55 if is_dark else 0.68)
	var specular_border: Color = Color(1.0, 1.0, 1.0, 0.28 if is_dark else 0.70)
	var shadow_col: Color = Color(0.0, 0.0, 0.0, 0.45) if is_dark else Color(0.08, 0.12, 0.20, 0.18)

	var sb_dock := StyleBoxFlat.new()
	sb_dock.bg_color = glass_bg
	sb_dock.set_corner_radius_all(23)
	sb_dock.corner_detail = 16
	sb_dock.set_border_width_all(ThemeManager.BORDER_HAIRLINE)
	sb_dock.border_color = specular_border
	sb_dock.shadow_color = shadow_col
	sb_dock.shadow_size = 18
	sb_dock.shadow_offset = Vector2(0, 6)
	sb_dock.content_margin_left = 12
	sb_dock.content_margin_right = 12
	sb_dock.content_margin_top = 4
	sb_dock.content_margin_bottom = 4

	add_theme_stylebox_override("panel", sb_dock)
	_update_notes_visuals()
	_update_blur_params()

func _on_theme_changed() -> void:
	_apply_theme_style()

extends RefCounted

## Builds the Godot Theme resource (type variations, styleboxes) from the ThemeManager
## tokens and the current palette.

const ThemeManager = preload("res://scripts/services/theme_manager.gd")

## Generates a high-contrast, theme-aware, anti-aliased CheckBox icon texture
static func _create_checkbox_texture(is_checked: bool, is_disabled: bool, is_hover: bool = false) -> ImageTexture:
	# 18 px, the size of a standard Android check box; the whole row is the touch target
	var sz := 18
	var img := Image.create_empty(sz, sz, false, Image.FORMAT_RGBA8)
	var radius := 3.5
	var border_w := 1.5

	var bg_col: Color = ThemeManager.get_color("bg")
	var surf_elev: Color = ThemeManager.get_color("surface_elevated")
	var border_col: Color = ThemeManager.get_color("border_subtle")
	var border_focus_col: Color = ThemeManager.get_color("border_focus")
	var sec_col: Color = ThemeManager.get_color("text_secondary")
	var accent_col: Color = ThemeManager.get_color("accent_blue", ThemeManager.get_color("accent"))
	var dis_col: Color = ThemeManager.get_color("button_text_disabled")

	var fill: Color = Color.TRANSPARENT
	var stroke: Color = Color.TRANSPARENT

	if is_checked:
		if is_disabled:
			fill = Color(accent_col.r, accent_col.g, accent_col.b, 0.4)
			stroke = fill
		else:
			fill = accent_col
			stroke = accent_col.lightened(0.12) if is_hover else accent_col
	else:
		if is_disabled:
			fill = Color(surf_elev.r, surf_elev.g, surf_elev.b, 0.2)
			stroke = dis_col
		elif is_hover:
			fill = Color(surf_elev.r, surf_elev.g, surf_elev.b, 0.7)
			stroke = border_focus_col
		else:
			fill = Color(surf_elev.r, surf_elev.g, surf_elev.b, 0.45)
			# Guarantee distinct visibility on Dark, AMOLED, and Light surfaces
			stroke = sec_col.lerp(border_col, 0.35)
			if stroke.get_luminance() < 0.35 and bg_col.get_luminance() < 0.5:
				stroke = stroke.lightened(0.3)

	# Anti-aliased rounded rect rendering using signed distance field
	var half := float(sz) * 0.5
	var inner_half := half - radius
	for y in range(sz):
		var py := absf(float(y) + 0.5 - half) - inner_half
		for x in range(sz):
			var px := absf(float(x) + 0.5 - half) - inner_half
			var dist := Vector2(maxf(px, 0.0), maxf(py, 0.0)).length() + minf(maxf(px, py), 0.0) - radius
			if dist <= 0.0:
				if border_w > 0.0 and dist >= -border_w:
					img.set_pixel(x, y, stroke)
				elif fill.a > 0.0:
					img.set_pixel(x, y, fill)
			elif dist < 1.0:
				var alpha: float = clampf(1.0 - dist, 0.0, 1.0)
				var c := stroke if border_w > 0.0 else fill
				if c.a > 0.0:
					img.set_pixel(x, y, Color(c.r, c.g, c.b, c.a * alpha))

	# Blend checkmark icon in center if checked
	if is_checked:
		var check_icon := ThemeManager.get_icon("check")
		if check_icon != null:
			var chk_img := check_icon.get_image()
			if chk_img != null:
				var chk_copy: Image = chk_img.duplicate() as Image
				chk_copy.resize(12, 12, Image.INTERPOLATE_LANCZOS)
				var mark_alpha: float = 0.6 if is_disabled else 1.0
				for cy in range(12):
					for cx in range(12):
						var cp: Color = chk_copy.get_pixel(cx, cy)
						if cp.a > 0.0:
							var cur: Color = img.get_pixel(cx + 3, cy + 3)
							img.set_pixel(cx + 3, cy + 3, cur.blend(Color(1.0, 1.0, 1.0, cp.a * mark_alpha)))

	return ImageTexture.create_from_image(img)

## Builds a unified, modern Godot Theme resource with native Theme Type Variations
static func build_godot_theme() -> Theme:
	var theme := Theme.new()

	var font_inter: Font = ThemeManager.get_font_inter()
	var font_serif_reg: Font = ThemeManager.get_font_serif_regular()
	var font_serif_semi: Font = ThemeManager.get_font_serif_semibold()
	var font_mono: Font = ThemeManager.get_font_mono()

	# The chosen family (bundled, regular weight, with a system font behind it for rare symbols)
	var active_font: Font = FontManager.get_current_font()
	if active_font == null:
		active_font = font_inter

	# Controls without a size of their own follow the text size too (Godot's default is 16)
	theme.default_font_size = ThemeManager.fs(16)
	if active_font != null:
		theme.default_font = active_font
		theme.set_font("font", "Button", active_font)
		theme.set_font("font", "Label", active_font)
		theme.set_font("font", "OptionButton", active_font)
		theme.set_font("font", "PopupMenu", active_font)
		theme.set_font("font", "CheckBox", active_font)
		theme.set_font("font", "LineEdit", active_font)
		theme.set_font("font", "TextEdit", active_font)

	var bg_col: Color = ThemeManager.get_color("bg")
	var is_dark: bool = bg_col.get_luminance() < 0.5

	var bg_normal := ThemeManager.get_color("button_normal")
	var bg_hover := ThemeManager.get_color("button_hover")
	var bg_pressed := ThemeManager.get_color("button_pressed")
	var bg_disabled := ThemeManager.get_color("button_disabled")
	var border := ThemeManager.get_color("border_subtle")
	var border_focus := ThemeManager.get_color("border_focus")

	var accent_col := ThemeManager.get_color("accent_blue", ThemeManager.get_color("accent"))
	var surface_col := ThemeManager.get_color("surface")
	var surface_elevated_col := ThemeManager.get_color("surface_elevated")

	var text_primary := ThemeManager.get_color("text_given")
	var text_secondary := ThemeManager.get_color("text_secondary", ThemeManager.get_color("text_notes"))
	var text_user := ThemeManager.get_color("text_user")
	var btn_text := ThemeManager.get_color("button_text")
	var btn_text_disabled := ThemeManager.get_color("button_text_disabled")

	var sb_empty := StyleBoxEmpty.new()

	# -------------------------------------------------------------------------
	# 1. Base Button Theme (Geometric Capsule, Hairline 1px border)
	# -------------------------------------------------------------------------
	var sb_btn_normal := ThemeManager.create_flat_stylebox(bg_normal, ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_HAIRLINE, border, 18, 9)
	var sb_btn_hover := ThemeManager.create_flat_stylebox(bg_hover, ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_HAIRLINE, border.lightened(0.12) if is_dark else border.darkened(0.08), 18, 9)
	var sb_btn_pressed := ThemeManager.create_flat_stylebox(bg_pressed, ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_HAIRLINE, border, 18, 9)
	var sb_btn_disabled := ThemeManager.create_flat_stylebox(bg_disabled, ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_HAIRLINE, border.darkened(0.2), 18, 9)

	theme.set_stylebox("normal", "Button", sb_btn_normal)
	theme.set_stylebox("hover", "Button", sb_btn_hover)
	theme.set_stylebox("pressed", "Button", sb_btn_pressed)
	theme.set_stylebox("disabled", "Button", sb_btn_disabled)
	theme.set_stylebox("focus", "Button", sb_empty)

	theme.set_color("font_color", "Button", btn_text)
	theme.set_color("font_hover_color", "Button", text_primary)
	theme.set_color("font_pressed_color", "Button", text_primary)
	theme.set_color("font_disabled_color", "Button", btn_text_disabled)
	theme.set_color("icon_normal_color", "Button", btn_text)
	theme.set_color("icon_hover_color", "Button", text_primary)
	theme.set_color("icon_pressed_color", "Button", text_primary)
	theme.set_color("icon_disabled_color", "Button", btn_text_disabled)
	theme.set_color("icon_focus_color", "Button", text_primary)
	theme.set_font_size("font_size", "Button", ThemeManager.fs(ThemeManager.FONT_SIZE_BODY))

	# -------------------------------------------------------------------------
	# 2. Button Type Variations (Coherent Quiet Precision Capsule Language)
	# -------------------------------------------------------------------------
	var highlight_border := Color(1.0, 1.0, 1.0, 0.22 if is_dark else 0.40)

	# PrimaryButton (Prime reference: "Devam Et" filled accent capsule with subtle highlight & soft shadow)
	theme.set_type_variation("PrimaryButton", "Button")
	var sb_pri_norm := ThemeManager.create_flat_stylebox(accent_col, ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_HAIRLINE, highlight_border, 20, 10, ThemeManager.get_shadow_color(0.14), 5, Vector2(0, 2))
	var sb_pri_hov := ThemeManager.create_flat_stylebox(accent_col.lightened(0.08) if is_dark else accent_col.darkened(0.06), ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_HAIRLINE, highlight_border.lightened(0.2), 20, 10, ThemeManager.get_shadow_color(0.18), 7, Vector2(0, 2))
	var sb_pri_press := ThemeManager.create_flat_stylebox(accent_col.darkened(0.1), ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_HAIRLINE, highlight_border.darkened(0.1), 20, 10, ThemeManager.get_shadow_color(0.08), 2, Vector2(0, 1))
	var sb_pri_dis := ThemeManager.create_flat_stylebox(bg_disabled, ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_NONE, Color.TRANSPARENT, 20, 10)

	theme.set_stylebox("normal", "PrimaryButton", sb_pri_norm)
	theme.set_stylebox("hover", "PrimaryButton", sb_pri_hov)
	theme.set_stylebox("pressed", "PrimaryButton", sb_pri_press)
	theme.set_stylebox("disabled", "PrimaryButton", sb_pri_dis)
	theme.set_stylebox("focus", "PrimaryButton", sb_empty)
	theme.set_color("font_color", "PrimaryButton", Color.WHITE)
	theme.set_color("font_hover_color", "PrimaryButton", Color.WHITE)
	theme.set_color("font_pressed_color", "PrimaryButton", Color.WHITE)
	theme.set_color("font_disabled_color", "PrimaryButton", btn_text_disabled)
	theme.set_color("icon_normal_color", "PrimaryButton", Color.WHITE)
	theme.set_color("icon_hover_color", "PrimaryButton", Color.WHITE)
	theme.set_color("icon_pressed_color", "PrimaryButton", Color.WHITE)
	theme.set_color("icon_disabled_color", "PrimaryButton", btn_text_disabled)
	theme.set_font_size("font_size", "PrimaryButton", ThemeManager.fs(ThemeManager.FONT_SIZE_TITLE_SM))

	# SecondaryButton (Opaque elevated surface capsule: counterpart to PrimaryButton)
	theme.set_type_variation("SecondaryButton", "Button")
	var sec_border_hov := border.lightened(0.15) if is_dark else border.darkened(0.10)
	var sb_sec_norm := ThemeManager.create_flat_stylebox(surface_elevated_col, ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_HAIRLINE, border, 20, 10, ThemeManager.get_shadow_color(0.08), 3, Vector2(0, 2))
	var sb_sec_hov := ThemeManager.create_flat_stylebox(surface_elevated_col.lightened(0.06) if is_dark else surface_elevated_col.darkened(0.04), ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_HAIRLINE, sec_border_hov, 20, 10, ThemeManager.get_shadow_color(0.12), 5, Vector2(0, 2))
	var sb_sec_press := ThemeManager.create_flat_stylebox(surface_elevated_col.darkened(0.06) if is_dark else surface_elevated_col.lightened(0.04), ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_HAIRLINE, border, 20, 10, ThemeManager.get_shadow_color(0.04), 1, Vector2(0, 1))
	var sb_sec_dis := ThemeManager.create_flat_stylebox(bg_disabled, ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_HAIRLINE, border.darkened(0.2), 20, 10)

	theme.set_stylebox("normal", "SecondaryButton", sb_sec_norm)
	theme.set_stylebox("hover", "SecondaryButton", sb_sec_hov)
	theme.set_stylebox("pressed", "SecondaryButton", sb_sec_press)
	theme.set_stylebox("disabled", "SecondaryButton", sb_sec_dis)
	theme.set_stylebox("focus", "SecondaryButton", sb_empty)
	theme.set_color("font_color", "SecondaryButton", btn_text)
	theme.set_color("font_hover_color", "SecondaryButton", text_primary)
	theme.set_color("font_pressed_color", "SecondaryButton", text_primary)
	theme.set_color("font_disabled_color", "SecondaryButton", btn_text_disabled)
	theme.set_color("icon_normal_color", "SecondaryButton", btn_text)
	theme.set_color("icon_hover_color", "SecondaryButton", text_primary)
	theme.set_color("icon_pressed_color", "SecondaryButton", text_primary)
	theme.set_color("icon_disabled_color", "SecondaryButton", btn_text_disabled)
	theme.set_font_size("font_size", "SecondaryButton", ThemeManager.fs(ThemeManager.FONT_SIZE_TITLE_SM))

	# CompactSecondaryButton & CompactButton (Compact surface capsule for lists, daily and inline actions)
	theme.set_type_variation("CompactSecondaryButton", "Button")
	theme.set_type_variation("CompactButton", "Button")
	var sb_comp_sec_norm := ThemeManager.create_flat_stylebox(surface_elevated_col, ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_HAIRLINE, border, 16, 6, ThemeManager.get_shadow_color(0.06), 2, Vector2(0, 1))
	var sb_comp_sec_hov := ThemeManager.create_flat_stylebox(surface_elevated_col.lightened(0.06) if is_dark else surface_elevated_col.darkened(0.04), ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_HAIRLINE, sec_border_hov, 16, 6, ThemeManager.get_shadow_color(0.10), 3, Vector2(0, 1))
	var sb_comp_sec_press := ThemeManager.create_flat_stylebox(surface_elevated_col.darkened(0.06) if is_dark else surface_elevated_col.lightened(0.04), ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_HAIRLINE, border, 16, 6, ThemeManager.get_shadow_color(0.03), 1, Vector2(0, 1))
	var sb_comp_sec_dis := ThemeManager.create_flat_stylebox(bg_disabled, ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_HAIRLINE, border.darkened(0.2), 16, 6)

	for c_sec in ["CompactSecondaryButton", "CompactButton"]:
		theme.set_stylebox("normal", c_sec, sb_comp_sec_norm)
		theme.set_stylebox("hover", c_sec, sb_comp_sec_hov)
		theme.set_stylebox("pressed", c_sec, sb_comp_sec_press)
		theme.set_stylebox("disabled", c_sec, sb_comp_sec_dis)
		theme.set_stylebox("focus", c_sec, sb_empty)
		theme.set_color("font_color", c_sec, btn_text)
		theme.set_color("font_hover_color", c_sec, text_primary)
		theme.set_color("font_pressed_color", c_sec, text_primary)
		theme.set_color("font_disabled_color", c_sec, btn_text_disabled)
		theme.set_color("icon_normal_color", c_sec, btn_text)
		theme.set_color("icon_hover_color", c_sec, text_primary)
		theme.set_color("icon_pressed_color", c_sec, text_primary)
		theme.set_color("icon_disabled_color", c_sec, btn_text_disabled)
		theme.set_font_size("font_size", c_sec, ThemeManager.fs(ThemeManager.FONT_SIZE_BODY))

	# CompactPrimaryButton (Compact filled accent capsule for inline high-priority actions)
	theme.set_type_variation("CompactPrimaryButton", "Button")
	var sb_comp_pri_norm := ThemeManager.create_flat_stylebox(accent_col, ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_HAIRLINE, highlight_border, 16, 6, ThemeManager.get_shadow_color(0.10), 3, Vector2(0, 1))
	var sb_comp_pri_hov := ThemeManager.create_flat_stylebox(accent_col.lightened(0.08) if is_dark else accent_col.darkened(0.06), ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_HAIRLINE, highlight_border.lightened(0.2), 16, 6, ThemeManager.get_shadow_color(0.14), 4, Vector2(0, 1))
	var sb_comp_pri_press := ThemeManager.create_flat_stylebox(accent_col.darkened(0.1), ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_HAIRLINE, highlight_border.darkened(0.1), 16, 6, ThemeManager.get_shadow_color(0.06), 1, Vector2(0, 1))
	var sb_comp_pri_dis := ThemeManager.create_flat_stylebox(bg_disabled, ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_NONE, Color.TRANSPARENT, 16, 6)

	theme.set_stylebox("normal", "CompactPrimaryButton", sb_comp_pri_norm)
	theme.set_stylebox("hover", "CompactPrimaryButton", sb_comp_pri_hov)
	theme.set_stylebox("pressed", "CompactPrimaryButton", sb_comp_pri_press)
	theme.set_stylebox("disabled", "CompactPrimaryButton", sb_comp_pri_dis)
	theme.set_stylebox("focus", "CompactPrimaryButton", sb_empty)
	theme.set_color("font_color", "CompactPrimaryButton", Color.WHITE)
	theme.set_color("font_hover_color", "CompactPrimaryButton", Color.WHITE)
	theme.set_color("font_pressed_color", "CompactPrimaryButton", Color.WHITE)
	theme.set_color("font_disabled_color", "CompactPrimaryButton", btn_text_disabled)
	theme.set_color("icon_normal_color", "CompactPrimaryButton", Color.WHITE)
	theme.set_color("icon_hover_color", "CompactPrimaryButton", Color.WHITE)
	theme.set_color("icon_pressed_color", "CompactPrimaryButton", Color.WHITE)
	theme.set_color("icon_disabled_color", "CompactPrimaryButton", btn_text_disabled)
	theme.set_font_size("font_size", "CompactPrimaryButton", ThemeManager.fs(ThemeManager.FONT_SIZE_BODY))

	# GhostButton (Border-less, transparent until interaction, smooth capsule hover/press)
	theme.set_type_variation("GhostButton", "Button")
	var sb_ghost_norm := ThemeManager.create_flat_stylebox(Color.TRANSPARENT, ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_NONE, Color.TRANSPARENT, 14, 8)
	var sb_ghost_hov := ThemeManager.create_flat_stylebox(Color(bg_hover.r, bg_hover.g, bg_hover.b, 0.45), ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_NONE, Color.TRANSPARENT, 14, 8)
	var sb_ghost_press := ThemeManager.create_flat_stylebox(Color(bg_pressed.r, bg_pressed.g, bg_pressed.b, 0.65), ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_NONE, Color.TRANSPARENT, 14, 8)
	var sb_ghost_dis := ThemeManager.create_flat_stylebox(Color.TRANSPARENT, ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_NONE, Color.TRANSPARENT, 14, 8)
	theme.set_stylebox("normal", "GhostButton", sb_ghost_norm)
	theme.set_stylebox("hover", "GhostButton", sb_ghost_hov)
	theme.set_stylebox("pressed", "GhostButton", sb_ghost_press)
	theme.set_stylebox("disabled", "GhostButton", sb_ghost_dis)
	theme.set_stylebox("focus", "GhostButton", sb_empty)
	theme.set_color("font_color", "GhostButton", btn_text)
	theme.set_color("font_hover_color", "GhostButton", text_primary)
	theme.set_color("font_disabled_color", "GhostButton", btn_text_disabled)
	theme.set_color("icon_normal_color", "GhostButton", btn_text)
	theme.set_color("icon_hover_color", "GhostButton", text_primary)
	theme.set_color("icon_pressed_color", "GhostButton", text_primary)
	theme.set_color("icon_disabled_color", "GhostButton", btn_text_disabled)
	theme.set_font_size("font_size", "GhostButton", ThemeManager.fs(ThemeManager.FONT_SIZE_BODY))

	# PickerItem (A choice in a picker sheet; the chosen one is tinted with the accent)
	theme.set_type_variation("PickerItem", "Button")
	var accent_tint := Color(accent_col, 0.16)
	theme.set_stylebox("normal", "PickerItem", sb_ghost_norm)
	theme.set_stylebox("hover", "PickerItem", sb_ghost_hov)
	theme.set_stylebox("pressed", "PickerItem", ThemeManager.create_flat_stylebox(accent_tint, ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_NONE, Color.TRANSPARENT, 14, 8))
	theme.set_stylebox("hover_pressed", "PickerItem", ThemeManager.create_flat_stylebox(Color(accent_col, 0.22), ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_NONE, Color.TRANSPARENT, 14, 8))
	theme.set_stylebox("disabled", "PickerItem", sb_ghost_dis)
	theme.set_stylebox("focus", "PickerItem", sb_empty)
	theme.set_color("font_color", "PickerItem", text_primary)
	theme.set_color("font_hover_color", "PickerItem", text_primary)
	theme.set_color("font_pressed_color", "PickerItem", accent_col)
	theme.set_color("font_hover_pressed_color", "PickerItem", accent_col)
	theme.set_color("font_disabled_color", "PickerItem", btn_text_disabled)
	theme.set_color("icon_pressed_color", "PickerItem", accent_col)
	theme.set_color("icon_hover_pressed_color", "PickerItem", accent_col)
	theme.set_font_size("font_size", "PickerItem", ThemeManager.fs(ThemeManager.FONT_SIZE_BODY))

	# IconButton (Circular for square aspect, compact capsule for elongated aspect)
	theme.set_type_variation("IconButton", "Button")
	var sb_icon_norm := ThemeManager.create_flat_stylebox(surface_elevated_col, ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_HAIRLINE, border, 10, 10, ThemeManager.get_shadow_color(0.06), 2, Vector2(0, 1))
	var sb_icon_hov := ThemeManager.create_flat_stylebox(surface_elevated_col.lightened(0.08) if is_dark else surface_elevated_col.darkened(0.05), ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_HAIRLINE, sec_border_hov, 10, 10, ThemeManager.get_shadow_color(0.10), 3, Vector2(0, 1))
	var sb_icon_press := ThemeManager.create_flat_stylebox(surface_elevated_col.darkened(0.08) if is_dark else surface_elevated_col.lightened(0.05), ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_HAIRLINE, border, 10, 10, ThemeManager.get_shadow_color(0.03), 1, Vector2(0, 1))
	var sb_icon_dis := ThemeManager.create_flat_stylebox(bg_disabled, ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_HAIRLINE, border.darkened(0.2), 10, 10)
	theme.set_stylebox("normal", "IconButton", sb_icon_norm)
	theme.set_stylebox("hover", "IconButton", sb_icon_hov)
	theme.set_stylebox("pressed", "IconButton", sb_icon_press)
	theme.set_stylebox("disabled", "IconButton", sb_icon_dis)
	theme.set_stylebox("focus", "IconButton", sb_empty)
	theme.set_color("font_color", "IconButton", btn_text)
	theme.set_color("font_hover_color", "IconButton", text_primary)
	theme.set_color("icon_normal_color", "IconButton", btn_text)
	theme.set_color("icon_hover_color", "IconButton", text_primary)
	theme.set_color("icon_pressed_color", "IconButton", text_primary)
	theme.set_color("icon_disabled_color", "IconButton", btn_text_disabled)
	theme.set_font_size("font_size", "IconButton", ThemeManager.fs(ThemeManager.FONT_SIZE_BODY))

	# ToolbarButton (In-game action bar controls: Undo, Redo, Notes, Hint)
	theme.set_type_variation("ToolbarButton", "Button")
	var sb_tb_norm := ThemeManager.create_flat_stylebox(surface_elevated_col, ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_HAIRLINE, border, 12, 6)
	var sb_tb_hov := ThemeManager.create_flat_stylebox(bg_hover, ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_HAIRLINE, border_focus, 12, 6)
	var sb_tb_press := ThemeManager.create_flat_stylebox(bg_pressed, ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_HAIRLINE, border_focus, 12, 6)
	var sb_tb_dis := ThemeManager.create_flat_stylebox(bg_disabled, ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_HAIRLINE, border.darkened(0.2), 12, 6)
	theme.set_stylebox("normal", "ToolbarButton", sb_tb_norm)
	theme.set_stylebox("hover", "ToolbarButton", sb_tb_hov)
	theme.set_stylebox("pressed", "ToolbarButton", sb_tb_press)
	theme.set_stylebox("disabled", "ToolbarButton", sb_tb_dis)
	theme.set_stylebox("focus", "ToolbarButton", sb_empty)
	theme.set_color("font_color", "ToolbarButton", btn_text)
	theme.set_color("font_hover_color", "ToolbarButton", text_primary)
	theme.set_color("font_disabled_color", "ToolbarButton", btn_text_disabled)
	theme.set_color("icon_normal_color", "ToolbarButton", btn_text)
	theme.set_color("icon_hover_color", "ToolbarButton", text_primary)
	theme.set_color("icon_pressed_color", "ToolbarButton", text_primary)
	theme.set_color("icon_disabled_color", "ToolbarButton", btn_text_disabled)
	theme.set_font_size("font_size", "ToolbarButton", ThemeManager.fs(ThemeManager.FONT_SIZE_BODY))

	# SegmentButton (Compact difficulty & tab segment controls)
	theme.set_type_variation("SegmentButton", "Button")
	var sb_seg_norm := ThemeManager.create_flat_stylebox(surface_col, ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_HAIRLINE, border, 10, 5)
	var sb_seg_hov := ThemeManager.create_flat_stylebox(bg_hover, ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_HAIRLINE, border, 10, 5)
	var sb_seg_press := ThemeManager.create_flat_stylebox(accent_col, ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_NONE, Color.TRANSPARENT, 10, 5)
	var sb_seg_dis := ThemeManager.create_flat_stylebox(accent_col, ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_NONE, Color.TRANSPARENT, 10, 5)
	theme.set_stylebox("normal", "SegmentButton", sb_seg_norm)
	theme.set_stylebox("hover", "SegmentButton", sb_seg_hov)
	theme.set_stylebox("pressed", "SegmentButton", sb_seg_press)
	theme.set_stylebox("disabled", "SegmentButton", sb_seg_dis)
	theme.set_stylebox("focus", "SegmentButton", sb_empty)
	theme.set_color("font_color", "SegmentButton", btn_text)
	theme.set_color("font_hover_color", "SegmentButton", text_primary)
	theme.set_color("font_pressed_color", "SegmentButton", Color.WHITE)
	theme.set_color("font_disabled_color", "SegmentButton", Color.WHITE)
	theme.set_color("icon_normal_color", "SegmentButton", btn_text)
	theme.set_color("icon_hover_color", "SegmentButton", text_primary)
	theme.set_color("icon_pressed_color", "SegmentButton", Color.WHITE)
	theme.set_color("icon_disabled_color", "SegmentButton", Color.WHITE)
	theme.set_font_size("font_size", "SegmentButton", ThemeManager.fs(ThemeManager.FONT_SIZE_SUBTITLE))

	for btn_var in ["PrimaryButton", "SecondaryButton", "CompactButton", "CompactPrimaryButton", "CompactSecondaryButton", "GhostButton", "PickerItem", "IconButton", "ToolbarButton", "SegmentButton"]:
		if active_font != null:
			theme.set_font("font", btn_var, active_font)

	# -------------------------------------------------------------------------
	# 3. Label & Typography Variations (Swiss Editorial Scale)
	# -------------------------------------------------------------------------
	theme.set_color("font_color", "Label", text_primary)
	theme.set_font_size("font_size", "Label", ThemeManager.fs(ThemeManager.FONT_SIZE_BODY))

	# Primary UI Variations (Inter variable TTF)
	# Display (28px, Hero / Title)
	for d_name in ["Display", "DisplayLabel"]:
		theme.set_type_variation(d_name, "Label")
		theme.set_color("font_color", d_name, text_primary)
		theme.set_font_size("font_size", d_name, ThemeManager.fs(ThemeManager.FONT_SIZE_DISPLAY))
		if active_font != null:
			theme.set_font("font", d_name, active_font)

	# Header (20px, Screen / Modal Title)
	for h_name in ["Header", "HeaderLabel"]:
		theme.set_type_variation(h_name, "Label")
		theme.set_color("font_color", h_name, text_primary)
		theme.set_font_size("font_size", h_name, ThemeManager.fs(ThemeManager.FONT_SIZE_HEADER))
		if active_font != null:
			theme.set_font("font", h_name, active_font)

	# Subtitle (13px, Section Headers & Indicators)
	for s_name in ["Subtitle", "SubtitleLabel"]:
		theme.set_type_variation(s_name, "Label")
		theme.set_color("font_color", s_name, text_secondary)
		theme.set_font_size("font_size", s_name, ThemeManager.fs(ThemeManager.FONT_SIZE_SUBTITLE))
		if active_font != null:
			theme.set_font("font", s_name, active_font)

	# Body (14px, Standard primary text)
	for b_name in ["Body", "BodyLabel"]:
		theme.set_type_variation(b_name, "Label")
		theme.set_color("font_color", b_name, text_primary)
		theme.set_font_size("font_size", b_name, ThemeManager.fs(ThemeManager.FONT_SIZE_BODY))
		if active_font != null:
			theme.set_font("font", b_name, active_font)

	# Caption (12px, Muted/notes text)
	for c_name in ["Caption", "CaptionLabel"]:
		theme.set_type_variation(c_name, "Label")
		theme.set_color("font_color", c_name, text_secondary)
		theme.set_font_size("font_size", c_name, ThemeManager.fs(ThemeManager.FONT_SIZE_CAPTION))
		if active_font != null:
			theme.set_font("font", c_name, active_font)

	# StatValue (22px, Key numerical callouts)
	for st_name in ["StatValue", "StatValueLabel"]:
		theme.set_type_variation(st_name, "Label")
		theme.set_color("font_color", st_name, text_user)
		theme.set_font_size("font_size", st_name, ThemeManager.fs(ThemeManager.FONT_SIZE_STAT))
		if active_font != null:
			theme.set_font("font", st_name, active_font)

	# Editorial / Brand Headings (Source Serif 4 Regular/Semibold - editorial excellence)
	var brand_font: Font = font_serif_semi if font_serif_semi != null else (font_serif_reg if font_serif_reg != null else active_font)
	theme.set_type_variation("BrandTitle", "Label")
	theme.set_color("font_color", "BrandTitle", text_primary)
	theme.set_font_size("font_size", "BrandTitle", ThemeManager.fs(ThemeManager.FONT_SIZE_BRAND))
	if brand_font != null:
		theme.set_font("font", "BrandTitle", brand_font)

	theme.set_type_variation("BrandHeader", "Label")
	theme.set_color("font_color", "BrandHeader", text_primary)
	theme.set_font_size("font_size", "BrandHeader", ThemeManager.fs(24))
	if brand_font != null:
		theme.set_font("font", "BrandHeader", brand_font)

	theme.set_type_variation("EditorialHeader", "Label")
	theme.set_color("font_color", "EditorialHeader", text_primary)
	theme.set_font_size("font_size", "EditorialHeader", ThemeManager.fs(ThemeManager.FONT_SIZE_HEADER))
	if brand_font != null:
		theme.set_font("font", "EditorialHeader", brand_font)

	var editorial_reg_font: Font = font_serif_reg if font_serif_reg != null else brand_font
	for reg_name in ["EditorialRegular", "EditorialBody"]:
		theme.set_type_variation(reg_name, "Label")
		theme.set_color("font_color", reg_name, text_primary)
		theme.set_font_size("font_size", reg_name, ThemeManager.fs(18))
		if editorial_reg_font != null:
			theme.set_font("font", reg_name, editorial_reg_font)

	# Technical Values (IBM Plex Mono Regular - reserved for technical values such as seed)
	var technical_font: Font = font_mono if font_mono != null else active_font
	for tech_name in ["MonoLabel", "TechnicalLabel", "SeedLabel", "TechnicalValue"]:
		theme.set_type_variation(tech_name, "Label")
		theme.set_color("font_color", tech_name, text_secondary)
		theme.set_font_size("font_size", tech_name, ThemeManager.fs(ThemeManager.FONT_SIZE_BODY))
		if technical_font != null:
			theme.set_font("font", tech_name, technical_font)

	for tech_cap in ["MonoCaption", "SeedCaption", "TechnicalCaption"]:
		theme.set_type_variation(tech_cap, "Label")
		theme.set_color("font_color", tech_cap, text_secondary)
		theme.set_font_size("font_size", tech_cap, ThemeManager.fs(ThemeManager.FONT_SIZE_CAPTION))
		if technical_font != null:
			theme.set_font("font", tech_cap, technical_font)

	for tech_stat in ["MonoStat", "TechnicalStat"]:
		theme.set_type_variation(tech_stat, "Label")
		theme.set_color("font_color", tech_stat, text_user)
		theme.set_font_size("font_size", tech_stat, ThemeManager.fs(ThemeManager.FONT_SIZE_STAT))
		if technical_font != null:
			theme.set_font("font", tech_stat, technical_font)

	# -------------------------------------------------------------------------
	# 4. PanelContainer & Surface Variations (Clean Calm Surfaces, Hairline 1px)
	# -------------------------------------------------------------------------
	var sb_panel := ThemeManager.create_flat_stylebox(surface_col, ThemeManager.RADIUS_MD, ThemeManager.BORDER_HAIRLINE, border, 12, 12, Color.TRANSPARENT, 0)
	theme.set_stylebox("panel", "PanelContainer", sb_panel)

	# SurfacePanel & CardPanel (Clean calm surface, 0 shadow, 1px border - NOT glass)
	for p_name in ["SurfacePanel", "CardPanel"]:
		theme.set_type_variation(p_name, "PanelContainer")
		theme.set_stylebox("panel", p_name, sb_panel)

	# ModalPanel (Floating functional dialog panel: restrained liquid glass translucency, specular hairline rim, smooth arc)
	theme.set_type_variation("ModalPanel", "PanelContainer")
	var glass_rim := border.lightened(0.25) if is_dark else border.darkened(0.05)
	if is_dark:
		glass_rim = glass_rim.lerp(Color(1.0, 1.0, 1.0, 0.24), 0.45)
	else:
		glass_rim = glass_rim.lerp(Color(1.0, 1.0, 1.0, 0.70), 0.35)
	var sb_modal := ThemeManager.create_liquid_glass_stylebox(
		surface_elevated_col,
		ThemeManager.RADIUS_XL,
		ThemeManager.BORDER_HAIRLINE,
		glass_rim,
		18, 18,
		22, Vector2(0, 8), 0.32,
		0.88 if not (ThemeManager.current_theme_name == ThemeManager.THEME_AMOLED) else 0.95
	)
	theme.set_stylebox("panel", "ModalPanel", sb_modal)

	# SegmentedDock (Capsule outer container for segmented controls)
	var sb_seg_dock := ThemeManager.create_flat_stylebox(surface_col, ThemeManager.RADIUS_PILL_SM, ThemeManager.BORDER_HAIRLINE, border, 3, 3, Color.TRANSPARENT, 0)
	for seg_name in ["SegmentedDock", "SegmentedControl"]:
		theme.set_type_variation(seg_name, "PanelContainer")
		theme.set_stylebox("panel", seg_name, sb_seg_dock)

	# -------------------------------------------------------------------------
	# 5. Form & Selection Controls
	# -------------------------------------------------------------------------
	# OptionButton (Unified capsule selector with chevron-down icon)
	var sb_option_normal := ThemeManager.create_flat_stylebox(surface_elevated_col, ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_HAIRLINE, border, 16, 8, ThemeManager.get_shadow_color(0.06), 2, Vector2(0, 1))
	var sb_option_hover := ThemeManager.create_flat_stylebox(surface_elevated_col.lightened(0.06) if is_dark else surface_elevated_col.darkened(0.04), ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_HAIRLINE, border_focus, 16, 8, ThemeManager.get_shadow_color(0.10), 4, Vector2(0, 2))
	var sb_option_pressed := ThemeManager.create_flat_stylebox(bg_pressed, ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_HAIRLINE, border_focus, 16, 8, ThemeManager.get_shadow_color(0.03), 1, Vector2(0, 1))
	var sb_option_disabled := ThemeManager.create_flat_stylebox(bg_disabled, ThemeManager.RADIUS_CAPSULE, ThemeManager.BORDER_HAIRLINE, border.darkened(0.2), 16, 8)

	theme.set_stylebox("normal", "OptionButton", sb_option_normal)
	theme.set_stylebox("hover", "OptionButton", sb_option_hover)
	theme.set_stylebox("pressed", "OptionButton", sb_option_pressed)
	theme.set_stylebox("disabled", "OptionButton", sb_option_disabled)
	theme.set_stylebox("focus", "OptionButton", sb_empty)
	theme.set_color("font_color", "OptionButton", text_primary)
	theme.set_color("font_hover_color", "OptionButton", text_primary)
	theme.set_color("font_pressed_color", "OptionButton", text_primary)
	theme.set_color("font_disabled_color", "OptionButton", btn_text_disabled)
	theme.set_font_size("font_size", "OptionButton", ThemeManager.fs(ThemeManager.FONT_SIZE_BODY))
	theme.set_icon("arrow", "OptionButton", ThemeManager.get_icon_sized("chevron-down", 16))
	theme.set_constant("arrow_margin", "OptionButton", 10)

	# PopupMenu (Elevated floating surface with hairline borders and refined item states)
	var sb_popup_panel := ThemeManager.create_flat_stylebox(
		surface_elevated_col,
		ThemeManager.RADIUS_MD,
		ThemeManager.BORDER_HAIRLINE,
		border,
		ThemeManager.PAD_SM,
		ThemeManager.PAD_SM,
		ThemeManager.get_shadow_color(0.20),
		14,
		Vector2(0, 4)
	)
	var sb_popup_hover := ThemeManager.create_flat_stylebox(
		bg_hover,
		ThemeManager.RADIUS_SM,
		0,
		Color.TRANSPARENT,
		ThemeManager.PAD_MD,
		ThemeManager.PAD_SM
	)
	var sb_popup_sep := ThemeManager.create_flat_stylebox(border, 0, 0, Color.TRANSPARENT, 0, 1)

	theme.set_stylebox("panel", "PopupMenu", sb_popup_panel)
	theme.set_stylebox("hover", "PopupMenu", sb_popup_hover)
	theme.set_stylebox("separator", "PopupMenu", sb_popup_sep)
	theme.set_stylebox("labeled_separator_left", "PopupMenu", sb_popup_sep)
	theme.set_stylebox("labeled_separator_right", "PopupMenu", sb_popup_sep)
	theme.set_color("font_color", "PopupMenu", text_primary)
	theme.set_color("font_hover_color", "PopupMenu", text_primary)
	theme.set_color("font_accelerator_color", "PopupMenu", text_secondary)
	theme.set_color("font_disabled_color", "PopupMenu", btn_text_disabled)
	theme.set_color("font_separator_color", "PopupMenu", text_secondary)
	theme.set_constant("v_separation", "PopupMenu", 8)
	theme.set_constant("h_separation", "PopupMenu", 12)
	theme.set_constant("item_start_padding", "PopupMenu", 8)
	theme.set_constant("item_end_padding", "PopupMenu", 8)
	if active_font != null:
		theme.set_font("font", "PopupMenu", active_font)
	theme.set_font_size("font_size", "PopupMenu", ThemeManager.fs(ThemeManager.FONT_SIZE_BODY))

	# CheckBox (Anti-aliased, high-contrast theme-aware custom textures)
	var tex_cb_unchecked := _create_checkbox_texture(false, false, false)
	var tex_cb_unchecked_hover := _create_checkbox_texture(false, false, true)
	var tex_cb_checked := _create_checkbox_texture(true, false, false)
	var tex_cb_checked_hover := _create_checkbox_texture(true, false, true)
	var tex_cb_unchecked_dis := _create_checkbox_texture(false, true, false)
	var tex_cb_checked_dis := _create_checkbox_texture(true, true, false)

	theme.set_icon("unchecked", "CheckBox", tex_cb_unchecked)
	theme.set_icon("unchecked_disabled", "CheckBox", tex_cb_unchecked_dis)
	theme.set_icon("checked", "CheckBox", tex_cb_checked)
	theme.set_icon("checked_disabled", "CheckBox", tex_cb_checked_dis)
	theme.set_icon("radio_unchecked", "CheckBox", tex_cb_unchecked)
	theme.set_icon("radio_checked", "CheckBox", tex_cb_checked)

	# Also apply to PopupMenu checkboxes/radio items
	theme.set_icon("checked", "PopupMenu", tex_cb_checked)
	theme.set_icon("unchecked", "PopupMenu", tex_cb_unchecked)
	theme.set_icon("radio_checked", "PopupMenu", tex_cb_checked)
	theme.set_icon("radio_unchecked", "PopupMenu", tex_cb_unchecked)

	theme.set_color("font_color", "CheckBox", text_primary)
	theme.set_color("font_hover_color", "CheckBox", text_primary)
	theme.set_color("font_pressed_color", "CheckBox", text_primary)
	theme.set_color("font_disabled_color", "CheckBox", btn_text_disabled)
	theme.set_stylebox("normal", "CheckBox", sb_empty)
	theme.set_stylebox("hover", "CheckBox", sb_empty)
	theme.set_stylebox("pressed", "CheckBox", sb_empty)
	theme.set_stylebox("disabled", "CheckBox", sb_empty)
	theme.set_stylebox("focus", "CheckBox", sb_empty)
	theme.set_font_size("font_size", "CheckBox", ThemeManager.fs(ThemeManager.FONT_SIZE_BODY))

	# HSeparator (1px hairline subtle line)
	var sb_sep := ThemeManager.create_flat_stylebox(border, 0, 0, Color.TRANSPARENT, 0, 1)
	theme.set_stylebox("separator", "HSeparator", sb_sep)

	# LineEdit & TextEdit
	var sb_edit := ThemeManager.create_flat_stylebox(surface_elevated_col, ThemeManager.RADIUS_SM, ThemeManager.BORDER_HAIRLINE, border, 10, 8)
	theme.set_stylebox("normal", "LineEdit", sb_edit)
	theme.set_stylebox("normal", "TextEdit", sb_edit)
	theme.set_color("font_color", "LineEdit", text_primary)
	theme.set_color("font_color", "TextEdit", text_primary)
	theme.set_font_size("font_size", "LineEdit", ThemeManager.fs(ThemeManager.FONT_SIZE_BODY))
	theme.set_font_size("font_size", "TextEdit", ThemeManager.fs(ThemeManager.FONT_SIZE_BODY))

	# ScrollBars (Clean, transparent, invisible minimalist feel globally)
	var sb_scroll_empty := StyleBoxEmpty.new()
	var empty_scroll_tex := ImageTexture.new()
	for scrollbar_type in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", scrollbar_type, sb_scroll_empty)
		theme.set_stylebox("scroll_focus", scrollbar_type, sb_scroll_empty)
		theme.set_stylebox("grabber", scrollbar_type, sb_scroll_empty)
		theme.set_stylebox("grabber_highlight", scrollbar_type, sb_scroll_empty)
		theme.set_stylebox("grabber_pressed", scrollbar_type, sb_scroll_empty)
		theme.set_icon("decrement", scrollbar_type, empty_scroll_tex)
		theme.set_icon("decrement_highlight", scrollbar_type, empty_scroll_tex)
		theme.set_icon("decrement_pressed", scrollbar_type, empty_scroll_tex)
		theme.set_icon("increment", scrollbar_type, empty_scroll_tex)
		theme.set_icon("increment_highlight", scrollbar_type, empty_scroll_tex)
		theme.set_icon("increment_pressed", scrollbar_type, empty_scroll_tex)

	return theme

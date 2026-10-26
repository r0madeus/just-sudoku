class_name ThemeManager
extends Node

const ThemeBuilder = preload("res://scripts/services/theme_builder.gd")
const ThemePalettes = preload("res://scripts/services/theme_palettes.gd")

## Design System & Theme Engine (GDD §37, §38)
static var listeners: Array[Callable] = []

static func add_listener(c: Callable) -> void:
	if not listeners.has(c):
		listeners.append(c)

static func remove_listener(c: Callable) -> void:
	listeners.erase(c)

static func _notify_listeners() -> void:
	for c in listeners:
		if c.is_valid():
			c.call()

const THEME_DARK: String = "Dark"
const THEME_AMOLED: String = "AMOLED"
const THEME_LIGHT: String = "Light"
const THEME_SEPIA: String = "Sepia"
const THEME_FOREST: String = "Forest"
const THEME_CUSTOM: String = "Custom"
## Light or Dark, as the phone is set; looked at again whenever the app comes back to the front
const THEME_SYSTEM: String = "System"
## Saved settings from before 1.0.1 had no version: they always held a concrete theme, as the
## phone's was saved on the first start, so a plain Light or Dark there was never chosen
const SETTINGS_VERSION: int = 2

const SETTINGS_PATH: String = "user://saves/settings.json"

static var current_theme_name: String = THEME_DARK
static var current_palette: Dictionary = {}

static var PALETTES: Dictionary = ThemePalettes.create()

static func _static_init() -> void:
	current_palette = PALETTES[THEME_DARK].duplicate()

static func detect_system_theme() -> String:
	if DisplayServer.is_dark_mode():
		return THEME_DARK
	return THEME_LIGHT

static func is_dark_theme() -> bool:
	return get_color("bg").get_luminance() < 0.5


static func _sync_clear_color() -> void:
	# Translucent fills on fully rounded (circular) StyleBoxFlat buttons leave a seam through the
	# middle, so the disabled fill is flattened onto the background once per palette change
	var dis: Color = current_palette.get("button_disabled", Color.TRANSPARENT)
	if dis.a < 1.0 and current_palette.has("bg"):
		current_palette["button_disabled"] = Color(current_palette["bg"]).lerp(Color(dis, 1.0), dis.a)
	RenderingServer.set_default_clear_color(get_color("bg"))

## Whether the theme follows the phone's light or dark mode (the System choice)
static var follows_system: bool = true

static func set_theme(theme_name: String) -> void:
	follows_system = theme_name == "Auto" or theme_name == THEME_SYSTEM
	if follows_system:
		theme_name = detect_system_theme()
	_apply_palette(theme_name)
	save_settings()
	_notify_listeners()

## Tells everything that draws from the theme to draw again (a setting that changes the look)
static func notify_changed() -> void:
	_notify_listeners()

## Following the phone, and it switched between light and dark while the app was away
static func refresh_system_theme() -> void:
	if follows_system and detect_system_theme() != current_theme_name:
		_apply_palette(detect_system_theme())
		_notify_listeners()

static func _apply_palette(theme_name: String) -> void:
	if PALETTES.has(theme_name):
		current_theme_name = theme_name
		current_palette = PALETTES[theme_name].duplicate()
	_sync_clear_color()

static func get_color(key: String, fallback: Color = Color.WHITE) -> Color:
	return current_palette.get(key, fallback)

static func set_custom_color(key: String, color: Color) -> void:
	follows_system = false
	current_theme_name = THEME_CUSTOM
	current_palette[key] = color
	_sync_clear_color()
	save_settings()
	_notify_listeners()

static func apply_custom_palette(new_palette: Dictionary) -> void:
	current_theme_name = THEME_CUSTOM
	current_palette = PALETTES[THEME_DARK].duplicate()

	for k in new_palette.keys():
		current_palette[k] = new_palette[k]

	# Harmonize secondary colors
	var bg_col: Color = current_palette.get("bg", Color("#0e1117"))
	var is_dark: bool = bg_col.get_luminance() < 0.5
	var contrast_target: Color = Color.WHITE if is_dark else Color.BLACK

	if new_palette.has("grid_major"):
		current_palette["grid_minor"] = current_palette["grid_major"].lerp(bg_col, 0.55)
		current_palette["border_subtle"] = current_palette["grid_major"].lerp(bg_col, 0.4)
	if new_palette.has("cell_selected") and new_palette.has("cell_bg"):
		current_palette["cell_peer"] = current_palette["cell_selected"].lerp(current_palette["cell_bg"], 0.65)
		current_palette["cell_same_num"] = current_palette["cell_selected"].lerp(current_palette["cell_bg"], 0.4)
	current_palette["surface"] = bg_col.lerp(contrast_target, 0.05)
	current_palette["surface_elevated"] = bg_col.lerp(contrast_target, 0.09)
	current_palette["button_normal"] = bg_col.lerp(contrast_target, 0.07)
	current_palette["button_hover"] = current_palette["button_normal"].lightened(0.12) if is_dark else current_palette["button_normal"].darkened(0.08)
	current_palette["button_pressed"] = current_palette["button_normal"].darkened(0.1) if is_dark else current_palette["button_normal"].lightened(0.08)
	current_palette["button_disabled"] = Color(current_palette["button_normal"], 0.5)
	if new_palette.has("text_given"):
		current_palette["button_text"] = current_palette["text_given"].lerp(bg_col, 0.15)
		current_palette["button_text_disabled"] = current_palette["text_given"].lerp(bg_col, 0.6)
	if new_palette.has("accent_blue"):
		current_palette["accent"] = current_palette["accent_blue"]
		current_palette["border_focus"] = current_palette["accent_blue"]
	if not current_palette.has("text_wrong"):
		current_palette["text_wrong"] = current_palette.get("text_conflict", Color.RED).darkened(0.2)

	_sync_clear_color()
	save_settings()
	_notify_listeners()

static func get_custom_palette() -> Dictionary:
	var keys := [
		"bg", "grid_major", "cell_bg", "cell_selected",
		"text_given", "text_user", "accent_blue", "text_conflict", "text_notes"
	]
	var res: Dictionary = {}
	for k in keys:
		res[k] = get_color(k)
	return res

# =============================================================================
# QUIET PRECISION DESIGN TOKENS
# Swiss/editorial minimalism + precision instrument + modern puzzle app
# =============================================================================

# Spacing Tokens (Geometric 4px rhythm)
const SPACE_2XS: int = 2
const SPACE_XS: int = 4
const SPACE_SM: int = 8
const SPACE_MD: int = 12
const SPACE_LG: int = 16
const SPACE_XL: int = 24
const SPACE_2XL: int = 32

# Controlled Geometric & Concentric Radiuses (Swiss Precision × Restrained Glass)
const RADIUS_NONE: int = 0
const RADIUS_XS: int = 3   # Subtle tags, inline indicators, micro cells
const RADIUS_SM: int = 4   # Small/medium controls (buttons, inputs, segments)
const RADIUS_MD: int = 6   # Surface containers, list items
const RADIUS_LG: int = 8   # Action docks, nested inner frames
const RADIUS_XL: int = 12  # Floating modals and dialogs
const RADIUS_PILL_SM: int = 18 # Compact capsule controls, segmented docks, small buttons
const RADIUS_PILL: int = 22 # Emphasized primary & secondary action capsules, large docks
const RADIUS_CAPSULE: int = 999 # Mathematically exact semicircle capsule pill geometry

## Concentric Radius Helper: computes mathematically harmonious inner radius: max(0, outer_radius - padding)
static func get_concentric_radius(outer_radius: int, padding: int) -> int:
	return maxi(0, outer_radius - padding)

# Precision Hairline Borders
const BORDER_NONE: int = 0
const BORDER_HAIRLINE: int = 1  # 1px precision hairline
const BORDER_THIN: int = 1      # Backward compatibility alias
const BORDER_MAJOR: int = 2     # 3x3 block & structural dividing lines

# Padding Tokens
const PAD_2XS: int = 2
const PAD_XS: int = 4
const PAD_SM: int = 8
const PAD_MD: int = 12
const PAD_LG: int = 16
const PAD_XL: int = 20

# Typography Tokens
const FONT_SIZE_BRAND: int = 40
const FONT_SIZE_DISPLAY: int = 28
const FONT_SIZE_STAT: int = 22
const FONT_SIZE_HEADER: int = 20
const FONT_SIZE_TITLE: int = 18
const FONT_SIZE_TITLE_SM: int = 16
const FONT_SIZE_BODY: int = 14
const FONT_SIZE_SUBTITLE: int = 13
const FONT_SIZE_CAPTION: int = 12
const FONT_SIZE_MICRO: int = 10

## Text size (Settings, accessibility): UI text grows by up to this factor (see fs()). Board
## digits and the number keys are sized to their cells and keep their size; notes grow a little.
const TEXT_SIZE_NORMAL: String = "normal"
const TEXT_SIZE_LARGE: String = "large"
const TEXT_SIZE_XLARGE: String = "xlarge"
const TEXT_SIZES: Dictionary = {TEXT_SIZE_NORMAL: 1.0, TEXT_SIZE_LARGE: 1.15, TEXT_SIZE_XLARGE: 1.3}
const BASE_FONT_SIZE_META: StringName = &"base_font_size"
static var text_size: String = TEXT_SIZE_NORMAL
static var text_scale: float = 1.0

## A font size at the chosen text size. Small text grows fully; display text grows less and
## the largest not at all (it is already easy to read, and growing it costs the most room).
static func fs(px: float) -> int:
	var weight: float = clampf((28.0 - px) / 12.0, 0.0, 1.0)
	return roundi(px * (1.0 + (text_scale - 1.0) * weight))

## Sets a control's font size at the chosen text size, and remembers `px` so a later change of
## text size can resize it in place
static func set_font_size(ctrl: Control, px: float) -> void:
	ctrl.set_meta(BASE_FONT_SIZE_META, px)
	ctrl.add_theme_font_size_override("font_size", fs(px))

## Changes the text size: resizes every text already on screen (`root`, when given), then lets
## the listeners rebuild the theme and anything sized from it
static func set_text_size(size_name: String, root: Node = null) -> void:
	if not TEXT_SIZES.has(size_name):
		size_name = TEXT_SIZE_NORMAL
	if size_name == text_size:
		return
	text_size = size_name
	text_scale = TEXT_SIZES[size_name]
	if root != null:
		var controls: Array[Node] = root.find_children("*", "Control", true, false)
		for n in controls:
			if n.has_meta(BASE_FONT_SIZE_META):
				n.add_theme_font_size_override("font_size", fs(float(n.get_meta(BASE_FONT_SIZE_META))))
		# Then whatever measures its text, now that every text has its new size
		for n in controls:
			if n.has_method("_on_text_size_changed"):
				n._on_text_size_changed()
	_notify_listeners()

# Bundled Font Resources & Paths (res://assets/fonts/)
const FONT_PATH_INTER: String = "res://assets/fonts/Inter[opsz,wght].ttf"
const FONT_PATH_SERIF_REGULAR: String = "res://assets/fonts/SourceSerif4-Regular.ttf"
const FONT_PATH_SERIF_SEMIBOLD: String = "res://assets/fonts/SourceSerif4-Semibold.ttf"
const FONT_PATH_MONO_REGULAR: String = "res://assets/fonts/IBMPlexMono-Regular.ttf"
## The display face of the wordmark on the home screen (DM Serif Display, OFL)
const FONT_PATH_DISPLAY: String = "res://assets/fonts/DMSerifDisplay-Regular.ttf"

static var _font_inter: Font = null
static var _font_serif_regular: Font = null
static var _font_serif_semibold: Font = null
static var _font_mono: Font = null
static var _font_display: Font = null

static func get_font_inter() -> Font:
	if _font_inter == null and ResourceLoader.exists(FONT_PATH_INTER):
		_font_inter = load(FONT_PATH_INTER) as Font
	return _font_inter

static func get_font_serif_regular() -> Font:
	if _font_serif_regular == null and ResourceLoader.exists(FONT_PATH_SERIF_REGULAR):
		_font_serif_regular = load(FONT_PATH_SERIF_REGULAR) as Font
	return _font_serif_regular

static func get_font_display() -> Font:
	if _font_display == null and ResourceLoader.exists(FONT_PATH_DISPLAY):
		_font_display = load(FONT_PATH_DISPLAY) as Font
	return _font_display

static func get_font_serif_semibold() -> Font:
	if _font_serif_semibold == null and ResourceLoader.exists(FONT_PATH_SERIF_SEMIBOLD):
		_font_serif_semibold = load(FONT_PATH_SERIF_SEMIBOLD) as Font
	return _font_serif_semibold

static func get_font_mono() -> Font:
	if _font_mono == null and ResourceLoader.exists(FONT_PATH_MONO_REGULAR):
		_font_mono = load(FONT_PATH_MONO_REGULAR) as Font
	return _font_mono

# Lucide Icon Resources & Paths (res://assets/icons/)
const ICON_BASE_PATH: String = "res://assets/icons/"
static var _icon_cache: Dictionary = {}

static func get_icon(icon_name: String) -> Texture2D:
	if _icon_cache.has(icon_name):
		return _icon_cache[icon_name]

	var file_name: String = icon_name
	if not file_name.ends_with(".svg"):
		file_name += ".svg"
	var full_path: String = ICON_BASE_PATH + file_name

	if not ResourceLoader.exists(full_path):
		printerr("ThemeManager: Icon not found at ", full_path)
		return null

	var raw_tex: Texture2D = load(full_path) as Texture2D
	if raw_tex == null:
		return null

	# The SVGs are drawn in white, so theme tints (which multiply) can colour them anything;
	# recolouring black ones here pixel by pixel cost ~0.7 ms per icon at start
	var img: Image = raw_tex.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		img.generate_mipmaps()
		var white_tex := ImageTexture.create_from_image(img)
		_icon_cache[icon_name] = white_tex
		return white_tex

	_icon_cache[icon_name] = raw_tex
	return raw_tex

## Icon rendered at an exact pixel size, for theme slots (like the OptionButton arrow) that
## draw the texture at its native size instead of honouring icon_max_width
static func get_icon_sized(icon_name: String, px: int) -> Texture2D:
	var key: String = "%s@%d" % [icon_name, px]
	if _icon_cache.has(key):
		return _icon_cache[key]
	var base: Texture2D = get_icon(icon_name)
	if base == null:
		return null
	var img: Image = base.get_image()
	if img == null:
		return base
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.resize(px, px, Image.INTERPOLATE_LANCZOS)
	var tex := ImageTexture.create_from_image(img)
	_icon_cache[key] = tex
	return tex

# Control Heights (Touch ergonomics with precision feel)
const HEIGHT_TOUCH_MIN: int = 44
const HEIGHT_BUTTON_PRIMARY: int = 44
const HEIGHT_BUTTON_SECONDARY: int = 44
const HEIGHT_BUTTON_COMPACT: int = 32
const HEIGHT_DOCK: int = 38
const HEIGHT_SEGMENT: int = 44

# Shadows (Minimal, controlled)
const SHADOW_SIZE_NONE: int = 0
const SHADOW_SIZE_MODAL: int = 14

## Device pixels per layout unit: about 2.6 on a typical phone, about 1 on a desktop window.
## Set at start (AppRoot) before the theme is built.
static var device_px_scale: float = 1.0

## Width of a box's anti-aliased edge, in layout units: one device pixel. Godot's default of one
## unit spread rounded edges over 2-3 pixels on phones and made them look soft.
static func edge_aa() -> float:
	return clampf(1.0 / maxf(device_px_scale, 0.01), 0.3, 1.0)

## Creates a polished flat StyleBoxFlat with clean hairline borders and subtle depth
static func create_flat_stylebox(
	bg_color: Color,
	corner_radius: int = RADIUS_SM,
	border_width: int = BORDER_NONE,
	border_color: Color = Color.TRANSPARENT,
	pad_h: int = PAD_MD,
	pad_v: int = PAD_SM,
	shadow_color: Color = Color.TRANSPARENT,
	shadow_size: int = 0,
	shadow_offset: Vector2 = Vector2.ZERO
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.anti_aliasing_size = edge_aa()
	sb.bg_color = bg_color
	sb.set_corner_radius_all(corner_radius)
	sb.corner_detail = 16
	if border_width > 0:
		sb.set_border_width_all(border_width)
		sb.border_color = border_color
	if shadow_size > 0 and shadow_color.a > 0.0:
		sb.shadow_color = shadow_color
		sb.shadow_size = shadow_size
		sb.shadow_offset = shadow_offset
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb

## Computes a soft ambient shadow color suited for the current palette
static func get_shadow_color(opacity: float = 0.15) -> Color:
	var bg_col: Color = get_color("bg")
	if bg_col.get_luminance() < 0.5:
		return Color(0.0, 0.0, 0.0, opacity)
	else:
		return Color(0.08, 0.12, 0.18, opacity * 0.75)

## Creates a refined Swiss Editorial × Restrained Liquid Glass StyleBox for functional/floating UI layers
static func create_liquid_glass_stylebox(
	bg_color: Color,
	corner_radius: int = RADIUS_XL,
	border_width: int = BORDER_HAIRLINE,
	border_highlight: Color = Color.TRANSPARENT,
	pad_h: int = PAD_LG,
	pad_v: int = PAD_LG,
	shadow_size: int = 14,
	shadow_offset: Vector2 = Vector2(0, 4),
	shadow_opacity: float = 0.18,
	alpha_translucency: float = 0.90
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.anti_aliasing_size = edge_aa()
	# Translucent liquid glass surface
	sb.bg_color = Color(bg_color.r, bg_color.g, bg_color.b, bg_color.a * alpha_translucency)
	sb.set_corner_radius_all(corner_radius)
	sb.corner_detail = 12 # Silky smooth arc
	if border_width > 0:
		sb.set_border_width_all(border_width)
		sb.border_color = border_highlight
	if shadow_size > 0:
		sb.shadow_color = get_shadow_color(shadow_opacity)
		sb.shadow_size = shadow_size
		sb.shadow_offset = shadow_offset
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb

## Generates a high-contrast, theme-aware, anti-aliased CheckBox icon texture (see ThemeBuilder)
static func _create_checkbox_texture(is_checked: bool, is_disabled: bool, is_hover: bool = false) -> ImageTexture:
	return ThemeBuilder._create_checkbox_texture(is_checked, is_disabled, is_hover)

## Builds a unified, modern Godot Theme resource with native Theme Type Variations (see ThemeBuilder)
static func build_godot_theme() -> Theme:
	return ThemeBuilder.build_godot_theme()

## Helper to style prominent Hero / Action buttons (Continue, New Game)
static func apply_primary_button_style(btn: Button, _corner_radius: int = RADIUS_PILL) -> void:
	btn.theme_type_variation = "PrimaryButton"

## Helper to style clean flat secondary buttons
static func apply_secondary_button_style(btn: Button, _corner_radius: int = RADIUS_PILL) -> void:
	btn.theme_type_variation = "SecondaryButton"

## Helper to style action buttons (e.g. Header Back, Action Bar toggles)
static func apply_pill_button_style(btn: Button, is_active: bool = false, _corner_radius: int = RADIUS_PILL, _pad_h: int = 12, _pad_v: int = 6) -> void:
	btn.theme_type_variation = "PrimaryButton" if is_active else "SecondaryButton"

## Helper to style compact capsule buttons (e.g. Daily, Replay, Resume)
static func apply_compact_button_style(btn: Button, is_primary: bool = false) -> void:
	btn.theme_type_variation = "CompactPrimaryButton" if is_primary else "CompactSecondaryButton"

## Helper to style icon actions (perfect circular buttons, 44–48px on mobile)
static func apply_icon_button_style(btn: Button, size: float = 44.0) -> void:
	btn.theme_type_variation = "IconButton"
	btn.custom_minimum_size = Vector2(size, size)
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

## Helper to style modern clean surfaces (Panels, Bento tiles, Containers)
static func apply_card_container_style(panel: PanelContainer, _corner_radius: int = RADIUS_MD, _pad: int = 12) -> void:
	panel.theme_type_variation = "SurfacePanel"

## Helper to style pill tags / badges (e.g. Difficulty pill, streak badge)
static func apply_badge_style(label: Label, bg_col: Color, text_col: Color = Color.WHITE, corner_radius: int = RADIUS_XS, pad_h: int = 6, pad_v: int = 2) -> void:
	var sb := create_flat_stylebox(bg_col, corner_radius, 0, Color.TRANSPARENT, pad_h, pad_v)
	label.add_theme_stylebox_override("normal", sb)
	label.add_theme_color_override("font_color", text_col)

## Helper to calculate dynamic 50% radius for circular numpad buttons
static func get_numpad_button_radius(btn: Button) -> int:
	var dim: float = btn.size.x if btn.size.x > 0.0 else btn.custom_minimum_size.x
	if dim <= 0.0:
		dim = btn.size.y if btn.size.y > 0.0 else btn.custom_minimum_size.y
	if dim <= 0.0:
		dim = 74.0
	return int(round(dim * 0.5))

## Helper to style Numpad buttons as perfect circles (50% dynamic radius, clean, tactile, 0 shadow, consistent with circular controls)
static func apply_numpad_button_style(btn: Button, corner_radius: int = -1, is_selected: bool = false) -> void:
	var radius: int = get_numpad_button_radius(btn)
	if corner_radius > 0 and corner_radius != RADIUS_MD and corner_radius != RADIUS_SM:
		radius = corner_radius

	var norm_bg: Color = get_color("cell_selected") if is_selected else get_color("button_normal")
	var norm_border: Color = get_color("border_focus") if is_selected else get_color("border_subtle")
	var norm_text: Color = get_color("text_user") if is_selected else get_color("text_given")

	var norm_border_w: int = 2 if is_selected else BORDER_HAIRLINE
	var sb_n := create_flat_stylebox(norm_bg, radius, norm_border_w, norm_border, 0, 0)
	var sb_h := create_flat_stylebox(get_color("button_hover"), radius, BORDER_HAIRLINE, get_color("border_focus"), 0, 0)
	var sb_p := create_flat_stylebox(get_color("button_pressed"), radius, BORDER_HAIRLINE, get_color("border_focus"), 0, 0)
	# Translucent fills on a full-radius (circular) StyleBoxFlat leave a visible seam through the
	# middle, so the disabled fill is flattened onto the background into an opaque colour
	var dis_fill: Color = get_color("button_disabled")
	dis_fill = get_color("bg").lerp(Color(dis_fill, 1.0), dis_fill.a)
	# Disabled keys recede: a fainter outline than an active key, never a stronger one
	var dis_border: Color = get_color("border_subtle")
	dis_border.a *= 0.5
	var sb_d := create_flat_stylebox(dis_fill, radius, BORDER_HAIRLINE, dis_border, 0, 0)

	btn.add_theme_stylebox_override("normal", sb_n)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_p)
	btn.add_theme_stylebox_override("disabled", sb_d)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	btn.add_theme_color_override("font_color", norm_text)
	btn.add_theme_color_override("font_hover_color", get_color("text_user"))
	btn.add_theme_color_override("font_pressed_color", get_color("text_user"))
	btn.add_theme_color_override("font_disabled_color", get_color("button_text_disabled"))

	if not btn.has_meta("_numpad_radius_connected"):
		btn.set_meta("_numpad_radius_connected", true)
		btn.resized.connect(func():
			if is_instance_valid(btn):
				var dynamic_r: int = get_numpad_button_radius(btn)
				for state in ["normal", "hover", "pressed", "disabled"]:
					var sb = btn.get_theme_stylebox(state)
					if sb is StyleBoxFlat:
						sb.set_corner_radius_all(dynamic_r)
		)

## Helper to style floating dialog / modal cards
static func apply_modal_card_style(panel: PanelContainer, _corner_radius: int = RADIUS_LG) -> void:
	panel.theme_type_variation = "ModalPanel"

static func save_settings() -> void:
	# On a fresh install nothing else may have made the folder yet (no game saved so far)
	DirAccess.make_dir_recursive_absolute(SETTINGS_PATH.get_base_dir())
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		var data: Dictionary = {
			"version": SETTINGS_VERSION,
			"theme": THEME_SYSTEM if follows_system else current_theme_name,
			"palette": {}
		}
		for k in current_palette.keys():
			data["palette"][k] = current_palette[k].to_html()
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

static func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		set_theme(THEME_SYSTEM)
		return

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		set_theme(THEME_SYSTEM)
		return
	var content: String = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(content) == OK and json.data is Dictionary:
		var t_name: String = json.data.get("theme", "")
		var old_file: bool = int(json.data.get("version", 1)) < SETTINGS_VERSION
		if t_name.is_empty() or t_name == "Auto" or t_name == THEME_SYSTEM \
				or (old_file and (t_name == THEME_DARK or t_name == THEME_LIGHT)):
			set_theme(THEME_SYSTEM)
			return
		if json.data.has("palette") and t_name == THEME_CUSTOM:
			follows_system = false
			current_theme_name = THEME_CUSTOM
			for k in json.data["palette"].keys():
				current_palette[k] = Color(json.data["palette"][k])
			_sync_clear_color()
			_notify_listeners()
		elif PALETTES.has(t_name):
			set_theme(t_name)
		else:
			set_theme(THEME_SYSTEM)
	else:
		set_theme(THEME_SYSTEM)

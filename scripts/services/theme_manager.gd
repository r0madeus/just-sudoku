class_name ThemeManager
extends Node

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

const SETTINGS_PATH: String = "user://saves/settings.json"

static var current_theme_name: String = THEME_DARK
static var current_palette: Dictionary = {}

static var PALETTES: Dictionary = {
	THEME_DARK: {
		# Canvas & Surfaces (Architectural Neutral Slate)
		"bg": Color("#11141a"),
		"surface": Color("#171b23"),
		"surface_elevated": Color("#1e232e"),
		"border_subtle": Color("#2a313d"),
		"border_focus": Color("#3b82f6"),

		# Sudoku Grid & Lines (Crisp 3x3 boundaries, subtle hairlines, visible crosshair & selection)
		"grid_major": Color("#6b7d99"),
		"grid_minor": Color("#252e3d"),
		"cell_bg": Color("#13161d"),
		"cell_selected": Color("#1d4a7a"),
		"cell_peer": Color("#1c2433"),
		"cell_same_num": Color("#263952"),

		# Typography
		"text_given": Color("#f8fafc"),
		"text_user": Color("#60a5fa"),
		"text_conflict": Color("#ef4444"),
		"text_wrong": Color("#dc2626"),
		"text_notes": Color("#7e899b"),
		"text_secondary": Color("#7e899b"),

		# Interactive & Brand (Quiet Precision: Focused Accent)
		"accent": Color("#2563eb"),
		"accent_blue": Color("#2563eb"),
		"accent_text": Color("#ffffff"),
		"button_normal": Color("#1c212a"),
		"button_hover": Color("#262c38"),
		"button_pressed": Color("#151820"),
		"button_disabled": Color("#15182080"),
		"button_text": Color("#e2e8f0"),
		"button_text_disabled": Color("#475569")
	},
	THEME_AMOLED: {
		# Canvas & Surfaces (Pure Black Precision Instrument)
		"bg": Color("#000000"),
		"surface": Color("#0a0a0a"),
		"surface_elevated": Color("#121212"),
		"border_subtle": Color("#202020"),
		"border_focus": Color("#3b82f6"),

		# Sudoku Grid & Lines
		"grid_major": Color("#7a7a7a"),
		"grid_minor": Color("#222222"),
		"cell_bg": Color("#000000"),
		"cell_selected": Color("#1e3a5f"),
		"cell_peer": Color("#111824"),
		"cell_same_num": Color("#1a2b3d"),

		# Typography
		"text_given": Color("#ffffff"),
		"text_user": Color("#60a5fa"),
		"text_conflict": Color("#ef4444"),
		"text_wrong": Color("#dc2626"),
		"text_notes": Color("#737373"),
		"text_secondary": Color("#737373"),

		# Interactive & Brand
		"accent": Color("#2563eb"),
		"accent_blue": Color("#2563eb"),
		"accent_text": Color("#ffffff"),
		"button_normal": Color("#101010"),
		"button_hover": Color("#1a1a1a"),
		"button_pressed": Color("#0d0d0d"),
		"button_disabled": Color("#080808"),
		"button_text": Color("#f5f5f5"),
		"button_text_disabled": Color("#404040")
	},
	THEME_LIGHT: {
		# Canvas & Surfaces (Swiss Editorial Paper)
		"bg": Color("#f8f9fa"),
		"surface": Color("#ffffff"),
		"surface_elevated": Color("#ffffff"),
		"border_subtle": Color("#e2e5e9"),
		"border_focus": Color("#2563eb"),

		# Sudoku Grid & Lines
		"grid_major": Color("#0f172a"),
		"grid_minor": Color("#cbd5e1"),
		"cell_bg": Color("#ffffff"),
		"cell_selected": Color("#bfdbfe"),
		"cell_peer": Color("#f1f5f9"),
		"cell_same_num": Color("#dbeafe"),

		# Typography
		"text_given": Color("#0f172a"),
		"text_user": Color("#1d4ed8"),
		"text_conflict": Color("#dc2626"),
		"text_wrong": Color("#b91c1c"),
		"text_notes": Color("#64748b"),
		"text_secondary": Color("#64748b"),

		# Interactive & Brand
		"accent": Color("#1d4ed8"),
		"accent_blue": Color("#2563eb"),
		"accent_text": Color("#ffffff"),
		"button_normal": Color("#f1f3f5"),
		"button_hover": Color("#e5e8ec"),
		"button_pressed": Color("#dce0e5"),
		"button_disabled": Color("#f1f3f580"),
		"button_text": Color("#1e293b"),
		"button_text_disabled": Color("#94a3b8")
	},
	THEME_SEPIA: {
		# Canvas & Surfaces (Warm Parchment / Paper)
		"bg": Color("#f4ecd8"),
		"surface": Color("#ede2c8"),
		"surface_elevated": Color("#fbf7ed"),
		"border_subtle": Color("#d5c4a1"),
		"border_focus": Color("#b57614"),

		# Sudoku Grid & Lines
		"grid_major": Color("#504945"),
		"grid_minor": Color("#d5c4a1"),
		"cell_bg": Color("#fbf7ed"),
		"cell_selected": Color("#e2d3b2"),
		"cell_peer": Color("#f0e4c8"),
		"cell_same_num": Color("#e5d5b5"),

		# Typography
		"text_given": Color("#3c3836"),
		"text_user": Color("#af3a03"),
		"text_conflict": Color("#cc241d"),
		"text_wrong": Color("#9d0006"),
		"text_notes": Color("#7c6f64"),
		"text_secondary": Color("#7c6f64"),

		# Interactive & Brand
		"accent": Color("#b57614"),
		"accent_blue": Color("#af3a03"),
		"accent_text": Color("#ffffff"),
		"button_normal": Color("#ede2c8"),
		"button_hover": Color("#e2d3b2"),
		"button_pressed": Color("#d5c4a1"),
		"button_disabled": Color("#ede2c880"),
		"button_text": Color("#3c3836"),
		"button_text_disabled": Color("#928374")
	},
	THEME_FOREST: {
		# Canvas & Surfaces (Dark Sage / Nordic Mint)
		"bg": Color("#101a14"),
		"surface": Color("#18261e"),
		"surface_elevated": Color("#203328"),
		"border_subtle": Color("#2b4235"),
		"border_focus": Color("#34d399"),

		# Sudoku Grid & Lines
		"grid_major": Color("#6f8875"),
		"grid_minor": Color("#253a2e"),
		"cell_bg": Color("#142119"),
		"cell_selected": Color("#274f39"),
		"cell_peer": Color("#1a2e22"),
		"cell_same_num": Color("#2f5b42"),

		# Typography
		"text_given": Color("#e6f4ec"),
		"text_user": Color("#34d399"),
		"text_conflict": Color("#f87171"),
		"text_wrong": Color("#ef4444"),
		"text_notes": Color("#7da58e"),
		"text_secondary": Color("#7da58e"),

		# Interactive & Brand
		"accent": Color("#10b981"),
		"accent_blue": Color("#059669"),
		"accent_text": Color("#ffffff"),
		"button_normal": Color("#1c2d23"),
		"button_hover": Color("#253d2f"),
		"button_pressed": Color("#15231b"),
		"button_disabled": Color("#1c2d2380"),
		"button_text": Color("#d1fae5"),
		"button_text_disabled": Color("#4e7962")
	}
}

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

static func set_theme(theme_name: String) -> void:
	if theme_name == "Auto" or theme_name == "System":
		theme_name = detect_system_theme()
	if PALETTES.has(theme_name):
		current_theme_name = theme_name
		current_palette = PALETTES[theme_name].duplicate()
	_sync_clear_color()
	save_settings()
	_notify_listeners()

static func get_color(key: String, fallback: Color = Color.WHITE) -> Color:
	return current_palette.get(key, fallback)

static func set_custom_color(key: String, color: Color) -> void:
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

# Bundled Font Resources & Paths (res://assets/fonts/)
const FONT_PATH_INTER: String = "res://assets/fonts/Inter[opsz,wght].ttf"
const FONT_PATH_SERIF_REGULAR: String = "res://assets/fonts/SourceSerif4-Regular.ttf"
const FONT_PATH_SERIF_SEMIBOLD: String = "res://assets/fonts/SourceSerif4-Semibold.ttf"
const FONT_PATH_MONO_REGULAR: String = "res://assets/fonts/IBMPlexMono-Regular.ttf"

static var _font_inter: Font = null
static var _font_serif_regular: Font = null
static var _font_serif_semibold: Font = null
static var _font_mono: Font = null

static func get_font_inter() -> Font:
	if _font_inter == null and ResourceLoader.exists(FONT_PATH_INTER):
		_font_inter = load(FONT_PATH_INTER) as Font
	return _font_inter

static func get_font_serif_regular() -> Font:
	if _font_serif_regular == null and ResourceLoader.exists(FONT_PATH_SERIF_REGULAR):
		_font_serif_regular = load(FONT_PATH_SERIF_REGULAR) as Font
	return _font_serif_regular

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

	var img: Image = raw_tex.get_image()
	if img != null:
		# Convert black stroke pixels to white (preserving alpha mask)
		# so Godot's theme icon tinting can modulate it to any theme color.
		for y in range(img.get_height()):
			for x in range(img.get_width()):
				var p := img.get_pixel(x, y)
				if p.a > 0.0:
					img.set_pixel(x, y, Color(1.0, 1.0, 1.0, p.a))
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
const HEIGHT_BUTTON_SECONDARY: int = 40
const HEIGHT_BUTTON_COMPACT: int = 32
const HEIGHT_DOCK: int = 38
const HEIGHT_SEGMENT: int = 34

# Shadows (Minimal, controlled)
const SHADOW_SIZE_NONE: int = 0
const SHADOW_SIZE_MODAL: int = 14

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

## Generates a high-contrast, theme-aware, anti-aliased CheckBox icon texture
static func _create_checkbox_texture(is_checked: bool, is_disabled: bool, is_hover: bool = false) -> ImageTexture:
	var sz := 22
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var radius := 4.0
	var border_w := 1.5

	var bg_col: Color = get_color("bg")
	var surf_elev: Color = get_color("surface_elevated")
	var border_col: Color = get_color("border_subtle")
	var border_focus_col: Color = get_color("border_focus")
	var sec_col: Color = get_color("text_secondary")
	var accent_col: Color = get_color("accent_blue", get_color("accent"))
	var dis_col: Color = get_color("button_text_disabled")

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
		var check_icon := get_icon("check")
		if check_icon != null:
			var chk_img := check_icon.get_image()
			if chk_img != null:
				var chk_copy: Image = chk_img.duplicate() as Image
				chk_copy.resize(14, 14, Image.INTERPOLATE_LANCZOS)
				var mark_alpha: float = 0.6 if is_disabled else 1.0
				for cy in range(14):
					for cx in range(14):
						var cp: Color = chk_copy.get_pixel(cx, cy)
						if cp.a > 0.0:
							var cur: Color = img.get_pixel(cx + 4, cy + 4)
							img.set_pixel(cx + 4, cy + 4, cur.blend(Color(1.0, 1.0, 1.0, cp.a * mark_alpha)))

	return ImageTexture.create_from_image(img)

## Builds a unified, modern Godot Theme resource with native Theme Type Variations
static func build_godot_theme() -> Theme:
	var theme := Theme.new()

	var font_inter: Font = get_font_inter()
	var font_serif_reg: Font = get_font_serif_regular()
	var font_serif_semi: Font = get_font_serif_semibold()
	var font_mono: Font = get_font_mono()

	var active_font: Font = font_inter
	if FontManager.current_font_name != FontManager.FONT_MODERN_SANS:
		active_font = FontManager.get_current_font()
	elif active_font == null:
		active_font = FontManager.get_current_font()

	if active_font != null:
		theme.default_font = active_font
		theme.set_font("font", "Button", active_font)
		theme.set_font("font", "Label", active_font)
		theme.set_font("font", "OptionButton", active_font)
		theme.set_font("font", "PopupMenu", active_font)
		theme.set_font("font", "CheckBox", active_font)
		theme.set_font("font", "LineEdit", active_font)
		theme.set_font("font", "TextEdit", active_font)

	var bg_col: Color = get_color("bg")
	var is_dark: bool = bg_col.get_luminance() < 0.5

	var bg_normal := get_color("button_normal")
	var bg_hover := get_color("button_hover")
	var bg_pressed := get_color("button_pressed")
	var bg_disabled := get_color("button_disabled")
	var border := get_color("border_subtle")
	var border_focus := get_color("border_focus")

	var accent_col := get_color("accent_blue", get_color("accent"))
	var surface_col := get_color("surface")
	var surface_elevated_col := get_color("surface_elevated")

	var text_primary := get_color("text_given")
	var text_secondary := get_color("text_secondary", get_color("text_notes"))
	var text_user := get_color("text_user")
	var btn_text := get_color("button_text")
	var btn_text_disabled := get_color("button_text_disabled")

	var sb_empty := StyleBoxEmpty.new()

	# -------------------------------------------------------------------------
	# 1. Base Button Theme (Geometric Capsule, Hairline 1px border)
	# -------------------------------------------------------------------------
	var sb_btn_normal := create_flat_stylebox(bg_normal, RADIUS_CAPSULE, BORDER_HAIRLINE, border, 18, 9)
	var sb_btn_hover := create_flat_stylebox(bg_hover, RADIUS_CAPSULE, BORDER_HAIRLINE, border.lightened(0.12) if is_dark else border.darkened(0.08), 18, 9)
	var sb_btn_pressed := create_flat_stylebox(bg_pressed, RADIUS_CAPSULE, BORDER_HAIRLINE, border, 18, 9)
	var sb_btn_disabled := create_flat_stylebox(bg_disabled, RADIUS_CAPSULE, BORDER_HAIRLINE, border.darkened(0.2), 18, 9)

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
	theme.set_font_size("font_size", "Button", FONT_SIZE_BODY)

	# -------------------------------------------------------------------------
	# 2. Button Type Variations (Coherent Quiet Precision Capsule Language)
	# -------------------------------------------------------------------------
	var highlight_border := Color(1.0, 1.0, 1.0, 0.22 if is_dark else 0.40)

	# PrimaryButton (Prime reference: "Devam Et" filled accent capsule with subtle highlight & soft shadow)
	theme.set_type_variation("PrimaryButton", "Button")
	var sb_pri_norm := create_flat_stylebox(accent_col, RADIUS_CAPSULE, BORDER_HAIRLINE, highlight_border, 20, 10, get_shadow_color(0.14), 5, Vector2(0, 2))
	var sb_pri_hov := create_flat_stylebox(accent_col.lightened(0.08) if is_dark else accent_col.darkened(0.06), RADIUS_CAPSULE, BORDER_HAIRLINE, highlight_border.lightened(0.2), 20, 10, get_shadow_color(0.18), 7, Vector2(0, 2))
	var sb_pri_press := create_flat_stylebox(accent_col.darkened(0.1), RADIUS_CAPSULE, BORDER_HAIRLINE, highlight_border.darkened(0.1), 20, 10, get_shadow_color(0.08), 2, Vector2(0, 1))
	var sb_pri_dis := create_flat_stylebox(bg_disabled, RADIUS_CAPSULE, BORDER_NONE, Color.TRANSPARENT, 20, 10)

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
	theme.set_font_size("font_size", "PrimaryButton", FONT_SIZE_TITLE_SM)

	# SecondaryButton (Opaque elevated surface capsule: counterpart to PrimaryButton)
	theme.set_type_variation("SecondaryButton", "Button")
	var sec_border_hov := border.lightened(0.15) if is_dark else border.darkened(0.10)
	var sb_sec_norm := create_flat_stylebox(surface_elevated_col, RADIUS_CAPSULE, BORDER_HAIRLINE, border, 20, 10, get_shadow_color(0.08), 3, Vector2(0, 2))
	var sb_sec_hov := create_flat_stylebox(surface_elevated_col.lightened(0.06) if is_dark else surface_elevated_col.darkened(0.04), RADIUS_CAPSULE, BORDER_HAIRLINE, sec_border_hov, 20, 10, get_shadow_color(0.12), 5, Vector2(0, 2))
	var sb_sec_press := create_flat_stylebox(surface_elevated_col.darkened(0.06) if is_dark else surface_elevated_col.lightened(0.04), RADIUS_CAPSULE, BORDER_HAIRLINE, border, 20, 10, get_shadow_color(0.04), 1, Vector2(0, 1))
	var sb_sec_dis := create_flat_stylebox(bg_disabled, RADIUS_CAPSULE, BORDER_HAIRLINE, border.darkened(0.2), 20, 10)

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
	theme.set_font_size("font_size", "SecondaryButton", FONT_SIZE_TITLE_SM)

	# CompactSecondaryButton & CompactButton (Compact surface capsule for lists, daily and inline actions)
	theme.set_type_variation("CompactSecondaryButton", "Button")
	theme.set_type_variation("CompactButton", "Button")
	var sb_comp_sec_norm := create_flat_stylebox(surface_elevated_col, RADIUS_CAPSULE, BORDER_HAIRLINE, border, 16, 6, get_shadow_color(0.06), 2, Vector2(0, 1))
	var sb_comp_sec_hov := create_flat_stylebox(surface_elevated_col.lightened(0.06) if is_dark else surface_elevated_col.darkened(0.04), RADIUS_CAPSULE, BORDER_HAIRLINE, sec_border_hov, 16, 6, get_shadow_color(0.10), 3, Vector2(0, 1))
	var sb_comp_sec_press := create_flat_stylebox(surface_elevated_col.darkened(0.06) if is_dark else surface_elevated_col.lightened(0.04), RADIUS_CAPSULE, BORDER_HAIRLINE, border, 16, 6, get_shadow_color(0.03), 1, Vector2(0, 1))
	var sb_comp_sec_dis := create_flat_stylebox(bg_disabled, RADIUS_CAPSULE, BORDER_HAIRLINE, border.darkened(0.2), 16, 6)

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
		theme.set_font_size("font_size", c_sec, FONT_SIZE_BODY)

	# CompactPrimaryButton (Compact filled accent capsule for inline high-priority actions)
	theme.set_type_variation("CompactPrimaryButton", "Button")
	var sb_comp_pri_norm := create_flat_stylebox(accent_col, RADIUS_CAPSULE, BORDER_HAIRLINE, highlight_border, 16, 6, get_shadow_color(0.10), 3, Vector2(0, 1))
	var sb_comp_pri_hov := create_flat_stylebox(accent_col.lightened(0.08) if is_dark else accent_col.darkened(0.06), RADIUS_CAPSULE, BORDER_HAIRLINE, highlight_border.lightened(0.2), 16, 6, get_shadow_color(0.14), 4, Vector2(0, 1))
	var sb_comp_pri_press := create_flat_stylebox(accent_col.darkened(0.1), RADIUS_CAPSULE, BORDER_HAIRLINE, highlight_border.darkened(0.1), 16, 6, get_shadow_color(0.06), 1, Vector2(0, 1))
	var sb_comp_pri_dis := create_flat_stylebox(bg_disabled, RADIUS_CAPSULE, BORDER_NONE, Color.TRANSPARENT, 16, 6)

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
	theme.set_font_size("font_size", "CompactPrimaryButton", FONT_SIZE_BODY)

	# GhostButton (Border-less, transparent until interaction, smooth capsule hover/press)
	theme.set_type_variation("GhostButton", "Button")
	var sb_ghost_norm := create_flat_stylebox(Color.TRANSPARENT, RADIUS_CAPSULE, BORDER_NONE, Color.TRANSPARENT, 14, 8)
	var sb_ghost_hov := create_flat_stylebox(Color(bg_hover.r, bg_hover.g, bg_hover.b, 0.45), RADIUS_CAPSULE, BORDER_NONE, Color.TRANSPARENT, 14, 8)
	var sb_ghost_press := create_flat_stylebox(Color(bg_pressed.r, bg_pressed.g, bg_pressed.b, 0.65), RADIUS_CAPSULE, BORDER_NONE, Color.TRANSPARENT, 14, 8)
	var sb_ghost_dis := create_flat_stylebox(Color.TRANSPARENT, RADIUS_CAPSULE, BORDER_NONE, Color.TRANSPARENT, 14, 8)
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
	theme.set_font_size("font_size", "GhostButton", FONT_SIZE_BODY)

	# IconButton (Circular for square aspect, compact capsule for elongated aspect)
	theme.set_type_variation("IconButton", "Button")
	var sb_icon_norm := create_flat_stylebox(surface_elevated_col, RADIUS_CAPSULE, BORDER_HAIRLINE, border, 10, 10, get_shadow_color(0.06), 2, Vector2(0, 1))
	var sb_icon_hov := create_flat_stylebox(surface_elevated_col.lightened(0.08) if is_dark else surface_elevated_col.darkened(0.05), RADIUS_CAPSULE, BORDER_HAIRLINE, sec_border_hov, 10, 10, get_shadow_color(0.10), 3, Vector2(0, 1))
	var sb_icon_press := create_flat_stylebox(surface_elevated_col.darkened(0.08) if is_dark else surface_elevated_col.lightened(0.05), RADIUS_CAPSULE, BORDER_HAIRLINE, border, 10, 10, get_shadow_color(0.03), 1, Vector2(0, 1))
	var sb_icon_dis := create_flat_stylebox(bg_disabled, RADIUS_CAPSULE, BORDER_HAIRLINE, border.darkened(0.2), 10, 10)
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
	theme.set_font_size("font_size", "IconButton", FONT_SIZE_BODY)

	# ToolbarButton (In-game action bar controls: Undo, Redo, Notes, Hint)
	theme.set_type_variation("ToolbarButton", "Button")
	var sb_tb_norm := create_flat_stylebox(surface_elevated_col, RADIUS_CAPSULE, BORDER_HAIRLINE, border, 12, 6)
	var sb_tb_hov := create_flat_stylebox(bg_hover, RADIUS_CAPSULE, BORDER_HAIRLINE, border_focus, 12, 6)
	var sb_tb_press := create_flat_stylebox(bg_pressed, RADIUS_CAPSULE, BORDER_HAIRLINE, border_focus, 12, 6)
	var sb_tb_dis := create_flat_stylebox(bg_disabled, RADIUS_CAPSULE, BORDER_HAIRLINE, border.darkened(0.2), 12, 6)
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
	theme.set_font_size("font_size", "ToolbarButton", FONT_SIZE_BODY)

	# SegmentButton (Compact difficulty & tab segment controls)
	theme.set_type_variation("SegmentButton", "Button")
	var sb_seg_norm := create_flat_stylebox(surface_col, RADIUS_CAPSULE, BORDER_HAIRLINE, border, 10, 5)
	var sb_seg_hov := create_flat_stylebox(bg_hover, RADIUS_CAPSULE, BORDER_HAIRLINE, border, 10, 5)
	var sb_seg_press := create_flat_stylebox(accent_col, RADIUS_CAPSULE, BORDER_NONE, Color.TRANSPARENT, 10, 5)
	var sb_seg_dis := create_flat_stylebox(accent_col, RADIUS_CAPSULE, BORDER_NONE, Color.TRANSPARENT, 10, 5)
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
	theme.set_font_size("font_size", "SegmentButton", FONT_SIZE_SUBTITLE)

	for btn_var in ["PrimaryButton", "SecondaryButton", "CompactButton", "CompactPrimaryButton", "CompactSecondaryButton", "GhostButton", "IconButton", "ToolbarButton", "SegmentButton"]:
		if active_font != null:
			theme.set_font("font", btn_var, active_font)

	# -------------------------------------------------------------------------
	# 3. Label & Typography Variations (Swiss Editorial Scale)
	# -------------------------------------------------------------------------
	theme.set_color("font_color", "Label", text_primary)
	theme.set_font_size("font_size", "Label", FONT_SIZE_BODY)

	# Primary UI Variations (Inter variable TTF)
	# Display (28px, Hero / Title)
	for d_name in ["Display", "DisplayLabel"]:
		theme.set_type_variation(d_name, "Label")
		theme.set_color("font_color", d_name, text_primary)
		theme.set_font_size("font_size", d_name, FONT_SIZE_DISPLAY)
		if active_font != null:
			theme.set_font("font", d_name, active_font)

	# Header (20px, Screen / Modal Title)
	for h_name in ["Header", "HeaderLabel"]:
		theme.set_type_variation(h_name, "Label")
		theme.set_color("font_color", h_name, text_primary)
		theme.set_font_size("font_size", h_name, FONT_SIZE_HEADER)
		if active_font != null:
			theme.set_font("font", h_name, active_font)

	# Subtitle (13px, Section Headers & Indicators)
	for s_name in ["Subtitle", "SubtitleLabel"]:
		theme.set_type_variation(s_name, "Label")
		theme.set_color("font_color", s_name, text_secondary)
		theme.set_font_size("font_size", s_name, FONT_SIZE_SUBTITLE)
		if active_font != null:
			theme.set_font("font", s_name, active_font)

	# Body (14px, Standard primary text)
	for b_name in ["Body", "BodyLabel"]:
		theme.set_type_variation(b_name, "Label")
		theme.set_color("font_color", b_name, text_primary)
		theme.set_font_size("font_size", b_name, FONT_SIZE_BODY)
		if active_font != null:
			theme.set_font("font", b_name, active_font)

	# Caption (12px, Muted/notes text)
	for c_name in ["Caption", "CaptionLabel"]:
		theme.set_type_variation(c_name, "Label")
		theme.set_color("font_color", c_name, text_secondary)
		theme.set_font_size("font_size", c_name, FONT_SIZE_CAPTION)
		if active_font != null:
			theme.set_font("font", c_name, active_font)

	# StatValue (22px, Key numerical callouts)
	for st_name in ["StatValue", "StatValueLabel"]:
		theme.set_type_variation(st_name, "Label")
		theme.set_color("font_color", st_name, text_user)
		theme.set_font_size("font_size", st_name, FONT_SIZE_STAT)
		if active_font != null:
			theme.set_font("font", st_name, active_font)

	# Editorial / Brand Headings (Source Serif 4 Regular/Semibold - editorial excellence)
	var brand_font: Font = font_serif_semi if font_serif_semi != null else (font_serif_reg if font_serif_reg != null else active_font)
	theme.set_type_variation("BrandTitle", "Label")
	theme.set_color("font_color", "BrandTitle", text_primary)
	theme.set_font_size("font_size", "BrandTitle", FONT_SIZE_BRAND)
	if brand_font != null:
		theme.set_font("font", "BrandTitle", brand_font)

	theme.set_type_variation("BrandHeader", "Label")
	theme.set_color("font_color", "BrandHeader", text_primary)
	theme.set_font_size("font_size", "BrandHeader", 24)
	if brand_font != null:
		theme.set_font("font", "BrandHeader", brand_font)

	theme.set_type_variation("EditorialHeader", "Label")
	theme.set_color("font_color", "EditorialHeader", text_primary)
	theme.set_font_size("font_size", "EditorialHeader", FONT_SIZE_HEADER)
	if brand_font != null:
		theme.set_font("font", "EditorialHeader", brand_font)

	var editorial_reg_font: Font = font_serif_reg if font_serif_reg != null else brand_font
	for reg_name in ["EditorialRegular", "EditorialBody"]:
		theme.set_type_variation(reg_name, "Label")
		theme.set_color("font_color", reg_name, text_primary)
		theme.set_font_size("font_size", reg_name, 18)
		if editorial_reg_font != null:
			theme.set_font("font", reg_name, editorial_reg_font)

	# Technical Values (IBM Plex Mono Regular - reserved for technical values such as seed)
	var technical_font: Font = font_mono if font_mono != null else active_font
	for tech_name in ["MonoLabel", "TechnicalLabel", "SeedLabel", "TechnicalValue"]:
		theme.set_type_variation(tech_name, "Label")
		theme.set_color("font_color", tech_name, text_secondary)
		theme.set_font_size("font_size", tech_name, FONT_SIZE_BODY)
		if technical_font != null:
			theme.set_font("font", tech_name, technical_font)

	for tech_cap in ["MonoCaption", "SeedCaption", "TechnicalCaption"]:
		theme.set_type_variation(tech_cap, "Label")
		theme.set_color("font_color", tech_cap, text_secondary)
		theme.set_font_size("font_size", tech_cap, FONT_SIZE_CAPTION)
		if technical_font != null:
			theme.set_font("font", tech_cap, technical_font)

	for tech_stat in ["MonoStat", "TechnicalStat"]:
		theme.set_type_variation(tech_stat, "Label")
		theme.set_color("font_color", tech_stat, text_user)
		theme.set_font_size("font_size", tech_stat, FONT_SIZE_STAT)
		if technical_font != null:
			theme.set_font("font", tech_stat, technical_font)

	# -------------------------------------------------------------------------
	# 4. PanelContainer & Surface Variations (Clean Calm Surfaces, Hairline 1px)
	# -------------------------------------------------------------------------
	var sb_panel := create_flat_stylebox(surface_col, RADIUS_MD, BORDER_HAIRLINE, border, 12, 12, Color.TRANSPARENT, 0)
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
	var sb_modal := create_liquid_glass_stylebox(
		surface_elevated_col,
		RADIUS_XL,
		BORDER_HAIRLINE,
		glass_rim,
		18, 18,
		22, Vector2(0, 8), 0.32,
		0.88 if not (current_theme_name == THEME_AMOLED) else 0.95
	)
	theme.set_stylebox("panel", "ModalPanel", sb_modal)

	# SegmentedDock (Capsule outer container for segmented controls)
	var sb_seg_dock := create_flat_stylebox(surface_col, RADIUS_PILL_SM, BORDER_HAIRLINE, border, 3, 3, Color.TRANSPARENT, 0)
	for seg_name in ["SegmentedDock", "SegmentedControl"]:
		theme.set_type_variation(seg_name, "PanelContainer")
		theme.set_stylebox("panel", seg_name, sb_seg_dock)

	# -------------------------------------------------------------------------
	# 5. Form & Selection Controls
	# -------------------------------------------------------------------------
	# OptionButton (Unified capsule selector with chevron-down icon)
	var sb_option_normal := create_flat_stylebox(surface_elevated_col, RADIUS_CAPSULE, BORDER_HAIRLINE, border, 16, 8, get_shadow_color(0.06), 2, Vector2(0, 1))
	var sb_option_hover := create_flat_stylebox(surface_elevated_col.lightened(0.06) if is_dark else surface_elevated_col.darkened(0.04), RADIUS_CAPSULE, BORDER_HAIRLINE, border_focus, 16, 8, get_shadow_color(0.10), 4, Vector2(0, 2))
	var sb_option_pressed := create_flat_stylebox(bg_pressed, RADIUS_CAPSULE, BORDER_HAIRLINE, border_focus, 16, 8, get_shadow_color(0.03), 1, Vector2(0, 1))
	var sb_option_disabled := create_flat_stylebox(bg_disabled, RADIUS_CAPSULE, BORDER_HAIRLINE, border.darkened(0.2), 16, 8)

	theme.set_stylebox("normal", "OptionButton", sb_option_normal)
	theme.set_stylebox("hover", "OptionButton", sb_option_hover)
	theme.set_stylebox("pressed", "OptionButton", sb_option_pressed)
	theme.set_stylebox("disabled", "OptionButton", sb_option_disabled)
	theme.set_stylebox("focus", "OptionButton", sb_empty)
	theme.set_color("font_color", "OptionButton", text_primary)
	theme.set_color("font_hover_color", "OptionButton", text_primary)
	theme.set_color("font_pressed_color", "OptionButton", text_primary)
	theme.set_color("font_disabled_color", "OptionButton", btn_text_disabled)
	theme.set_font_size("font_size", "OptionButton", FONT_SIZE_BODY)
	theme.set_icon("arrow", "OptionButton", get_icon_sized("chevron-down", 16))
	theme.set_constant("arrow_margin", "OptionButton", 10)

	# PopupMenu (Elevated floating surface with hairline borders and refined item states)
	var sb_popup_panel := create_flat_stylebox(
		surface_elevated_col,
		RADIUS_MD,
		BORDER_HAIRLINE,
		border,
		PAD_SM,
		PAD_SM,
		get_shadow_color(0.20),
		14,
		Vector2(0, 4)
	)
	var sb_popup_hover := create_flat_stylebox(
		bg_hover,
		RADIUS_SM,
		0,
		Color.TRANSPARENT,
		PAD_MD,
		PAD_SM
	)
	var sb_popup_sep := create_flat_stylebox(border, 0, 0, Color.TRANSPARENT, 0, 1)

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
	theme.set_font_size("font_size", "PopupMenu", FONT_SIZE_BODY)

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
	theme.set_font_size("font_size", "CheckBox", FONT_SIZE_BODY)

	# HSeparator (1px hairline subtle line)
	var sb_sep := create_flat_stylebox(border, 0, 0, Color.TRANSPARENT, 0, 1)
	theme.set_stylebox("separator", "HSeparator", sb_sep)

	# LineEdit & TextEdit
	var sb_edit := create_flat_stylebox(surface_elevated_col, RADIUS_SM, BORDER_HAIRLINE, border, 10, 8)
	theme.set_stylebox("normal", "LineEdit", sb_edit)
	theme.set_stylebox("normal", "TextEdit", sb_edit)
	theme.set_color("font_color", "LineEdit", text_primary)
	theme.set_color("font_color", "TextEdit", text_primary)
	theme.set_font_size("font_size", "LineEdit", FONT_SIZE_BODY)
	theme.set_font_size("font_size", "TextEdit", FONT_SIZE_BODY)

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
	var sb_d := create_flat_stylebox(dis_fill, radius, BORDER_HAIRLINE, get_color("border_subtle").darkened(0.2), 0, 0)

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
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		var data: Dictionary = {
			"theme": current_theme_name,
			"palette": {}
		}
		for k in current_palette.keys():
			data["palette"][k] = current_palette[k].to_html()
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

static func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		set_theme(detect_system_theme())
		return

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		set_theme(detect_system_theme())
		return
	var content: String = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(content) == OK and json.data is Dictionary:
		var t_name: String = json.data.get("theme", "")
		if t_name.is_empty() or t_name == "Auto" or t_name == "System":
			set_theme(detect_system_theme())
			return
		if json.data.has("palette") and t_name == THEME_CUSTOM:
			current_theme_name = THEME_CUSTOM
			for k in json.data["palette"].keys():
				current_palette[k] = Color(json.data["palette"][k])
			_sync_clear_color()
			_notify_listeners()
		elif PALETTES.has(t_name):
			set_theme(t_name)
		else:
			set_theme(detect_system_theme())
	else:
		set_theme(detect_system_theme())

class_name FontManager
extends Node

## Typography and Font Family Manager (GDD §39, §43)
## Manages embedded font families with SystemFont fallbacks and dynamic hot-swapping.

const FONT_MODERN_SANS: String = "Modern Sans"
const FONT_ROUNDED_SANS: String = "Rounded Sans"
const FONT_CLASSIC_SERIF: String = "Classic Serif"

const FONT_FAMILIES: Array[String] = [
	FONT_MODERN_SANS,
	FONT_ROUNDED_SANS,
	FONT_CLASSIC_SERIF
]

static var current_font_name: String = FONT_MODERN_SANS
static var _font_cache: Dictionary = {}
static var _listeners: Array[Callable] = []

static func _static_init() -> void:
	_init_font_cache()

static func _init_font_cache() -> void:
	# 1. Modern Sans (Default: Clean geometric sans-serif)
	var modern := SystemFont.new()
	modern.font_names = PackedStringArray([
		"Segoe UI", "Inter", "Roboto", "SF Pro Display", "Helvetica Neue", "Cantarell", "Noto Sans", "sans-serif"
	])
	modern.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	modern.oversampling = 2.0
	_font_cache[FONT_MODERN_SANS] = modern

	# 2. Rounded Sans (Soft & friendly game-focused sans-serif)
	var rounded := SystemFont.new()
	rounded.font_names = PackedStringArray([
		"Comfortaa", "Nunito", "Quicksand", "Arial Rounded MT Bold", "Varela Round", "Segoe UI", "sans-serif"
	])
	rounded.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	rounded.oversampling = 2.0
	_font_cache[FONT_ROUNDED_SANS] = rounded

	# 3. Classic Serif (Traditional / Premium newspaper & book style)
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray([
		"Georgia", "Times New Roman", "Merriweather", "Noto Serif", "Palatino", "serif"
	])
	serif.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	serif.oversampling = 2.0
	_font_cache[FONT_CLASSIC_SERIF] = serif

static func add_listener(cb: Callable) -> void:
	if not _listeners.has(cb):
		_listeners.append(cb)

static func remove_listener(cb: Callable) -> void:
	_listeners.erase(cb)

static func _notify_listeners() -> void:
	for cb in _listeners:
		if cb.is_valid():
			cb.call()

static func get_font(family_name: String) -> Font:
	if _font_cache.has(family_name):
		return _font_cache[family_name]
	if _font_cache.has(FONT_MODERN_SANS):
		return _font_cache[FONT_MODERN_SANS]
	# Fallback if cache not initialized yet
	_init_font_cache()
	return _font_cache.get(FONT_MODERN_SANS, null)

static func get_current_font() -> Font:
	return get_font(current_font_name)

static func set_font(family_name: String) -> bool:
	if not FONT_FAMILIES.has(family_name):
		return false
	if current_font_name == family_name:
		return true

	current_font_name = family_name
	_notify_listeners()
	return true

static func get_family_display_name(family_name: String) -> String:
	match family_name:
		FONT_MODERN_SANS: return "Modern Sans"
		FONT_ROUNDED_SANS: return "Rounded Sans"
		FONT_CLASSIC_SERIF: return "Classic Serif"
		_: return family_name

static func get_bundled_inter() -> Font:
	return ThemeManager.get_font_inter()

static func get_bundled_serif_regular() -> Font:
	return ThemeManager.get_font_serif_regular()

static func get_bundled_serif_semibold() -> Font:
	return ThemeManager.get_font_serif_semibold()

static func get_bundled_mono() -> Font:
	return ThemeManager.get_font_mono()


class_name ResponsiveManager
extends RefCounted

## Centralized UI Scaling & Layout System (Responsive Architecture)
## Provides a single source of truth for:
## - Base design resolution (portrait mobile: 390x844)
## - Viewport scaling & device categorization (compact phone, phone, tablet, desktop)
## - Mobile safe areas & notch insets (DisplayServer integration)
## - Semantic tokens: spacing, control heights, touch targets (>=44px), fonts, icons, radii
## - Standardized layout methods for screens, game board, menus, and modals
## Eliminates duplicated per-screen responsive logic.

# =============================================================================
# 1. BASE DESIGN RESOLUTION & BREAKPOINTS
# =============================================================================
const BASE_WIDTH: float = 390.0
const BASE_HEIGHT: float = 844.0

enum DeviceCategory {
	COMPACT_PHONE, # width < 380 or height < 700 (e.g., 360x640, iPhone SE)
	PHONE,         # 380 <= width < 600 and portrait (e.g., 390x844, 412x915, 430x932)
	TABLET,        # 600 <= width < 1000 in portrait, or aspect ratio < 1.45
	DESKTOP        # width >= 1000 or landscape aspect ratio >= 1.15
}

# =============================================================================
# 2. SEMANTIC DESIGN TOKENS
# =============================================================================
# Spacing Tokens (Geometric 4px rhythm)
const SPACE_2XS: int = 2
const SPACE_XS: int = 4
const SPACE_SM: int = 8
const SPACE_MD: int = 12
const SPACE_LG: int = 16
const SPACE_XL: int = 24
const SPACE_2XL: int = 32

# Mobile Touch Target Floor (GDD §38, §44)
const TOUCH_TARGET_MIN: float = 44.0

# Control Heights
const HEIGHT_BUTTON_HERO: float = 52.0
const HEIGHT_BUTTON_PRIMARY: float = 48.0
const HEIGHT_BUTTON_SECONDARY: float = 44.0
const HEIGHT_BUTTON_COMPACT: float = 36.0
const HEIGHT_ROW_SETTING: float = 48.0
const HEIGHT_ACTION_DOCK: float = 52.0
const HEIGHT_INPUT: float = 44.0
const HEIGHT_SEGMENT: float = 44.0

# Typography Tokens
const FONT_SIZE_HERO: int = 40
const FONT_SIZE_DISPLAY: int = 28
const FONT_SIZE_STAT: int = 22
const FONT_SIZE_HEADER: int = 20
const FONT_SIZE_TITLE: int = 18
const FONT_SIZE_TITLE_SM: int = 16
const FONT_SIZE_BODY: int = 14
const FONT_SIZE_SUBTITLE: int = 13
const FONT_SIZE_CAPTION: int = 12
const FONT_SIZE_MICRO: int = 10

# Icon Sizes
const ICON_SIZE_SM: int = 14
const ICON_SIZE_MD: int = 16
const ICON_SIZE_LG: int = 20
const ICON_SIZE_XL: int = 24

# Corner Radiuses
const RADIUS_NONE: int = 0
const RADIUS_XS: int = 3
const RADIUS_SM: int = 4
const RADIUS_MD: int = 6
const RADIUS_LG: int = 8
const RADIUS_XL: int = 12
const RADIUS_PILL_SM: int = 18
const RADIUS_PILL: int = 22

# Standard Content Width Limits
const MAX_CONTENT_WIDTH: float = 480.0
const MAX_MENU_WIDTH: float = 380.0
const MAX_BOARD_WIDTH: float = 520.0
const MAX_BOARD_WIDTH_LANDSCAPE: float = 720.0
const LANDSCAPE_SIDE_PANEL_W: float = 340.0
const LANDSCAPE_GAP: float = 32.0
const MAX_MODAL_WIDTH: float = 380.0

# =============================================================================
# 3. VIEWPORT, SCALE FACTOR & DEVICE CATEGORY
# =============================================================================
## Device pixels per dp on phones and tablets (Android density bucket, iOS point scale);
## 0 on desktop, which keeps the project's base size and is used with a mouse
static func screen_density() -> float:
	if OS.has_feature("android"):
		return maxf(1.0, DisplayServer.screen_get_dpi() / 160.0)
	if OS.has_feature("ios"):
		return maxf(1.0, DisplayServer.screen_get_scale())
	return 0.0

## Lays the UI out in dp: 1 logical px = 1 dp on every phone and tablet, so a 44 px control
## is a 44 dp touch target whatever the screen's shape. A fixed base size cannot do this: the
## stretch scale comes from the tighter of width and height, so a 16:9 phone shrank the UI to
## about 0.75 dp per px and a tablet blew it up to 2 dp per px.
static func apply_device_scaling(window: Window, density: float = screen_density()) -> void:
	if window == null or density <= 0.0:
		return
	window.set_meta(&"dp_density", density)
	_fit_to_density(window)
	# One listener per window (rotation, split screen); it reads the density stored above
	if not window.has_meta(&"dp_listening"):
		window.set_meta(&"dp_listening", true)
		window.size_changed.connect(_fit_to_density.bind(window))

static func _fit_to_density(window: Window) -> void:
	var density: float = window.get_meta(&"dp_density", 0.0)
	var px: Vector2i = window.size
	if density <= 0.0 or px.x <= 0 or px.y <= 0:
		return
	var logical := Vector2i(roundi(px.x / density), roundi(px.y / density))
	# Setting it re-emits size_changed, so only when it changes
	if window.content_scale_size != logical:
		window.content_scale_size = logical

## Resolves the actual viewport size from a control or root window
static func get_viewport_size(node: Control = null) -> Vector2:
	if node != null:
		if node.size.x > 0.0 and node.size.y > 0.0:
			return node.size
		if node.is_inside_tree() and node.get_viewport() != null:
			var vp_rect := node.get_viewport_rect()
			if vp_rect.size.x > 0.0 and vp_rect.size.y > 0.0:
				return vp_rect.size
	return Vector2(BASE_WIDTH, BASE_HEIGHT)

## Determines the device category from viewport dimensions
static func get_device_category(viewport_size: Vector2) -> DeviceCategory:
	var w: float = viewport_size.x
	var h: float = viewport_size.y
	if w <= 0.0 or h <= 0.0:
		return DeviceCategory.PHONE

	var aspect: float = w / h
	# Landscape or large screen -> Desktop
	if aspect >= 1.15 or w >= 1000.0:
		return DeviceCategory.DESKTOP
	# Tablet portrait
	if w >= 600.0 or (aspect >= 0.70 and h >= 800.0):
		return DeviceCategory.TABLET
	# Compact phone
	if w < 380.0 or h < 700.0:
		return DeviceCategory.COMPACT_PHONE
	# Standard Phone
	return DeviceCategory.PHONE

## True when the game screen should put the board and the controls side by side
static func is_game_landscape(viewport_size: Vector2) -> bool:
	return viewport_size.x > 0.0 and viewport_size.y > 0.0 and viewport_size.x / viewport_size.y >= 1.15

## Computes a smooth clamped scaling factor relative to BASE_WIDTH (390px)
static func get_scale_factor(viewport_size: Vector2) -> float:
	var w: float = viewport_size.x
	if w <= 0.0:
		return 1.0

	var cat := get_device_category(viewport_size)
	match cat:
		DeviceCategory.COMPACT_PHONE:
			return clampf(w / BASE_WIDTH, 0.88, 1.0)
		DeviceCategory.PHONE:
			return clampf(w / BASE_WIDTH, 0.95, 1.12)
		DeviceCategory.TABLET:
			return 1.05
		DeviceCategory.DESKTOP:
			return 1.0
	return 1.0

# =============================================================================
# 4. MOBILE SAFE AREA & NOTCH INSETS
# =============================================================================
## Returns safe area insets {top, bottom, left, right} in logical pixels.
## Automatically detects hardware notch / home indicator via DisplayServer,
## or provides sensible design defaults.
static func get_safe_area_insets(node: Control = null) -> Dictionary:
	var insets := {
		"top": 16,
		"bottom": 16,
		"left": 0,
		"right": 0
	}

	# Check OS / DisplayServer safe area
	var safe_rect: Rect2i = DisplayServer.get_display_safe_area()
	var window_size: Vector2i = DisplayServer.window_get_size()

	if window_size.x > 0 and window_size.y > 0 and safe_rect.size.x > 0 and safe_rect.size.y > 0:
		var vp_size := get_viewport_size(node)
		var scale_x: float = vp_size.x / float(window_size.x)
		var scale_y: float = vp_size.y / float(window_size.y)

		var top_inset: int = int(float(safe_rect.position.y) * scale_y)
		var bottom_inset: int = int(float(window_size.y - (safe_rect.position.y + safe_rect.size.y)) * scale_y)
		var left_inset: int = int(float(safe_rect.position.x) * scale_x)
		var right_inset: int = int(float(window_size.x - (safe_rect.position.x + safe_rect.size.x)) * scale_x)

		insets["top"] = maxi(16, top_inset)
		insets["bottom"] = maxi(16, bottom_inset)
		insets["left"] = maxi(0, left_inset)
		insets["right"] = maxi(0, right_inset)

	return insets

# =============================================================================
# 5. SEMANTIC TOKEN SCALING HELPERS
# =============================================================================
static func get_scaled_space(base_space: int, viewport_size: Vector2) -> int:
	var s := get_scale_factor(viewport_size)
	return maxi(2, int(round(float(base_space) * s)))

static func get_scaled_font_size(base_size: int, viewport_size: Vector2) -> int:
	var s := get_scale_factor(viewport_size)
	return maxi(10, int(round(float(base_size) * s)))

static func get_scaled_control_height(base_height: float, viewport_size: Vector2) -> float:
	var cat := get_device_category(viewport_size)
	if cat == DeviceCategory.COMPACT_PHONE:
		return maxf(TOUCH_TARGET_MIN, base_height * 0.92)
	return maxf(TOUCH_TARGET_MIN, base_height)

# =============================================================================
# 6. CENTRALIZED SCREEN LAYOUT LOGIC
# =============================================================================

## Standard content margin calculator for secondary screens
## (Settings, History, Statistics, LoadGame).
## Handles horizontal centering on wide viewports (tablet/desktop) and safe insets on mobile.
## Keeps the title of a [left buttons][title][right buttons] header on the screen's centre line.
## The sides are rarely equally wide (a back button against a timer or an "Import" button, and
## the widths change with the language), so a spacer pads the narrower side to match - but only
## as far as the header has room left after the title's text, so a narrow screen never overflows.
static func balance_header(header: HBoxContainer, title: Control) -> void:
	var labels: Array[Label] = []
	if title is Label:
		labels.append(title)
	for c in title.get_children():
		if c is Label:
			labels.append(c)
	# The title's text is measured below, so its own minimum width must not widen the row
	for l in labels:
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var left_pad := Control.new()
	left_pad.name = "BalanceLeft"
	left_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var right_pad := Control.new()
	right_pad.name = "BalanceRight"
	right_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(left_pad)
	header.move_child(left_pad, title.get_index())
	header.add_child(right_pad)
	header.move_child(right_pad, title.get_index() + 1)
	var rebalance := func() -> void:
		var left := 0.0
		var right := 0.0
		var count := 0
		for c in header.get_children():
			if not (c is Control) or not c.visible:
				continue
			count += 1
			if c == left_pad or c == right_pad or c == title:
				continue
			if c.get_index() < title.get_index():
				left += c.get_combined_minimum_size().x
			else:
				right += c.get_combined_minimum_size().x
		var text_w := 0.0
		for l in labels:
			var font := l.get_theme_font("font")
			var margins: float = l.get_theme_stylebox("normal").get_minimum_size().x
			text_w = maxf(text_w, font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				l.get_theme_font_size("font_size")).x + margins)
		var room: float = header.size.x - left - right - text_w \
			- header.get_theme_constant("separation") * maxf(0.0, count - 1)
		var pad: float = clampf(absf(right - left), 0.0, maxf(0.0, room))
		# Setting the same value again does not re-sort, so this settles after one pass
		left_pad.custom_minimum_size.x = pad if right > left else 0.0
		right_pad.custom_minimum_size.x = pad if left > right else 0.0
	header.sort_children.connect(rebalance)
	header.resized.connect(rebalance)
	rebalance.call()

static func apply_content_margins(
	screen: Control,
	margin_container: MarginContainer,
	max_content_w: float = MAX_CONTENT_WIDTH
) -> void:
	if screen == null or margin_container == null:
		return
	var vp_size := get_viewport_size(screen)
	var w: float = vp_size.x
	var h: float = vp_size.y
	if w <= 0.0 or h <= 0.0:
		return

	var safe := get_safe_area_insets(screen)
	var cat := get_device_category(vp_size)

	# Responsive horizontal margin
	var side_margin: int = 16
	if cat == DeviceCategory.COMPACT_PHONE:
		side_margin = 14
	elif cat == DeviceCategory.PHONE:
		side_margin = 20

	# On tablet or desktop, clamp content column width and center horizontally
	if w > (max_content_w + 32.0):
		side_margin = int((w - max_content_w) * 0.5)

	var top_margin: int = maxi(safe.top, 20)
	var bottom_margin: int = maxi(safe.bottom, 20)

	margin_container.add_theme_constant_override("margin_left", side_margin + safe.left)
	margin_container.add_theme_constant_override("margin_right", side_margin + safe.right)
	margin_container.add_theme_constant_override("margin_top", top_margin)
	margin_container.add_theme_constant_override("margin_bottom", bottom_margin)

## Centralized layout logic for Main Menu (Home Screen)
static func apply_menu_layout(
	screen: Control,
	margin_container: MarginContainer,
	top_spacer: Control,
	mid_spacer: Control,
	bottom_spacer: Control,
	max_menu_w: float = MAX_MENU_WIDTH
) -> void:
	if screen == null or margin_container == null:
		return
	var vp_size := get_viewport_size(screen)
	var w: float = vp_size.x
	var h: float = vp_size.y
	if w <= 0.0 or h <= 0.0:
		return

	var safe := get_safe_area_insets(screen)
	var cat := get_device_category(vp_size)

	var target_w: float = max_menu_w
	if cat == DeviceCategory.COMPACT_PHONE:
		target_w = minf(340.0, w - 24.0)
	elif cat == DeviceCategory.DESKTOP:
		var is_landscape: bool = (w > h * 1.15) and (h <= 720.0)
		if is_landscape:
			target_w = minf(380.0, maxf(300.0, h - 80.0))

	var side_margin: int = 24
	if w > (target_w + 48.0):
		side_margin = int((w - target_w) * 0.5)

	var top_margin: int = maxi(safe.top, 24)
	var bottom_margin: int = maxi(safe.bottom, 20)

	margin_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin_container.offset_left = 0
	margin_container.offset_right = 0
	margin_container.offset_top = 0
	margin_container.offset_bottom = 0

	margin_container.add_theme_constant_override("margin_left", side_margin + safe.left)
	margin_container.add_theme_constant_override("margin_right", side_margin + safe.right)
	margin_container.add_theme_constant_override("margin_top", top_margin)
	margin_container.add_theme_constant_override("margin_bottom", bottom_margin)

	# Balanced vertical spacers for ergonomic mobile reach (actions in thumb zone)
	var content_h: float = 390.0
	var extra_h: float = maxf(0.0, h - content_h - top_margin - bottom_margin)

	if top_spacer != null:
		# Masthead stays comfortably in upper area
		top_spacer.custom_minimum_size.y = clampf(extra_h * 0.12, 12.0, 32.0)
	if mid_spacer != null:
		# Only a small gap: the resume card above the actions expands to take the free height
		mid_spacer.custom_minimum_size.y = clampf(extra_h * 0.05, 12.0, 24.0)
	if bottom_spacer != null:
		# Controlled separation before baseline utility nav
		bottom_spacer.custom_minimum_size.y = clampf(extra_h * 0.20, 14.0, 36.0)

## Centralized layout logic for Game Screen
## Guarantees strictly square 1:1 Sudoku board, responsive numpad & action dock,
## safe areas, and zero clipping across compact phones to desktop.
static func apply_game_layout(
	screen: Control,
	margin_container: MarginContainer,
	grid_container: Control,
	top_spacer: Control,
	mid_spacer: Control,
	numpad_spacer: Control,
	bottom_spacer: Control,
	numpad: Control = null,
	max_board_w: float = MAX_BOARD_WIDTH
) -> void:
	if screen == null or margin_container == null:
		return
	var vp_size := get_viewport_size(screen)
	var w: float = vp_size.x
	var h: float = vp_size.y
	if w <= 0.0 or h <= 0.0:
		return

	var safe := get_safe_area_insets(screen)
	var cat := get_device_category(vp_size)

	if is_game_landscape(vp_size):
		_apply_game_layout_landscape(vp_size, safe, margin_container, grid_container, [top_spacer, mid_spacer, numpad_spacer, bottom_spacer], numpad)
		return

	# Clamps board width on desktop/tablet
	var max_w: float = max_board_w
	if cat == DeviceCategory.DESKTOP and (w > h * 1.15) and (h <= 720.0):
		max_w = minf(max_board_w, maxf(280.0, h - 120.0))

	var side_margin: int = 16
	if cat == DeviceCategory.COMPACT_PHONE:
		side_margin = 12
	if w > (max_w + 32.0):
		side_margin = int((w - max_w) * 0.5)

	var top_margin: int = maxi(safe.top, 14)
	var bottom_margin: int = maxi(safe.bottom, 16)

	margin_container.add_theme_constant_override("margin_left", side_margin + safe.left)
	margin_container.add_theme_constant_override("margin_right", side_margin + safe.right)
	margin_container.add_theme_constant_override("margin_top", top_margin)
	margin_container.add_theme_constant_override("margin_bottom", bottom_margin)

	var is_compact: bool = (cat == DeviceCategory.COMPACT_PHONE) or (h < 720.0)
	var numpad_h: float = 242.0
	if is_compact:
		numpad_h = 198.0
	if numpad != null and numpad.has_method("set_compact_mode"):
		numpad.set_compact_mode(is_compact)
		# The pad's real height (keys, gaps and frame), so the board never pushes the bottom off screen
		numpad_h = maxf(numpad_h, numpad.get_combined_minimum_size().y)

	var header_h: float = 44.0
	var non_grid_h: float = header_h + HEIGHT_ACTION_DOCK + numpad_h + 36.0 + float(top_margin + bottom_margin)

	var avail_w: float = maxf(100.0, w - float(side_margin * 2 + safe.left + safe.right))
	var avail_h: float = maxf(100.0, h - non_grid_h)

	# 1:1 strictly square board size
	var target_grid_size: float = minf(avail_w, minf(avail_h, max_w))

	if grid_container != null:
		grid_container.custom_minimum_size = Vector2(target_grid_size, target_grid_size)

	# Distribute extra height proportionally
	var extra_h: float = maxf(0.0, h - target_grid_size - non_grid_h)
	if top_spacer != null:
		top_spacer.custom_minimum_size.y = 8.0 + extra_h * 0.20
	if mid_spacer != null:
		mid_spacer.custom_minimum_size.y = 10.0 + extra_h * 0.25
	if numpad_spacer != null:
		numpad_spacer.custom_minimum_size.y = 8.0 + extra_h * 0.25
	if bottom_spacer != null:
		bottom_spacer.custom_minimum_size.y = 10.0 + extra_h * 0.30

## Landscape: board on the left (height-bound), dock + numpad in a side panel on the right
static func _apply_game_layout_landscape(
	vp_size: Vector2,
	safe: Dictionary,
	margin_container: MarginContainer,
	grid_container: Control,
	spacers: Array,
	numpad: Control
) -> void:
	var w: float = vp_size.x
	var h: float = vp_size.y
	var top_margin: int = maxi(safe.top, 14)
	var bottom_margin: int = maxi(safe.bottom, 16)
	var header_h: float = 44.0
	var edge: float = 24.0

	var avail_h: float = maxf(100.0, h - header_h - 16.0 - float(top_margin + bottom_margin))
	var avail_w: float = maxf(100.0, w - edge * 2.0 - float(safe.left + safe.right) - LANDSCAPE_SIDE_PANEL_W - LANDSCAPE_GAP)
	var grid_size: float = minf(MAX_BOARD_WIDTH_LANDSCAPE, minf(avail_h, avail_w))

	var body_w: float = grid_size + LANDSCAPE_GAP + LANDSCAPE_SIDE_PANEL_W
	var side_margin: int = maxi(int(edge), int((w - body_w) * 0.5))

	margin_container.add_theme_constant_override("margin_left", side_margin + safe.left)
	margin_container.add_theme_constant_override("margin_right", side_margin + safe.right)
	margin_container.add_theme_constant_override("margin_top", top_margin)
	margin_container.add_theme_constant_override("margin_bottom", bottom_margin)

	# Side panel holds: dock (46) + numpad + gaps, so tight heights need the compact numpad
	var is_compact: bool = grid_size < 420.0
	if numpad != null and numpad.has_method("set_compact_mode"):
		numpad.set_compact_mode(is_compact)

	if grid_container != null:
		grid_container.custom_minimum_size = Vector2(grid_size, grid_size)
	for sp in spacers:
		if sp != null:
			sp.custom_minimum_size.y = 0.0

## Centralized layout logic for AppModal dialogs
static func apply_modal_layout(
	modal: Control,
	modal_panel: Control,
	modal_vbox: Control,
	max_modal_w: float = MAX_MODAL_WIDTH
) -> void:
	if modal == null or modal_panel == null:
		return
	var vp_size := get_viewport_size(modal)
	var w: float = vp_size.x
	var h: float = vp_size.y
	if w <= 0.0 or h <= 0.0:
		return

	var target_w: float = minf(max_modal_w, w - 32.0)
	modal_panel.custom_minimum_size.x = target_w

	if modal_vbox != null:
		if h <= 560.0:
			modal_vbox.add_theme_constant_override("separation", 8)
		else:
			modal_vbox.add_theme_constant_override("separation", 14)

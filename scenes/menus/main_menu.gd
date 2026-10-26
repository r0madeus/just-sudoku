class_name MainMenu
extends Control

const LocalizationManager = preload("res://scripts/services/localization_manager.gd")
const ThemeManager = preload("res://scripts/services/theme_manager.gd")
const SaveManager = preload("res://scripts/data/save_manager.gd")
const DailyManager = preload("res://scripts/data/daily_manager.gd")
const ResponsiveManager = preload("res://scripts/services/responsive_manager.gd")

## Main Menu Screen (GDD §5, §44)
## Swiss Editorial × Restrained Liquid Glass Home Composition.
## Distinct editorial masthead, deliberate typographic hierarchy, restrained hero & daily actions,
## and quiet baseline utility navigation.

signal continue_pressed()
## The resume card was tapped: the game opens from the card, its board growing into the game's
signal resume_card_pressed()
signal new_game_requested()
signal load_game_requested()
signal daily_sudoku_requested()
## The calendar of past Dailies
signal daily_archive_requested()
signal history_requested()
signal statistics_requested()
signal settings_requested()
signal techniques_requested()

const AmbientBackdrop = preload("res://scenes/ui/ambient_backdrop.gd")
const GlassPanel = preload("res://scenes/ui/glass_panel.gd")
const SHADOW_PAD: int = 22
const ResumeCard = preload("res://scenes/menus/resume_card.gd")

var bg: ColorRect
var margin_container: MarginContainer
var root_vbox: VBoxContainer
var top_spacer: Control
var mid_spacer: Control
var bottom_spacer: Control

# 1. Masthead
var header_vbox: VBoxContainer
var title_label: Label
## The full stop after the name: a rounded square, the lit cell of the app icon
var wordmark_dot: Panel
var wordmark_dot_holder: MarginContainer

# 2. Hero & Puzzle Actions
var resume_holder: VBoxContainer
var resume_card: ResumeCard
var actions_vbox: VBoxContainer
var hero_vbox: VBoxContainer
var continue_btn: Button
## The play icon at the left edge of the Continue button
var continue_icon: TextureRect
var continue_meta_label: Label
var new_game_btn: Button

# 3. Daily Sudoku Strip (Distinct & Restrained)
var daily_panel: PanelContainer
## Calendar icon at the start of the Daily strip; opens the archive
var daily_archive_btn: Button
var daily_title_label: Label
var daily_meta_label: Label
var daily_btn: Button

# 4. Saved Games Link
var load_game_btn: Button

# 5. Baseline Utility Navigation
var nav_section_vbox: VBoxContainer
var nav_separator: HSeparator
var nav_glass: GlassPanel
## The navigation buttons: one row, or two rows of two where one row cannot fit them
var nav_grid: GridContainer
var history_btn: Button
var stats_btn: Button
var techniques_btn: Button
var settings_btn: Button

# Backwards compatibility reference
var menu_card_panel: Control

## Wide landscape screens (a tablet turned sideways, a large window): the resume card on the left,
## the actions and navigation on the right, under the masthead
var wide_row: HBoxContainer
var wide_right: VBoxContainer
var is_wide: bool = false

func _init() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_build_ui()
	_update_locale_texts()
	LocalizationManager.add_listener(_update_locale_texts)
	ThemeManager.add_listener(_on_theme_changed)

func _exit_tree() -> void:
	LocalizationManager.remove_listener(_update_locale_texts)
	ThemeManager.remove_listener(_on_theme_changed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_responsive_layout()
	elif what == NOTIFICATION_THEME_CHANGED:
		# The font and its size arrive with the theme (a new text size is one), after _ready; the
		# label has them only once the notification has reached it, after this one
		_fit_wordmark_dot.call_deferred()

func _ready() -> void:
	_apply_responsive_layout()
	refresh_buttons()

func _apply_responsive_layout() -> void:
	if margin_container == null:
		return
	var vp_size := ResponsiveManager.get_viewport_size(self)
	_set_wide(ResponsiveManager.content_columns(vp_size) == 2 and ResponsiveManager.is_game_landscape(vp_size))
	ResponsiveManager.apply_menu_layout(
		self,
		margin_container,
		top_spacer,
		mid_spacer,
		bottom_spacer,
		ResponsiveManager.MAX_MENU_WIDTH,
		is_wide
	)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin_container.add_theme_constant_override(side, maxi(0, margin_container.get_theme_constant(side) - SHADOW_PAD))
	var vp := ResponsiveManager.get_viewport_size(self)
	if resume_card != null:
		resume_card.set_compact(vp.y < 720.0)
	_fit_nav_buttons()

func _nav_buttons() -> Array[Button]:
	return [history_btn, stats_btn, techniques_btn, settings_btn]

## Fits the four navigation buttons on the screen, whatever the language, text size and screen:
## the roomiest look that fits wins, from icons beside the labels down to labels with less padding
## in a smaller size, and at last two rows of two. Measured from the buttons themselves, as the
## labels differ per language.
func _fit_nav_buttons() -> void:
	if history_btn == null or not is_inside_tree():
		return
	var room: float = ResponsiveManager.get_viewport_size(self).x - 2.0 * SHADOW_PAD
	if margin_container != null:
		room -= margin_container.get_theme_constant("margin_left") + margin_container.get_theme_constant("margin_right")
	room -= nav_glass.get_combined_minimum_size().x - nav_grid.get_combined_minimum_size().x
	var looks: Array[Dictionary] = [
		{"icons": true, "pad": -1, "font": 13.0, "gap": 8, "columns": 4},
		{"icons": false, "pad": -1, "font": 13.0, "gap": 8, "columns": 4},
		{"icons": false, "pad": 6, "font": 13.0, "gap": 4, "columns": 4},
		{"icons": false, "pad": 6, "font": 12.0, "gap": 4, "columns": 4},
		{"icons": false, "pad": -1, "font": 13.0, "gap": 8, "columns": 2},
	]
	# A side-by-side layout has the room, and a wide window must not change the phone look
	var last: int = 0 if is_wide else looks.size() - 1
	for i in range(looks.size()):
		_set_nav_look(looks[i])
		if i >= last or nav_grid.get_combined_minimum_size().x <= room:
			break
	# The looks above were tried within one frame, so the grid's minimum size ends up as it was
	# before and Godot sees no change: nothing sorts it again, and it stayed as wide as a look
	# that did not fit, running off the right edge. Sort it and what holds it now.
	nav_grid.queue_sort()
	nav_glass.queue_sort()

func _set_nav_look(look: Dictionary) -> void:
	var icon_names := ["rotate-ccw", "chart-column-big", "lightbulb", "settings"]
	nav_grid.columns = look["columns"]
	nav_grid.add_theme_constant_override("h_separation", look["gap"])
	var buttons := _nav_buttons()
	for i in range(buttons.size()):
		var btn: Button = buttons[i]
		btn.icon = ThemeManager.get_icon(icon_names[i]) if look["icons"] else null
		ThemeManager.set_font_size(btn, look["font"])
		# The theme's styleboxes, with less padding at the sides when the row is short of room
		for state in ["normal", "hover", "pressed", "disabled"]:
			btn.remove_theme_stylebox_override(state)
			if look["pad"] >= 0:
				var sb: StyleBox = btn.get_theme_stylebox(state).duplicate()
				sb.content_margin_left = look["pad"]
				sb.content_margin_right = look["pad"]
				btn.add_theme_stylebox_override(state, sb)

## Moves the resume card and the actions between the single column and the two-column row.
## Only their parents change; the order within the single column is the original one.
func _set_wide(wide: bool) -> void:
	if wide == is_wide or wide_row == null:
		return
	is_wide = wide
	for n in [resume_holder, mid_spacer, actions_vbox, bottom_spacer, nav_section_vbox]:
		n.get_parent().remove_child(n)
	if wide:
		wide_row.add_child(resume_holder)
		wide_row.move_child(resume_holder, 0)
		wide_right.add_child(actions_vbox)
		wide_right.add_child(bottom_spacer)
		wide_right.add_child(nav_section_vbox)
		root_vbox.add_child(mid_spacer)
		root_vbox.move_child(mid_spacer, wide_row.get_index())
	else:
		var at: int = wide_row.get_index()
		for n in [resume_holder, mid_spacer, actions_vbox, bottom_spacer, nav_section_vbox]:
			root_vbox.add_child(n)
			root_vbox.move_child(n, at)
			at += 1
	wide_row.visible = wide

func refresh_buttons() -> void:
	var has_active := SaveManager.has_active_game()
	continue_btn.disabled = not has_active
	# With nothing to resume the button is noise; New Game takes the primary spot instead
	continue_btn.visible = has_active

	if has_active:
		continue_btn.theme_type_variation = "PrimaryButton"
		new_game_btn.theme_type_variation = "GhostButton"
		if continue_meta_label != null:
			continue_meta_label.text = LocalizationManager.translate("KEY_APP_SUBTITLE")
			continue_meta_label.visible = false
	else:
		continue_btn.theme_type_variation = "GhostButton"
		new_game_btn.theme_type_variation = "PrimaryButton"
		if continue_meta_label != null:
			continue_meta_label.visible = false

	if resume_card != null:
		var active_state: GameState = SaveManager.load_active_game() if has_active else null
		resume_card.set_game(active_state)

	var is_daily_done := DailyManager.is_today_completed()
	var has_daily_game := DailyManager.has_today_game()
	daily_btn.disabled = false
	if is_daily_done:
		daily_btn.text = LocalizationManager.translate("BTN_DAILY_COMPLETED")
		daily_btn.theme_type_variation = "GhostButton"
	elif has_daily_game:
		daily_btn.text = LocalizationManager.translate("BTN_CONTINUE")
		daily_btn.theme_type_variation = "CompactPrimaryButton"
	else:
		daily_btn.text = LocalizationManager.translate("BTN_PLAY")
		daily_btn.theme_type_variation = "CompactSecondaryButton"

	var streak := DailyManager.get_current_streak()
	if daily_meta_label != null:
		# The name says what it is; the line under it is only there when there is a streak to show
		daily_meta_label.visible = streak > 0
		if streak > 0:
			daily_meta_label.text = LocalizationManager.format_streak(streak)

func _build_ui() -> void:
	bg = AmbientBackdrop.new()
	bg.color = ThemeManager.get_color("bg")
	add_child(bg)

	margin_container = MarginContainer.new()
	margin_container.set_anchors_preset(PRESET_FULL_RECT)
	margin_container.add_theme_constant_override("margin_left", 24)
	margin_container.add_theme_constant_override("margin_right", 24)
	margin_container.add_theme_constant_override("margin_top", 28)
	margin_container.add_theme_constant_override("margin_bottom", 20)
	add_child(margin_container)

	# Scrolls only when the content cannot fit (very short screens); otherwise it fills the screen
	var scroll := ScrollContainer.new()
	TouchScroll.attach(scroll)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	margin_container.add_child(scroll)

	# The scroll container clips to its rect; this padding keeps the glass drop shadows inside it
	# (the outer margins are reduced by the same amount, see _apply_responsive_layout)
	var shadow_pad := MarginContainer.new()
	shadow_pad.size_flags_horizontal = SIZE_EXPAND_FILL
	shadow_pad.size_flags_vertical = SIZE_EXPAND_FILL
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		shadow_pad.add_theme_constant_override(side, SHADOW_PAD)
	scroll.add_child(shadow_pad)

	root_vbox = VBoxContainer.new()
	root_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 0)
	shadow_pad.add_child(root_vbox)

	menu_card_panel = root_vbox

	# --- 1. Top Spacer ---
	top_spacer = Control.new()
	top_spacer.custom_minimum_size = Vector2(0, 28)
	root_vbox.add_child(top_spacer)

	# --- 2. Swiss Editorial Masthead ---
	header_vbox = VBoxContainer.new()
	header_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	root_vbox.add_child(header_vbox)

	# The name, set in the display face and left-aligned with the cards below, ending in the
	# icon's lit cell as its full stop
	var wordmark := HBoxContainer.new()
	wordmark.add_theme_constant_override("separation", 5)
	header_vbox.add_child(wordmark)

	title_label = Label.new()
	title_label.theme_type_variation = "Wordmark"
	wordmark.add_child(title_label)

	wordmark_dot_holder = MarginContainer.new()
	wordmark_dot_holder.size_flags_vertical = SIZE_SHRINK_END
	wordmark.add_child(wordmark_dot_holder)
	wordmark_dot = Panel.new()
	wordmark_dot_holder.add_child(wordmark_dot)

	# --- 3. Resume card: live miniature of the unfinished game, centred in the free space ---
	resume_holder = VBoxContainer.new()
	resume_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	resume_holder.size_flags_horizontal = SIZE_EXPAND_FILL
	resume_holder.size_flags_vertical = SIZE_EXPAND_FILL
	root_vbox.add_child(resume_holder)

	resume_card = ResumeCard.new()
	resume_card.pressed.connect(func(): resume_card_pressed.emit())
	resume_holder.add_child(resume_card)

	mid_spacer = Control.new()
	mid_spacer.custom_minimum_size = Vector2(0, 20)
	root_vbox.add_child(mid_spacer)

	# --- 4. Main Puzzle Actions (Distinct Daily + Continue + New Game + Saved Games in Lower Ergonomic Thumb Zone) ---
	actions_vbox = VBoxContainer.new()
	actions_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	actions_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	actions_vbox.add_theme_constant_override("separation", 10)
	root_vbox.add_child(actions_vbox)

	# 1. Action: Günün Sudokusu Strip (Restrained, distinct editorial card - Placed at Top of Action Group)
	var daily_glass := GlassPanel.new()
	daily_glass.elevated = false
	daily_glass.corner_radius = 20.0
	daily_glass.pad_h = 16
	daily_glass.pad_v = 10
	daily_glass.shadow_size = 10
	daily_glass.shadow_offset = Vector2(0, 3)
	daily_panel = daily_glass
	daily_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	daily_panel.mouse_filter = MOUSE_FILTER_PASS
	actions_vbox.add_child(daily_panel)

	var daily_hbox := HBoxContainer.new()
	daily_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	daily_hbox.add_theme_constant_override("separation", 12)
	daily_panel.add_child(daily_hbox)

	daily_archive_btn = Button.new()
	daily_archive_btn.theme_type_variation = "IconButton"
	daily_archive_btn.icon = ThemeManager.get_icon("calendar")
	daily_archive_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	daily_archive_btn.add_theme_constant_override("icon_max_width", 20)
	daily_archive_btn.custom_minimum_size = Vector2(ResponsiveManager.TOUCH_TARGET_MIN, ResponsiveManager.TOUCH_TARGET_MIN)
	daily_archive_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	daily_archive_btn.pressed.connect(func(): daily_archive_requested.emit())
	daily_hbox.add_child(daily_archive_btn)

	var daily_info_vbox := VBoxContainer.new()
	daily_info_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	daily_info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	daily_info_vbox.add_theme_constant_override("separation", 2)
	daily_hbox.add_child(daily_info_vbox)

	daily_title_label = Label.new()
	daily_title_label.theme_type_variation = "Body"
	ThemeManager.set_font_size(daily_title_label, 15)
	daily_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	daily_info_vbox.add_child(daily_title_label)

	daily_meta_label = Label.new()
	daily_meta_label.theme_type_variation = "Caption"
	ThemeManager.set_font_size(daily_meta_label, 12)
	daily_meta_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	daily_info_vbox.add_child(daily_meta_label)

	daily_btn = Button.new()
	daily_btn.custom_minimum_size = Vector2(112, ResponsiveManager.TOUCH_TARGET_MIN)
	daily_btn.clip_text = false
	daily_btn.theme_type_variation = "CompactSecondaryButton"
	ThemeManager.set_font_size(daily_btn, 14)
	daily_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	daily_btn.pressed.connect(func(): daily_sudoku_requested.emit())
	daily_hbox.add_child(daily_btn)

	# Hero Action Section (Trio of full-width capsule buttons with consistent 10px separation)
	# One glass sheet holds the three actions: the accent capsule stays the call to action,
	# the other two are quiet rows on the glass instead of separate opaque slabs
	var hero_glass := GlassPanel.card(26.0, 10, 10)
	hero_glass.shadow_size = 12
	hero_glass.shadow_offset = Vector2(0, 4)
	actions_vbox.add_child(hero_glass)

	hero_vbox = VBoxContainer.new()
	hero_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	hero_vbox.add_theme_constant_override("separation", 4)
	hero_glass.add_child(hero_vbox)

	# 2. Action: Primary / Resume - Continue Game (Prime reference: 52px hero capsule with 20px Lucide play icon)
	var cont_box := VBoxContainer.new()
	cont_box.size_flags_horizontal = SIZE_EXPAND_FILL
	cont_box.add_theme_constant_override("separation", 4)
	hero_vbox.add_child(cont_box)

	continue_btn = Button.new()
	continue_btn.custom_minimum_size = Vector2(0, ResponsiveManager.HEIGHT_BUTTON_HERO)
	continue_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	continue_btn.theme_type_variation = "PrimaryButton"
	# The play icon is a child at the left edge, not the button's own icon: an icon in the button
	# takes room from its text and pushed "Continue" off the centre the other two labels share
	continue_icon = TextureRect.new()
	continue_icon.texture = ThemeManager.get_icon("play")
	continue_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	continue_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	continue_icon.mouse_filter = MOUSE_FILTER_IGNORE
	continue_icon.set_anchors_preset(PRESET_CENTER_LEFT)
	continue_icon.offset_left = 20.0
	continue_icon.offset_right = 40.0
	continue_icon.offset_top = -10.0
	continue_icon.offset_bottom = 10.0
	continue_btn.add_child(continue_icon)
	ThemeManager.set_font_size(continue_btn, 17)
	continue_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	continue_btn.pressed.connect(func(): continue_pressed.emit())
	cont_box.add_child(continue_btn)

	continue_meta_label = Label.new()
	continue_meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_meta_label.theme_type_variation = "Caption"
	ThemeManager.set_font_size(continue_meta_label, 12)
	continue_meta_label.visible = false
	cont_box.add_child(continue_meta_label)

	# 3. Action: New Game (48px primary/secondary capsule)
	new_game_btn = Button.new()
	new_game_btn.custom_minimum_size = Vector2(0, ResponsiveManager.HEIGHT_BUTTON_PRIMARY)
	new_game_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	new_game_btn.theme_type_variation = "GhostButton"
	ThemeManager.set_font_size(new_game_btn, 16)
	new_game_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	new_game_btn.pressed.connect(func(): new_game_requested.emit())
	hero_vbox.add_child(new_game_btn)

	# 4. Action: Saved Games (48px capsule button matching Devam Et / Yeni Oyun geometry & visual weight)
	load_game_btn = Button.new()
	load_game_btn.custom_minimum_size = Vector2(0, ResponsiveManager.HEIGHT_BUTTON_PRIMARY)
	load_game_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	load_game_btn.theme_type_variation = "GhostButton"
	ThemeManager.set_font_size(load_game_btn, 16)
	load_game_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	load_game_btn.pressed.connect(func(): load_game_requested.emit())
	hero_vbox.add_child(load_game_btn)

	# --- 5. Bottom Controlled Separation Spacer ---
	bottom_spacer = Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0, 24)
	root_vbox.add_child(bottom_spacer)

	# --- 6. Lower Utility Baseline Navigation (Low Weight, 44px touch targets) ---
	nav_section_vbox = VBoxContainer.new()
	nav_section_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	nav_section_vbox.add_theme_constant_override("separation", 10)
	root_vbox.add_child(nav_section_vbox)

	nav_separator = HSeparator.new()
	nav_separator.visible = false
	nav_section_vbox.add_child(nav_separator)

	nav_glass = GlassPanel.new()
	nav_glass.elevated = false
	nav_glass.corner_radius = 26.0
	nav_glass.pad_h = 10
	nav_glass.pad_v = 4
	nav_glass.shadow_size = 12
	nav_glass.shadow_offset = Vector2(0, 4)
	nav_glass.size_flags_horizontal = SIZE_EXPAND_FILL
	nav_section_vbox.add_child(nav_glass)

	nav_grid = GridContainer.new()
	nav_grid.columns = 4
	nav_grid.size_flags_horizontal = SIZE_EXPAND_FILL
	nav_grid.add_theme_constant_override("h_separation", 8)
	nav_grid.add_theme_constant_override("v_separation", 2)
	nav_glass.add_child(nav_grid)

	history_btn = Button.new()
	history_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	history_btn.custom_minimum_size = Vector2(0, 44)
	history_btn.theme_type_variation = "GhostButton"
	history_btn.icon = ThemeManager.get_icon("rotate-ccw")
	history_btn.add_theme_constant_override("icon_max_width", 16)
	ThemeManager.set_font_size(history_btn, 13)
	history_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	history_btn.pressed.connect(func(): history_requested.emit())
	nav_grid.add_child(history_btn)

	stats_btn = Button.new()
	stats_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	stats_btn.custom_minimum_size = Vector2(0, 44)
	stats_btn.theme_type_variation = "GhostButton"
	stats_btn.icon = ThemeManager.get_icon("chart-column-big")
	stats_btn.add_theme_constant_override("icon_max_width", 16)
	ThemeManager.set_font_size(stats_btn, 13)
	stats_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	stats_btn.pressed.connect(func(): statistics_requested.emit())
	nav_grid.add_child(stats_btn)

	techniques_btn = Button.new()
	techniques_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	techniques_btn.custom_minimum_size = Vector2(0, 44)
	techniques_btn.theme_type_variation = "GhostButton"
	techniques_btn.icon = ThemeManager.get_icon("lightbulb")
	techniques_btn.add_theme_constant_override("icon_max_width", 16)
	ThemeManager.set_font_size(techniques_btn, 13)
	techniques_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	techniques_btn.pressed.connect(func(): techniques_requested.emit())
	nav_grid.add_child(techniques_btn)

	settings_btn = Button.new()
	settings_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	settings_btn.custom_minimum_size = Vector2(0, 44)
	settings_btn.theme_type_variation = "GhostButton"
	settings_btn.icon = ThemeManager.get_icon("settings")
	settings_btn.add_theme_constant_override("icon_max_width", 16)
	ThemeManager.set_font_size(settings_btn, 13)
	settings_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	settings_btn.pressed.connect(func(): settings_requested.emit())
	nav_grid.add_child(settings_btn)

	wide_row = HBoxContainer.new()
	wide_row.size_flags_horizontal = SIZE_EXPAND_FILL
	wide_row.size_flags_vertical = SIZE_EXPAND_FILL
	wide_row.add_theme_constant_override("separation", 40)
	wide_row.visible = false
	root_vbox.add_child(wide_row)
	root_vbox.move_child(wide_row, resume_holder.get_index())
	wide_right = VBoxContainer.new()
	wide_right.size_flags_horizontal = SIZE_EXPAND_FILL
	wide_right.alignment = BoxContainer.ALIGNMENT_CENTER
	wide_row.add_child(wide_right)

	_apply_theme_polish()

## A new text size is on every label by now: the buttons may need another look
func _on_text_size_changed() -> void:
	_fit_nav_buttons()

## The full stop is a rounded square a little over a quarter of the type size, in the accent, its
## foot on the baseline (the label's height is ascent plus descent, so the descent lifts it there)
func _fit_wordmark_dot() -> void:
	if title_label == null or wordmark_dot == null:
		return
	var font: Font = title_label.get_theme_font("font")
	var px: int = title_label.get_theme_font_size("font_size")
	var side: float = roundf(px * 0.27)
	wordmark_dot.custom_minimum_size = Vector2(side, side)
	var sb := StyleBoxFlat.new()
	sb.bg_color = ThemeManager.get_color("accent_blue", ThemeManager.get_color("accent"))
	sb.set_corner_radius_all(maxi(2, int(side * 0.28)))
	wordmark_dot.add_theme_stylebox_override("panel", sb)
	wordmark_dot_holder.add_theme_constant_override("margin_bottom", int(roundf(font.get_descent(px))))

func _apply_theme_polish() -> void:
	if title_label != null:
		title_label.add_theme_color_override("font_color", ThemeManager.get_color("text_given"))
		_fit_wordmark_dot()
	if continue_meta_label != null:
		continue_meta_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	if daily_title_label != null:
		daily_title_label.add_theme_color_override("font_color", ThemeManager.get_color("text_given"))
	if daily_meta_label != null:
		daily_meta_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	if history_btn != null:
		history_btn.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	if stats_btn != null:
		stats_btn.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	if techniques_btn != null:
		techniques_btn.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	if settings_btn != null:
		settings_btn.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))

func _on_theme_changed() -> void:
	if bg != null:
		bg.color = ThemeManager.get_color("bg")
	_apply_theme_polish()
	_fit_nav_buttons()

func _update_locale_texts() -> void:
	var is_tr := (LocalizationManager.get_locale() == LocalizationManager.LOCALE_TR)
	if title_label != null:
		title_label.text = "Just Sudoku"
	if continue_btn != null:
		continue_btn.text = LocalizationManager.translate("BTN_CONTINUE")
	if new_game_btn != null:
		new_game_btn.text = LocalizationManager.translate("BTN_NEW_GAME")
	if daily_title_label != null:
		daily_title_label.text = LocalizationManager.translate("BTN_DAILY_SUDOKU")
	if daily_archive_btn != null:
		daily_archive_btn.tooltip_text = LocalizationManager.translate("ARCHIVE_TITLE")
	if load_game_btn != null:
		load_game_btn.text = LocalizationManager.translate("BTN_LOAD_GAME")
	if history_btn != null:
		history_btn.text = LocalizationManager.translate("BTN_HISTORY")
	if stats_btn != null:
		stats_btn.text = LocalizationManager.translate("BTN_STATS")
	if techniques_btn != null:
		techniques_btn.text = LocalizationManager.translate("BTN_TECHNIQUES")
	if settings_btn != null:
		settings_btn.text = LocalizationManager.translate("BTN_SETTINGS")
	_fit_nav_buttons()
	refresh_buttons()

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
signal new_game_requested()
signal load_game_requested()
signal daily_sudoku_requested()
signal history_requested()
signal statistics_requested()
signal settings_requested()

var bg: ColorRect
var margin_container: MarginContainer
var root_vbox: VBoxContainer
var top_spacer: Control
var mid_spacer: Control
var bottom_spacer: Control

# 1. Masthead
var header_vbox: VBoxContainer
var title_label: Label
var subtitle_label: Label
var masthead_separator: HSeparator

# 2. Hero & Puzzle Actions
var actions_vbox: VBoxContainer
var hero_vbox: VBoxContainer
var continue_btn: Button
var continue_meta_label: Label
var new_game_btn: Button

# 3. Daily Sudoku Strip (Distinct & Restrained)
var daily_panel: PanelContainer
var daily_icon_tex: TextureRect
var daily_title_label: Label
var daily_meta_label: Label
var daily_btn: Button

# 4. Saved Games Link
var load_game_btn: Button

# 5. Baseline Utility Navigation
var nav_separator: HSeparator
var nav_hbox: HBoxContainer
var history_btn: Button
var stats_btn: Button
var settings_btn: Button

# Backwards compatibility reference
var menu_card_panel: Control

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

func _ready() -> void:
	_apply_responsive_layout()
	refresh_buttons()

func _apply_responsive_layout() -> void:
	if margin_container == null:
		return
	ResponsiveManager.apply_menu_layout(
		self,
		margin_container,
		top_spacer,
		mid_spacer,
		bottom_spacer
	)

func refresh_buttons() -> void:
	var has_active := SaveManager.has_active_game()
	continue_btn.disabled = not has_active

	if has_active:
		continue_btn.theme_type_variation = "PrimaryButton"
		new_game_btn.theme_type_variation = "SecondaryButton"
		if continue_meta_label != null:
			continue_meta_label.text = LocalizationManager.translate("KEY_APP_SUBTITLE")
			continue_meta_label.visible = false
	else:
		continue_btn.theme_type_variation = "SecondaryButton"
		new_game_btn.theme_type_variation = "PrimaryButton"
		if continue_meta_label != null:
			continue_meta_label.visible = false

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
		if streak > 0:
			daily_meta_label.text = LocalizationManager.translate("DAILY_STREAK_FORMAT") % streak
		else:
			daily_meta_label.text = LocalizationManager.translate("DAILY_SUBTITLE")

func _build_ui() -> void:
	bg = ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = ThemeManager.get_color("bg")
	add_child(bg)

	margin_container = MarginContainer.new()
	margin_container.set_anchors_preset(PRESET_FULL_RECT)
	margin_container.add_theme_constant_override("margin_left", 24)
	margin_container.add_theme_constant_override("margin_right", 24)
	margin_container.add_theme_constant_override("margin_top", 28)
	margin_container.add_theme_constant_override("margin_bottom", 20)
	add_child(margin_container)

	root_vbox = VBoxContainer.new()
	root_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 0)
	margin_container.add_child(root_vbox)

	menu_card_panel = root_vbox

	# --- 1. Top Spacer ---
	top_spacer = Control.new()
	top_spacer.custom_minimum_size = Vector2(0, 28)
	root_vbox.add_child(top_spacer)

	# --- 2. Swiss Editorial Masthead ---
	header_vbox = VBoxContainer.new()
	header_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	header_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	header_vbox.add_theme_constant_override("separation", 6)
	root_vbox.add_child(header_vbox)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.theme_type_variation = "BrandTitle"
	header_vbox.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.theme_type_variation = "Subtitle"
	subtitle_label.add_theme_font_size_override("font_size", 12)
	header_vbox.add_child(subtitle_label)

	var masthead_gap := Control.new()
	masthead_gap.custom_minimum_size = Vector2(0, 8)
	header_vbox.add_child(masthead_gap)

	masthead_separator = HSeparator.new()
	header_vbox.add_child(masthead_separator)

	# --- 3. Mid Spacer (Expands vertically to position action cluster in thumb reach zone) ---
	mid_spacer = Control.new()
	mid_spacer.custom_minimum_size = Vector2(0, 36)
	mid_spacer.size_flags_vertical = SIZE_EXPAND_FILL
	root_vbox.add_child(mid_spacer)

	# --- 4. Main Puzzle Actions (Distinct Daily + Continue + New Game + Saved Games in Lower Ergonomic Thumb Zone) ---
	actions_vbox = VBoxContainer.new()
	actions_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	actions_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	actions_vbox.add_theme_constant_override("separation", 10)
	root_vbox.add_child(actions_vbox)

	# 1. Action: Günün Sudokusu Strip (Restrained, distinct editorial card - Placed at Top of Action Group)
	daily_panel = PanelContainer.new()
	daily_panel.size_flags_horizontal = SIZE_EXPAND_FILL
	daily_panel.mouse_filter = MOUSE_FILTER_PASS
	actions_vbox.add_child(daily_panel)

	var daily_hbox := HBoxContainer.new()
	daily_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	daily_hbox.add_theme_constant_override("separation", 12)
	daily_panel.add_child(daily_hbox)

	daily_icon_tex = TextureRect.new()
	daily_icon_tex.texture = ThemeManager.get_icon("clock-3")
	daily_icon_tex.custom_minimum_size = Vector2(20, 20)
	daily_icon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	daily_icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	daily_hbox.add_child(daily_icon_tex)

	var daily_info_vbox := VBoxContainer.new()
	daily_info_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	daily_info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	daily_info_vbox.add_theme_constant_override("separation", 2)
	daily_hbox.add_child(daily_info_vbox)

	daily_title_label = Label.new()
	daily_title_label.theme_type_variation = "Body"
	daily_title_label.add_theme_font_size_override("font_size", 15)
	daily_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	daily_info_vbox.add_child(daily_title_label)

	daily_meta_label = Label.new()
	daily_meta_label.theme_type_variation = "Caption"
	daily_meta_label.add_theme_font_size_override("font_size", 12)
	daily_meta_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	daily_info_vbox.add_child(daily_meta_label)

	daily_btn = Button.new()
	daily_btn.custom_minimum_size = Vector2(112, 42)
	daily_btn.clip_text = false
	daily_btn.theme_type_variation = "CompactSecondaryButton"
	daily_btn.add_theme_font_size_override("font_size", 14)
	daily_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	daily_btn.pressed.connect(func(): daily_sudoku_requested.emit())
	daily_hbox.add_child(daily_btn)

	# Hero Action Section (Trio of full-width capsule buttons with consistent 10px separation)
	hero_vbox = VBoxContainer.new()
	hero_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	hero_vbox.add_theme_constant_override("separation", 10)
	actions_vbox.add_child(hero_vbox)

	# 2. Action: Primary / Resume - Continue Game (Prime reference: 52px hero capsule with 20px Lucide play icon)
	var cont_box := VBoxContainer.new()
	cont_box.size_flags_horizontal = SIZE_EXPAND_FILL
	cont_box.add_theme_constant_override("separation", 4)
	hero_vbox.add_child(cont_box)

	continue_btn = Button.new()
	continue_btn.custom_minimum_size = Vector2(0, ResponsiveManager.HEIGHT_BUTTON_HERO)
	continue_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	continue_btn.theme_type_variation = "PrimaryButton"
	continue_btn.icon = ThemeManager.get_icon("play")
	continue_btn.add_theme_constant_override("icon_max_width", 20)
	continue_btn.add_theme_font_size_override("font_size", 17)
	continue_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	continue_btn.pressed.connect(func(): continue_pressed.emit())
	cont_box.add_child(continue_btn)

	continue_meta_label = Label.new()
	continue_meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_meta_label.theme_type_variation = "Caption"
	continue_meta_label.add_theme_font_size_override("font_size", 12)
	continue_meta_label.visible = false
	cont_box.add_child(continue_meta_label)

	# 3. Action: New Game (48px primary/secondary capsule)
	new_game_btn = Button.new()
	new_game_btn.custom_minimum_size = Vector2(0, ResponsiveManager.HEIGHT_BUTTON_PRIMARY)
	new_game_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	new_game_btn.theme_type_variation = "SecondaryButton"
	new_game_btn.add_theme_font_size_override("font_size", 16)
	new_game_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	new_game_btn.pressed.connect(func(): new_game_requested.emit())
	hero_vbox.add_child(new_game_btn)

	# 4. Action: Saved Games (48px capsule button matching Devam Et / Yeni Oyun geometry & visual weight)
	load_game_btn = Button.new()
	load_game_btn.custom_minimum_size = Vector2(0, ResponsiveManager.HEIGHT_BUTTON_PRIMARY)
	load_game_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	load_game_btn.theme_type_variation = "SecondaryButton"
	load_game_btn.icon = ThemeManager.get_icon("folder-open")
	load_game_btn.add_theme_constant_override("icon_max_width", 20)
	load_game_btn.add_theme_font_size_override("font_size", 16)
	load_game_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	load_game_btn.pressed.connect(func(): load_game_requested.emit())
	hero_vbox.add_child(load_game_btn)

	# --- 5. Bottom Controlled Separation Spacer ---
	bottom_spacer = Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0, 24)
	root_vbox.add_child(bottom_spacer)

	# --- 6. Lower Utility Baseline Navigation (Low Weight, 44px touch targets) ---
	var nav_section_vbox := VBoxContainer.new()
	nav_section_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	nav_section_vbox.add_theme_constant_override("separation", 10)
	root_vbox.add_child(nav_section_vbox)

	nav_separator = HSeparator.new()
	nav_section_vbox.add_child(nav_separator)

	nav_hbox = HBoxContainer.new()
	nav_hbox.size_flags_horizontal = SIZE_EXPAND_FILL
	nav_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_hbox.add_theme_constant_override("separation", 8)
	nav_section_vbox.add_child(nav_hbox)

	history_btn = Button.new()
	history_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	history_btn.custom_minimum_size = Vector2(0, 44)
	history_btn.theme_type_variation = "GhostButton"
	history_btn.icon = ThemeManager.get_icon("rotate-ccw")
	history_btn.add_theme_constant_override("icon_max_width", 16)
	history_btn.add_theme_font_size_override("font_size", 13)
	history_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	history_btn.pressed.connect(func(): history_requested.emit())
	nav_hbox.add_child(history_btn)

	stats_btn = Button.new()
	stats_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	stats_btn.custom_minimum_size = Vector2(0, 44)
	stats_btn.theme_type_variation = "GhostButton"
	stats_btn.icon = ThemeManager.get_icon("chart-column-big")
	stats_btn.add_theme_constant_override("icon_max_width", 16)
	stats_btn.add_theme_font_size_override("font_size", 13)
	stats_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	stats_btn.pressed.connect(func(): statistics_requested.emit())
	nav_hbox.add_child(stats_btn)

	settings_btn = Button.new()
	settings_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	settings_btn.custom_minimum_size = Vector2(0, 44)
	settings_btn.theme_type_variation = "GhostButton"
	settings_btn.icon = ThemeManager.get_icon("settings")
	settings_btn.add_theme_constant_override("icon_max_width", 16)
	settings_btn.add_theme_font_size_override("font_size", 13)
	settings_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	settings_btn.pressed.connect(func(): settings_requested.emit())
	nav_hbox.add_child(settings_btn)

	_apply_theme_polish()

func _apply_theme_polish() -> void:
	if title_label != null:
		title_label.add_theme_color_override("font_color", ThemeManager.get_color("text_given"))
	if subtitle_label != null:
		subtitle_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	if continue_meta_label != null:
		continue_meta_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	if daily_panel != null:
		# Distinct, restrained hairline frame for the daily strip
		var border_col: Color = ThemeManager.get_color("border_subtle")
		var surf_col: Color = ThemeManager.get_color("surface")
		var sb_daily := ThemeManager.create_flat_stylebox(
			surf_col,
			ThemeManager.RADIUS_MD,
			ThemeManager.BORDER_HAIRLINE,
			border_col,
			14, 10
		)
		daily_panel.add_theme_stylebox_override("panel", sb_daily)
	if daily_icon_tex != null:
		daily_icon_tex.modulate = ThemeManager.get_color("text_secondary")
	if daily_title_label != null:
		daily_title_label.add_theme_color_override("font_color", ThemeManager.get_color("text_given"))
	if daily_meta_label != null:
		daily_meta_label.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	if history_btn != null:
		history_btn.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	if stats_btn != null:
		stats_btn.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	if settings_btn != null:
		settings_btn.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))

func _on_theme_changed() -> void:
	if bg != null:
		bg.color = ThemeManager.get_color("bg")
	_apply_theme_polish()

func _update_locale_texts() -> void:
	var is_tr := (LocalizationManager.get_locale() == LocalizationManager.LOCALE_TR)
	if title_label != null:
		title_label.text = "JUST SUDOKU"
	if subtitle_label != null:
		subtitle_label.text = LocalizationManager.translate("SUBTITLE_CALM")
	if continue_btn != null:
		continue_btn.text = LocalizationManager.translate("BTN_CONTINUE")
	if new_game_btn != null:
		new_game_btn.text = LocalizationManager.translate("BTN_NEW_GAME")
	if daily_title_label != null:
		daily_title_label.text = LocalizationManager.translate("BTN_DAILY_SUDOKU")
	if load_game_btn != null:
		load_game_btn.text = LocalizationManager.translate("BTN_LOAD_GAME")
	if history_btn != null:
		history_btn.text = LocalizationManager.translate("BTN_HISTORY")
	if stats_btn != null:
		stats_btn.text = LocalizationManager.translate("BTN_STATS")
	if settings_btn != null:
		settings_btn.text = LocalizationManager.translate("BTN_SETTINGS")
	refresh_buttons()

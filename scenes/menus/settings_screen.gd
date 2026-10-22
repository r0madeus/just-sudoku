class_name SettingsScreen
extends Control

const LocalizationManager = preload("res://scripts/services/localization_manager.gd")
const ThemeManager = preload("res://scripts/services/theme_manager.gd")
const FontManager = preload("res://scripts/services/font_manager.gd")
const SettingRow = preload("res://scenes/ui/setting_row.gd")
const ResponsiveManager = preload("res://scripts/services/responsive_manager.gd")
const AmbientBackdrop = preload("res://scenes/ui/ambient_backdrop.gd")
const GlassPanel = preload("res://scenes/ui/glass_panel.gd")

## Settings Menu Screen (GDD §17, §19, §38, §40, §41, §44)
## Clean settings list with clear sections and aligned controls.

signal back_requested()
signal custom_theme_requested()

const CONFIG_PATH: String = "user://saves/config.json"

static var auto_open_last_game: bool = true
static var smart_numpad_enabled: bool = true
static var auto_remove_notes: bool = true
static var smart_candidates_enabled: bool = false
static var show_conflicts: bool = true
static var show_wrong_immediately: bool = false

## Width of the dropdowns on the right of the setting rows
const PICKER_WIDTH: float = 150.0
static var animations_enabled: bool = true
static var sounds_enabled: bool = true
static var haptics_enabled: bool = true

static var _config_listeners: Array[Callable] = []

static func add_listener(cb: Callable) -> void:
	if not _config_listeners.has(cb):
		_config_listeners.append(cb)

static func remove_listener(cb: Callable) -> void:
	_config_listeners.erase(cb)

static func _notify_listeners() -> void:
	for cb in _config_listeners:
		if cb.is_valid():
			cb.call()

var bg: ColorRect
var margin: MarginContainer
var back_btn: Button
var title_label: Label

# Section Header Labels
var sec_appearance_lbl: Label
var sec_gameplay_lbl: Label
var sec_feedback_lbl: Label

# Section Containers (Preserved for compatibility)
var card_appearance: PanelContainer
var card_gameplay: PanelContainer
var card_feedback: PanelContainer

# Setting Rows
var lang_row: SettingRow
var theme_row: SettingRow
var custom_theme_row: SettingRow
var font_row: SettingRow

var auto_open_row: SettingRow
var smart_numpad_row: SettingRow
var auto_notes_row: SettingRow
var smart_cand_row: SettingRow

var conflict_row: SettingRow
var wrong_row: SettingRow
var anim_row: SettingRow
var sound_row: SettingRow
var haptics_row: SettingRow

# Appearance Controls
var lang_label: Label
var lang_option: OptionButton
var theme_label: Label
var theme_option: OptionButton
var custom_theme_lbl: Label
var custom_theme_btn: Button
var font_label: Label
var font_option: OptionButton

# Gameplay Controls
var auto_open_lbl: Label
var auto_open_check: CheckBox
var smart_numpad_lbl: Label
var smart_numpad_check: CheckBox
var auto_notes_lbl: Label
var auto_notes_check: CheckBox
var smart_candidates_lbl: Label
var smart_candidates_check: CheckBox

# Feedback Controls
var conflict_lbl: Label
var conflict_check: CheckBox
var anim_lbl: Label
var anim_check: CheckBox
var sound_lbl: Label
var sound_check: CheckBox

func _init() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	load_config()
	_build_ui()
	_apply_responsive_layout()
	_update_locale_texts()
	LocalizationManager.add_listener(_update_locale_texts)
	ThemeManager.add_listener(_update_theme_option_selection)
	ThemeManager.add_listener(_on_theme_changed)
	FontManager.add_listener(_update_font_option_selection)

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_apply_responsive_layout()

func _exit_tree() -> void:
	LocalizationManager.remove_listener(_update_locale_texts)
	ThemeManager.remove_listener(_update_theme_option_selection)
	ThemeManager.remove_listener(_on_theme_changed)
	FontManager.remove_listener(_update_font_option_selection)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_responsive_layout()

func _apply_responsive_layout() -> void:
	if margin == null:
		return
	ResponsiveManager.apply_content_margins(self, margin, ResponsiveManager.MAX_CONTENT_WIDTH)

static func save_config() -> void:
	var data := {
		"locale": LocalizationManager.get_locale(),
		"font": FontManager.current_font_name,
		"auto_open": auto_open_last_game,
		"smart_numpad": smart_numpad_enabled,
		"auto_notes": auto_remove_notes,
		"smart_candidates": smart_candidates_enabled,
		"show_conflicts": show_conflicts,
		"show_wrong": show_wrong_immediately,
		"animations": animations_enabled,
		"sounds": sounds_enabled,
		"haptics": haptics_enabled
	}
	var file := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
	_notify_listeners()

static func load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		LocalizationManager.set_locale(LocalizationManager.detect_system_locale())
		return
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		var saved_loc: String = json.data.get("locale", "")
		if saved_loc.is_empty() or not LocalizationManager.SUPPORTED_LOCALES.has(saved_loc):
			saved_loc = LocalizationManager.detect_system_locale()
		LocalizationManager.set_locale(saved_loc)
		var saved_font: String = json.data.get("font", FontManager.FONT_MODERN_SANS)
		FontManager.set_font(saved_font)
		auto_open_last_game = json.data.get("auto_open", true)
		smart_numpad_enabled = json.data.get("smart_numpad", true)
		auto_remove_notes = json.data.get("auto_notes", true)
		smart_candidates_enabled = json.data.get("smart_candidates", false)
		show_conflicts = json.data.get("show_conflicts", true)
		show_wrong_immediately = json.data.get("show_wrong", false)
		animations_enabled = json.data.get("animations", true)
		sounds_enabled = json.data.get("sounds", true)
		haptics_enabled = json.data.get("haptics", true)

func _build_ui() -> void:
	# Soft accent glows behind the content, so glass cards have something to refract
	var ambient_bg := AmbientBackdrop.new()
	ambient_bg.intensity = 0.7
	ambient_bg.color = ThemeManager.get_color("bg")
	bg = ambient_bg
	add_child(bg)

	margin = MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 16)
	margin.add_child(root_vbox)

	# Header
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vbox.add_child(header)

	back_btn = Button.new()
	back_btn.text = ""
	back_btn.tooltip_text = LocalizationManager.translate("BTN_BACK")
	back_btn.theme_type_variation = "IconButton"
	back_btn.icon = ThemeManager.get_icon("chevron-left")
	back_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_btn.add_theme_constant_override("icon_max_width", 20)
	back_btn.custom_minimum_size = Vector2(44, 44)
	back_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back_btn.pressed.connect(func(): back_requested.emit())
	header.add_child(back_btn)

	title_label = Label.new()
	title_label.size_flags_horizontal = SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.theme_type_variation = "Header"
	header.add_child(title_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(44, 0)
	header.add_child(spacer)

	var header_sep := HSeparator.new()
	root_vbox.add_child(header_sep)

	# Scrollable settings list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	root_vbox.add_child(scroll)

	var list_vbox := VBoxContainer.new()
	list_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 24)
	scroll.add_child(list_vbox)

	# =========================================================================
	# 1. Appearance Section (Görünüm)
	# =========================================================================
	var sec_app_group := VBoxContainer.new()
	sec_app_group.add_theme_constant_override("separation", 8)
	list_vbox.add_child(sec_app_group)

	sec_appearance_lbl = Label.new()
	sec_appearance_lbl.theme_type_variation = "Caption"
	sec_appearance_lbl.add_theme_font_size_override("font_size", 11)
	sec_appearance_lbl.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	sec_app_group.add_child(sec_appearance_lbl)

	var sep_app := HSeparator.new()
	sec_app_group.add_child(sep_app)

	card_appearance = GlassPanel.card()
	sec_app_group.add_child(card_appearance)

	var app_vbox := VBoxContainer.new()
	app_vbox.add_theme_constant_override("separation", 8)
	card_appearance.add_child(app_vbox)

	# Dil / Language
	# The three pickers share one width so their left edges line up down the card
	lang_option = OptionButton.new()
	lang_option.custom_minimum_size = Vector2(PICKER_WIDTH, 38)
	lang_option.clip_text = true
	lang_option.fit_to_longest_item = false
	lang_option.add_item("Türkçe")
	lang_option.add_item("English")
	lang_option.selected = 0 if LocalizationManager.get_locale() == LocalizationManager.LOCALE_TR else 1
	lang_option.item_selected.connect(_on_language_selected)

	lang_row = SettingRow.new("", "", lang_option)
	lang_label = lang_row.title_label
	app_vbox.add_child(lang_row)

	app_vbox.add_child(_create_divider())

	# Görsel Tema / Visual Theme
	theme_option = OptionButton.new()
	theme_option.custom_minimum_size = Vector2(PICKER_WIDTH, 38)
	theme_option.clip_text = true
	theme_option.fit_to_longest_item = false
	theme_option.add_item("Dark")
	theme_option.add_item("AMOLED")
	theme_option.add_item("Light")
	theme_option.add_item("Sepia")
	theme_option.add_item("Forest")
	theme_option.add_item("Custom")
	_update_theme_option_selection()
	theme_option.item_selected.connect(_on_theme_selected)

	theme_row = SettingRow.new("", "", theme_option)
	theme_label = theme_row.title_label
	app_vbox.add_child(theme_row)

	app_vbox.add_child(_create_divider())

	# Özel Tema / Custom Theme Editor
	custom_theme_btn = Button.new()
	custom_theme_btn.custom_minimum_size = Vector2(120, 38)
	custom_theme_btn.theme_type_variation = "CompactSecondaryButton"
	custom_theme_btn.icon = ThemeManager.get_icon("palette")
	custom_theme_btn.add_theme_constant_override("icon_max_width", 18)
	custom_theme_btn.add_theme_font_size_override("font_size", 14)
	custom_theme_btn.pressed.connect(func(): custom_theme_requested.emit())

	custom_theme_row = SettingRow.new("", "", custom_theme_btn)
	custom_theme_lbl = custom_theme_row.title_label
	app_vbox.add_child(custom_theme_row)

	app_vbox.add_child(_create_divider())

	# Yazı Tipi / Font Family
	font_option = OptionButton.new()
	font_option.custom_minimum_size = Vector2(PICKER_WIDTH, 38)
	font_option.clip_text = true
	font_option.fit_to_longest_item = false
	font_option.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	font_option.add_item("Modern Sans")
	font_option.add_item("Rounded Sans")
	font_option.add_item("Classic Serif")
	_update_font_option_selection()
	font_option.item_selected.connect(_on_font_selected)

	font_row = SettingRow.new("", "", font_option)
	font_label = font_row.title_label
	app_vbox.add_child(font_row)

	# =========================================================================
	# 2. Gameplay Section (Oynanış)
	# =========================================================================
	var sec_game_group := VBoxContainer.new()
	sec_game_group.add_theme_constant_override("separation", 8)
	list_vbox.add_child(sec_game_group)

	sec_gameplay_lbl = Label.new()
	sec_gameplay_lbl.theme_type_variation = "Caption"
	sec_gameplay_lbl.add_theme_font_size_override("font_size", 11)
	sec_gameplay_lbl.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	sec_game_group.add_child(sec_gameplay_lbl)

	var sep_game := HSeparator.new()
	sec_game_group.add_child(sep_game)

	card_gameplay = GlassPanel.card()
	sec_game_group.add_child(card_gameplay)

	var game_vbox := VBoxContainer.new()
	game_vbox.add_theme_constant_override("separation", 8)
	card_gameplay.add_child(game_vbox)

	# Auto open last game
	auto_open_check = CheckBox.new()
	auto_open_check.button_pressed = auto_open_last_game
	auto_open_check.toggled.connect(func(v): auto_open_last_game = v; save_config())

	auto_open_row = SettingRow.new("", "", auto_open_check)
	auto_open_lbl = auto_open_row.title_label
	game_vbox.add_child(auto_open_row)

	game_vbox.add_child(_create_divider())

	# Smart numpad
	smart_numpad_check = CheckBox.new()
	smart_numpad_check.button_pressed = smart_numpad_enabled
	smart_numpad_check.toggled.connect(func(v): smart_numpad_enabled = v; save_config())

	smart_numpad_row = SettingRow.new("", "", smart_numpad_check)
	smart_numpad_lbl = smart_numpad_row.title_label
	game_vbox.add_child(smart_numpad_row)

	game_vbox.add_child(_create_divider())

	# Auto notes
	auto_notes_check = CheckBox.new()
	auto_notes_check.button_pressed = auto_remove_notes
	auto_notes_check.toggled.connect(func(v): auto_remove_notes = v; save_config())

	auto_notes_row = SettingRow.new("", "", auto_notes_check)
	auto_notes_lbl = auto_notes_row.title_label
	game_vbox.add_child(auto_notes_row)

	game_vbox.add_child(_create_divider())

	# Smart candidates
	smart_candidates_check = CheckBox.new()
	smart_candidates_check.button_pressed = smart_candidates_enabled
	smart_candidates_check.toggled.connect(func(v): smart_candidates_enabled = v; save_config())

	smart_cand_row = SettingRow.new("", "", smart_candidates_check)
	smart_candidates_lbl = smart_cand_row.title_label
	game_vbox.add_child(smart_cand_row)

	# =========================================================================
	# 3. Feedback Section (Geri Bildirim ve Sesler)
	# =========================================================================
	var sec_feed_group := VBoxContainer.new()
	sec_feed_group.add_theme_constant_override("separation", 8)
	list_vbox.add_child(sec_feed_group)

	sec_feedback_lbl = Label.new()
	sec_feedback_lbl.theme_type_variation = "Caption"
	sec_feedback_lbl.add_theme_font_size_override("font_size", 11)
	sec_feedback_lbl.add_theme_color_override("font_color", ThemeManager.get_color("text_secondary"))
	sec_feed_group.add_child(sec_feedback_lbl)

	var sep_feed := HSeparator.new()
	sec_feed_group.add_child(sep_feed)

	card_feedback = GlassPanel.card()
	sec_feed_group.add_child(card_feedback)

	var feed_vbox := VBoxContainer.new()
	feed_vbox.add_theme_constant_override("separation", 8)
	card_feedback.add_child(feed_vbox)

	# Show conflicts
	conflict_check = CheckBox.new()
	conflict_check.button_pressed = show_conflicts
	conflict_check.toggled.connect(func(v): show_conflicts = v; save_config())

	conflict_row = SettingRow.new("", "", conflict_check)
	conflict_lbl = conflict_row.title_label
	feed_vbox.add_child(conflict_row)

	feed_vbox.add_child(_create_divider())

	# Show wrong digits right away (off by default: GDD §18 reveals them with Check)
	var wrong_check := CheckBox.new()
	wrong_check.button_pressed = show_wrong_immediately
	wrong_check.toggled.connect(func(v): show_wrong_immediately = v; save_config())
	wrong_row = SettingRow.new("", "", wrong_check)
	feed_vbox.add_child(wrong_row)

	feed_vbox.add_child(_create_divider())

	# UI Animations
	anim_check = CheckBox.new()
	anim_check.button_pressed = animations_enabled
	anim_check.toggled.connect(func(v): animations_enabled = v; save_config())

	anim_row = SettingRow.new("", "", anim_check)
	anim_lbl = anim_row.title_label
	feed_vbox.add_child(anim_row)

	feed_vbox.add_child(_create_divider())

	# UI Sounds
	sound_check = CheckBox.new()
	sound_check.button_pressed = sounds_enabled
	sound_check.toggled.connect(func(v): sounds_enabled = v; save_config())

	sound_row = SettingRow.new("", "", sound_check)
	sound_lbl = sound_row.title_label
	feed_vbox.add_child(sound_row)

	# Vibration (phones only)
	if Haptics.is_available():
		feed_vbox.add_child(_create_divider())
		var haptics_check := CheckBox.new()
		haptics_check.button_pressed = haptics_enabled
		haptics_check.toggled.connect(func(v): haptics_enabled = v; save_config())
		haptics_row = SettingRow.new("", "", haptics_check)
		feed_vbox.add_child(haptics_row)

func _create_divider() -> HSeparator:
	var div := HSeparator.new()
	div.add_theme_constant_override("separation", 2)
	return div

func _on_theme_changed() -> void:
	if bg != null:
		bg.color = ThemeManager.get_color("bg")
	_update_theme_option_selection()

func _on_language_selected(idx: int) -> void:
	var loc := LocalizationManager.LOCALE_TR if idx == 0 else LocalizationManager.LOCALE_EN
	LocalizationManager.set_locale(loc)
	save_config()

func _on_theme_selected(idx: int) -> void:
	match idx:
		0: ThemeManager.set_theme(ThemeManager.THEME_DARK)
		1: ThemeManager.set_theme(ThemeManager.THEME_AMOLED)
		2: ThemeManager.set_theme(ThemeManager.THEME_LIGHT)
		3: ThemeManager.set_theme(ThemeManager.THEME_SEPIA)
		4: ThemeManager.set_theme(ThemeManager.THEME_FOREST)
		5:
			ThemeManager.set_theme(ThemeManager.THEME_CUSTOM)
			custom_theme_requested.emit()

func _on_font_selected(idx: int) -> void:
	match idx:
		0: FontManager.set_font(FontManager.FONT_MODERN_SANS)
		1: FontManager.set_font(FontManager.FONT_ROUNDED_SANS)
		2: FontManager.set_font(FontManager.FONT_CLASSIC_SERIF)
	save_config()

func _update_font_option_selection() -> void:
	if font_option == null:
		return
	match FontManager.current_font_name:
		FontManager.FONT_MODERN_SANS: font_option.selected = 0
		FontManager.FONT_ROUNDED_SANS: font_option.selected = 1
		FontManager.FONT_CLASSIC_SERIF: font_option.selected = 2

func _update_theme_option_selection() -> void:
	if theme_option == null:
		return
	match ThemeManager.current_theme_name:
		ThemeManager.THEME_DARK: theme_option.selected = 0
		ThemeManager.THEME_AMOLED: theme_option.selected = 1
		ThemeManager.THEME_LIGHT: theme_option.selected = 2
		ThemeManager.THEME_SEPIA: theme_option.selected = 3
		ThemeManager.THEME_FOREST: theme_option.selected = 4
		ThemeManager.THEME_CUSTOM: theme_option.selected = 5

func _update_locale_texts() -> void:
	if back_btn != null:
		back_btn.text = ""
		back_btn.tooltip_text = LocalizationManager.translate("BTN_BACK")
		back_btn.icon = ThemeManager.get_icon("chevron-left")
	if title_label != null:
		title_label.text = LocalizationManager.translate("SETTINGS_TITLE")

	# Section titles
	if sec_appearance_lbl != null:
		sec_appearance_lbl.text = LocalizationManager.upper(LocalizationManager.translate("SETTINGS_SEC_APPEARANCE"))
	if sec_gameplay_lbl != null:
		sec_gameplay_lbl.text = LocalizationManager.upper(LocalizationManager.translate("SETTINGS_SEC_GAMEPLAY"))
	if sec_feedback_lbl != null:
		sec_feedback_lbl.text = LocalizationManager.upper(LocalizationManager.translate("SETTINGS_SEC_FEEDBACK"))

	var is_tr := (LocalizationManager.get_locale() == LocalizationManager.LOCALE_TR)

	# Appearance labels
	if lang_row != null:
		lang_row.set_title(LocalizationManager.translate("SETTING_LANGUAGE"))
		lang_row.set_description(LocalizationManager.translate("SETTING_DESC_LANGUAGE"))
	elif lang_label != null:
		lang_label.text = LocalizationManager.translate("SETTING_LANGUAGE")

	if lang_option != null:
		lang_option.selected = 0 if LocalizationManager.get_locale() == LocalizationManager.LOCALE_TR else 1

	if theme_row != null:
		theme_row.set_title(LocalizationManager.translate("SETTING_THEME"))
		theme_row.set_description(LocalizationManager.translate("SETTING_DESC_THEME"))
	elif theme_label != null:
		theme_label.text = LocalizationManager.translate("SETTING_THEME")

	if theme_option != null:
		theme_option.set_item_text(0, LocalizationManager.translate("THEME_DARK"))
		theme_option.set_item_text(1, LocalizationManager.translate("THEME_AMOLED"))
		theme_option.set_item_text(2, LocalizationManager.translate("THEME_LIGHT"))
		theme_option.set_item_text(3, LocalizationManager.translate("THEME_SEPIA"))
		theme_option.set_item_text(4, LocalizationManager.translate("THEME_FOREST"))
		theme_option.set_item_text(5, LocalizationManager.translate("THEME_CUSTOM"))
		_update_theme_option_selection()

	if custom_theme_row != null:
		custom_theme_row.set_title(LocalizationManager.translate("THEME_CUSTOM"))
		custom_theme_row.set_description(LocalizationManager.translate("SETTING_DESC_CUSTOM_THEME"))
	elif custom_theme_lbl != null:
		custom_theme_lbl.text = LocalizationManager.translate("THEME_CUSTOM")

	if custom_theme_btn != null:
		custom_theme_btn.text = LocalizationManager.translate("BTN_EDIT_CUSTOM_THEME")

	if font_row != null:
		font_row.set_title(LocalizationManager.translate("SETTING_FONT"))
		font_row.set_description(LocalizationManager.translate("SETTING_DESC_FONT"))
	elif font_label != null:
		font_label.text = LocalizationManager.translate("SETTING_FONT")

	if font_option != null:
		font_option.set_item_text(0, LocalizationManager.translate("FONT_MODERN_SANS"))
		font_option.set_item_text(1, LocalizationManager.translate("FONT_ROUNDED_SANS"))
		font_option.set_item_text(2, LocalizationManager.translate("FONT_CLASSIC_SERIF"))
		_update_font_option_selection()

	# Gameplay labels
	if auto_open_row != null:
		auto_open_row.set_title(LocalizationManager.translate("SETTING_AUTO_OPEN"))
		auto_open_row.set_description(LocalizationManager.translate("SETTING_DESC_AUTO_OPEN"))
	elif auto_open_lbl != null:
		auto_open_lbl.text = LocalizationManager.translate("SETTING_AUTO_OPEN")

	if smart_numpad_row != null:
		smart_numpad_row.set_title(LocalizationManager.translate("SETTING_SMART_NUMPAD"))
		smart_numpad_row.set_description(LocalizationManager.translate("SETTING_DESC_SMART_NUMPAD"))
	elif smart_numpad_lbl != null:
		smart_numpad_lbl.text = LocalizationManager.translate("SETTING_SMART_NUMPAD")

	if auto_notes_row != null:
		auto_notes_row.set_title(LocalizationManager.translate("SETTING_AUTO_NOTES"))
		auto_notes_row.set_description(LocalizationManager.translate("SETTING_DESC_AUTO_NOTES"))
	elif auto_notes_lbl != null:
		auto_notes_lbl.text = LocalizationManager.translate("SETTING_AUTO_NOTES")

	if smart_cand_row != null:
		smart_cand_row.set_title(LocalizationManager.translate("SETTING_SMART_CANDIDATES"))
		smart_cand_row.set_description(LocalizationManager.translate("SETTING_DESC_SMART_CANDIDATES"))
	elif smart_candidates_lbl != null:
		smart_candidates_lbl.text = LocalizationManager.translate("SETTING_SMART_CANDIDATES")

	# Feedback labels
	if conflict_row != null:
		conflict_row.set_title(LocalizationManager.translate("SETTING_SHOW_CONFLICTS"))
		conflict_row.set_description(LocalizationManager.translate("SETTING_DESC_SHOW_CONFLICTS"))
	elif conflict_lbl != null:
		conflict_lbl.text = LocalizationManager.translate("SETTING_SHOW_CONFLICTS")

	if wrong_row != null:
		wrong_row.set_title(LocalizationManager.translate("SETTING_SHOW_WRONG"))
		wrong_row.set_description(LocalizationManager.translate("SETTING_DESC_SHOW_WRONG"))

	if anim_row != null:
		anim_row.set_title(LocalizationManager.translate("SETTING_ANIMATIONS"))
		anim_row.set_description(LocalizationManager.translate("SETTING_DESC_ANIMATIONS"))
	elif anim_lbl != null:
		anim_lbl.text = LocalizationManager.translate("SETTING_ANIMATIONS")

	if sound_row != null:
		sound_row.set_title(LocalizationManager.translate("SETTING_SOUNDS"))
		sound_row.set_description(LocalizationManager.translate("SETTING_DESC_SOUNDS"))
	elif sound_lbl != null:
		sound_lbl.text = LocalizationManager.translate("SETTING_SOUNDS")

	if haptics_row != null:
		haptics_row.set_title(LocalizationManager.translate("SETTING_HAPTICS"))
		haptics_row.set_description(LocalizationManager.translate("SETTING_DESC_HAPTICS"))

class_name LoadGameScreen
extends Control

const PuzzleShareService = preload("res://scripts/services/puzzle_share_service.gd")
const LocalizationManager = preload("res://scripts/services/localization_manager.gd")
const ThemeManager = preload("res://scripts/services/theme_manager.gd")
const GameRecordItem = preload("res://scenes/ui/game_record_item.gd")
const ResponsiveManager = preload("res://scripts/services/responsive_manager.gd")

## Displays active, unfinished games with progress and time (GDD §5, §27, §31, §44)
## Redesigned with clean ListItem cards, responsive width, and no horizontal overflow.

signal back_requested()
signal game_selected(game_id: String)
signal import_requested()

var bg: ColorRect
var margin: MarginContainer
var back_btn: Button
var title: Label
var import_btn: Button
var list_vbox: VBoxContainer
var _list_dirty: bool = true

func _init() -> void:
	set_anchors_preset(PRESET_FULL_RECT)

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_build_ui()
	_apply_responsive_layout()
	_update_locale_texts()
	LocalizationManager.add_listener(_update_locale_texts)
	ThemeManager.add_listener(_on_theme_changed)

func _exit_tree() -> void:
	LocalizationManager.remove_listener(_update_locale_texts)
	ThemeManager.remove_listener(_on_theme_changed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_responsive_layout()
	elif what == NOTIFICATION_VISIBILITY_CHANGED:
		if is_visible_in_tree() and _list_dirty:
			refresh_list()

func _apply_responsive_layout() -> void:
	if margin == null:
		return
	ResponsiveManager.apply_content_margins(self, margin, ResponsiveManager.MAX_CONTENT_WIDTH)

func _on_theme_changed() -> void:
	if bg != null:
		bg.color = ThemeManager.get_color("bg")
	if is_visible_in_tree():
		refresh_list()
	else:
		_list_dirty = true

func _build_ui() -> void:
	bg = ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = ThemeManager.get_color("bg")
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
	back_btn.tooltip_text = LocalizationManager.translate("BTN_MENU")
	back_btn.theme_type_variation = "IconButton"
	back_btn.icon = ThemeManager.get_icon("chevron-left")
	back_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_btn.add_theme_constant_override("icon_max_width", 20)
	back_btn.custom_minimum_size = Vector2(44, 44)
	back_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back_btn.pressed.connect(func(): back_requested.emit())
	header.add_child(back_btn)

	title = Label.new()
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.theme_type_variation = "Header"
	header.add_child(title)

	import_btn = Button.new()
	import_btn.theme_type_variation = "SecondaryButton"
	import_btn.icon = ThemeManager.get_icon("download")
	import_btn.add_theme_constant_override("icon_max_width", 18)
	import_btn.add_theme_font_size_override("font_size", 14)
	import_btn.custom_minimum_size = Vector2(96, 42)
	import_btn.pressed.connect(func(): import_requested.emit())
	header.add_child(import_btn)

	var header_sep := HSeparator.new()
	root_vbox.add_child(header_sep)

	# List ScrollContainer
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	root_vbox.add_child(scroll)

	list_vbox = VBoxContainer.new()
	list_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 0)
	scroll.add_child(list_vbox)

func _update_locale_texts() -> void:
	if back_btn != null:
		back_btn.text = ""
		back_btn.tooltip_text = LocalizationManager.translate("BTN_MENU")
		back_btn.icon = ThemeManager.get_icon("chevron-left")
	if title != null:
		title.text = LocalizationManager.translate("SAVED_GAMES_TITLE")
	if import_btn != null:
		import_btn.text = LocalizationManager.translate("BTN_IMPORT")
		import_btn.icon = ThemeManager.get_icon("download")
	if is_visible_in_tree():
		refresh_list()
	else:
		_list_dirty = true

func refresh_list() -> void:
	_list_dirty = false
	if list_vbox == null:
		return
	for c in list_vbox.get_children():
		c.queue_free()

	var games := SaveManager.list_active_games()
	if games.is_empty():
		var empty_container := VBoxContainer.new()
		empty_container.alignment = BoxContainer.ALIGNMENT_CENTER
		empty_container.custom_minimum_size = Vector2(0, 160)
		empty_container.size_flags_horizontal = SIZE_EXPAND_FILL

		var empty_lbl := Label.new()
		empty_lbl.text = LocalizationManager.translate("NO_ACTIVE_GAMES")
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.theme_type_variation = "Subtitle"
		empty_container.add_child(empty_lbl)

		list_vbox.add_child(empty_container)
		return

	var is_tr := (LocalizationManager.get_locale() == LocalizationManager.LOCALE_TR)

	for g in games:
		var gid: String = g.get("game_id", "")
		var item := GameRecordItem.new()
		item.setup_saved_game(g)
		item.play_pressed.connect(func(id): game_selected.emit(id))
		item.share_pressed.connect(func(id, btn):
			var slot_state := SaveManager.load_game_slot(id)
			if slot_state != null and slot_state.initial_puzzle != null:
				var text := PuzzleShareService.export_puzzle_share_text(
					slot_state.seed_value, slot_state.difficulty, slot_state.initial_puzzle
				)
				PuzzleShareService.copy_to_clipboard(text)
				btn.text = "Tamam" if is_tr else "Copied"
				var t := create_tween()
				if t != null:
					t.tween_interval(1.5)
					t.tween_callback(func():
						if is_instance_valid(btn):
							btn.text = LocalizationManager.translate("BTN_SHARE")
					)
		)
		item.delete_pressed.connect(func(id):
			SaveManager.delete_game_slot(id)
			refresh_list()
		)
		list_vbox.add_child(item)

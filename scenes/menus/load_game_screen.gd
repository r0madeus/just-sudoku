class_name LoadGameScreen
extends Control

const PuzzleShareService = preload("res://scripts/services/puzzle_share_service.gd")
const LocalizationManager = preload("res://scripts/services/localization_manager.gd")
const ThemeManager = preload("res://scripts/services/theme_manager.gd")
const GameRecordItem = preload("res://scenes/ui/game_record_item.gd")
const ResponsiveManager = preload("res://scripts/services/responsive_manager.gd")
const AmbientBackdrop = preload("res://scenes/ui/ambient_backdrop.gd")
const GlassPanel = preload("res://scenes/ui/glass_panel.gd")

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
## The rows: one column on a phone, two on a wide screen
var list_vbox: GridContainer
## How many rows the list holds (they arrive a few at a time); a lone row spans the whole width
var _row_total: int = 0
var list_card: PanelContainer
var _list_dirty: bool = true

## Cards built right away (enough to fill a screen); the rest follow a few per frame, so a long
## list of unfinished games no longer freezes the screen while it opens
## Rows per page: a phone screen shows about six, so the first page fills it with room to scroll
const PAGE_SIZE: int = 15
var _pager: ListPager

## Set once _ready is done: every screen is still visible during it, before the app shows
## only the menu, so lists are not built then
var _started: bool = false

func _init() -> void:
	set_anchors_preset(PRESET_FULL_RECT)

func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	_build_ui()
	_apply_responsive_layout()
	_update_locale_texts()
	LocalizationManager.add_listener(_update_locale_texts)
	ThemeManager.add_listener(_on_theme_changed)
	_started = true

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
	ResponsiveManager.apply_content_margins(self, margin, ResponsiveManager.MAX_CONTENT_WIDTH, true)
	_update_list_columns()
	_update_import_label()

## Narrower than this, Import shows only its icon so the title keeps its full width
const IMPORT_LABEL_MIN_WIDTH: float = 400.0

func _update_import_label() -> void:
	if import_btn == null:
		return
	var label := LocalizationManager.translate("BTN_IMPORT")
	var compact: bool = size.x > 0.0 and size.x < IMPORT_LABEL_MIN_WIDTH
	import_btn.text = "" if compact else label
	import_btn.tooltip_text = label
	import_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER if compact else HORIZONTAL_ALIGNMENT_LEFT
	import_btn.custom_minimum_size.x = ResponsiveManager.TOUCH_TARGET_MIN if compact else 96.0

func _on_theme_changed() -> void:
	if bg != null:
		bg.color = ThemeManager.get_color("bg")
	if is_visible_in_tree():
		refresh_list()
	else:
		_list_dirty = true

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
	ThemeManager.set_font_size(import_btn, 14)
	import_btn.custom_minimum_size = Vector2(96, ResponsiveManager.TOUCH_TARGET_MIN)
	import_btn.pressed.connect(func(): import_requested.emit())
	header.add_child(import_btn)
	ResponsiveManager.balance_header(header, title)

	var header_sep := HSeparator.new()
	root_vbox.add_child(header_sep)

	# List ScrollContainer
	var scroll := ScrollContainer.new()
	TouchScroll.attach(scroll)
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	root_vbox.add_child(scroll)
	_pager = ListPager.new(scroll, PAGE_SIZE)

	# Rows sit together in one card, like the groups in Settings (one glass surface per list)
	var list_pad := MarginContainer.new()
	list_pad.size_flags_horizontal = SIZE_EXPAND_FILL
	list_pad.add_theme_constant_override("margin_bottom", 16)
	scroll.add_child(list_pad)
	list_card = GlassPanel.card(20.0, 14, 4)
	list_card.size_flags_vertical = SIZE_SHRINK_BEGIN
	list_pad.add_child(list_card)

	list_vbox = GridContainer.new()
	list_vbox.columns = 1
	list_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("h_separation", 28)
	list_vbox.add_theme_constant_override("v_separation", 0)
	list_card.add_child(list_vbox)

func _update_locale_texts() -> void:
	if back_btn != null:
		back_btn.text = ""
		back_btn.tooltip_text = LocalizationManager.translate("BTN_MENU")
		back_btn.icon = ThemeManager.get_icon("chevron-left")
	if title != null:
		title.text = LocalizationManager.translate("SAVED_GAMES_TITLE")
	if import_btn != null:
		import_btn.icon = ThemeManager.get_icon("download")
		_update_import_label()
	# Not from _ready: every screen is still visible then, before the app shows only the menu
	if is_visible_in_tree() and _started:
		refresh_list()
	else:
		_list_dirty = true

func refresh_list() -> void:
	_list_dirty = false
	if list_vbox == null:
		return
	for c in list_vbox.get_children():
		list_vbox.remove_child(c)
		c.queue_free()

	var games := SaveManager.list_active_games()
	if games.is_empty():
		_pager.start(0, Callable())
		var empty_container := VBoxContainer.new()
		empty_container.alignment = BoxContainer.ALIGNMENT_CENTER
		empty_container.custom_minimum_size = Vector2(0, 160)
		empty_container.size_flags_horizontal = SIZE_EXPAND_FILL

		var empty_lbl := Label.new()
		empty_lbl.text = LocalizationManager.translate("NO_ACTIVE_GAMES")
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.theme_type_variation = "Subtitle"
		# A sentence: it wraps on a narrow phone instead of widening the screen
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_container.add_child(empty_lbl)

		list_vbox.add_child(empty_container)
		_update_list_columns()
		return

	_row_total = games.size()
	_pager.start(games.size(), func(i: int): _add_game_item(games[i]))
	_update_list_columns()

func _add_game_item(g: Dictionary) -> void:
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
			btn.text = LocalizationManager.translate("COPIED_FEEDBACK")
			var t := create_tween()
			if t != null:
				t.tween_interval(1.5)
				t.tween_callback(func():
					if is_instance_valid(btn):
						btn.text = LocalizationManager.translate("BTN_SHARE")
				)
	)
	item.delete_pressed.connect(func(id):
		AppModal.ask(self, LocalizationManager.translate("DELETE_GAME_TITLE"),
			LocalizationManager.translate("DELETE_GAME_BODY"), LocalizationManager.translate("BTN_DELETE"),
			func():
				SaveManager.delete_game_slot(id)
				refresh_list(),
			true)
	)
	list_vbox.add_child(item)

## Two columns of rows on a wide screen (one row alone keeps the full width, with its buttons at
## the far edge instead of mid-screen); the empty-list message keeps the full width
func _update_list_columns() -> void:
	if list_vbox == null:
		return
	var has_rows: bool = list_vbox.get_child_count() > 0 and list_vbox.get_child(0) is GameRecordItem
	var cols: int = ResponsiveManager.list_columns(ResponsiveManager.get_viewport_size(self), _row_total) if has_rows else 1
	if list_vbox.columns != cols:
		list_vbox.columns = cols
		# Each row draws the hairline above it, except on the first line
		for c in list_vbox.get_children():
			c.queue_redraw()

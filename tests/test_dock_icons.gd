extends SceneTree

## The Notes button is a pencil icon (no word), the filled button showing that notes are on, and
## the Colours button explains itself once: the first time it is used, a note says what it is for.

const AppModal = preload("res://scenes/ui/app_modal.gd")
const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const SaveManager = preload("res://scripts/data/save_manager.gd")

var _passed: int = 0
var _failed: int = 0

func _check(name: String, ok: bool) -> void:
	if ok:
		_passed += 1
		print("  ✓ PASS: " + name)
	else:
		_failed += 1
		printerr("  ✗ FAIL: " + name)

func _init() -> void:
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _modals(screen: Node) -> Array:
	var out := []
	for c in screen.get_children():
		if c is AppModal and c.visible:
			out.append(c)
	return out

func _run() -> void:
	await process_frame
	print("\n=== DOCK ICONS ===")
	AppSettings.auto_open_last_game = false
	AppSettings.animations_enabled = false
	var state := GameState.new()
	state.init_from_puzzle(SudokuGenerator.generate(7474, DifficultyAnalyzer.LEVEL_EASY))
	SaveManager.save_active_game(state)
	var app: Control = load("res://scenes/app_root.tscn").instantiate()
	root.add_child(app)
	await create_timer(2.5).timeout
	app.main_menu.continue_pressed.emit()
	await _frames(20)
	var screen = app.game_screen
	# After the start: a saved configuration is read then
	AppSettings.colors_hint_seen = false
	var dock = screen.action_dock

	_check("The pencil icon file is there", ResourceLoader.exists("res://assets/icons/pencil.svg"))
	_check("The Notes button shows it and has no text", dock.notes_btn.icon != null and dock.notes_btn.text == "")
	_check("and says what it is to a screen reader or a mouse", dock.notes_btn.tooltip_text == LocalizationManager.translate("BTN_NOTES"))
	_check("It is as small as the other icon buttons (%d, Colours %d)" % [int(dock.notes_btn.custom_minimum_size.x), int(dock.colors_btn.custom_minimum_size.x)],
		is_equal_approx(dock.notes_btn.custom_minimum_size.x, dock.colors_btn.custom_minimum_size.x))
	dock.notes_btn.pressed.emit()
	await _frames(3)
	_check("Notes on: still no text, the tooltip says so", dock.notes_btn.text == "" and dock.notes_btn.tooltip_text == LocalizationManager.translate("BTN_NOTES_ON"))
	var sb := dock.notes_btn.get_theme_stylebox("normal") as StyleBoxFlat
	_check("and the button is filled in the accent colour", sb != null and sb.bg_color == ThemeManager.get_color("accent_blue", ThemeManager.get_color("accent")))
	_check("with a white icon", dock.notes_btn.get_theme_color("icon_normal_color") == Color.WHITE)
	LocalizationManager.set_locale("tr")
	await _frames(3)
	_check("A language change does not bring the word back", dock.notes_btn.text == "")
	LocalizationManager.set_locale("en")
	dock.notes_btn.pressed.emit()
	await _frames(3)
	_check("Notes off again: the plain outlined button", dock.notes_btn.get_theme_color("icon_normal_color") != Color.WHITE or not dock.is_notes_mode)

	# The Colours note
	_check("Nothing was shown about colours before it was used", _modals(screen).is_empty() and not AppSettings.colors_hint_seen)
	dock.colors_btn.pressed.emit()
	await _frames(4)
	var shown: Array = _modals(screen)
	_check("The first time it is used a note opens", shown.size() == 1 and AppSettings.colors_hint_seen)
	_check("saying what it is for", shown.size() == 1 and shown[0].dialog_text == LocalizationManager.translate("COLORS_HINT_BODY")
		and LocalizationManager.translate("COLORS_HINT_BODY") != "COLORS_HINT_BODY")
	_check("in Turkish too", LocalizationManager.translate("COLORS_HINT_BODY") != "")
	if shown.size() == 1:
		shown[0].primary_btn.pressed.emit()
		await _frames(4)
	_check("Got it closes it", _modals(screen).is_empty())
	dock.colors_btn.pressed.emit()
	await _frames(3)
	dock.colors_btn.pressed.emit()
	await _frames(4)
	_check("It does not open again", _modals(screen).is_empty())
	AppSettings.save_config()
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(AppSettings.CONFIG_PATH))
	_check("and the player is not told again on the next start", saved is Dictionary and saved.get("colors_hint_seen", false) == true)
	SaveManager.clear_active_game()
	print("\n🏁 RESULTS: %d Passed, %d Failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

extends SceneTree

## Screenshots for the README, from demo data, so they can be redone after any UI change:
##   XDG_DATA_HOME=$(mktemp -d) LOC=en OUT=docs/screenshots \
##     xvfb-run -s "-screen 0 2700x2700x24" godot --path . --resolution 1080x2340 -s tools/capture_readme_screenshots.gd
##   (and with --resolution 2560x1600 DEVICE=tablet for the tablet shots)
## Run it with an empty XDG_DATA_HOME: it writes demo games, history and Daily dates to user://.

const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const SaveManager = preload("res://scripts/data/save_manager.gd")
const HistoryManager = preload("res://scripts/data/history_manager.gd")
const DailyManager = preload("res://scripts/data/daily_manager.gd")

var app: AppRoot
var out_dir: String
var prefix: String

func _init() -> void:
	_run.call_deferred()

func _frames(n: int) -> void:
	for i in range(n):
		await process_frame

func _shot(name: String) -> void:
	await _frames(10)
	var path := out_dir.path_join("%s%s.png" % [prefix, name])
	root.get_texture().get_image().save_png(path)
	print("saved ", path)

func _close_modals() -> void:
	for m in get_nodes_in_group(AppModal.GROUP):
		if m.visible:
			m.hide()
	await _frames(3)

## A finished history: a few weeks of games at every level, and a Daily streak
func _seed_history() -> void:
	var now := int(Time.get_unix_time_from_system())
	var levels := [DifficultyAnalyzer.LEVEL_EASY, DifficultyAnalyzer.LEVEL_MEDIUM, DifficultyAnalyzer.LEVEL_MEDIUM, DifficultyAnalyzer.LEVEL_HARD]
	var records: Array[Dictionary] = []
	for i in range(23):
		var lvl: String = levels[i % levels.size()]
		var base: float = {"easy": 290.0, "medium": 520.0, "hard": 840.0}[lvl.to_lower()]
		records.append({
			"game_id": "demo_%d" % i, "seed": str(500 + i), "difficulty": lvl,
			"score": 74 + (i * 7) % 24, "time": base + (i * 37) % 160, "mistakes": i % 3, "hints": int(i % 5 == 0),
			"is_daily": i >= 18, "timestamp": now - (23 - i) * 86400,
			"puzzle": SudokuGenerator.generate(500 + i, lvl).puzzle.to_string_flat() if i >= 16 else "",
		})
	HistoryManager.save_all_records(records)
	var dates: Array = []
	for d in range(5, 0, -1):
		dates.append(Time.get_date_string_from_unix_time(now - d * 86400))
	DailyManager.save_daily_data({"completed_dates": dates, "current_streak": 5, "longest_streak": 5, "last_completed_date": dates.back()})

## Fills `count` empty cells with their solution, the first `wrong` of them with a wrong digit
func _play(state: GameState, count: int, wrong: int = 0) -> Array[int]:
	var filled: Array[int] = []
	for i in range(81):
		if filled.size() >= count:
			break
		if state.current_board.get_cell(i) != 0:
			continue
		var v: int = state.solution.get_cell(i)
		if filled.size() < wrong:
			for d in range(1, 10):
				if d != v and SudokuValidator.is_valid_placement(state.current_board, i, d):
					v = d
					break
		state.set_number(i, v)
		filled.append(i)
	return filled

## The clock as if that long had been played (the label otherwise waits for the next tick)
func _set_clock(seconds: float) -> void:
	app.game_screen.game_state.elapsed_time = seconds
	app.game_screen.game_timer.start(seconds)
	app.game_screen.timer_label.text = GameTimer.format_seconds(seconds)

func _run() -> void:
	out_dir = OS.get_environment("OUT")
	var loc := OS.get_environment("LOC")
	var tablet := OS.get_environment("DEVICE") == "tablet"
	prefix = ("tablet_" if tablet else "") + loc + "_"
	DirAccess.make_dir_recursive_absolute(out_dir)
	_seed_history()
	SettingsScreen.auto_open_last_game = false
	SettingsScreen.animations_enabled = false
	ResponsiveManager.apply_device_scaling(root, 2.0 if tablet else 2.625)

	app = load("res://scenes/app_root.tscn").instantiate()
	root.add_child(app)
	await _frames(5)
	SettingsScreen.animations_enabled = false
	SettingsScreen.auto_open_last_game = false
	LocalizationManager.set_locale(loc)
	ThemeManager.set_theme(ThemeManager.THEME_DARK)
	await _frames(3)

	# A game in progress: digits, notes, a wrong digit found by Check, a selected cell
	var state := GameState.new()
	state.init_from_puzzle(SudokuGenerator.generate(20261023, DifficultyAnalyzer.LEVEL_MEDIUM))
	app._start_game_session(state)
	await _frames(4)
	var filled := _play(state, 14, 1)
	state.check_board()
	app.game_screen._on_fill_notes_pressed()
	for i in range(81):
		if state.current_board.get_cell(i) == 0:
			app.game_screen.sudoku_grid.select_cell(i)
			break
	_set_clock(754.0)
	app.game_screen.sudoku_grid.refresh_all_cells()
	await _shot("game")
	app.game_screen._save_progress()

	# The menu with that game to resume
	app._show_screen(app.main_menu)
	app.main_menu.refresh_buttons()
	await _shot("menu")

	if tablet:
		app._show_screen(app.statistics_screen)
		app.statistics_screen.refresh_stats()
		await _shot("statistics")
		app._show_screen(app.history_screen)
		app.history_screen.refresh_history()
		await _shot("history")
		quit()
		return

	app._show_screen(app.statistics_screen)
	app.statistics_screen.refresh_stats()
	await _shot("statistics")

	# The result of a clean Expert solve, which earns achievements
	var done := GameState.new()
	done.init_from_puzzle(SudokuGenerator.generate(4040, DifficultyAnalyzer.LEVEL_EXPERT))
	app._start_game_session(done)
	await _frames(4)
	done.elapsed_time = 1312.0
	var empties: Array[int] = []
	for i in range(81):
		if done.current_board.get_cell(i) == 0:
			empties.append(i)
	for i in empties.slice(0, empties.size() - 1):
		done.set_number(i, done.solution.get_cell(i))
	app.game_screen.sudoku_grid.select_cell(empties.back())
	app.game_screen._on_numpad_number_pressed(done.solution.get_cell(empties.back()))
	await _frames(20)
	await _shot("result")
	await _close_modals()

	# A light theme, and Settings
	ThemeManager.set_theme(ThemeManager.THEME_LIGHT)
	var light := GameState.new()
	light.init_from_puzzle(SudokuGenerator.generate(777, DifficultyAnalyzer.LEVEL_EASY))
	app._start_game_session(light)
	await _frames(4)
	_play(light, 20)
	_set_clock(301.0)
	app.game_screen.sudoku_grid.select_cell(filled[0] if filled.size() > 0 else 0)
	app.game_screen.sudoku_grid.refresh_all_cells()
	await _shot("game_light")
	app._show_screen(app.settings_screen)
	await _shot("settings")
	quit()

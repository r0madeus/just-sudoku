class_name PuzzlePrefetcher
extends RefCounted

const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const AsyncPuzzleGenerator = preload("res://scripts/services/async_puzzle_generator.gd")
const DailyManager = preload("res://scripts/data/daily_manager.gd")

## Keeps one ready puzzle per difficulty (plus today's Daily) generated in the background,
## so New Game and Daily open instantly instead of waiting for the generator (GDD §2.3, §7).
## One generation at a time on a single worker keeps CPU and battery impact low; everything
## here runs on the main thread, generation results arrive through call_deferred.

const DAILY_KEY: String = "daily"
const LEVELS: Array[String] = [
	DifficultyAnalyzer.LEVEL_MEDIUM,
	DifficultyAnalyzer.LEVEL_EASY,
	DifficultyAnalyzer.LEVEL_HARD,
	DifficultyAnalyzer.LEVEL_EXPERT
]

static var _ready_puzzles: Dictionary = {}
static var _wanted: Array[String] = []
static var _running: bool = false
static var _inflight_key: String = ""
static var _inflight_id: int = 0

## Starts filling the cache. `priority_difficulty` (usually the last one played) goes first.
static func start(priority_difficulty: String = DifficultyAnalyzer.LEVEL_MEDIUM) -> void:
	_running = true
	_wanted.clear()
	_wanted.append(priority_difficulty)
	if not DailyManager.has_today_game():
		_wanted.append(DAILY_KEY)
	for level in LEVELS:
		if not _wanted.has(level):
			_wanted.append(level)
	_pump()

## Stops generating; puzzles already prepared stay available
static func stop() -> void:
	_running = false
	if _inflight_id != 0:
		AsyncPuzzleGenerator.cancel_request(_inflight_id)
	_inflight_key = ""
	_inflight_id = 0

static func is_ready(difficulty: String) -> bool:
	return _ready_puzzles.has(difficulty)

## Hands out a prepared puzzle (or null) and starts refilling that slot
static func take(difficulty: String) -> SudokuGenerator.GeneratedPuzzle:
	var gen: SudokuGenerator.GeneratedPuzzle = _ready_puzzles.get(difficulty, null)
	_ready_puzzles.erase(difficulty)
	_pump()
	return gen

## Today's Daily puzzle if it has been prepared for exactly this seed
static func take_daily(daily_seed: int) -> SudokuGenerator.GeneratedPuzzle:
	var gen: SudokuGenerator.GeneratedPuzzle = _ready_puzzles.get(DAILY_KEY, null)
	if gen == null or gen.seed_value != daily_seed:
		return null
	_ready_puzzles.erase(DAILY_KEY)
	return gen

## Returns an unused puzzle (e.g. the preview the player looked at but did not start)
static func put_back(gen: SudokuGenerator.GeneratedPuzzle) -> void:
	if gen == null or _ready_puzzles.has(gen.difficulty):
		return
	_ready_puzzles[gen.difficulty] = gen

static func _pump() -> void:
	if not _running:
		return
	# A request cancelled elsewhere never reports back, so drop it instead of waiting forever
	if _inflight_key != "" and not AsyncPuzzleGenerator.is_request_active(_inflight_id):
		_inflight_key = ""
		_inflight_id = 0
	if _inflight_key != "":
		return
	for key in _wanted:
		if _ready_puzzles.has(key):
			continue
		_launch(key)
		return

static func _launch(key: String) -> void:
	var seed_val: int = DailyManager.get_today_seed() if key == DAILY_KEY else SudokuGenerator.generate_new_seed()
	var difficulty: String = DifficultyAnalyzer.LEVEL_MEDIUM if key == DAILY_KEY else key
	_inflight_key = key
	_inflight_id = AsyncPuzzleGenerator.request_puzzle_async(
		seed_val,
		difficulty,
		func(gen: SudokuGenerator.GeneratedPuzzle) -> void: _on_generated(key, gen),
		1
	)

static func _on_generated(key: String, gen: SudokuGenerator.GeneratedPuzzle) -> void:
	_inflight_key = ""
	_inflight_id = 0
	if gen != null and _running:
		_ready_puzzles[key] = gen
	_pump()

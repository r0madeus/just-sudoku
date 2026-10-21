class_name AsyncPuzzleGenerator
extends RefCounted

const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")

## Background thread puzzle generator using WorkerThreadPool (GDD §11, §41)
## Prevents frame drops / UI freeze on complex puzzles (Hard/Expert)

static var _current_request_id: int = 0
static var _active_tasks: Dictionary = {}

## Requests puzzle generation in background thread.
## callback must have signature func(puzzle: SudokuGenerator.GeneratedPuzzle)
## Returns unique request_id
static func request_puzzle_async(
	seed_val: int,
	difficulty: String,
	callback: Callable
) -> int:
	_current_request_id += 1
	var req_id: int = _current_request_id
	_active_tasks[req_id] = false

	var task_callable := func():
		var is_cancelled_check := func() -> bool:
			return _active_tasks.get(req_id, false) == true

		var result = SudokuGenerator.generate(seed_val, difficulty, is_cancelled_check)
		_dispatch_completion.call_deferred(req_id, result, callback)

	WorkerThreadPool.add_task(task_callable, true)
	return req_id

## Cancels a specific request if still running
static func cancel_request(req_id: int) -> void:
	if _active_tasks.has(req_id):
		_active_tasks[req_id] = true

## Cancels all ongoing background generations
static func cancel_all() -> void:
	for k in _active_tasks.keys():
		_active_tasks[k] = true

static func _dispatch_completion(req_id: int, result: SudokuGenerator.GeneratedPuzzle, callback: Callable) -> void:
	var was_cancelled: bool = _active_tasks.get(req_id, false)
	_active_tasks.erase(req_id)

	if not was_cancelled and callback.is_valid():
		callback.call(result)

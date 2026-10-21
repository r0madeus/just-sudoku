class_name GameTimer
extends Node

## Accurate game timer tracking active play time
## Pauses automatically when game is paused or application goes to background.

signal time_updated(elapsed_seconds: float)
signal second_ticked(total_seconds: int)

var elapsed_time: float = 0.0
var is_running: bool = false
var _last_emitted_sec: int = 0

func _process(delta: float) -> void:
	if not is_running:
		return

	elapsed_time += delta
	time_updated.emit(elapsed_time)

	var current_sec: int = int(elapsed_time)
	if current_sec > _last_emitted_sec:
		_last_emitted_sec = current_sec
		second_ticked.emit(current_sec)

func start(initial_time: float = 0.0) -> void:
	elapsed_time = initial_time
	_last_emitted_sec = int(elapsed_time)
	is_running = true

func pause() -> void:
	is_running = false

func resume() -> void:
	is_running = true

func stop() -> void:
	is_running = false

func reset() -> void:
	elapsed_time = 0.0
	_last_emitted_sec = 0
	is_running = false

static func format_seconds(total_seconds: float) -> String:
	var total_sec: int = int(total_seconds)
	var hrs: int = total_sec / 3600
	var mins: int = (total_sec % 3600) / 60
	var secs: int = total_sec % 60

	if hrs > 0:
		return "%02d:%02d:%02d" % [hrs, mins, secs]
	return "%02d:%02d" % [mins, secs]

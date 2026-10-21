class_name Haptics
extends RefCounted

## Short vibrations for touch feedback on phones (no-op on desktop or when disabled in Settings)

static func is_available() -> bool:
	return OS.has_feature("mobile")

static func _vibrate(duration_ms: int, amplitude: float) -> void:
	if not SettingsScreen.haptics_enabled or not is_available():
		return
	Input.vibrate_handheld(duration_ms, amplitude)

static func tap() -> void:
	_vibrate(10, 0.3)

static func conflict() -> void:
	_vibrate(40, 0.8)

static func unit_completed() -> void:
	_vibrate(20, 0.5)

static func game_completed() -> void:
	_vibrate(70, 0.9)

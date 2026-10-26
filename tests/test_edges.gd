extends SceneTree

## The filled capsule buttons (Continue, New Game, Play) have no border. A border over the
## anti-aliased edge of a fill shows as a dark ring with a speckled fringe on a phone, which read
## as broken edges.

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

func _run() -> void:
	await process_frame
	print("\n=== EDGES ===")
	for theme_name in ["Dark", "AMOLED", "Light", "Sepia", "Forest"]:
		ThemeManager.set_theme(theme_name)
		var theme := ThemeManager.build_godot_theme()
		var bordered := false
		for state in ["normal", "hover", "pressed"]:
			var sb := theme.get_stylebox(state, "PrimaryButton") as StyleBoxFlat
			if sb == null or sb.border_width_left > 0 or sb.border_width_top > 0 or sb.border_width_right > 0 or sb.border_width_bottom > 0:
				bordered = true
		_check("%s: the filled capsule has no border in any state" % theme_name, not bordered)
	var sb := ThemeManager.build_godot_theme().get_stylebox("normal", "PrimaryButton") as StyleBoxFlat
	_check("and keeps its soft shadow and smoothed edge", sb.shadow_size > 0 and sb.anti_aliasing and sb.corner_detail >= 12)
	ThemeManager.set_theme("Dark")
	print("\n🏁 RESULTS: %d Passed, %d Failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

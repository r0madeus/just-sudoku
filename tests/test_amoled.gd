extends SceneTree

## AMOLED is black: the page has no glows (they would light pixels and make it look like Dark),
## and the glass cards over it are plain dark surfaces that do not copy the screen. Other themes
## keep their glows and their blurred glass.

const AmbientBackdrop = preload("res://scenes/ui/ambient_backdrop.gd")
const GlassPanel = preload("res://scenes/ui/glass_panel.gd")

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

func _run() -> void:
	await process_frame
	print("\n=== AMOLED ===")
	AppSettings.auto_open_last_game = false
	AppSettings.animations_enabled = false
	var back := AmbientBackdrop.new()
	var glass := GlassPanel.new()
	root.add_child(back)
	root.add_child(glass)
	await _frames(2)

	ThemeManager.set_theme("AMOLED")
	await _frames(2)
	_check("AMOLED has no glows", is_zero_approx(float(back.material.get_shader_parameter("strength"))))
	_check("and no noise to light a pixel", is_zero_approx(float(back.material.get_shader_parameter("dither"))))
	_check("Its page colour is black", back.color == Color.BLACK)
	_check("The glass over it does not read the screen",
		not glass.glass_rect.material.shader.code.contains("hint_screen_texture"))

	ThemeManager.set_theme("Dark")
	await _frames(2)
	_check("Dark keeps its glows", float(back.material.get_shader_parameter("strength")) > 0.05)
	_check("and its dither", float(back.material.get_shader_parameter("dither")) > 0.0)
	_check("and its blurred glass", glass.glass_rect.material.shader.code.contains("hint_screen_texture"))
	ThemeManager.set_theme("AMOLED")
	await _frames(2)
	_check("Going back to AMOLED switches the glass back to plain", not glass.glass_rect.material.shader.code.contains("hint_screen_texture"))
	back.queue_free()
	glass.queue_free()

	if DisplayServer.get_name() != "headless":
		var app: Control = load("res://scenes/app_root.tscn").instantiate()
		root.add_child(app)
		await create_timer(2.5).timeout
		await _frames(3)
		var img := root.get_texture().get_image()
		var lit := 0
		for p in [Vector2i(3, 3), Vector2i(img.get_width() - 4, img.get_height() / 2), Vector2i(img.get_width() / 2, img.get_height() - 4), Vector2i(img.get_width() - 4, 4)]:
			var c := img.get_pixelv(p)
			if c.r8 + c.g8 + c.b8 > 0:
				lit += 1
		_check("The home screen's page is black where there is nothing on it (%d of 4 spots lit)" % lit, lit == 0)
		app.queue_free()
		await process_frame
	ThemeManager.set_theme("Dark")
	print("\n🏁 RESULTS: %d Passed, %d Failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

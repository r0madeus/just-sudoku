extends SceneTree

## Android release settings: the renderer the game is tested with, textures Android can export,
## a splash in the app's colour, and an export that ships no tests or tools and asks for
## nothing beyond vibration.

var tests_passed: int = 0
var tests_failed: int = 0

func assert_true(condition: bool, msg: String) -> void:
	if condition:
		tests_passed += 1
		print("  ✓ PASS: %s" % msg)
	else:
		tests_failed += 1
		printerr("  ✗ FAIL: %s" % msg)

func _init() -> void:
	print("========================================")
	print("🧪 RUNNING ANDROID CONFIG TESTS")
	print("========================================")
	var gl := "gl_compatibility"
	assert_true(ProjectSettings.get_setting("rendering/renderer/rendering_method") == gl
		and ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile") == gl,
		"Compatibility renderer everywhere: the one the tests and screenshots run on")
	assert_true(int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_2d", 0)) == 0,
		"No 2D MSAA: every edge is anti-aliased already, and MSAA would multiply a phone's fill cost")
	assert_true(ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc", false),
		"ETC2/ASTC import on (Android export requires it)")
	var bg: Color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color")
	assert_true(ProjectSettings.get_setting("application/boot_splash/bg_color").is_equal_approx(bg),
		"Boot splash has the app's background colour, so start-up does not flash")
	assert_true(int(ProjectSettings.get_setting("display/window/handheld/orientation")) == DisplayServer.SCREEN_PORTRAIT,
		"Phones start in portrait (tablets unlock rotation at run time)")

	var presets := ConfigFile.new()
	assert_true(presets.load("res://export_presets.cfg") == OK, "Export presets load")
	var exclude: String = presets.get_value("preset.0", "exclude_filter", "")
	assert_true(presets.get_value("preset.0", "platform", "") == "Android" and exclude.contains("tests/*") and exclude.contains("addons/godot_mcp/*"),
		"Android export leaves out tests and the editor add-on")
	var perms: Array = []
	for key in presets.get_section_keys("preset.0.options"):
		if key.begins_with("permissions/") and key != "permissions/custom_permissions" and presets.get_value("preset.0.options", key) == true:
			perms.append(key)
	assert_true(perms == ["permissions/vibrate"], "Only the vibration permission %s" % str(perms))
	assert_true(presets.get_value("preset.0.options", "architectures/arm64-v8a", false), "64-bit ARM build")
	assert_true(Color(presets.get_value("preset.0.options", "splash_screen/background_color", Color.BLACK)).is_equal_approx(bg),
		"Android splash in the app's background colour")

	print("========================================")
	print("🏁 RESULTS: %d Passed, %d Failed" % [tests_passed, tests_failed])
	print("========================================")
	quit(1 if tests_failed > 0 else 0)

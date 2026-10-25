extends SceneTree

## The name on the home screen: "Just Sudoku" in DM Serif Display, left-aligned with the cards,
## ending in a small accent square (the icon's lit cell) whose foot sits on the baseline. There
## is no tagline and no rule under it. The all-caps serif title with a tracked tagline and a
## hairline looked like a template.

const AppRoot = preload("res://scenes/app_root.gd")

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
	print("\n=== WORDMARK ===")
	AppSettings.auto_open_last_game = false
	AppSettings.animations_enabled = false
	_test_font_files()
	await _test_header()
	await _test_fits()
	print("\n🏁 RESULTS: %d Passed, %d Failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)

func _test_font_files() -> void:
	var font := ThemeManager.get_font_display()
	_check("DM Serif Display is bundled and loads", font != null and font is FontFile)
	_check("with its licence next to the other fonts", FileAccess.file_exists("res://assets/fonts/licenses/DMSerifDisplay-OFL.txt"))
	var missing := ""
	for ch in "Just Sudoku":
		if not font.has_char(ch.unicode_at(0)):
			missing += ch
	_check("It has every letter of the name ('%s' missing)" % missing, missing.is_empty())
	var turkish := ""
	for ch in "ığşİĞŞçöüÇÖÜ":
		if not font.has_char(ch.unicode_at(0)):
			turkish += ch
	_check("and the Turkish letters, for any heading set in it later ('%s' missing)" % turkish, turkish.is_empty())
	var theme := ThemeManager.build_godot_theme()
	_check("The Wordmark style uses it, whatever UI font is chosen", theme.get_font("font", "Wordmark") == font)

func _app() -> Control:
	var app: Control = load("res://scenes/app_root.tscn").instantiate()
	root.add_child(app)
	return app

func _test_header() -> void:
	var app := _app()
	await _frames(6)
	var menu = app.main_menu
	var title: Label = menu.title_label
	_check("The title is the name in sentence case", title.text == "Just Sudoku")
	_check("in the Wordmark style, resolved to DM Serif Display",
		title.theme_type_variation == "Wordmark" and title.get_theme_font("font") == ThemeManager.get_font_display())
	LocalizationManager.set_locale("tr")
	await _frames(2)
	_check("It is the same in Turkish", title.text == "Just Sudoku")
	LocalizationManager.set_locale("en")
	_check("There is no tagline and no rule under it", menu.get("subtitle_label") == null and menu.get("masthead_separator") == null)

	var card: Control = menu.resume_card
	_check("The name is left-aligned with the cards (%s and %s)" % [title.get_global_rect().position.x, card.get_global_rect().position.x],
		absf(title.get_global_rect().position.x - card.get_global_rect().position.x) <= 1.0)

	var dot: Panel = menu.wordmark_dot
	var px: int = title.get_theme_font_size("font_size")
	var font: Font = title.get_theme_font("font")
	var baseline: float = title.get_global_rect().position.y + font.get_ascent(px)
	var rect := dot.get_global_rect()
	_check("The full stop is a square of about a quarter of the type size (%d px for %d)" % [int(rect.size.x), px],
		absf(rect.size.x - px * 0.27) <= 1.5 and absf(rect.size.x - rect.size.y) < 0.5)
	_check("its foot on the baseline (%.1f and %.1f)" % [rect.end.y, baseline], absf(rect.end.y - baseline) <= 1.5)
	_check("just after the last letter", rect.position.x > title.get_global_rect().end.x - 1.0 and rect.position.x - title.get_global_rect().end.x < 12.0)
	var sb := dot.get_theme_stylebox("panel") as StyleBoxFlat
	var accent: Color = ThemeManager.get_color("accent_blue", ThemeManager.get_color("accent"))
	_check("in the accent colour, rounded like the icon's cell", sb != null and sb.bg_color == accent and sb.corner_radius_top_left >= 2)

	ThemeManager.set_theme("Light")
	await _frames(3)
	var sb2 := menu.wordmark_dot.get_theme_stylebox("panel") as StyleBoxFlat
	_check("A new theme keeps the stop in the accent", sb2 != null and sb2.bg_color == ThemeManager.get_color("accent_blue", ThemeManager.get_color("accent")))
	ThemeManager.set_theme("Dark")
	app.queue_free()
	await process_frame

func _test_fits() -> void:
	var app := _app()
	await _frames(4)
	for dp in [320.0, 360.0, 411.0]:
		ResponsiveManager.apply_device_scaling(root, root.size.x / dp)
		await _frames(5)
		var title: Label = app.main_menu.title_label
		var dot_end: float = app.main_menu.wordmark_dot.get_global_rect().end.x
		_check("At %d dp the name and its stop fit on the screen (end at %.0f)" % [int(dp), dot_end], dot_end <= app.size.x - 8.0)
	app.queue_free()
	await process_frame

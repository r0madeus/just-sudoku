extends SceneTree

## GlassPanel / AmbientBackdrop: glass covers the whole padded panel, follows the theme,
## and the dock, modals and pause overlay are built on it.

const GlassPanel = preload("res://scenes/ui/glass_panel.gd")
const AmbientBackdrop = preload("res://scenes/ui/ambient_backdrop.gd")
const GameActionDock = preload("res://scenes/ui/game_action_dock.gd")
const SudokuGenerator = preload("res://scripts/core/sudoku_generator.gd")
const DifficultyAnalyzer = preload("res://scripts/core/difficulty_analyzer.gd")
const GameState = preload("res://scripts/gameplay/game_state.gd")
const AppModal = preload("res://scenes/ui/app_modal.gd")
const ThemeManager = preload("res://scripts/services/theme_manager.gd")
const ResumeCard = preload("res://scenes/menus/resume_card.gd")
const MainMenu = preload("res://scenes/menus/main_menu.gd")

var passed: int = 0
var failed: int = 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		passed += 1
		print("  ✓ PASS: ", msg)
	else:
		failed += 1
		printerr("  ✗ FAIL: ", msg)

func _frames(n: int = 4) -> void:
	for i in range(n):
		await process_frame

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	print("--- GLASS COMPONENTS ---")
	ThemeManager.set_theme(ThemeManager.THEME_DARK)
	var root := get_root()

	# GlassPanel covers padding too (PanelContainer would otherwise squeeze the glass inward)
	var panel := GlassPanel.new()
	panel.pad_h = 20
	panel.pad_v = 16
	panel.custom_minimum_size = Vector2(240, 120)
	var label := Label.new()
	label.text = "content"
	panel.add_child(label)
	root.add_child(panel)
	await _frames()
	var margin: float = panel._quad_margin()
	_check(panel.glass_rect.position.is_equal_approx(Vector2(-margin, -margin)), "Glass layer is centred on the panel (shadow margin %.0f px)" % margin)
	_check(panel.glass_rect.size.is_equal_approx(panel.size + Vector2(margin, margin) * 2.0), "Glass layer covers the whole panel including padding, plus the shadow margin")
	_check(label.position.x >= 20.0 - 0.5, "Content stays inside the padding (x = %.1f)" % label.position.x)

	var mat := panel.glass_rect.material as ShaderMaterial
	_check(mat != null and (mat.get_shader_parameter("rect_size") as Vector2).is_equal_approx(panel.size), "Shader rect size follows the panel size")

	var dark_tint: Color = mat.get_shader_parameter("tint_color")
	ThemeManager.set_theme(ThemeManager.THEME_LIGHT)
	await _frames()
	var light_tint: Color = mat.get_shader_parameter("tint_color")
	_check(light_tint.get_luminance() > dark_tint.get_luminance() + 0.3, "Glass tint follows the theme (dark -> light)")

	# Dock is a GlassPanel with a working glass layer
	var dock := GameActionDock.new()
	root.add_child(dock)
	await _frames()
	_check(dock is GlassPanel and dock.glass_rect != null, "GameActionDock is a GlassPanel with a glass layer")
	_check(is_equal_approx(dock.corner_radius, 26.0) and not dock.elevated, "Dock uses the light capsule glass settings")

	# Modals sit on glass; ambient replaces the scrim when requested
	var modal := AppModal.new()
	root.add_child(modal)
	await _frames()
	_check(modal.modal_panel is GlassPanel, "AppModal panel is a GlassPanel")
	_check(modal.backdrop.visible and not modal.ambient.visible, "Default modal uses the frosted scrim")
	modal.ambient_background = true
	_check(modal.ambient.visible and not modal.backdrop.visible, "ambient_background swaps the scrim for the ambient glows")

	# Ambient backdrop keeps `color` as the flat base and follows the theme
	var ambient := AmbientBackdrop.new()
	root.add_child(ambient)
	await _frames()
	ThemeManager.set_theme(ThemeManager.THEME_DARK)
	await _frames()
	var dark_base := ambient.color
	ThemeManager.set_theme(ThemeManager.THEME_LIGHT)
	await _frames()
	_check(ambient.color.get_luminance() > dark_base.get_luminance() + 0.3, "AmbientBackdrop base colour follows the theme")
	var amb_mat := ambient.material as ShaderMaterial
	var strength_full: float = amb_mat.get_shader_parameter("strength")
	ambient.intensity = 0.0
	_check(is_zero_approx(amb_mat.get_shader_parameter("strength")) and strength_full > 0.0, "intensity 0 turns the glows off")

	# Home resume card: invitation without a game, live progress with one
	var card := ResumeCard.new()
	root.add_child(card)
	await _frames()
	_check(not card.has_game and card.body_label.visible and not card.progress_bar.visible, "Resume card shows the invitation when there is no game")
	var gen := SudokuGenerator.generate(321, DifficultyAnalyzer.LEVEL_EASY)
	var state := GameState.new()
	state.init_from_puzzle(gen)
	var first_empty: int = -1
	for i in range(81):
		if state.current_board.get_cell(i) == 0:
			first_empty = i
			break
	state.current_board.set_cell(first_empty, gen.solution.get_cell(first_empty), false)
	card.set_game(state)
	await _frames()
	_check(card.has_game and card.progress_bar.visible and card.progress_bar.value > 0.0, "Resume card shows progress for an active game (%d%%)" % int(card.progress_bar.value))
	var tapped := [false]
	card.pressed.connect(func(): tapped[0] = true)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	card._gui_input(click)
	_check(tapped[0], "Tapping the resume card emits pressed")
	card.set_game(null)
	tapped[0] = false
	card._gui_input(click)
	_check(not tapped[0], "The empty card is not tappable")

	var menu := MainMenu.new()
	root.add_child(menu)
	menu.size = Vector2(540, 960)
	await _frames()
	_check(menu.resume_card != null and menu.daily_panel is GlassPanel and menu.nav_glass != null, "Main menu uses glass for resume card, daily strip and navigation")

	print("RESULTS: %d Passed, %d Failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

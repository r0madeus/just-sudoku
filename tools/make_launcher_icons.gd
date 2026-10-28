extends SceneTree

## Draws the app icon and writes every file that carries it, from one drawing: a flat blue tile
## with a white serif 5 on it, the typeface and the blue of the browser version's loading screen
## ("Just Sudoku" in DM Serif Display with a blue square for a full stop). No gradient, no glow.
##  - assets/launcher/adaptive_{background,foreground,monochrome}(.svg, _432x432.png): the
##    Android adaptive icon layers. 108 dp canvas; launchers show the middle 72 dp through their
##    own mask (circle, squircle, teardrop...) and only the 66 dp circle in the middle is sure to
##    show, so the digit stays inside it (tests/test_release.gd checks it, pixel by pixel).
##    The background is a rounded tile with transparent margin, not a full-bleed square: some
##    launchers (seen on a real phone) draw the whole 108 dp canvas without cropping or
##    masking it, and a full-bleed background then shows as a hard-cornered square with the digit
##    lost in the middle. A masking launcher crops the tile to its own shape; the tile is larger
##    than the visible 72 dp so no transparent edge shows. A flat tile fills the slot on such a
##    launcher as completely as full-art icons do.
##    The monochrome layer is what Android 13+ tints for themed icons: the digit alone.
##  - assets/launcher/main(.svg, _192x192.png): the legacy icon, for launchers without adaptive
##    icons: the visible 72 dp on a rounded square.
##  - assets/launcher/pwa_{144,180,512}.png: the install icons of the browser version (full bleed).
##  - icon.svg: the project icon (window, editor, the browser version's tab icon, and the Windows exe,
##    whose Windows preset embeds it).
##  - packaging/linux/io.github.r0madeus.JustSudoku.{svg,png}: the Linux menu and AppImage icon.
##  - fastlane/metadata/android/*/images/icon.png: the 512 px store icon, full bleed (the stores
##    round the corners themselves).
## The 5 is the glyph of DM Serif Display (assets/fonts, SIL OFL) as a drawn path, so no font is
## needed to render it.
##   godot --headless --path . -s tools/make_launcher_icons.gd

const LAUNCHER_DIR: String = "res://assets/launcher/"
const STORE_LOCALES: Array[String] = ["en-US", "tr-TR"]

const BLUE: String = "#2563eb"
const INK: String = "#ffffff"

const CENTRE: float = 54.0
## The adaptive background tile: 98 dp, centred, corners rounded to 22%. It covers the whole
## visible 72 dp square, corners included, for every mask (a teardrop has a square corner).
const TILE: float = 98.0
## The digit's height in dp on the 108 dp canvas: as large as the 66 dp safe circle allows
const DIGIT_HEIGHT: float = 54.0

## The glyph "5" in font units (1000 per em; bounding box x 60..501, y -15..634, y up)
const GLYPH_PATH: String = "M244 -15Q186 -15 140.5 -4.5Q95 6 60 30L67 156H77L123 74Q143 38 172.0 21.5Q201 5 236 5Q351 5 351 180Q351 259 320.5 300.0Q290 341 230 341Q202 341 174.5 333.5Q147 326 124 314L106 325L128 634H478V520H148L134 347Q157 364 196.0 379.0Q235 394 278 394Q343 394 393.5 371.0Q444 348 472.5 303.5Q501 259 501 194Q501 127 467.5 80.0Q434 33 376.0 9.0Q318 -15 244 -15Z"
const GLYPH_BOX: Rect2 = Rect2(60.0, -15.0, 441.0, 649.0)

func _init() -> void:
	_write_layer("adaptive_background", _tile(TILE, (108.0 - TILE) / 2.0, TILE * 0.22), 432)
	_write_layer("adaptive_foreground", _digit(), 432)
	_write_layer("adaptive_monochrome", _digit(), 432)
	var legacy := _tile(72.0, 18.0, 72.0 * 0.22) + _digit()
	_write("assets/launcher/main.svg", _svg(legacy, 192, 18.0, 72.0))
	_render(_svg(legacy, 192, 18.0, 72.0), LAUNCHER_DIR + "main_192x192.png")
	_write("icon.svg", _svg(legacy, 128, 18.0, 72.0))
	_write("packaging/linux/io.github.r0madeus.JustSudoku.svg", _svg(legacy, 128, 18.0, 72.0))
	_render(_svg(legacy, 512, 18.0, 72.0), "res://packaging/linux/io.github.r0madeus.JustSudoku.png")
	var store := _svg(_tile(72.0, 18.0, 0.0) + _digit(), 512, 18.0, 72.0)
	for locale in STORE_LOCALES:
		_render(store, "res://fastlane/metadata/android/%s/images/icon.png" % locale)
	# The web app's install icons (the browser version can be installed like an app)
	for px in [144, 180, 512]:
		_render(_svg(_tile(72.0, 18.0, 0.0) + _digit(), px, 18.0, 72.0), LAUNCHER_DIR + "pwa_%dx%d.png" % [px, px])
	print("Launcher icons written")
	quit()

func _write_layer(name: String, body: String, px: int) -> void:
	var svg := _svg(body, px, 0.0, 108.0)
	_write("assets/launcher/%s.svg" % name, svg)
	_render(svg, LAUNCHER_DIR + "%s_%dx%d.png" % [name, px, px])

## An SVG of `px` pixels showing the square of side `side` dp from (`origin`, `origin`)
func _svg(body: String, px: int, origin: float, side: float) -> String:
	return ("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"%s %s %s %s\">\n" % [px, px, _n(origin), _n(origin), _n(side), _n(side)]
		+ body + "</svg>\n")

func _tile(side: float, origin: float, radius: float) -> String:
	return "<rect x=\"%s\" y=\"%s\" width=\"%s\" height=\"%s\" rx=\"%s\" fill=\"%s\"/>\n" % [_n(origin), _n(origin), _n(side), _n(side), _n(radius), BLUE]

## The 5, centred on the canvas (the font's y axis points up, the SVG's down)
func _digit() -> String:
	var s: float = DIGIT_HEIGHT / GLYPH_BOX.size.y
	var mid: Vector2 = GLYPH_BOX.get_center()
	return "<path d=\"%s\" fill=\"%s\" transform=\"translate(%s %s) scale(%s %s) translate(%s %s)\"/>\n" % [GLYPH_PATH, INK, _n(CENTRE), _n(CENTRE), _n(s), _n(-s), _n(-mid.x), _n(-mid.y)]

func _n(v: float) -> String:
	return String.num(v, 3)

func _write(rel: String, text: String) -> void:
	var f := FileAccess.open("res://" + rel, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func _render(svg: String, path: String) -> void:
	var img := Image.new()
	var err := img.load_svg_from_string(svg, 1.0)
	if err != OK:
		push_error("Could not render %s" % path)
		return
	img.save_png(ProjectSettings.globalize_path(path))

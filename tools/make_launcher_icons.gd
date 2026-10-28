extends SceneTree

## Draws the app icon and writes every file that carries it, from one drawing:
##  - assets/launcher/adaptive_{background,foreground,monochrome}(.svg, _432x432.png): the
##    Android adaptive icon layers. 108 dp canvas; launchers show the middle 72 dp through their
##    own mask (circle, squircle, teardrop...) and only the 66 dp circle in the middle is sure to
##    show, so the board stays inside it (60 dp square, its rounded corners reach 36.6 dp from the centre:
##    right at the edge of a 72 dp mask, beyond the 66 dp sure circle by the tips of the corners only).
##    The board is as large as that allows: a smaller one made the icon look small next to full-art
##    icons on a real phone, where the launcher draws the whole canvas and the board is half of it.
##    The background is a rounded tile with transparent margin, not a full-bleed square: some
##    launchers (seen on a real phone) draw the whole 108 dp canvas without cropping or
##    masking it, and a full-bleed background then shows as a hard-cornered square with the board
##    lost in the middle. A masking launcher crops the tile to its own shape; the tile is larger
##    than the visible 72 dp so no transparent edge shows.
##    The monochrome layer is what Android 13+ tints for themed icons: outlines, not filled
##    blocks, so it does not read as one big square.
##  - assets/launcher/main(.svg, _192x192.png): the legacy icon, for launchers without adaptive
##    icons: the visible 72 dp on a rounded square.
##  - assets/launcher/pwa_{144,180,512}.png: the install icons of the browser version (full bleed).
##  - icon.svg: the project icon (window, editor).
##  - fastlane/metadata/android/*/images/icon.png: the 512 px store icon, full bleed (the stores
##    round the corners themselves).
## The board: a rounded outline with the two box lines each way and the centre cell lit, holding
## a 5. The digit is a drawn path, so no font is needed to render it.
##   godot --headless --path . -s tools/make_launcher_icons.gd

const LAUNCHER_DIR: String = "res://assets/launcher/"
const STORE_LOCALES: Array[String] = ["en-US", "tr-TR"]

const BG_FROM: String = "#0e1117"
const BG_TO: String = "#17294a"
const ACCENT: String = "#2563eb"

## Board geometry in dp, on the 108 dp canvas
const CENTRE: float = 54.0
const BOARD: float = 60.0
const BOARD_RADIUS: float = 14.0
## The adaptive background tile: 88 dp, centred, corners rounded to 22%. It covers the whole
## visible 72 dp square, corners included, for every mask (a teardrop has a square corner); a
## bigger tile also fills more of the slot on a launcher that does not mask.
const TILE: float = 98.0

## A 5 drawn in a 100-unit box (bbox x 27..80, y 14..92), stroked with round ends
const FIVE_PATH: String = "M72 14 H34 L30 46 C38 41 46 40 54 40 C70 40 80 52 80 66 C80 82 68 92 52 92 C42 92 33 88 27 81"

func _init() -> void:
	_write_layer("adaptive_background", _background(TILE, (108.0 - TILE) / 2.0, TILE * 0.22), 432)
	_write_layer("adaptive_foreground", _glow() + _board(false), 432)
	_write_layer("adaptive_monochrome", _board(true), 432)
	var legacy := _background(72.0, 18.0, 72.0 * 0.22) + _glow() + _board(false)
	_write("assets/launcher/main.svg", _svg(legacy, 192, 18.0, 72.0))
	_render(_svg(legacy, 192, 18.0, 72.0), LAUNCHER_DIR + "main_192x192.png")
	_write("icon.svg", _svg(legacy, 128, 18.0, 72.0))
	var store := _svg(_background(72.0, 18.0, 0.0) + _glow() + _board(false), 512, 18.0, 72.0)
	for locale in STORE_LOCALES:
		_render(store, "res://fastlane/metadata/android/%s/images/icon.png" % locale)
	# The web app's install icons (the browser version can be installed like an app)
	for px in [144, 180, 512]:
		_render(_svg(_background(72.0, 18.0, 0.0) + _glow() + _board(false), px, 18.0, 72.0), LAUNCHER_DIR + "pwa_%dx%d.png" % [px, px])
	print("Launcher icons written")
	quit()

func _write_layer(name: String, body: String, px: int) -> void:
	var svg := _svg(body, px, 0.0, 108.0)
	_write("assets/launcher/%s.svg" % name, svg)
	_render(svg, LAUNCHER_DIR + "%s_%dx%d.png" % [name, px, px])

## An SVG of `px` pixels showing the square of side `side` dp from (`origin`, `origin`)
func _svg(body: String, px: int, origin: float, side: float) -> String:
	return ("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"%s %s %s %s\">\n" % [px, px, _n(origin), _n(origin), _n(side), _n(side)]
		+ "<defs>\n<linearGradient id=\"bg\" x1=\"0\" y1=\"0\" x2=\"1\" y2=\"1\">"
		+ "<stop offset=\"0\" stop-color=\"%s\"/><stop offset=\"1\" stop-color=\"%s\"/></linearGradient>\n" % [BG_FROM, BG_TO]
		+ "<radialGradient id=\"glow\" cx=\"0.5\" cy=\"0.5\" r=\"0.5\">"
		+ "<stop offset=\"0\" stop-color=\"%s\" stop-opacity=\"0.45\"/><stop offset=\"1\" stop-color=\"%s\" stop-opacity=\"0\"/></radialGradient>\n</defs>\n" % [ACCENT, ACCENT]
		+ body + "</svg>\n")

func _background(side: float, origin: float, radius: float) -> String:
	return "<rect x=\"%s\" y=\"%s\" width=\"%s\" height=\"%s\" rx=\"%s\" fill=\"url(#bg)\"/>\n" % [_n(origin), _n(origin), _n(side), _n(side), _n(radius)]

func _glow() -> String:
	return "<circle cx=\"%s\" cy=\"%s\" r=\"38\" fill=\"url(#glow)\"/>\n" % [_n(CENTRE), _n(CENTRE)]

## The board. `mono`: one opaque colour for the themed icon, the lit cell solid and no digit.
func _board(mono: bool) -> String:
	var x := CENTRE - BOARD / 2.0
	var third := BOARD / 3.0
	var out := ""
	if not mono:
		out += "<rect x=\"%s\" y=\"%s\" width=\"%s\" height=\"%s\" rx=\"%s\" fill=\"#ffffff\" fill-opacity=\"0.09\"/>\n" % [_n(x), _n(x), _n(BOARD), _n(BOARD), _n(BOARD_RADIUS)]
	var cell := third - 2.4
	out += "<rect x=\"%s\" y=\"%s\" width=\"%s\" height=\"%s\" rx=\"3\" fill=\"%s\"/>\n" % [_n(x + third + 1.2), _n(x + third + 1.2), _n(cell), _n(cell), "#ffffff" if mono else ACCENT]
	var line_width := 1.4 if mono else 0.9
	var line_opacity := 1.0 if mono else 0.43
	for i in [1, 2]:
		var p: float = x + third * i
		for d in [[p, x + 3.0, p, x + BOARD - 3.0], [x + 3.0, p, x + BOARD - 3.0, p]]:
			out += "<line x1=\"%s\" y1=\"%s\" x2=\"%s\" y2=\"%s\" stroke=\"#ffffff\" stroke-opacity=\"%s\" stroke-width=\"%s\"/>\n" % [_n(d[0]), _n(d[1]), _n(d[2]), _n(d[3]), _n(line_opacity), _n(line_width)]
	var edge := 2.2
	out += "<rect x=\"%s\" y=\"%s\" width=\"%s\" height=\"%s\" rx=\"%s\" fill=\"none\" stroke=\"#ffffff\" stroke-opacity=\"%s\" stroke-width=\"%s\"/>\n" % [_n(x + edge / 2.0), _n(x + edge / 2.0), _n(BOARD - edge), _n(BOARD - edge), _n(BOARD_RADIUS - edge / 2.0), "1" if mono else "0.86", _n(edge)]
	if not mono:
		out += "<path d=\"%s\" transform=\"translate(%s %s) scale(0.0984) translate(-53.5 -53)\" fill=\"none\" stroke=\"#ffffff\" stroke-width=\"19\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>\n" % [FIVE_PATH, _n(CENTRE), _n(CENTRE)]
	return out

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

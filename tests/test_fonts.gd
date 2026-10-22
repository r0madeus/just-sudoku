extends SceneTree

## Fonts: each family is a font bundled with the game (so it looks the same on every device),
## each covers every character the game shows in both languages on its own, without leaning on
## a system fallback, and each ships with its licence.

var tests_passed: int = 0
var tests_failed: int = 0

func assert_true(condition: bool, msg: String) -> void:
	if condition:
		tests_passed += 1
		print("  ✓ PASS: %s" % msg)
	else:
		tests_failed += 1
		printerr("  ✗ FAIL: %s" % msg)

## Every character of every text in both languages, plus the symbols the code writes itself
func _all_ui_chars() -> Dictionary:
	var chars: Dictionary = {}
	var texts: Array = LocalizationManager.DICTIONARY_EN.values() + LocalizationManager.DICTIONARY_TR.values()
	texts.append("0123456789 ·•…×={},.:;!?%/()[]-+'\"")
	for t in texts:
		for ch in String(t):
			if ch != "\n":
				chars[ch] = true
	return chars

func _init() -> void:
	print("========================================")
	print("🧪 RUNNING FONT TESTS")
	print("========================================")
	var chars := _all_ui_chars()
	var expected := {
		FontManager.FONT_MODERN_SANS: "Inter",
		FontManager.FONT_ROUNDED_SANS: "Nunito",
		FontManager.FONT_CLASSIC_SERIF: "SourceSerif4",
	}
	for family in FontManager.FONT_FAMILIES:
		var font: Font = FontManager.get_font(family)
		var file: FontFile = font.base_font as FontFile if font is FontVariation else font as FontFile
		assert_true(file != null and file.resource_path.get_file().begins_with(expected[family]),
			"%s is the bundled %s (%s)" % [family, expected[family], file.resource_path.get_file() if file != null else "none"])
		if file == null:
			continue
		var weight_tag: int = TextServerManager.get_primary_interface().name_to_tag("weight")
		if file.get_supported_variation_list().has(weight_tag):
			assert_true(int(font.variation_opentype.get(weight_tag, 0)) == 400, "%s is drawn at regular weight (400)" % family)
		# The font itself, not its fallbacks
		var main_rid: RID = file.get_rids()[0]
		var missing: Array = []
		for ch in chars:
			if not TextServerManager.get_primary_interface().font_has_char(main_rid, ch.unicode_at(0)):
				missing.append(ch)
		assert_true(missing.is_empty(), "%s has every character the game shows (%d), missing %s" % [family, chars.size(), str(missing)])
		assert_true(not font.fallbacks.is_empty(), "%s keeps a system font behind it for anything else" % family)

	for licence in ["Inter", "Nunito", "SourceSerif4", "IBMPlexMono"]:
		assert_true(FileAccess.file_exists("res://assets/fonts/licenses/%s-OFL.txt" % licence), "%s licence (SIL OFL) is included" % licence)
	var presets := ConfigFile.new()
	presets.load("res://export_presets.cfg")
	assert_true(String(presets.get_value("preset.0", "include_filter", "")).contains("assets/fonts/licenses/"),
		"The licences are exported with the game")

	print("========================================")
	print("🏁 RESULTS: %d Passed, %d Failed" % [tests_passed, tests_failed])
	print("========================================")
	quit(1 if tests_failed > 0 else 0)

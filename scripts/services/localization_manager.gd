class_name LocalizationManager
extends Node

## Localization & Internationalization Manager (GDD §44, §49)
## Integrates Godot TranslationServer with dynamic runtime UI hot-swapping.

const LOCALE_TR: String = "tr"
const LOCALE_EN: String = "en"
const SUPPORTED_LOCALES: Array[String] = [LOCALE_TR, LOCALE_EN]

const LOCALE_NAMES: Dictionary = {
	LOCALE_TR: "Türkçe",
	LOCALE_EN: "English"
}

static var current_locale: String = LOCALE_TR
static var _listeners: Array[Callable] = []
static var _initialized: bool = false

const StringsEn = preload("res://scripts/services/strings_en.gd")
const StringsTr = preload("res://scripts/services/strings_tr.gd")

# In-memory dictionary for 100% reliable translations across headless tests and runtime
static var DICTIONARY_EN: Dictionary = StringsEn.STRINGS.duplicate()

static var DICTIONARY_TR: Dictionary = StringsTr.STRINGS.duplicate()

static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true

	var t_en := Translation.new()
	t_en.locale = LOCALE_EN
	for k in DICTIONARY_EN:
		t_en.add_message(k, DICTIONARY_EN[k])
	TranslationServer.add_translation(t_en)

	var t_tr := Translation.new()
	t_tr.locale = LOCALE_TR
	for k in DICTIONARY_TR:
		t_tr.add_message(k, DICTIONARY_TR[k])
	TranslationServer.add_translation(t_tr)

static func add_listener(cb: Callable) -> void:
	if not _listeners.has(cb):
		_listeners.append(cb)

static func remove_listener(cb: Callable) -> void:
	_listeners.erase(cb)

static func _notify_listeners() -> void:
	for cb in _listeners:
		if cb.is_valid():
			cb.call()

static func set_locale(loc: String) -> void:
	_ensure_initialized()
	var clean: String = loc.strip_edges().to_lower()
	if clean.begins_with(LOCALE_TR):
		current_locale = LOCALE_TR
	else:
		current_locale = LOCALE_EN

	TranslationServer.set_locale(current_locale)
	_notify_listeners()

static func get_locale() -> String:
	return current_locale

static func translate(key: String) -> String:
	_ensure_initialized()
	var res := TranslationServer.translate(key)
	if res != key:
		return str(res)

	# Fallback to in-memory dictionaries
	var dict: Dictionary = DICTIONARY_TR if current_locale == LOCALE_TR else DICTIONARY_EN
	if dict.has(key):
		return dict[key]
	if DICTIONARY_EN.has(key):
		return DICTIONARY_EN[key]
	return key

## Translates Difficulty level string (e.g. "Easy" -> "Kolay" in TR, "Easy" in EN)
## Any letter case, so older or imported records ("medium") read the same
static func get_difficulty_name(diff_key: String) -> String:
	match diff_key.strip_edges().to_lower():
		"easy", "kolay":
			return translate("DIFF_EASY")
		"medium", "orta":
			return translate("DIFF_MEDIUM")
		"hard", "zor":
			return translate("DIFF_HARD")
		"expert", "uzman":
			return translate("DIFF_EXPERT")
		_:
			return diff_key

## Translates technique title (e.g. "Naked Single" -> "Açık Tekli (Naked Single)" in TR)
static func get_technique_title(tech: String) -> String:
	match tech:
		"Full House":
			return translate("TECH_FULL_HOUSE")
		"Naked Single":
			return translate("TECH_NAKED_SINGLE")
		"Hidden Single":
			return translate("TECH_HIDDEN_SINGLE")
		"Locked Candidates":
			return translate("TECH_LOCKED_CANDIDATES")
		"Naked Pair":
			return translate("TECH_NAKED_PAIR")
		"Hidden Pair":
			return translate("TECH_HIDDEN_PAIR")
		"Naked Triple":
			return translate("TECH_NAKED_TRIPLE")
		"Hidden Triple":
			return translate("TECH_HIDDEN_TRIPLE")
		"X-Wing":
			return translate("TECH_X_WING")
		"Swordfish":
			return translate("TECH_SWORDFISH")
		"XY-Wing":
			return translate("TECH_XY_WING")
		"XYZ-Wing":
			return translate("TECH_XYZ_WING")
		"Simple Coloring":
			return translate("TECH_SIMPLE_COLORING")
		"XY-Chain":
			return translate("TECH_XY_CHAIN")
		"Logical Guess / Backtracking", "Solution Hint", "Advanced Logical Deduction":
			return translate("TECH_BACKTRACKING")
		_:
			return translate(tech)

## GDD §44: UI number, percentage, and date/time formatting per locale
## "1 Day" / "5 Days" (Turkish has no plural form)
static func format_days(count: int) -> String:
	return plural("STAT_DAYS", count)

## "Streak: 1 Day" / "Streak: 5 Days"
static func format_streak(count: int) -> String:
	return plural("DAILY_STREAK_FORMAT", count)

## "%d ..." text for a count: English uses the key's "_ONE" form for exactly one
## ("1 game completed"); Turkish nouns stay singular after a number, so it has no such forms
static func plural(key: String, count: int) -> String:
	if current_locale == LOCALE_EN and absi(count) == 1 and DICTIONARY_EN.has(key + "_ONE"):
		return translate(key + "_ONE") % count
	return translate(key) % count

## Upper case for small section labels (overlines). Godot's to_upper() is not locale aware,
## so Turkish "i" would become "I" instead of "İ" ("En İyi" -> "EN İYI")
static func upper(text: String) -> String:
	if current_locale == LOCALE_TR:
		text = text.replace("i", "İ").replace("ı", "I")
	return text.to_upper()

static func format_percentage(pct: int) -> String:
	if current_locale == LOCALE_TR:
		return "%%%d" % pct
	return "%d%%" % pct

static func format_number(val: int) -> String:
	var s := str(abs(val))
	var formatted := ""
	var count := 0
	var sep := "." if current_locale == LOCALE_TR else ","
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			formatted = sep + formatted
		formatted = s[i] + formatted
		count += 1
	if val < 0:
		formatted = "-" + formatted
	return formatted

## "12 Mar" / "Mar 12" from "YYYY-MM-DD"
static func format_short_date(date_str: String) -> String:
	var parts := date_str.split("-")
	if parts.size() != 3:
		return date_str
	var month := translate("MONTH_SHORT_%d" % parts[1].to_int())
	if current_locale == LOCALE_TR:
		return "%d %s" % [parts[2].to_int(), month]
	return "%s %d" % [month, parts[2].to_int()]

## "Ekim 2026" / "October 2026"
static func format_month_year(year: int, month: int) -> String:
	return "%s %d" % [translate("MONTH_%d" % month), year]

static func format_date(year: int, month: int, day: int) -> String:
	if current_locale == LOCALE_TR:
		return "%02d.%02d.%04d" % [day, month, year]
	return "%04d-%02d-%02d" % [year, month, day]

## A length of time in words for comparisons ("1 dk 20 sn", "45 s")
static func format_duration_words(seconds: float) -> String:
	var sec := int(roundf(absf(seconds)))
	var m := sec / 60
	var s := sec % 60
	if m == 0:
		return translate("DURATION_SEC") % s
	if s == 0:
		return translate("DURATION_MIN") % m
	return translate("DURATION_MIN_SEC") % [m, s]

static func format_duration(seconds: float) -> String:
	var sec := int(roundf(seconds))
	var m := sec / 60
	var s := sec % 60
	return "%02d:%02d" % [m, s]

static func detect_system_locale() -> String:
	var os_loc := OS.get_locale_language().to_lower().strip_edges()
	if os_loc.is_empty():
		var full_loc := OS.get_locale().to_lower().strip_edges()
		if full_loc.begins_with(LOCALE_TR):
			return LOCALE_TR
		return LOCALE_EN
	if os_loc.begins_with(LOCALE_TR):
		return LOCALE_TR
	return LOCALE_EN

static func get_technique_name(raw_tech: String) -> String:
	return get_technique_title(raw_tech)

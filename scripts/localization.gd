class_name Localization
extends RefCounted

const LOCALES := ["en", "ja", "ko", "zh_CN", "zh_TW"]
const NAMES := ["English", "日本語", "한국어", "简体中文", "繁體中文"]
const FONT_PATHS := {
	"ja": "res://fonts/cjk/NotoSansCJKjp-Regular.otf",
	"ko": "res://fonts/cjk/NotoSansCJKkr-Regular.otf",
	"zh_CN": "res://fonts/cjk/NotoSansCJKsc-Regular.otf",
	"zh_TW": "res://fonts/cjk/NotoSansCJKtc-Regular.otf",
}
const LATIN_FONTS := ["res://fonts/VT323-Regular.ttf", "res://fonts/RockSalt-Regular.ttf",
	"res://fonts/Caveat-Regular.ttf", "res://fonts/RazorKeen-Regular.otf"]
static var _loaded := false
static var _translations: Array[Translation] = []
static var _locale := "en"

static func normalize(value: String) -> String:
	var code := value.replace("-", "_").to_lower()
	if code.begins_with("ja"): return "ja"
	if code.begins_with("ko"): return "ko"
	if code.begins_with("zh"):
		return "zh_TW" if "hant" in code or code.ends_with("tw") or code.ends_with("hk") or code.ends_with("mo") else "zh_CN"
	return "en"

static func current_locale() -> String:
	return _locale

static func apply(code: String) -> void:
	if not _loaded:
		_loaded = true
		for supported: String in LOCALES:
			if supported == "en": continue
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://localization/%s.json" % supported))
			if not data is Dictionary:
				push_error("Invalid localization catalog: " + supported)
				continue
			var translation := preload("res://scripts/game_translation.gd").new()
			translation.configure(supported, data)
			_translations.append(translation)
			TranslationServer.add_translation(translation)
	_locale = normalize(code)
	# All CJK faces contain kana, Hangul and Han, including the language picker.
	# Prefer the chosen region's glyph forms; English uses Japanese as fallback.
	var face: Font = load(FONT_PATHS.get(_locale, FONT_PATHS.ja))
	for path: String in LATIN_FONTS:
		var font := load(path) as Font
		font.fallbacks = [face]
	ThemeDB.fallback_font.fallbacks = [face]
	TranslationServer.set_locale(_locale)

static func text(source: String) -> String:
	return str(TranslationServer.translate(source))

static func max_text_width(font: Font, source: String, size: int) -> float:
	# Reserve enough physical sign space for every language, including switches
	# after the chunk was built. No locale changes or world regeneration needed.
	var width := font.get_string_size(source, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	for translation in _translations:
		var value: String = translation.translate_text(source)
		if not value.is_empty():
			width = maxf(width, font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	return width

static func shutdown() -> void:
	# Remove script-backed translations while the script language is still alive.
	for translation in _translations:
		TranslationServer.remove_translation(translation)
	_translations.clear()
	_loaded = false

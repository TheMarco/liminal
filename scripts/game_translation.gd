extends Translation
## Keeps source text on Controls/Label3D, so Godot can translate existing nodes
## again when the language changes. Formatted HUD messages retain their source
## values (including saved photo captions); only presentation is translated.

var _entries: Dictionary = {}
var patterns: Array[Dictionary] = []
var _cache: Dictionary = {}

func configure(code: String, catalog: Dictionary) -> void:
	locale = code
	for source: String in catalog:
		_entries[source] = str(catalog[source])
		_entries[source.to_upper()] = str(catalog[source])
	var tokens := RegEx.create_from_string("%[-+0-9.]*[sdif]|%%")
	for source: String in catalog:
		if tokens.search(source) == null and not source.begins_with("E —"):
			continue
		# Generic wrappers must not swallow an entire multi-line inscription.
		# Literal newlines in authored templates still match; other lines are
		# translated independently below.
		var pattern := "(?i)^"
		var end := 0
		var target: String = _entries[source]
		var count := 0
		for token in tokens.search_all(source):
			pattern += _escape(source.substr(end, token.get_start() - end))
			var spec: String = token.get_string()
			pattern += "%" if spec == "%%" else ("(.+?)" if spec.ends_with("s") else "([-+0-9.,]+)")
			if spec != "%%": count += 1
			end = token.get_end()
		pattern += _escape(source.substr(end)) + "$"
		# Interactions replace the authored E with the player's current binding.
		if source.begins_with("E —") and target.begins_with("E —"):
			pattern = pattern.replace("^E —", "^(.+?) —")
			target = "%s" + target.substr(1)
			count += 1
		var replacement := ""
		var target_end := 0
		for token in tokens.search_all(target):
			replacement += target.substr(target_end, token.get_start() - target_end)
			replacement += "%%" if token.get_string() == "%%" else "%s"
			target_end = token.get_end()
		replacement += target.substr(target_end)
		# Percent-only messages are numeric; preserve literal percent signs.
		if count > 0:
			patterns.append({"regex": RegEx.create_from_string(pattern),
				"target": replacement, "weight": source.length() - count * 2})
	patterns.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.weight > b.weight)

func _get_message(source: StringName, _context: StringName) -> StringName:
	if _cache.has(source): return _cache[source]
	var translated := StringName(translate_text(str(source)))
	# Distance and clock readouts continually create new values. Bound the
	# cache while avoiding regex work for unchanged HUD text on every frame.
	if _cache.size() >= 1024: _cache.clear()
	_cache[source] = translated
	return translated

func translate_text(source: String, depth := 0) -> String:
	if _entries.has(source): return str(_entries[source])
	if depth >= 5 or source.is_empty(): return ""
	for entry in patterns:
		var match_result: RegExMatch = entry.regex.search(source)
		if match_result == null: continue
		var values: Array = []
		for i in range(1, match_result.get_group_count() + 1):
			var value := match_result.get_string(i)
			var translated := translate_text(value, depth + 1)
			values.append(value if translated.is_empty() else translated)
		return str(entry.target) % values
	if source.contains("\n"):
		var lines := source.split("\n")
		var changed := false
		for i in lines.size():
			var translated := translate_text(lines[i], depth + 1)
			if not translated.is_empty():
				lines[i] = translated
				changed = true
		if changed: return "\n".join(lines)
	return ""

static func _escape(value: String) -> String:
	var result := ""
	for c in value:
		if c in "\\.^$|?*+()[]{}": result += "\\"
		result += c
	return result

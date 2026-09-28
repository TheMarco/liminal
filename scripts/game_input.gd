class_name GameInput
extends RefCounted
## Named core keyboard actions with remappable physical-key primaries.
##
## Defaults match the historical hard-coded keys exactly: WASD plus arrow
## alternatives for movement, Shift sprint, E interact, F torch, C camera,
## Space shutter, P album, Q return-to-title. Right mouse (raise camera) and
## left mouse (shutter) stay fixed alongside the camera/shutter primaries.
## Escape stays fixed menu/cancel and is never bindable. Floor-selection keys
## (1-9, 0, minus, keypad twins) and debug keys F6-F9 are reserved so a rebind
## can neither strand Wander floors nor steal diagnostics.
##
## Every helper takes an optional GameSettings, falls back to
## GameSettings.current, then to defaults — callers and audits keep working
## when no settings object exists.

const ACTIONS = ["forward", "back", "left", "right", "sprint", "interact",
	"torch", "camera", "shutter", "album", "return_to_title"]

const DEFAULTS = {
	"forward": KEY_W,
	"back": KEY_S,
	"left": KEY_A,
	"right": KEY_D,
	"sprint": KEY_SHIFT,
	"interact": KEY_E,
	"torch": KEY_F,
	"camera": KEY_C,
	"shutter": KEY_SPACE,
	"album": KEY_P,
	"return_to_title": KEY_Q,
}

const DISPLAY_NAMES = {
	"forward": "MOVE FORWARD",
	"back": "MOVE BACK",
	"left": "MOVE LEFT",
	"right": "MOVE RIGHT",
	"sprint": "SPRINT",
	"interact": "INTERACT",
	"torch": "TORCH",
	"camera": "CAMERA",
	"shutter": "TAKE PHOTO",
	"album": "PHOTO ALBUM",
	"return_to_title": "RETURN TO TITLE",
}

## Fixed secondary movement keys. An alternative counts only while no action
## uses it as a primary, so rebinding onto an arrow never double-drives.
const ALTERNATIVES = {
	"forward": [KEY_UP],
	"back": [KEY_DOWN],
	"left": [KEY_LEFT],
	"right": [KEY_RIGHT],
}

const RESERVED_FLOOR = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7,
	KEY_8, KEY_9, KEY_0, KEY_MINUS, KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4,
	KEY_KP_5, KEY_KP_6, KEY_KP_7, KEY_KP_8, KEY_KP_9, KEY_KP_0,
	KEY_KP_SUBTRACT]

const RESERVED_DEBUG = [KEY_F6, KEY_F7, KEY_F8, KEY_F9]


static func default_bindings() -> Dictionary:
	return DEFAULTS.duplicate(true)


static func _source(settings: Variant) -> Variant:
	if settings != null:
		return settings
	return GameSettings.current


## Current action-to-key map: live settings when available, else defaults.
static func primaries(settings: Variant = null) -> Dictionary:
	var out := DEFAULTS.duplicate(true)
	var source: Variant = _source(settings)
	if source != null and source.has_method("get_binding"):
		for action in ACTIONS:
			out[action] = int(source.get_binding(action))
	return out


static func primary(action: String, settings: Variant = null) -> Key:
	var source: Variant = _source(settings)
	if source != null and source.has_method("get_binding"):
		var code: Key = source.get_binding(action)
		return code
	return DEFAULTS.get(action, KEY_NONE)


## Pure keycode match, without pressed/echo checks.
static func matches_code(code: Key, action: String,
		settings: Variant = null) -> bool:
	return code != KEY_NONE and code == primary(action, settings)


## Pressed, non-echo physical-key match for a discrete action.
static func matches(event: InputEvent, action: String,
		settings: Variant = null) -> bool:
	if not (event is InputEventKey):
		return false
	var key := event as InputEventKey
	return key.pressed and not key.echo \
		and matches_code(key.physical_keycode, action, settings)


## True while any movement alternative for the action still counts.
static func alternative_active(action: String,
		settings: Variant = null) -> bool:
	var bound := primaries(settings)
	var own: Key = bound.get(action, DEFAULTS.get(action, KEY_NONE))
	for alt in ALTERNATIVES.get(action, []):
		if alt == own:
			continue
		if not bound.values().has(alt):
			return true
	return false


## Primary plus surviving alternatives — the full held-state resolution.
static func held_keys(action: String, settings: Variant = null) -> Array:
	var bound := primaries(settings)
	var own: Key = bound.get(action, DEFAULTS.get(action, KEY_NONE))
	var out: Array = [own]
	for alt in ALTERNATIVES.get(action, []):
		if alt != own and not bound.values().has(alt):
			out.append(alt)
	return out


static func is_held(action: String, settings: Variant = null) -> bool:
	for code in held_keys(action, settings):
		var keycode: Key = code
		if Input.is_physical_key_pressed(keycode):
			return true
	return false


static func reserved_reason(code: Key) -> String:
	if code in RESERVED_FLOOR:
		return "1-9, 0 and minus select floors in Wander."
	if code in RESERVED_DEBUG:
		return "F6-F9 are debug keys."
	return ""


## "" when bindable, else a message naming the conflict. `bindings` maps
## actions to current primaries (defaults fill gaps).
static func validate(action: String, code: Key,
		bindings: Dictionary) -> String:
	if not DEFAULTS.has(action):
		return "Unknown control."
	var key_problem := key_error(code)
	if not key_problem.is_empty():
		return key_problem
	for other in ACTIONS:
		if other != action \
				and int(bindings.get(other, DEFAULTS[other])) == int(code):
			return "%s is already used by %s. Pick another key." % [
				key_label(code), DISPLAY_NAMES.get(other, other)]
	return ""


static func key_error(code: Key) -> String:
	if code == KEY_NONE:
		return "Press a keyboard key."
	if int(code) < 0 or int(code) > int(KEY_UNKNOWN):
		return "That key is not supported."
	var label := OS.get_keycode_string(code)
	if label.is_empty() or OS.find_keycode_from_string(label) != code:
		return "That key is not supported."
	if code == KEY_ESCAPE:
		return "Escape is always menu / cancel."
	var reserved := reserved_reason(code)
	if not reserved.is_empty():
		return reserved
	return ""


static func key_label(code: Key) -> String:
	if code == KEY_ESCAPE:
		return "ESC"
	if code == KEY_NONE:
		return "--"
	# Bind positions, but display the character printed by the active layout
	# (for example Z at the physical W position on an AZERTY keyboard).
	if DisplayServer.get_name() != "headless":
		var layout_code := DisplayServer.keyboard_get_keycode_from_physical(code)
		if layout_code != KEY_NONE:
			code = layout_code
	var text := OS.get_keycode_string(code)
	if text.is_empty():
		return "KEY %d" % int(code)
	return text.to_upper()


static func primary_label(action: String,
		settings: Variant = null) -> String:
	return key_label(primary(action, settings))


## Sentence-case label for inline hints ("Space", "E").
static func primary_hint(action: String, settings: Variant = null) -> String:
	return primary_label(action, settings).to_lower().capitalize()


## Title-screen movement row; "WASD  /  ARROWS" on QWERTY defaults.
static func movement_label(settings: Variant = null) -> String:
	var bound := primaries(settings)
	var arrows: Array[String] = []
	for action in ["forward", "left", "back", "right"]:
		if alternative_active(action, settings):
			arrows.append(key_label(ALTERNATIVES[action][0]))
	var text := ""
	if bound["forward"] == KEY_W and bound["back"] == KEY_S \
			and bound["left"] == KEY_A and bound["right"] == KEY_D:
		text = movement_compact_label(settings)
	else:
		text = "%s / %s / %s / %s" % [key_label(bound["forward"]),
			key_label(bound["left"]), key_label(bound["back"]),
			key_label(bound["right"])]
	if arrows.size() == 4:
		return text + "  /  ARROWS"
	if not arrows.is_empty():
		return text + "  /  " + " / ".join(arrows)
	return text


## Compact movement label for the mode hint; "WASD" on QWERTY defaults.
static func movement_compact_label(settings: Variant = null) -> String:
	var bound := primaries(settings)
	var parts := [key_label(bound["forward"]), key_label(bound["left"]),
		key_label(bound["back"]), key_label(bound["right"])]
	for part in parts:
		if part.length() != 1:
			return " / ".join(parts)
	return "".join(parts)

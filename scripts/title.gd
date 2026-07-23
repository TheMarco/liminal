class_name TitleScreen
extends CanvasLayer
## The way in. Black, the logo, what the keys do, and one instruction.
##
## Nothing moves until you press space: the mouse is left free and the player
## is deaf, so the world behind is already built and already running — the
## lights are on and the music has started before you have agreed to be there.
## Sits above the tube pass (layer 3) so the key list stays legible; the CRT
## would eat 15px text at 240 lines.

signal started

const KEYS := [
	["WASD  /  arrows", "walk"],
	["Shift", "run"],
	["E", "use terminals, lifts and selected doors"],
	["1 - 6", "ride the elevator between floors"],
	["V", "look with your own eyes instead of the tube"],
	["Esc", "release the mouse"],
]
const ASIDE := "or walk into a swirling portal, and come out somewhere else"

var _prompt: Label
var _logo: TextureRect
var _scaled: Array[Array] = []   # [label, base font size]
var _t := 0.0
var _gone := false


func _ready() -> void:
	layer = 3
	var back := ColorRect.new()
	# the logo's own black is 2/255, not 0 — match it or its frame shows
	back.color = Color8(2, 2, 2)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	_logo = TextureRect.new()
	var logo := _logo
	logo.texture = load("res://textures/ui/title.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(0, 390)
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(logo)

	for k in KEYS:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 0)
		var key := Label.new()
		key.text = str(k[0])
		key.custom_minimum_size = Vector2(150, 0)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_style(key, 15, Color(0.86, 0.80, 0.66, 0.95))
		var what := Label.new()
		what.text = "      " + str(k[1])
		what.custom_minimum_size = Vector2(430, 0)
		_style(what, 15, Color(0.62, 0.60, 0.55, 0.85))
		row.add_child(key)
		row.add_child(what)
		col.add_child(row)

	var aside := Label.new()
	aside.text = ASIDE
	aside.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(aside, 15, Color(0.52, 0.51, 0.47, 0.8))
	var gap0 := Control.new()
	gap0.custom_minimum_size = Vector2(0, 10)
	col.add_child(gap0)
	col.add_child(aside)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 26)
	col.add_child(gap)

	_prompt = Label.new()
	_prompt.text = "PRESS  SPACE  TO  START"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(_prompt, 20, Color(0.93, 0.89, 0.78, 1.0))
	col.add_child(_prompt)

	_relayout()
	get_viewport().size_changed.connect(_relayout)


## The project has no stretch mode, so a Control is laid out in raw pixels and
## a title built for 720p would sit tiny in the middle of a 1440p screen.
## Everything here is sized against the viewport instead, and resized with it.
func _relayout() -> void:
	var k := clampf(float(get_viewport().size.y) / 720.0, 0.6, 3.0)
	_logo.custom_minimum_size = Vector2(0, 390.0 * k)
	for row in _scaled:
		var lb: Label = row[0]
		lb.add_theme_font_size_override("font_size", maxi(9, int(round(float(row[1]) * k))))
		if lb.custom_minimum_size.x > 0.0:
			lb.custom_minimum_size = Vector2(row[2] * k, 0)


func _style(lb: Label, size: int, col: Color) -> void:
	_scaled.append([lb, size, lb.custom_minimum_size.x])
	lb.add_theme_font_size_override("font_size", size)
	lb.add_theme_color_override("font_color", col)
	lb.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lb.add_theme_constant_override("shadow_offset_x", 1)
	lb.add_theme_constant_override("shadow_offset_y", 1)


func _process(dt: float) -> void:
	# a slow breath, like the fluorescents further in
	_t += dt
	_prompt.modulate.a = 0.55 + 0.45 * (0.5 + 0.5 * sin(_t * 2.2))


## Everything is swallowed until space — no wandering off during the titles.
func _input(event: InputEvent) -> void:
	if _gone:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_SPACE:
		_start()
	get_viewport().set_input_as_handled()


func _start() -> void:
	_gone = true
	set_process_input(false)
	started.emit()
	var tw := create_tween()
	tw.tween_property(self, "offset:y", -40.0, 0.5)
	tw.parallel().tween_method(_dim, 1.0, 0.0, 0.5)
	await tw.finished
	queue_free()


func _dim(a: float) -> void:
	for c in get_children():
		(c as CanvasItem).modulate.a = a

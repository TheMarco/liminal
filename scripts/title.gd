class_name TitleScreen
extends CanvasLayer
## The way in. Black, the logo, what the keys do, and one instruction.
##
## Nothing moves until you press space: the mouse is left free and the player
## is deaf, so the world behind is already built and already running — the
## lights are on and the music has started before you have agreed to be there.
## Sits above the tube pass (layer 3) so the key list stays legible; the CRT
## would eat 15px text at 240 lines.

signal mode_selected(descent: bool)
signal started(descent: bool)

const KEYS := [
	["WASD  /  arrows", "walk"],
	["Shift", "run"],
	["E", "use terminals, lifts and selected doors"],
	["F", "flashlight"],
	["1 - 8", "ride the elevator between floors"],
	["V", "look with your own eyes instead of the tube"],
	["Q", "return to title"],
	["Esc", "release the mouse"],
]
const ASIDE := "or walk into a swirling portal, and come out somewhere else"
const CREDIT_SECTIONS := [
	["3D MODELS",
		[
			"Poly Haven  —  furniture, fixtures and environmental props  ·  CC0",
			"nisu / 3DModelsCC0  —  office task chair  ·  CC0",
			"小林 団那紀 / dannaki_  —  office water cooler  ·  Sketchfab Standard",
			"Red Fox / nokillnando  —  office printer  ·  CC BY 4.0",
			"NotAnotherApocalypticCo.  —  office boxes  ·  CC BY 4.0",
			"AquaEquinox  —  office ceiling tiles  ·  CC BY 4.0",
			"Rylae Shylna  —  office air conditioners  ·  CC BY 4.0",
			"Bucks / Its_Bucks  —  airport seating  ·  CC BY 4.0",
			"Ellis Fossett  —  airport departure board  ·  CC BY 4.0",
			"Niels Philipsen  —  airport luggage  ·  CC BY 4.0",
			"AdrianXY  —  mall shopping carts  ·  CC BY 4.0",
			"Jawahar Yokesh  —  school chemistry tables  ·  CC BY 4.0",
			"dercruz926  —  chemistry glassware  ·  CC BY 4.0",
			"morrrtu1o  —  vintage slot machine  ·  CC BY 4.0",
			"Mihai / mmike0  —  prison bunk bed  ·  CC BY-NC 4.0",
			"Mark Peters  —  prison toilet  ·  CC BY 4.0",
			"Mehdi Shahsavan / adventurer  —  prison doors  ·  CC BY 4.0",
		]],
	["SURFACES & TYPE",
		[
			"ambientCG  —  physically based environment textures  ·  CC0",
			"Peter Hull / VT323  —  terminal typeface  ·  SIL Open Font License",
		]],
	["FIGURE SOURCES",
		[
			"Mette Aumala · Madeleine Price Ball · OpenClipart-Vectors  —  CC0",
			"Phil Bronnery / Beao  —  walking woman silhouette  ·  CC BY 2.0",
		]],
]

var _prompt: Label
var _logo: TextureRect
var _menu: VBoxContainer
var _rules: VBoxContainer
var _credits: VBoxContainer
var _scaled: Array[Array] = []   # [label, base font size]
var _t := 0.0
var _gone := false
var _descent_selected := false
var _descent_ready := false


func _ready() -> void:
	layer = 3
	var back := ColorRect.new()
	# the logo's own black is 2/255, not 0 — match it or its frame shows
	back.color = Color8(2, 2, 2)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)

	var col := VBoxContainer.new()
	_menu = col
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
	_prompt.text = "SPACE  —  WANDER          ENTER  —  DESCEND          C  —  CREDITS"
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
	if event is InputEventKey and event.pressed and not event.echo:
		if is_instance_valid(_credits):
			if event.physical_keycode in [KEY_C, KEY_ESCAPE, KEY_SPACE]:
				_hide_credits()
			get_viewport().set_input_as_handled()
			return
		if not _descent_selected:
			if event.physical_keycode == KEY_SPACE:
				mode_selected.emit(false)
				_start(false)
			elif event.physical_keycode == KEY_ENTER:
				_descent_selected = true
				_show_descent_rules()
				mode_selected.emit(true)
			elif event.physical_keycode == KEY_C:
				_show_credits()
		elif event.physical_keycode == KEY_SPACE and _descent_ready:
			_start(true)
	get_viewport().set_input_as_handled()


func set_descent_ready() -> void:
	_descent_ready = true
	if _descent_selected and is_instance_valid(_prompt):
		_prompt.text = "PRESS  SPACE  TO  DESCEND"


func present_descent(ready := false) -> void:
	if _descent_selected:
		if ready:
			set_descent_ready()
		return
	_descent_selected = true
	_show_descent_rules()
	if ready:
		set_descent_ready()


func _show_descent_rules() -> void:
	_menu.visible = false
	_rules = VBoxContainer.new()
	_rules.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rules.alignment = BoxContainer.ALIGNMENT_CENTER
	_rules.add_theme_constant_override("separation", 14)
	_rules.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rules)

	var head := Label.new()
	head.text = "DESCENT"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(head, 38, Color(0.94, 0.88, 0.72))
	_rules.add_child(head)
	var sub := Label.new()
	sub.text = "THE BUILDING HAS FOUR RULES"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(sub, 17, Color(0.55, 0.53, 0.48))
	_rules.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size.y = 22
	_rules.add_child(gap)
	var rules := [
		"DO NOT STARE AT THEM",
		"DO NOT STOP WALKING",
		"DO NOT GO BACK",
		"WHEN THE LIGHTS FAIL, STAND STILL",
	]
	for i in rules.size():
		var line := Label.new()
		line.text = "%d     %s" % [i + 1, rules[i]]
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_style(line, 24, Color(0.86, 0.80, 0.66))
		_rules.add_child(line)
	var gap2 := Control.new()
	gap2.custom_minimum_size.y = 34
	_rules.add_child(gap2)
	_prompt = Label.new()
	_prompt.text = "PREPARING THE FIRST FLOOR"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(_prompt, 18, Color(0.66, 0.61, 0.51))
	_rules.add_child(_prompt)
	_relayout()


func _show_credits() -> void:
	_menu.visible = false
	_credits = VBoxContainer.new()
	_credits.set_anchors_preset(Control.PRESET_FULL_RECT)
	_credits.alignment = BoxContainer.ALIGNMENT_CENTER
	_credits.add_theme_constant_override("separation", 8)
	_credits.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_credits)

	var head := Label.new()
	head.text = "CREDITS"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(head, 36, Color(0.94, 0.88, 0.72))
	_credits.add_child(head)
	var intro := Label.new()
	intro.text = "LIMINAL VEGAS USES ART SHARED BY THE FOLLOWING CREATORS"
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(intro, 14, Color(0.53, 0.52, 0.48))
	_credits.add_child(intro)
	var top_gap := Control.new()
	top_gap.custom_minimum_size.y = 15
	_credits.add_child(top_gap)

	for section in CREDIT_SECTIONS:
		var section_head := Label.new()
		section_head.text = str(section[0])
		section_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_style(section_head, 16, Color(0.82, 0.75, 0.62))
		_credits.add_child(section_head)
		for credit in section[1]:
			var line := Label.new()
			line.text = str(credit)
			line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_style(line, 14, Color(0.65, 0.63, 0.57))
			_credits.add_child(line)
		var gap := Control.new()
		gap.custom_minimum_size.y = 8
		_credits.add_child(gap)

	var details := Label.new()
	details.text = "FULL ASSET TITLES, SOURCE LINKS, LICENSES AND MODIFICATIONS\nTHIRD_PARTY_ASSETS.md"
	details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(details, 13, Color(0.48, 0.47, 0.43))
	_credits.add_child(details)
	var return_line := Label.new()
	return_line.text = "C  /  ESC  /  SPACE     RETURN"
	return_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(return_line, 18, Color(0.90, 0.84, 0.70))
	_credits.add_child(return_line)
	_relayout()


func _hide_credits() -> void:
	if is_instance_valid(_credits):
		_credits.queue_free()
	_credits = null
	_menu.visible = true


func _start(selected_descent: bool) -> void:
	_gone = true
	set_process_input(false)
	started.emit(selected_descent)
	var tw := create_tween()
	tw.tween_property(self, "offset:y", -40.0, 0.5)
	tw.parallel().tween_method(_dim, 1.0, 0.0, 0.5)
	await tw.finished
	queue_free()


func _dim(a: float) -> void:
	for c in get_children():
		(c as CanvasItem).modulate.a = a

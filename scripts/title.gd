class_name TitleScreen
extends CanvasLayer
## Front door for the game: a quiet title, then one deliberate page at a time.
##
## The generated world is already alive behind this opaque layer, but player
## input, figures and haunt timers remain suspended until a mode starts.

signal mode_selected(descent: bool)
signal started(descent: bool)

enum Page {
	MAIN,
	INSTRUCTIONS,
	ABOUT,
	CREDITS,
	DESCENT,
}

const UI_FONT: Font = preload("res://fonts/VT323-Regular.ttf")
const INSTRUCTION_ROWS := [
	["WASD  /  ARROWS", "Walk"],
	["SHIFT", "Run  ·  Wander only"],
	["E", "Use terminals, lifts and selected doors"],
	["F", "Toggle the flashlight"],
	["1  —  8", "Move between floors  ·  Wander only"],
	["V", "Toggle the video filter  ·  Wander only"],
	["B", "Switch CRT / recovered-tape video mode"],
	["Q", "Ask to leave the current mode"],
	["ESC", "Release the mouse"],
]
## Every attributed creator named in THIRD_PARTY_ASSETS.md appears here. The
## canonical record carries individual model titles, links and modifications.
const CREDIT_SECTIONS := [
	["3D MODEL CREATORS",
		[
			"Poly Haven  ·  CC0     nisu / 3DModelsCC0  ·  CC0     WillowBoxArt",
			"CASINO   morrrtu1o · Audrey Gonçalves · nermin · Dudzy · juliegraham178",
			"OFFICE   Red Fox / nokillnando · NotAnotherApocalypticCo. · AquaEquinox",
			"    Rylae Shylna · maxdragonn · dannaki_ · R3indeer",
			"ANNEX   carlcapu9 · Avot · Drake · jimbogies · Doverlock",
			"AIRPORT   Bucks / Its_Bucks · Ellis Fossett · n.philipsen · assetfactory",
			"ASYLUM   Veterock · loxfear · Ellie · creative_beast · Mehdi Shahsavan",
			"    Matt LeMoine",
			"SCHOOL   Jawahar Yokesh · dercruz926 · barism09 · neverfollow81 · CAL21",
			"    Osian CG · HippoStance · Dun · FLUXIUM3D · Kerridge1",
			"MALL   AdrianXY · mtaesiri · kapookkt · shirlanne · matejbiskup97 · Katydid",
			"    Some Random Mall Modeller · MaX3Dd",
			"PRISON   Mihai / mmike0 · Mark Peters · Mehdi Shahsavan / adventurer",
			"    dudecon · ShepDes",
			"CC BY 4.0 except  Katydid, R3indeer, mmike0, Kerridge1  ·  CC BY-NC 4.0",
			"and  dannaki_, assetfactory, MaX3Dd  ·  Sketchfab Standard",
		]],
	["SURFACES, TYPE & FIGURES",
		[
			"ambientCG  ·  CC0     Peter Hull / VT323  ·  SIL Open Font License",
			"Mette Aumala · Madeleine Price Ball · OpenClipart-Vectors  ·  CC0",
			"Phil Bronnery / Beao  —  walking woman silhouette  ·  CC BY 2.0",
		]],
]

const CREAM := Color(0.93, 0.88, 0.75)
const GOLD := Color(0.77, 0.69, 0.53)
const BODY := Color(0.66, 0.64, 0.58)
const DIM := Color(0.46, 0.45, 0.41)
const BACK := Color8(2, 2, 2)

var _logo: TextureRect
var _pages: Dictionary = {}
var _scaled: Array[Array] = []   # [Control, base font, width, height]
var _prompt: Label
var _current_page := Page.MAIN
var _t := 0.0
var _gone := false
var _descent_selected := false
var _descent_ready := false


func _ready() -> void:
	layer = 3
	var back := ColorRect.new()
	# The title image uses RGB 2 black; matching it makes its bounds disappear.
	back.color = BACK
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)

	_build_main()
	_build_instructions()
	_build_about()
	_build_credits()
	_set_page(Page.MAIN)
	_relayout()
	get_viewport().size_changed.connect(_relayout)


func _page_root() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_theme_constant_override("separation", 7)
	page.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(page)
	return page


func _build_main() -> void:
	var page := _page_root()
	_pages[Page.MAIN] = page

	var eyebrow := _label("AI & DESIGN GAME STUDIOS  /  PRESENTS", 14, DIM)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(eyebrow)

	_logo = TextureRect.new()
	_logo.texture = load("res://textures/ui/title.png")
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.custom_minimum_size = Vector2(0, 360)
	_logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(_logo)

	page.add_child(_rule(520))
	var menu := VBoxContainer.new()
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.add_theme_constant_override("separation", 3)
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	page.add_child(menu)
	_menu_button(menu, "SPACE        WANDER", _select_wander)
	_menu_button(menu, "ENTER        DESCENT", _select_descent)
	_menu_button(menu, "I            INSTRUCTIONS",
		func(): _set_page(Page.INSTRUCTIONS))
	_menu_button(menu, "A            ABOUT",
		func(): _set_page(Page.ABOUT))
	_menu_button(menu, "C            CREDITS",
		func(): _set_page(Page.CREDITS))

	_prompt = _label("CHOOSE HOW TO ENTER", 15, GOLD)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(_prompt)


func _build_instructions() -> void:
	var page := _page_root()
	_pages[Page.INSTRUCTIONS] = page
	_page_heading(page, "INSTRUCTIONS", "THE BUILDING WILL NOT EXPLAIN ITSELF TWICE")

	var wander := _paragraph(
		"WANDER  /  Explore eight endless procedural worlds. Elevators and "
		+ "portals carry you between floors, and every floor remembers where "
		+ "you left it.", 17, BODY, 820)
	page.add_child(wander)
	var descent := _paragraph(
		"DESCENT  /  Cross all eight floors in order. Follow the route needle. "
		+ "There is no sprinting, floor selection or way to disable the video "
		+ "filter. The rules are shown after you choose the mode.", 17, BODY, 820)
	page.add_child(descent)
	page.add_child(_rule(820))

	var controls := VBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 3)
	controls.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	page.add_child(controls)
	for instruction in INSTRUCTION_ROWS:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 30)
		row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var key := _label(str(instruction[0]), 17, CREAM, 210)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var action := _label(str(instruction[1]), 17, BODY, 500)
		row.add_child(key)
		row.add_child(action)
		controls.add_child(row)

	var aside := _label(
		"Move the mouse to look. The flashlight burns back what should not be there.",
		15, DIM)
	aside.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(aside)
	_return_button(page, "I")


func _build_about() -> void:
	var page := _page_root()
	_pages[Page.ABOUT] = page
	_page_heading(page, "ABOUT", "A GAME ABOUT PLACES THAT HAVE FORGOTTEN THEIR PURPOSE")

	var title := _label("LIMINAL SPACES", 38, CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(title)
	page.add_child(_rule(650))
	var description := _paragraph(
		"Eight endless procedural interiors, connected by elevators, portals "
		+ "and the suspicion that the architecture is paying attention.",
		19, BODY, 720)
	page.add_child(description)

	var gap := Control.new()
	gap.custom_minimum_size.y = 20
	page.add_child(gap)
	var authored := _label("CREATED AND AUTHORED BY", 16, DIM)
	authored.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(authored)
	var author := _label("MARCO VAN HYLCKAMA VLIEG", 30, CREAM)
	author.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(author)
	var studio := _label("AI & DESIGN GAME STUDIOS", 22, GOLD)
	studio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(studio)

	var gap2 := Control.new()
	gap2.custom_minimum_size.y = 20
	page.add_child(gap2)
	var acknowledgement := _paragraph(
		"All third-party 3D model creators and supporting asset authors are "
		+ "acknowledged on the CREDITS screen. Full model titles, source links, "
		+ "licenses and modifications are recorded in THIRD_PARTY_ASSETS.md.",
		16, BODY, 780)
	page.add_child(acknowledgement)
	var credit_link := _label("PRESS  C  FOR  CREATOR  ACKNOWLEDGEMENTS", 18, GOLD)
	credit_link.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(credit_link)
	_return_button(page, "A")


func _build_credits() -> void:
	var page := _page_root()
	_pages[Page.CREDITS] = page
	_page_heading(page, "CREDITS", "3D MODEL & ASSET CREATOR ACKNOWLEDGEMENTS")

	for section in CREDIT_SECTIONS:
		var section_head := _label(str(section[0]), 16, GOLD)
		section_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		page.add_child(section_head)
		for credit in section[1]:
			var line := _label(str(credit), 14, BODY)
			line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			page.add_child(line)
		var gap := Control.new()
		gap.custom_minimum_size.y = 7
		page.add_child(gap)

	var details := _label(
		"FULL TITLES, LINKS, LICENSES & MODIFICATIONS  /  THIRD_PARTY_ASSETS.md",
		14, DIM)
	details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(details)
	_return_button(page, "C")


func _build_descent() -> void:
	var page := _page_root()
	_pages[Page.DESCENT] = page
	_page_heading(page, "DESCENT", "THE BUILDING HAS FOUR RULES")
	var rules := [
		"DO NOT STARE AT THEM",
		"DO NOT STOP WALKING",
		"DO NOT GO BACK",
		"WHEN THE LIGHTS FAIL, STAND STILL",
	]
	for i in rules.size():
		var line := _label("%02d     %s" % [i + 1, rules[i]], 25, CREAM)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		page.add_child(line)
	var gap := Control.new()
	gap.custom_minimum_size.y = 18
	page.add_child(gap)
	var warn := _label("AND ONE THING THAT IS NOT A RULE", 15, DIM)
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(warn)
	var warn2 := _label(
		"WHAT REACHES YOU TAKES YOU  —  BURN IT WITH THE TORCH",
		20, Color(0.80, 0.66, 0.50))
	warn2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(warn2)
	page.add_child(_rule(760))
	_prompt = _label("PREPARING THE FIRST FLOOR", 19, GOLD)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(_prompt)


func _page_heading(parent: VBoxContainer, heading: String,
		subheading: String) -> void:
	var marker := _label("LIMINAL SPACES  /  ARCHIVE", 13, DIM)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(marker)
	var head := _label(heading, 40, CREAM)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(head)
	var sub := _label(subheading, 16, GOLD)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(sub)
	parent.add_child(_rule(820))


func _return_button(parent: VBoxContainer, page_key: String) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	parent.add_child(gap)
	var button := _button(
		"ESC  /  SPACE  /  %s        RETURN TO TITLE" % page_key,
		func(): _set_page(Page.MAIN), 420, 34, true)
	parent.add_child(button)


func _menu_button(parent: VBoxContainer, text: String,
		action: Callable) -> void:
	parent.add_child(_button(text, action, 520, 38))


func _button(text: String, action: Callable, width: float,
		height: float, centered := false) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER if centered \
		else HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style(button, 19, CREAM, width, height)
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.82))
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_stylebox_override("normal", _button_box(Color(0, 0, 0, 0),
		Color(0.24, 0.22, 0.18, 0.55)))
	button.add_theme_stylebox_override("hover", _button_box(
		Color(0.08, 0.075, 0.06, 0.95), GOLD))
	button.add_theme_stylebox_override("pressed", _button_box(
		Color(0.12, 0.105, 0.075, 1.0), CREAM))
	button.pressed.connect(action)
	return button


func _button_box(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.border_width_left = 2
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.corner_radius_top_left = 2
	box.corner_radius_bottom_left = 2
	return box


func _rule(width: float) -> ColorRect:
	var rule := ColorRect.new()
	rule.color = Color(0.32, 0.29, 0.23, 0.75)
	rule.custom_minimum_size = Vector2(width, 1)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule


func _paragraph(text: String, size: int, color: Color,
		width: float) -> Label:
	var label := _label(text, size, color, width)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return label


func _label(text: String, size: int, color: Color,
		width := 0.0) -> Label:
	var label := Label.new()
	label.text = text
	_style(label, size, color, width)
	if width > 0.0:
		label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return label


func _style(control: Control, size: int, color: Color,
		width := 0.0, height := 0.0) -> void:
	_scaled.append([control, float(size), width, height])
	control.add_theme_font_override("font", UI_FONT)
	control.add_theme_font_size_override("font_size", size)
	control.add_theme_color_override("font_color", color)
	control.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	control.add_theme_constant_override("shadow_offset_x", 1)
	control.add_theme_constant_override("shadow_offset_y", 1)
	if width > 0.0 or height > 0.0:
		control.custom_minimum_size = Vector2(width, height)


## Controls are laid out in raw pixels, so scale from the 1280×720 authored
## frame while respecting both viewport axes.
func _relayout() -> void:
	var viewport: Vector2i = get_viewport().size
	var scale := clampf(minf(float(viewport.x) / 1280.0,
		float(viewport.y) / 720.0), 0.55, 3.0)
	if is_instance_valid(_logo):
		_logo.custom_minimum_size = Vector2(0, 360.0 * scale)
	for entry in _scaled:
		var control: Control = entry[0]
		if not is_instance_valid(control):
			continue
		control.add_theme_font_size_override("font_size",
			maxi(9, roundi(float(entry[1]) * scale)))
		var width := float(entry[2]) * scale
		var height := float(entry[3]) * scale
		if width > 0.0 or height > 0.0:
			control.custom_minimum_size = Vector2(width, height)


func _process(dt: float) -> void:
	_t += dt
	if is_instance_valid(_prompt):
		_prompt.modulate.a = 0.60 + 0.40 * (0.5 + 0.5 * sin(_t * 2.2))


## The title consumes every key so the already-built world cannot move behind
## it. Main-menu shortcuts remain the original SPACE/ENTER contract.
func _input(event: InputEvent) -> void:
	if _gone or not event is InputEventKey \
			or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode
	if _current_page == Page.DESCENT:
		if key == KEY_SPACE and _descent_ready:
			_start(true)
		get_viewport().set_input_as_handled()
		return
	if _current_page == Page.MAIN:
		match key:
			KEY_SPACE:
				_select_wander()
			KEY_ENTER, KEY_KP_ENTER:
				_select_descent()
			KEY_I:
				_set_page(Page.INSTRUCTIONS)
			KEY_A:
				_set_page(Page.ABOUT)
			KEY_C:
				_set_page(Page.CREDITS)
	else:
		if key == KEY_ESCAPE or key == KEY_SPACE:
			_set_page(Page.MAIN)
		elif key == KEY_I:
			_set_page(Page.INSTRUCTIONS)
		elif key == KEY_A:
			_set_page(Page.ABOUT)
		elif key == KEY_C:
			_set_page(Page.CREDITS)
	get_viewport().set_input_as_handled()


func _set_page(page: Page) -> void:
	if _descent_selected and page != Page.DESCENT:
		return
	_current_page = page
	for key in _pages:
		(_pages[key] as Control).visible = int(key) == int(page)


func _select_wander() -> void:
	if _gone or _current_page != Page.MAIN:
		return
	mode_selected.emit(false)
	_start(false)


func _select_descent() -> void:
	if _gone or _descent_selected or _current_page != Page.MAIN:
		return
	_descent_selected = true
	if not _pages.has(Page.DESCENT):
		_build_descent()
	_set_page(Page.DESCENT)
	mode_selected.emit(true)
	_relayout()


func set_descent_ready() -> void:
	_descent_ready = true
	if _descent_selected and is_instance_valid(_prompt):
		_prompt.text = "PRESS  SPACE  TO  DESCEND"


func present_descent(ready := false) -> void:
	if not _descent_selected:
		_descent_selected = true
		if not _pages.has(Page.DESCENT):
			_build_descent()
		_set_page(Page.DESCENT)
		_relayout()
	if ready:
		set_descent_ready()


## Kept as a stable preview hook for tools/preview_credits.gd.
func _show_descent_rules() -> void:
	present_descent(_descent_ready)


## Stable preview/navigation hooks.
func _show_instructions() -> void:
	_set_page(Page.INSTRUCTIONS)


func _show_about() -> void:
	_set_page(Page.ABOUT)


func _show_credits() -> void:
	_set_page(Page.CREDITS)


func _start(selected_descent: bool) -> void:
	if _gone:
		return
	_gone = true
	set_process_input(false)
	started.emit(selected_descent)
	var tween := create_tween()
	tween.tween_property(self, "offset:y", -40.0, 0.5)
	tween.parallel().tween_method(_dim, 1.0, 0.0, 0.5)
	await tween.finished
	queue_free()


func _dim(alpha: float) -> void:
	for child in get_children():
		(child as CanvasItem).modulate.a = alpha

class_name TitleScreen
extends CanvasLayer
## Front door for the game: a quiet title, then one deliberate page at a time.
##
## The generated world is already alive behind this opaque layer, but player
## input, figures and haunt timers remain suspended until a mode starts.

signal mode_selected(descent: bool)
signal started(descent: bool)
signal descent_requested(entry: int)

enum DescentEntry {
	CONTINUE,
	RESTART,
	NEW,
}

enum Page {
	MAIN,
	INSTRUCTIONS,
	ABOUT,
	CREDITS,
	DESCENT,
}

const UI_FONT: Font = preload("res://fonts/VT323-Regular.ttf")
const TITLE_ART: Texture2D = preload("res://textures/ui/title_screen.png")
const INSTRUCTION_ROWS := [
	["WASD  /  ARROWS", "Walk"],
	["SHIFT", "Run  ·  Draws attention in Descent"],
	["E", "Use terminals, lifts, doors and charging stations"],
	["F", "Toggle the flashlight"],
	["C  /  SPACE", "Raise camera  /  Take photograph"],
	["1  —  9", "Move between the original floors  ·  Wander only"],
	["0", "Enter the Data Center  ·  Wander only"],
	["−", "Enter the Bloom  ·  Wander only"],
	["V", "Toggle the video filter"],
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
			"    Rylae Shylna · maxdragonn · dannaki_",
			"ANNEX   carlcapu9 · Avot · Drake · jimbogies · Doverlock · Archer Sterling",
			"AIRPORT   Bucks / Its_Bucks · Ellis Fossett · n.philipsen · assetfactory",
			"ASYLUM   Veterock · loxfear · Ellie · creative_beast · Mehdi Shahsavan",
			"    Matt LeMoine",
			"SCHOOL   Jawahar Yokesh · dercruz926 · barism09 · neverfollow81 · CAL21",
			"    Osian CG · HippoStance · Dun · FLUXIUM3D · ap-school",
			"MALL   AdrianXY · mtaesiri · kapookkt · shirlanne · matejbiskup97 · Katydid",
			"    Some Random Mall Modeller · MaX3Dd",
			"PRISON   neverfollow81 · Mark Peters · Mehdi Shahsavan / adventurer",
			"    dudecon",
			"POOLROOMS   NXTLVLPLY · CadmiumCoffee (bsishir) · JackFarrand",
			"DATA CENTER   Mark Peters · carlcapu9 · FlevasGR · JamieDTran",
			"    EntropyNine · Khoa Nguyen · Lora · wpanayides · JmPrsh153 · Network manager",
			"BLOOM   Somersby · ChopperManiac · Mark Peters",
			"CC BY 4.0 except  Katydid  ·  CC BY-NC 4.0",
			"and  dannaki_, assetfactory, MaX3Dd  ·  Sketchfab Standard",
		]],
	["SURFACES, TYPE & FIGURES",
		[
			"ambientCG + Poly Haven + TextureCan  ·  CC0     Peter Hull / VT323  ·  SIL Open Font License",
			"Mette Aumala · Madeleine Price Ball · OpenClipart-Vectors  ·  CC0",
			"Phil Bronnery / Beao  —  walking woman silhouette  ·  CC BY 2.0",
		]],
]

const CREAM := Color(0.93, 0.88, 0.75)
const GOLD := Color(0.77, 0.69, 0.53)
const BODY := Color(0.66, 0.64, 0.58)
const DIM := Color(0.58, 0.57, 0.52)
const BACK := Color8(2, 2, 2)

var _background: TextureRect
var _page_shade: ColorRect
var _main_dock: VBoxContainer
var _pages: Dictionary = {}
var _scaled: Array[Array] = []   # [Control, base font, width, height]
var _prompt: Label
var _current_page := Page.MAIN
var _t := 0.0
var _gone := false
var _descent_selected := false
var _descent_ready := false
var _has_descent_progress := false
var _checkpoint_floor := 0
var _checkpoint_name := ""
var _descent_entry := DescentEntry.NEW


func _ready() -> void:
	# The supplied title art already owns its VHS treatment. Keep menu and rule
	# typography above the layer-100 gameplay post pass so instructional text is
	# not blurred, bloomed and scan-resampled a second time.
	layer = 101
	var back := ColorRect.new()
	back.color = BACK
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)

	# The supplied composition is the title. Cover the viewport so the corridor
	# remains immersive at 16:9 while its own black perimeter absorbs the modest
	# vertical crop from the 3:2 source image.
	_background = TextureRect.new()
	_background.texture = TITLE_ART
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_background)

	# Secondary pages retain the artwork as their ground, but quiet it enough
	# for long-form instructions and credits to remain comfortably readable.
	_page_shade = ColorRect.new()
	_page_shade.color = Color(0.002, 0.002, 0.002, 0.91)
	_page_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_page_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_shade.visible = false
	add_child(_page_shade)

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
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(page)
	_pages[Page.MAIN] = page

	# Keep all interaction below the authored image hierarchy. The footer has no
	# opaque card: the artwork's heavy lower vignette already supplies contrast.
	_main_dock = VBoxContainer.new()
	_main_dock.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_main_dock.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(_main_dock)

	_prompt = _label(
		"CHECKPOINT  /  FLOOR %02d  /  %s" % [
			_checkpoint_floor + 1, _checkpoint_name.to_upper()]
			if _has_descent_progress else "SELECT ENTRY",
		22, Color(0.62, 0.64, 0.60))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main_dock.add_child(_prompt)

	var menu := HBoxContainer.new()
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.add_theme_constant_override("separation", 8)
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_main_dock.add_child(menu)
	_footer_button(menu, "SPACE  WANDER", _select_wander)
	if _has_descent_progress:
		_footer_button(menu, "ENTER  CONTINUE F%02d" % [
			_checkpoint_floor + 1],
			func(): _select_descent(DescentEntry.CONTINUE))
		_footer_button(menu, "R  RESTART DESCENT",
			func(): _select_descent(DescentEntry.RESTART))
		_footer_button(menu, "N  NEW DESCENT",
			func(): _select_descent(DescentEntry.NEW))
	else:
		_footer_button(menu, "ENTER  DESCENT",
			func(): _select_descent(DescentEntry.NEW))
	# Keep saved-run actions together and the reference pages on their own row.
	# Seven full-size buttons cannot fit in one title-safe 16:9 footer.
	var info := HBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 8)
	info.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_main_dock.add_child(info)
	_footer_button(info, "I  INSTRUCTIONS",
		func(): _set_page(Page.INSTRUCTIONS))
	_footer_button(info, "A  ABOUT",
		func(): _set_page(Page.ABOUT))
	_footer_button(info, "C  CREDITS",
		func(): _set_page(Page.CREDITS))


func _build_instructions() -> void:
	var page := _page_root()
	_pages[Page.INSTRUCTIONS] = page
	_page_heading(page, "INSTRUCTIONS", "THE BUILDING WILL NOT EXPLAIN ITSELF TWICE")

	var wander := _paragraph(
		"WANDER  /  Explore eleven endless procedural worlds. Number keys and "
		+ "physical elevators carry you between floors, and every floor remembers where "
		+ "you left it.", 17, BODY, 820)
	page.add_child(wander)
	var descent := _paragraph(
		"DESCENT  /  Cross all eleven floors in order. Follow the distance counter. "
		+ "Sprinting drains a short reserve; there is no floor selection. The "
		+ "rules are shown after you choose the mode.", 17, BODY, 820)
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
	_page_heading(page, "ABOUT",
		"A HORROR GAME ABOUT A BUILDING THAT REFUSES TO LET GO")

	var title := _label("IT WANTS YOU TO STAY", 46, CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(title)
	page.add_child(_rule(760))
	var description := _paragraph(
		"A first-person horror descent through eleven procedural spaces. Follow "
		+ "Dr. Cross's recovered tapes, survive what hunts the halls, and find "
		+ "the elevator before the architecture decides you belong to it.",
		20, BODY, 820)
	page.add_child(description)
	var modes := _label(
		"DESCENT  /  THE STORY        WANDER  /  THE ENDLESS BUILDING",
		17, GOLD)
	modes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(modes)

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
	# This is the last reading screen before the film/game takes over. Its old
	# body sizes were technically scaled but still dissolved through a large
	# display and the title artwork. Give the rule the visual authority of a
	# warning card, with a clear hierarchy readable from across the room.
	_page_heading(page, "DESCENT", "THE BUILDING HAS ONE RULE",
		56, 23, 18)
	var rules := [
		"WHEN THE LIGHTS FAIL, STAND STILL",
	]
	for i in rules.size():
		var line := _label("%02d     %s" % [i + 1, rules[i]], 38, CREAM)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		page.add_child(line)
	var gap := Control.new()
	gap.custom_minimum_size.y = 28
	page.add_child(gap)
	var warn := _label("AND ONE THING THAT IS NOT A RULE", 22, DIM)
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(warn)
	var warn2 := _label(
		"WHAT REACHES YOU TAKES YOU  —  BURN IT WITH THE TORCH",
		30, Color(0.80, 0.66, 0.50))
	warn2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(warn2)
	page.add_child(_rule(760))
	var preparing := "PREPARING THE FIRST FLOOR"
	if _descent_entry == DescentEntry.CONTINUE:
		preparing = "PREPARING FLOOR %02d  —  %s" % [
			_checkpoint_floor + 1, _checkpoint_name.to_upper()]
	elif _descent_entry == DescentEntry.RESTART:
		preparing = "RESETTING EVERYTHING  —  PREPARING FLOOR 01"
	_prompt = _label(preparing, 28, GOLD)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(_prompt)


func _page_heading(parent: VBoxContainer, heading: String,
		subheading: String, heading_size := 40, subheading_size := 16,
		marker_size := 13) -> void:
	var marker := _label("IT WANTS YOU TO STAY  /  RECOVERED ARCHIVE",
		marker_size, DIM)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(marker)
	var head := _label(heading, heading_size, CREAM)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(head)
	var sub := _label(subheading, subheading_size, GOLD)
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


func _footer_button(parent: HBoxContainer, text: String,
		action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# 30pt at the 720p base — the 20pt footer was unreadable through the
	# tube on large displays (owner, 2026-08-20).
	var width := maxf(150.0, 36.0 + float(text.length()) * 14.0)
	_style(button, 30, Color(0.80, 0.81, 0.76), width, 60)
	button.add_theme_color_override("font_hover_color", Color(0.94, 0.92, 0.82))
	button.add_theme_color_override("font_pressed_color", Color(0.84, 0.79, 0.63))
	button.add_theme_stylebox_override("normal",
		_footer_button_box(Color(0.0, 0.0, 0.0, 0.32),
			Color(0.30, 0.31, 0.28, 0.34)))
	button.add_theme_stylebox_override("hover",
		_footer_button_box(Color(0.025, 0.027, 0.024, 0.88),
			Color(0.72, 0.68, 0.51, 0.78)))
	button.add_theme_stylebox_override("pressed",
		_footer_button_box(Color(0.08, 0.075, 0.06, 0.92), CREAM))
	button.pressed.connect(action)
	parent.add_child(button)


func _footer_button_box(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.border_width_top = 1
	box.border_width_bottom = 1
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.corner_radius_top_left = 1
	box.corner_radius_top_right = 1
	box.corner_radius_bottom_left = 1
	box.corner_radius_bottom_right = 1
	return box


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
	control.add_theme_constant_override("shadow_offset_x", 2)
	control.add_theme_constant_override("shadow_offset_y", 2)
	# Same-ink outline: fattens the hairline so the tube pass keeps it.
	control.add_theme_color_override("font_outline_color", color)
	control.add_theme_constant_override("outline_size", 1)
	if width > 0.0 or height > 0.0:
		control.custom_minimum_size = Vector2(width, height)


## Controls are laid out in raw pixels, so scale from the 1280×720 authored
## frame while respecting both viewport axes.
func _relayout() -> void:
	var viewport: Vector2i = get_viewport().size
	var scale := clampf(minf(float(viewport.x) / 1280.0,
		float(viewport.y) / 720.0), 0.55, 3.0)
	# The footer used to retain a 70 px dock while its contents scaled up, which
	# clipped the buttons on large and tall displays. Scale the dock itself and
	# keep a generous safe margin below the controls.
	# Title-safe: the footer keeps at least the OSD's safe fraction from
	# every edge, whichever is larger at this size.
	var safe := VhsOsd.safe_inset(Vector2(viewport))
	if is_instance_valid(_main_dock):
		_main_dock.offset_left = maxf(34.0 * scale, safe.x)
		_main_dock.offset_right = -maxf(34.0 * scale, safe.x)
		_main_dock.offset_top = -(186.0 * scale + safe.y)
		_main_dock.offset_bottom = -safe.y
		_main_dock.add_theme_constant_override("separation",
			maxi(4, roundi(6.0 * scale)))
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
	if is_instance_valid(_background):
		# Almost imperceptible exposure drift keeps the still frame feeling like a
		# live tape without sliding or distorting the supplied composition.
		var exposure := 0.985 + sin(_t * 1.7) * 0.007 \
			+ sin(_t * 7.3) * 0.003
		_background.modulate = Color(exposure, exposure, exposure, 1.0)
	if is_instance_valid(_prompt):
		_prompt.modulate.a = 0.84 + 0.16 * (0.5 + 0.5 * sin(_t * 2.2))


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
			KEY_R:
				if _has_descent_progress:
					_select_descent(DescentEntry.RESTART)
			KEY_N:
				if _has_descent_progress:
					_select_descent(DescentEntry.NEW)
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
	if is_instance_valid(_page_shade):
		_page_shade.visible = page != Page.MAIN
	for key in _pages:
		(_pages[key] as Control).visible = int(key) == int(page)


func _select_wander() -> void:
	if _gone or _current_page != Page.MAIN:
		return
	mode_selected.emit(false)
	_start(false)


func _select_descent(entry := -1) -> void:
	if _gone or _descent_selected or _current_page != Page.MAIN:
		return
	if entry < 0:
		_descent_entry = DescentEntry.CONTINUE if _has_descent_progress \
			else DescentEntry.NEW
	else:
		_descent_entry = entry
	_descent_selected = true
	if not _pages.has(Page.DESCENT):
		_build_descent()
	_set_page(Page.DESCENT)
	descent_requested.emit(_descent_entry)
	mode_selected.emit(true)
	_relayout()


func set_descent_ready() -> void:
	_descent_ready = true
	if _descent_selected and is_instance_valid(_prompt):
		_prompt.text = "PRESS  SPACE  TO  CONTINUE" \
			if _descent_entry == DescentEntry.CONTINUE \
			else "PRESS  SPACE  TO  DESCEND"


## Called before this node enters the tree, so the main menu can be built with
## the saved run as a first-class choice rather than changing labels afterward.
func configure_descent_progress(has_progress: bool, floor_idx := 0,
		floor_name := "") -> void:
	_has_descent_progress = has_progress
	_checkpoint_floor = maxi(0, floor_idx)
	_checkpoint_name = floor_name


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

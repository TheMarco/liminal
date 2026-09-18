class_name TitleScreen
extends CanvasLayer
## Front door for the game: a quiet title, then one deliberate page at a time.
##
## The generated world is already alive behind this opaque layer, but player
## input, figures and haunt timers remain suspended until a mode starts.

signal mode_selected(descent: bool)
signal started(descent: bool)
signal settings_requested
signal descent_requested(entry: int)
signal quit_requested

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
	["C  /  SPACE  /  P", "Raise camera  /  Take photograph  /  Photo album"],
	["1  —  9", "Move between the original floors  ·  Wander only"],
	["0", "Enter the Data Center  ·  Wander only"],
	["−", "Enter the Bloom  ·  Wander only"],
	["Q", "Ask to leave the current mode"],
	["ESC", "Pause / settings"],
]
## Creators of the third-party models and surfaces used by the current game.
## The canonical record carries individual titles, links and modifications.
const CREDIT_SECTIONS := [
	["3D MODEL CREATORS",
		[
			"Poly Haven  ·  CC0     nisu / 3DModelsCC0  ·  CC0     WillowBoxArt",
			"CASINO   Dudzy",
			"OFFICE   Red Fox / nokillnando · NotAnotherApocalypticCo. · AquaEquinox",
			"    Rylae Shylna · maxdragonn · dannaki_",
		"ANNEX   carlcapu9 · Avot · Drake · jimbogies · varrocharlie · Archer Sterling",
			"AIRPORT   Bucks / Its_Bucks · Ellis Fossett · n.philipsen · assetfactory",
			"ASYLUM   Veterock · loxfear · Ellie · creative_beast · Mehdi Shahsavan · Matt LeMoine",
			"SCHOOL   Jawahar Yokesh · dercruz926 · barism09 · neverfollow81 · CAL21",
			"    Osian CG · HippoStance · Dun · FLUXIUM3D · ap-school",
			"MALL   kapookkt · matejbiskup97",
			"    Some Random Mall Modeller · MaX3Dd",
			"PRISON   neverfollow81 · Mark Peters · Mehdi Shahsavan / adventurer · dudecon",
			"POOLROOMS   NXTLVLPLY · CadmiumCoffee (bsishir)",
			"    SadiqKhan911 · ApprenticeRaccoon",
			"SHARED PROPS   William Burke · Tom Seddon · Parth · 5CNG5",
			"DATA CENTER   Mark Peters · carlcapu9 · FlevasGR · JamieDTran",
			"    EntropyNine · Khoa Nguyen · Lora · wpanayides · JmPrsh153 · Network manager",
			"BLOOM   Somersby · ChopperManiac · Mark Peters",
			"CC BY 4.0 except  dannaki_, assetfactory, MaX3Dd  ·  Sketchfab Standard",
		]],
	["SURFACES & TYPE",
		[
			"ambientCG + Poly Haven + TextureCan  ·  CC0     Peter Hull / VT323  ·  SIL Open Font License",
			"Kless Gyzen  —  Poolrooms tile textures  ·  CC BY 4.0",
		]],
]

const CREAM := Color(0.93, 0.88, 0.75)
const GOLD := Color(0.77, 0.69, 0.53)
const BODY := Color(0.66, 0.64, 0.58)
const DIM := Color(0.58, 0.57, 0.52)
const BACK := Color8(2, 2, 2)
const PAGE_WIDTH := 820.0
const PAGE_ORIGIN := Vector2(68.0, 48.0)

var _background: TextureRect
var _page_shade: TextureRect
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
var _entry_confirmation: ReturnPrompt
var _page_trigger: Control
var _primary_button: Button
var _descent_start_button: Button

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

	# The supplied 16:9 composition is the title. Cover preserves the image on
	# ordinary displays while allowing the black perimeter to absorb other ratios.
	_background = TextureRect.new()
	_background.texture = TITLE_ART
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# Its covered size is set explicitly in _relayout(): the logo side is pinned
	# to x=0 and any horizontal overflow is discarded only on the right.
	_background.stretch_mode = TextureRect.STRETCH_SCALE
	_background.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_background)

	# The archive pages stay inside the same composition. A left-side matte keeps
	# copy readable while fading away before it buries the corridor and figure.
	var shade_gradient := Gradient.new()
	shade_gradient.set_color(0, Color(0.002, 0.004, 0.003, 1.0))
	shade_gradient.add_point(0.60, Color(0.004, 0.006, 0.005, 1.0))
	shade_gradient.add_point(0.68, Color(0.004, 0.006, 0.005, 0.96))
	shade_gradient.add_point(0.82, Color(0.004, 0.006, 0.005, 0.42))
	shade_gradient.set_color(shade_gradient.get_point_count() - 1,
		Color(0.004, 0.006, 0.005, 0.08))
	var shade_texture := GradientTexture2D.new()
	shade_texture.gradient = shade_gradient
	shade_texture.width = 1280
	shade_texture.height = 4
	shade_texture.fill_from = Vector2(0.0, 0.5)
	shade_texture.fill_to = Vector2(1.0, 0.5)
	_page_shade = TextureRect.new()
	_page_shade.texture = shade_texture
	_page_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_page_shade.stretch_mode = TextureRect.STRETCH_SCALE
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


func _page_root(base_separation := 7.0) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	page.alignment = BoxContainer.ALIGNMENT_BEGIN
	page.set_meta("base_separation", base_separation)
	page.add_theme_constant_override("separation", roundi(base_separation))
	page.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(page)
	return page


func _build_main() -> void:
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(page)
	_pages[Page.MAIN] = page

	# The artwork reserves the wall beneath its upper-left logo for navigation.
	# One narrow column keeps every option legible without obscuring either figure.
	_main_dock = VBoxContainer.new()
	_main_dock.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_main_dock.alignment = BoxContainer.ALIGNMENT_BEGIN
	page.add_child(_main_dock)

	_prompt = _label(
		"CHECKPOINT  /  FLOOR %02d  /  %s" % [
			_checkpoint_floor + 1, _checkpoint_name.to_upper()]
			if _has_descent_progress else "SELECT ENTRY",
		14, Color(0.68, 0.70, 0.66))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_main_dock.add_child(_prompt)

	_title_button(_main_dock, "WANDER", _select_wander)
	if _has_descent_progress:
		_primary_button = _title_button(_main_dock, "CONTINUE F%02d" % [
			_checkpoint_floor + 1],
			func(): _select_descent(DescentEntry.CONTINUE))
		_title_button(_main_dock, "RESTART DESCENT",
			func(): _select_descent(DescentEntry.RESTART))
		_title_button(_main_dock, "NEW DESCENT",
			func(): _select_descent(DescentEntry.NEW))
	else:
		_primary_button = _title_button(_main_dock, "DESCENT",
			func(): _select_descent(DescentEntry.NEW))
	_title_button(_main_dock, "SETTINGS",
		func(): settings_requested.emit())
	_title_button(_main_dock, "INSTRUCTIONS",
		func(): _set_page(Page.INSTRUCTIONS))
	_title_button(_main_dock, "ABOUT",
		func(): _set_page(Page.ABOUT))
	_title_button(_main_dock, "CREDITS",
		func(): _set_page(Page.CREDITS))
	_title_button(_main_dock, "QUIT", func(): quit_requested.emit())


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
	controls.alignment = BoxContainer.ALIGNMENT_BEGIN
	controls.add_theme_constant_override("separation", 3)
	controls.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	page.add_child(controls)
	for instruction in INSTRUCTION_ROWS:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_BEGIN
		row.add_theme_constant_override("separation", 30)
		row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var key := _label(str(instruction[0]), 17, CREAM, 210)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var action := _label(str(instruction[1]), 17, BODY, 500)
		row.add_child(key)
		row.add_child(action)
		controls.add_child(row)

	var aside := _label(
		"Move the mouse to look. The flashlight burns back what should not be there.",
		15, DIM)
	aside.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	page.add_child(aside)
	_return_button(page)


func _build_about() -> void:
	var page := _page_root()
	_pages[Page.ABOUT] = page
	_page_heading(page, "ABOUT",
		"A HORROR GAME ABOUT A BUILDING THAT REFUSES TO LET GO")

	var title := _label("IT WANTS YOU TO STAY", 46, CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
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
	modes.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	page.add_child(modes)

	var gap := Control.new()
	gap.custom_minimum_size.y = 20
	page.add_child(gap)
	var authored := _label("CREATED AND AUTHORED BY", 16, DIM)
	authored.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	page.add_child(authored)
	var author := _label("MARCO VAN HYLCKAMA VLIEG", 30, CREAM)
	author.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	page.add_child(author)
	var studio := _label("AI & DESIGN GAME STUDIOS", 22, GOLD)
	studio.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
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
	var credit_link := _label("CREATOR ACKNOWLEDGEMENTS  /  CREDITS", 18, GOLD)
	credit_link.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	page.add_child(credit_link)
	_return_button(page)


func _build_credits() -> void:
	var page := _page_root(3.0)
	_pages[Page.CREDITS] = page
	_page_heading(page, "CREDITS", "3D MODEL & ASSET CREATOR ACKNOWLEDGEMENTS")

	for section in CREDIT_SECTIONS:
		var section_head := _label(str(section[0]), 16, GOLD)
		section_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		page.add_child(section_head)
		for credit in section[1]:
			var line := _label(str(credit), 14, BODY)
			line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			page.add_child(line)
		var gap := Control.new()
		gap.custom_minimum_size.y = 7
		page.add_child(gap)

	var details := _label(
		"FULL TITLES, LINKS, LICENSES & MODIFICATIONS  /  THIRD_PARTY_ASSETS.md",
		14, DIM)
	details.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	page.add_child(details)
	_return_button(page)


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
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		page.add_child(line)
	var gap := Control.new()
	gap.custom_minimum_size.y = 28
	page.add_child(gap)
	var warn := _label("AND ONE THING THAT IS NOT A RULE", 22, DIM)
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	page.add_child(warn)
	var warn2 := _label(
		"WHAT REACHES YOU TAKES YOU  —  BURN IT WITH THE TORCH",
		30, Color(0.80, 0.66, 0.50))
	warn2.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	page.add_child(warn2)
	page.add_child(_rule(760))
	var preparing := "PREPARING THE FIRST FLOOR"
	if _descent_entry == DescentEntry.CONTINUE:
		preparing = "PREPARING FLOOR %02d  —  %s" % [
			_checkpoint_floor + 1, _checkpoint_name.to_upper()]
	elif _descent_entry == DescentEntry.RESTART:
		preparing = "RESETTING EVERYTHING  —  PREPARING FLOOR 01"
	_prompt = _label(preparing, 28, GOLD)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	page.add_child(_prompt)
	_descent_start_button = _button(
		"CONTINUE" if _descent_entry == DescentEntry.CONTINUE else "DESCEND",
		func():
			if _descent_ready:
				_start(true),
		300, 60, false, 28)
	_descent_start_button.disabled = true
	page.add_child(_descent_start_button)


func _page_heading(parent: VBoxContainer, heading: String,
		subheading: String, heading_size := 40, subheading_size := 16,
		marker_size := 13) -> void:
	var marker := _label("IT WANTS YOU TO STAY  /  RECOVERED ARCHIVE",
		marker_size, DIM)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(marker)
	var head := _label(heading, heading_size, CREAM)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(head)
	var sub := _label(subheading, subheading_size, GOLD)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(sub)
	parent.add_child(_rule(820))


func _return_button(parent: VBoxContainer) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	parent.add_child(gap)
	var button := _button(
		"RETURN TO TITLE",
		func(): _set_page(Page.MAIN), 240, 34, false)
	parent.add_child(button)


func _title_button(parent: VBoxContainer, text: String,
		action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.size_flags_horizontal = Control.SIZE_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style(button, 20, Color(0.86, 0.87, 0.82), 220, 34)
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.97, 0.86))
	button.add_theme_color_override("font_pressed_color", CREAM)
	button.add_theme_stylebox_override("normal",
		_title_button_box(Color(0.0, 0.0, 0.0, 0.14),
			Color(0.54, 0.56, 0.51, 0.46)))
	button.add_theme_stylebox_override("hover",
		_title_button_box(Color(0.02, 0.025, 0.022, 0.82),
			Color(0.88, 0.82, 0.61, 0.94)))
	button.add_theme_stylebox_override("pressed",
		_title_button_box(Color(0.07, 0.065, 0.05, 0.90), CREAM))
	button.add_theme_stylebox_override("focus",
		_title_button_box(Color(0.04, 0.045, 0.038, 0.88), CREAM))
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _title_button_box(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.border_width_left = 2
	box.content_margin_left = 12
	box.content_margin_right = 8
	box.corner_radius_top_right = 2
	box.corner_radius_bottom_right = 2
	return box


func _button(text: String, action: Callable, width: float,
		height: float, centered := false, font_size := 19) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER if centered \
		else HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style(button, font_size, CREAM, width, height)
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.82))
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_stylebox_override("normal", _button_box(Color(0, 0, 0, 0),
		Color(0.24, 0.22, 0.18, 0.55)))
	button.add_theme_stylebox_override("hover", _button_box(
		Color(0.08, 0.075, 0.06, 0.95), GOLD))
	button.add_theme_stylebox_override("pressed", _button_box(
		Color(0.12, 0.105, 0.075, 1.0), CREAM))
	button.add_theme_stylebox_override("focus", _button_box(
		Color(0.08, 0.075, 0.06, 0.95), CREAM))
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
	_scaled.append([rule, 0.0, width, 1.0])
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule


func _paragraph(text: String, size: int, color: Color,
		width: float) -> Label:
	var label := _label(text, size, color, width)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return label


func _label(text: String, size: int, color: Color,
		width := 0.0) -> Label:
	var label := Label.new()
	label.text = text
	_style(label, size, color, width)
	if width > 0.0:
		label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
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


## Secondary pages scale from the 1280x720 UI frame. The artwork is cover-sized
## but left-pinned: tall windows may lose corridor on the right, never the logo.
## The main menu follows those same artwork coordinates beneath the baked mark.
func _relayout() -> void:
	var viewport: Vector2i = get_viewport().size
	var scale := clampf(minf(float(viewport.x) / 1280.0,
		float(viewport.y) / 720.0), 0.55, 3.0)
	var safe := VhsOsd.safe_inset(Vector2(viewport))
	var art_size := Vector2(TITLE_ART.get_width(), TITLE_ART.get_height())
	var art_scale := maxf(float(viewport.x) / art_size.x,
		float(viewport.y) / art_size.y)
	var covered_size := art_size * art_scale
	var art_origin := Vector2(0.0,
		(float(viewport.y) - covered_size.y) * 0.5)
	if is_instance_valid(_background):
		_background.offset_left = art_origin.x
		_background.offset_top = art_origin.y
		_background.offset_right = art_origin.x + covered_size.x
		_background.offset_bottom = art_origin.y + covered_size.y
	if is_instance_valid(_main_dock):
		var menu_origin := art_origin + Vector2(318.0, 400.0) * art_scale
		var left := maxf(safe.x, menu_origin.x)
		var top := maxf(safe.y, menu_origin.y)
		_main_dock.offset_left = left
		_main_dock.offset_right = minf(float(viewport.x) - safe.x,
			left + 220.0 * scale)
		_main_dock.offset_top = top
		_main_dock.offset_bottom = float(viewport.y) - safe.y
		_main_dock.add_theme_constant_override("separation",
			maxi(2, roundi(4.0 * scale)))
	var page_left := maxf(safe.x, PAGE_ORIGIN.x * scale)
	var page_top := maxf(safe.y, PAGE_ORIGIN.y * scale)
	for key in _pages:
		if int(key) == Page.MAIN:
			continue
		var page := _pages[key] as Control
		if not is_instance_valid(page):
			continue
		page.offset_left = page_left
		page.offset_right = minf(float(viewport.x) - safe.x,
			page_left + PAGE_WIDTH * scale)
		page.offset_top = page_top
		page.offset_bottom = float(viewport.y) - safe.y
		var base_separation := float(page.get_meta("base_separation", 7.0))
		page.add_theme_constant_override("separation",
			maxi(1, roundi(base_separation * scale)))
	for entry in _scaled:
		var control: Control = entry[0]
		if not is_instance_valid(control):
			continue
		if float(entry[1]) > 0.0:
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


## One interaction model: activate a visible button, with mouse or GUI focus.
## No action-specific shortcuts compete with the focused button. Consume other
## keys so the already-built world cannot move behind the title.
func _input(event: InputEvent) -> void:
	if is_instance_valid(_entry_confirmation):
		return  # The confirmation owns keyboard and mouse input until dismissed.
	if _gone or not event is InputEventKey \
			or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	var focused := get_viewport().gui_get_focus_owner()
	if key in [KEY_TAB, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		if not (focused is Button and is_ancestor_of(focused) and focused.is_visible_in_tree()):
			_focus_page_control(_current_page)
			get_viewport().set_input_as_handled()
		return
	if key in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER] and focused is Button \
			and is_ancestor_of(focused) and focused.is_visible_in_tree():
		return
	if key == KEY_ESCAPE and _current_page in [Page.INSTRUCTIONS, Page.ABOUT, Page.CREDITS]:
		_set_page(Page.MAIN)
	elif key in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		# The first key reveals focus; it must not launch a different action just
		# because nothing had focus yet.
		_focus_page_control(_current_page)
	get_viewport().set_input_as_handled()

func _unhandled_input(_event: InputEvent) -> void:
	if not _gone and not is_instance_valid(_entry_confirmation):
		get_viewport().set_input_as_handled()


func _set_page(page: Page) -> void:
	if _descent_selected and page != Page.DESCENT:
		return
	var focused := get_viewport().gui_get_focus_owner()
	var restore_focus := focused != null and is_ancestor_of(focused)
	if restore_focus:
		focused.release_focus()
	_current_page = page
	if is_instance_valid(_page_shade):
		_page_shade.visible = page != Page.MAIN
	for key in _pages:
		(_pages[key] as Control).visible = int(key) == int(page)
	if restore_focus:
		call_deferred("_focus_page_control", page)

func _focus_page_control(page: Page) -> void:
	if page == Page.MAIN and is_instance_valid(_primary_button) \
			and _primary_button.is_visible_in_tree():
		_primary_button.grab_focus()
		return
	var root: Node = _pages.get(page)
	if not root:
		return
	var controls := root.find_children("*", "Control", true, false)
	for node in controls:
		if node is Button and node.is_visible_in_tree() and not node.disabled:
			(node as Control).grab_focus()
			return


func _select_wander() -> void:
	if _gone or _current_page != Page.MAIN:
		return
	mode_selected.emit(false)
	_start(false)


func _select_descent(entry := -1) -> void:
	if _gone or _descent_selected or _current_page != Page.MAIN \
			or is_instance_valid(_entry_confirmation):
		return
	if entry < 0:
		entry = DescentEntry.CONTINUE if _has_descent_progress \
			else DescentEntry.NEW
	if _has_descent_progress and entry != DescentEntry.CONTINUE:
		_entry_confirmation = ReturnPrompt.new()
		_entry_confirmation.heading_text = "REPLACE THIS DESCENT?"
		_entry_confirmation.warning_text = \
			"YOUR FLOOR %02d CHECKPOINT AND RUN PROGRESS WILL BE REPLACED.\n%s" % [
				_checkpoint_floor + 1, "START AGAIN IN A NEW BUILDING?" if entry == DescentEntry.NEW
				else "START AGAIN FROM FLOOR 01?"]
		_entry_confirmation.confirmed.connect(func():
			_cancel_descent_entry()
			_begin_descent(entry))
		_entry_confirmation.cancelled.connect(_cancel_descent_entry)
		add_child(_entry_confirmation)
		_entry_confirmation.layer = 112
		return
	_begin_descent(entry)


func _cancel_descent_entry() -> void:
	if is_instance_valid(_entry_confirmation):
		_entry_confirmation.queue_free()
	_entry_confirmation = null
	call_deferred("_focus_page_control", _current_page)


## No world preparation or checkpoint writes are requested until confirmation.
func _begin_descent(entry: int) -> void:
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
		_prompt.visible = false
		_descent_start_button.disabled = false
		call_deferred("_focus_page_control", Page.DESCENT)


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

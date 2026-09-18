extends SceneTree
## Active preload resources, credit regressions and removal of retired assets.
## godot --headless --path . --script tools/audit_asset_credits.gd

const RETIRED_DIRS := [
	"res://models/cc_by/alarm/",
	"res://models/cc_by/blackjack_table/",
	"res://models/cc_by/hotdog_stand/",
	"res://models/cc_by/shopping_cart/",
	"res://models/cc_by/change_machine/",
	"res://models/cc_by/office_phone/",
	"res://models/cc_by/payphone/",
	"res://models/cc_by/pool_light/",
	"res://models/cc_by/pool_ladder/",
	"res://models/cc_by/slot_machine/",
	"res://models/cc_by/slot_machine_alt/",
	"res://models/cc_by/wood_dining_chair/",
	"res://models/cc0/Barrel_01/",
	"res://models/cc0/Lantern_01/",
	"res://models/cc0/SchoolDesk_01/",
	"res://models/cc0/barrel_03/",
	"res://models/cc0/barrel_stove/",
	"res://models/cc0/bunsen_burner/",
	"res://models/cc0/chemistry_set/",
	"res://models/cc0/fancy_picture_frame_01/",
	"res://models/cc0/fancy_picture_frame_02/",
	"res://models/cc0/industrial_caged_sconce/",
	"res://models/cc0/old_military_compressor/",
	"res://models/cc0/projector_screen/",
	"res://models/cc0/rusted_wheel_rim_01/",
	"res://models/cc0/rusted_wheel_rim_02/",
	"res://models/cc0/street_lamp_01/",
	"res://models/cc0/tree_stump_01/",
	"res://models/cc0/vintage_suitcase/",
	"res://models/cc0/wooden_barrels_01/",
	"res://models/cc0/wooden_ladder/",
	"res://textures/cc_by_nc/",
]
const RETIRED_CREDITS := [
	"morrrtu1o", "juliegraham178", "mtaesiri", "JackFarrand", "Katydid",
	"Mette Aumala", "Madeleine Price Ball", "OpenClipart-Vectors", "Phil Bronnery", "Beao",
	"Thibaut Rostagnat", "Doverlock", "Audrey Gonçalves", "nermin", "AdrianXY",
	"shirlanne",
]
## These include creators missed by the old screen, plus two creators whose
## other models were replaced but whose remaining assets still need credit.
const ACTIVE_CREDITS := {
	"William Burke": "res://models/cc_by/old_school_vcr/old_school_vcr.glb",
	"Tom Seddon": "res://models/cc_by/retro_television/retro_television.glb",
	"Parth": "res://models/cc_by/tv_table/tv_table.glb",
	"5CNG5": "res://models/cc_by/alarm_light/alarm_light.glb",
	"SadiqKhan911": "res://models/cc_by/plastic_chair/plastic_chair.glb",
	"ApprenticeRaccoon": "res://models/cc_by/pool_buoy/pool_buoy.glb",
	"Kless Gyzen": "res://models/cc_by/white_tiles/white_tiles_albedo.png",
	"maxdragonn": "res://models/cc_by/ibm_3278_terminal/ibm_3278_terminal.glb",
	"varrocharlie": "res://models/cc_by/backrooms_ladderback_chair/backrooms_ladderback_chair.tscn",
}

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func _run() -> void:
	var paths: Array[String] = Chunk._prop_preload_paths()
	for theme in range(12):
		paths.append_array(Chunk.theme_prop_paths(theme))
	paths.append_array([VhsRitual.TABLE_PATH, VhsRitual.TV_PATH, VhsRitual.VCR_PATH])
	paths.append(Mats.POOL_TILE_DIR + "white_tiles_albedo.png")
	var unique := {}
	for path in paths:
		unique[path] = true
	for path: String in unique:
		_check(ResourceLoader.exists(path), "missing active resource: " + path)
		for retired: String in RETIRED_DIRS:
			_check(not path.begins_with(retired), "retired resource still preloaded: " + path)
	for retired: String in RETIRED_DIRS:
		_check(not DirAccess.dir_exists_absolute(retired), "retired directory still present: " + retired)
	var credits := ""
	for section in TitleScreen.CREDIT_SECTIONS:
		for line in section[1]:
			credits += str(line) + "\n"
	var record := FileAccess.get_file_as_string("res://THIRD_PARTY_ASSETS.md")
	for creator: String in ACTIVE_CREDITS:
		var path: String = ACTIVE_CREDITS[creator]
		_check(unique.has(path), "credit fixture is no longer in the active manifest: " + creator)
		_check(credits.contains(creator), "active creator missing from credits: " + creator)
		_check(record.contains(creator), "active creator missing from canonical record: " + creator)
	for creator: String in RETIRED_CREDITS:
		_check(not credits.contains(creator), "retired creator remains on screen: " + creator)
		_check(not record.contains(creator), "retired creator remains in active record: " + creator)
	_check_export_notices()
	await _check_credit_layout()
	for failure in failures:
		push_error("ASSET_CREDITS: " + failure)
	print("ASSET_CREDITS %s: %d unique active resources, %d retained credit fixtures, %d retired directories" % [
		"PASS" if failures.is_empty() else "FAIL", unique.size(), ACTIVE_CREDITS.size(), RETIRED_DIRS.size()])
	quit(0 if failures.is_empty() else 1)


func _check_export_notices() -> void:
	var config := ConfigFile.new()
	if config.load("res://export_presets.cfg") != OK:
		_check(false, "could not load export presets")
		return
	var checked := 0
	for section: String in config.get_sections():
		if not section.begins_with("preset.") or section.ends_with(".options"):
			continue
		checked += 1
		var includes_notice := false
		for pattern: String in str(config.get_value(section, "include_filter", "")).split(","):
			if "THIRD_PARTY_ASSETS.md".match(pattern.strip_edges()):
				includes_notice = true
		_check(includes_notice, "export omits the full attribution record: " + section)
	_check(checked >= 2, "fewer than two export presets checked")


func _check_credit_layout() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(1280, 720)
	root.add_child(view)
	var title := TitleScreen.new()
	view.add_child(title)
	title._show_credits()
	var page: Control = title._pages[TitleScreen.Page.CREDITS]
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080),
			Vector2i(1024, 768), Vector2i(720, 1280),
			Vector2i(3456, 2234)]:
		view.size = size
		for frame in range(6):
			await process_frame
		var bounds := Rect2(Vector2.ZERO, Vector2(size)).grow(1.0)
		for node in page.find_children("*", "Control", true, false):
			if node is Label or node is Button:
				_check(bounds.encloses(node.get_global_rect()),
					"credit text/button clipped at %s: %s" % [size, node.text])
	view.free()
	await process_frame

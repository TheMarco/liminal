extends SceneTree
## Lightweight constructor smoke test for the public Chunk facade.
##
## The discovery pass uses only WorldGen queries. It finds one deterministic
## room-root representative for every valid style, plus both generic corridor
## directions and all three Annex passage variants. The build pass then calls
## the legacy three-argument Chunk.new(seed, cell, theme) constructor for each
## representative and briefly enters every chunk into a temporary scene root.
##
## Run:
##   godot --headless --path . --script tools/audit_chunk_smoke.gd
## Optional:
##   godot --headless --path . --script tools/audit_chunk_smoke.gd -- \
##     [seed_attempts] [search_radius]

const THEMES := [0, 1, 2, 4, 5, 6, 7, 8, 9, 10, 11]

const EXPECTED_STYLES := {
	0: [
		WorldGen.STYLE_EMPTY,
		WorldGen.STYLE_PILLARS,
		WorldGen.STYLE_SLOTS,
		WorldGen.STYLE_LOUNGE,
		WorldGen.STYLE_GRAND,
		WorldGen.STYLE_HALLWAY,
		WorldGen.STYLE_BALLROOM,
	],
	1: [
		WorldGen.OFFICE_EMPTY,
		WorldGen.OFFICE_CORRIDOR,
		WorldGen.OFFICE_CUBICLES,
		WorldGen.OFFICE_STORAGE,
		WorldGen.OFFICE_BREAK,
		WorldGen.OFFICE_BOARDROOM,
	],
	2: [
		WorldGen.ANNEX_OPEN,
		WorldGen.ANNEX_MAZE,
		WorldGen.ANNEX_LONG,
		WorldGen.ANNEX_QUIET,
		WorldGen.ANNEX_PASSAGE,
		WorldGen.ANNEX_LOBBY,
	],
	4: [
		WorldGen.AIR_GATE,
		WorldGen.AIR_CONCOURSE,
		WorldGen.AIR_CHECKIN,
		WorldGen.AIR_BAGGAGE,
		WorldGen.AIR_ESCALATOR,
		WorldGen.AIR_HALL,
		WorldGen.AIR_TRANSIT,
		WorldGen.AIR_FOODCOURT,
	],
	5: [
		WorldGen.ASY_CELL,
		WorldGen.ASY_WARD,
		WorldGen.ASY_DAYROOM,
		WorldGen.ASY_TREATMENT,
		WorldGen.ASY_HYDRO,
		WorldGen.ASY_OFFICE,
		WorldGen.ASY_CORRIDOR,
		WorldGen.ASY_CHAPEL,
	],
	6: [
		WorldGen.SCH_CORRIDOR,
		WorldGen.SCH_CLASSROOM,
		WorldGen.SCH_CAFETERIA,
		WorldGen.SCH_BATHROOM,
		WorldGen.SCH_GYM,
		WorldGen.SCH_LIBRARY,
		WorldGen.SCH_LAB,
		WorldGen.SCH_ADMIN,
		WorldGen.SCH_AUDITORIUM,
	],
	7: [
		WorldGen.MALL_CORRIDOR,
		WorldGen.MALL_STORE,
		WorldGen.MALL_ANCHOR,
		WorldGen.MALL_FOODCOURT,
		WorldGen.MALL_ATRIUM,
		WorldGen.MALL_SERVICE,
		WorldGen.MALL_KIOSKS,
		WorldGen.MALL_CINEMA,
	],
	8: [
		WorldGen.PRISON_CORRIDOR,
		WorldGen.PRISON_CELLBLOCK,
		WorldGen.PRISON_CELLS,
		WorldGen.PRISON_MESS,
		WorldGen.PRISON_SHOWER,
		WorldGen.PRISON_GUARD,
		WorldGen.PRISON_INDUSTRY,
		WorldGen.PRISON_VISITATION,
		WorldGen.PRISON_ROTUNDA,
	],
	9: [
		WorldGen.POOL_BASIN,
		WorldGen.POOL_CHANNEL,
		WorldGen.POOL_DECK,
		WorldGen.POOL_SOLARIUM,
		WorldGen.POOL_ALCOVE,
		WorldGen.POOL_STAIRS,
		WorldGen.POOL_GALLERY,
		WorldGen.POOL_CISTERN,
	],
	10: [
		WorldGen.BRUTAL_PASSAGE,
		WorldGen.BRUTAL_HALL,
		WorldGen.BRUTAL_GALLERY,
		WorldGen.BRUTAL_ATRIUM,
		WorldGen.BRUTAL_WATER_COURT,
		WorldGen.BRUTAL_RAMP,
		WorldGen.BRUTAL_SERVICE,
		WorldGen.BRUTAL_SANCTUM,
	],
	11: [
		WorldGen.BLOOM_PASSAGE,
		WorldGen.BLOOM_COMMONS,
		WorldGen.BLOOM_CLASSROOM,
		WorldGen.BLOOM_INCUBATOR,
		WorldGen.BLOOM_NEST,
		WorldGen.BLOOM_ATRIUM,
		WorldGen.BLOOM_GYM,
		WorldGen.BLOOM_HEART,
		WorldGen.BLOOM_STORM_APERTURE,
	],
}

const CORRIDOR_STYLES := {
	0: WorldGen.STYLE_HALLWAY,
	1: WorldGen.OFFICE_CORRIDOR,
	2: WorldGen.ANNEX_PASSAGE,
	4: WorldGen.AIR_TRANSIT,
	5: WorldGen.ASY_CORRIDOR,
	6: WorldGen.SCH_CORRIDOR,
	7: WorldGen.MALL_CORRIDOR,
	8: WorldGen.PRISON_CORRIDOR,
	9: WorldGen.POOL_CHANNEL,
	10: WorldGen.BRUTAL_PASSAGE,
	11: WorldGen.BLOOM_PASSAGE,
}

const THEME_NAMES := {
	0: "vegas",
	1: "office",
	2: "annex",
	4: "airport",
	5: "asylum",
	6: "school",
	7: "mall",
	8: "prison",
	9: "pool",
	10: "data_center",
	11: "bloom",
}

const STYLE_NAMES := {
	WorldGen.STYLE_EMPTY: "empty",
	WorldGen.STYLE_PILLARS: "pillars",
	WorldGen.STYLE_SLOTS: "slots",
	WorldGen.STYLE_LOUNGE: "lounge",
	WorldGen.STYLE_GRAND: "grand",
	WorldGen.STYLE_HALLWAY: "hallway",
	WorldGen.STYLE_BALLROOM: "ballroom",
	WorldGen.OFFICE_EMPTY: "empty",
	WorldGen.OFFICE_CORRIDOR: "corridor",
	WorldGen.OFFICE_CUBICLES: "cubicles",
	WorldGen.OFFICE_STORAGE: "storage",
	WorldGen.OFFICE_BREAK: "break",
	WorldGen.OFFICE_BOARDROOM: "boardroom",
	WorldGen.ANNEX_OPEN: "open",
	WorldGen.ANNEX_MAZE: "maze",
	WorldGen.ANNEX_LONG: "long",
	WorldGen.ANNEX_QUIET: "quiet",
	WorldGen.ANNEX_PASSAGE: "passage",
	WorldGen.ANNEX_LOBBY: "lobby",
	WorldGen.AIR_GATE: "gate",
	WorldGen.AIR_CONCOURSE: "concourse",
	WorldGen.AIR_CHECKIN: "checkin",
	WorldGen.AIR_BAGGAGE: "baggage",
	WorldGen.AIR_ESCALATOR: "escalator",
	WorldGen.AIR_HALL: "hall",
	WorldGen.AIR_TRANSIT: "transit",
	WorldGen.AIR_FOODCOURT: "foodcourt",
	WorldGen.ASY_CELL: "cell",
	WorldGen.ASY_WARD: "ward",
	WorldGen.ASY_DAYROOM: "dayroom",
	WorldGen.ASY_TREATMENT: "treatment",
	WorldGen.ASY_HYDRO: "hydro",
	WorldGen.ASY_OFFICE: "office",
	WorldGen.ASY_CORRIDOR: "corridor",
	WorldGen.ASY_CHAPEL: "chapel",
	WorldGen.SCH_CORRIDOR: "corridor",
	WorldGen.SCH_CLASSROOM: "classroom",
	WorldGen.SCH_CAFETERIA: "cafeteria",
	WorldGen.SCH_BATHROOM: "bathroom",
	WorldGen.SCH_GYM: "gym",
	WorldGen.SCH_LIBRARY: "library",
	WorldGen.SCH_LAB: "lab",
	WorldGen.SCH_ADMIN: "admin",
	WorldGen.SCH_AUDITORIUM: "auditorium",
	WorldGen.MALL_CORRIDOR: "corridor",
	WorldGen.MALL_STORE: "store",
	WorldGen.MALL_ANCHOR: "anchor",
	WorldGen.MALL_FOODCOURT: "foodcourt",
	WorldGen.MALL_ATRIUM: "atrium",
	WorldGen.MALL_SERVICE: "service",
	WorldGen.MALL_KIOSKS: "kiosks",
	WorldGen.MALL_CINEMA: "cinema",
	WorldGen.PRISON_CORRIDOR: "corridor",
	WorldGen.PRISON_CELLBLOCK: "cellblock",
	WorldGen.PRISON_CELLS: "cells",
	WorldGen.PRISON_MESS: "mess",
	WorldGen.PRISON_SHOWER: "shower",
	WorldGen.PRISON_GUARD: "guard",
	WorldGen.PRISON_INDUSTRY: "industry",
	WorldGen.PRISON_VISITATION: "visitation",
	WorldGen.PRISON_ROTUNDA: "rotunda",
	WorldGen.BRUTAL_PASSAGE: "data_passage",
	WorldGen.BRUTAL_HALL: "server_hall",
	WorldGen.BRUTAL_GALLERY: "rack_gallery",
	WorldGen.BRUTAL_ATRIUM: "operations_atrium",
	WorldGen.BRUTAL_WATER_COURT: "cooling_plant",
	WorldGen.BRUTAL_RAMP: "cable_riser",
	WorldGen.BRUTAL_SERVICE: "service_plant",
	WorldGen.BRUTAL_SANCTUM: "core_vault",
	WorldGen.POOL_BASIN: "basin",
	WorldGen.POOL_CHANNEL: "channel",
	WorldGen.POOL_DECK: "deck",
	WorldGen.POOL_SOLARIUM: "solarium",
	WorldGen.POOL_ALCOVE: "alcove",
	WorldGen.POOL_STAIRS: "stairs",
	WorldGen.POOL_GALLERY: "gallery",
	WorldGen.POOL_CISTERN: "cistern",
	WorldGen.BLOOM_PASSAGE: "passage",
	WorldGen.BLOOM_COMMONS: "commons",
	WorldGen.BLOOM_CLASSROOM: "classroom",
	WorldGen.BLOOM_INCUBATOR: "incubator",
	WorldGen.BLOOM_NEST: "nest",
	WorldGen.BLOOM_ATRIUM: "atrium",
	WorldGen.BLOOM_GYM: "gym",
	WorldGen.BLOOM_HEART: "heart",
	WorldGen.BLOOM_STORM_APERTURE: "storm_aperture",
}

const DEFAULT_SEED_ATTEMPTS := 10
const DEFAULT_SEARCH_RADIUS := 28
const DISCOVERY_SEED := 918273


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_attempts := clampi(
		int(args[0]) if args.size() > 0 else DEFAULT_SEED_ATTEMPTS,
		1,
		32
	)
	var search_radius := clampi(
		int(args[1]) if args.size() > 1 else DEFAULT_SEARCH_RADIUS,
		8,
		64
	)
	var samples := _discover_samples(seed_attempts, search_radius)
	var failures := 0

	for theme in THEMES:
		for key in _expected_sample_keys(theme):
			if not samples[theme].has(key):
				failures += 1
				print("FAIL discovery theme=%d (%s) missing %s" % [
					theme,
					THEME_NAMES[theme],
					key,
				])

	if failures > 0:
		print("chunk smoke audit: discovery failed (%d missing representatives)" % failures)
		print("  attempts=%d radius=%d" % [seed_attempts, search_radius])
		await preload("res://tools/lib/audit_cleanup.gd").release(self)
		quit(1)
		return

	var host := Node3D.new()
	host.name = "ChunkSmokeAuditHost"
	get_root().add_child(host)
	var built := 0

	for theme in THEMES:
		var keys: Array = samples[theme].keys()
		keys.sort()
		for key in keys:
			var sample: Dictionary = samples[theme][key]
			var world_seed := int(sample["world_seed"])
			var cell := sample["cell"] as Vector2i
			var expected_style := int(sample["style"])
			print("BUILD theme=%d (%s) %s seed=%d cell=%s style=%d (%s)" % [
				theme,
				THEME_NAMES[theme],
				key,
				world_seed,
				cell,
				expected_style,
				STYLE_NAMES.get(expected_style, "unknown"),
			])

			# Deliberately exercise the original compatibility surface. If a
			# delegated level module cannot construct, Godot reports the error
			# immediately after the BUILD line above.
			var chunk := Chunk.new(world_seed, cell, theme)
			if chunk == null or not is_instance_valid(chunk):
				failures += 1
				print("FAIL constructor returned no valid Chunk for theme=%d %s" % [
					theme,
					key,
				])
				continue

			host.add_child(chunk)
			built += 1
			if chunk.theme != theme:
				failures += 1
				print("FAIL theme mismatch for %s: expected=%d actual=%d" % [
					key,
					theme,
					chunk.theme,
				])
			if chunk.cell != cell:
				failures += 1
				print("FAIL cell mismatch for theme=%d %s: expected=%s actual=%s" % [
					theme,
					key,
					cell,
					chunk.cell,
				])
			if chunk.style != expected_style:
				failures += 1
				print("FAIL style mismatch for theme=%d %s: expected=%d actual=%d" % [
					theme,
					key,
					expected_style,
					chunk.style,
				])
			if chunk.get_child_count() == 0:
				failures += 1
				print("FAIL empty Chunk tree for theme=%d %s" % [theme, key])
			if chunk.runtime_identity_violations() != 0:
				failures += 1
				print("FAIL duplicate stable runtime object identity for theme=%d %s" % [
					theme, key])
			chunk.free()

	host.free()
	print("chunk smoke audit: built %d representatives across %d active themes" % [
		built,
		THEMES.size(),
	])
	print("  attempts=%d radius=%d failures=%d" % [
		seed_attempts,
		search_radius,
		failures,
	])
	if failures == 0:
		print("  PASS — all styles construct with unique runtime object identities")
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit(0 if failures == 0 else 1)


func _discover_samples(seed_attempts: int, search_radius: int) -> Dictionary:
	var samples := {}
	for theme in THEMES:
		samples[theme] = {}

	for attempt in seed_attempts:
		for theme in THEMES:
			if _theme_is_complete(samples[theme], theme):
				continue
			var base_seed := WorldGen.h(
				DISCOVERY_SEED,
				attempt * 131 + theme * 17,
				attempt * 293 - theme * 31,
				4409
			) | 1
			var world_seed := WorldGen.level_seed(base_seed, theme)
			for x in range(-search_radius, search_radius + 1):
				for z in range(-search_radius, search_radius + 1):
					_consider_sample(
						samples[theme],
						world_seed,
						Vector2i(x, z),
						theme,
						attempt
					)
		if _all_themes_complete(samples):
			break
	return samples


func _consider_sample(
	theme_samples: Dictionary,
	world_seed: int,
	cell: Vector2i,
	theme: int,
	attempt: int
) -> void:
	var axis := WorldGen.annex_corridor_axis(world_seed, cell) \
		if theme == 2 else WorldGen.corridor(world_seed, cell)
	var style := WorldGen.cell_style(world_seed, cell, theme)
	if axis != 0:
		var corridor_key := _corridor_key(theme, axis)
		if corridor_key != "" \
				and style == int(CORRIDOR_STYLES[theme]) \
				and not theme_samples.has(corridor_key):
			theme_samples[corridor_key] = _sample(
				world_seed,
				cell,
				style,
				attempt
			)
		return

	var root := WorldGen.annex_room_id(world_seed, cell) \
		if theme == 2 else WorldGen.room_id(world_seed, cell)
	if root != cell:
		return
	if not EXPECTED_STYLES[theme].has(style):
		return
	if style == int(CORRIDOR_STYLES[theme]):
		return
	var style_key := _style_key(style)
	if not theme_samples.has(style_key):
		theme_samples[style_key] = _sample(world_seed, cell, style, attempt)


func _sample(
	world_seed: int,
	cell: Vector2i,
	style: int,
	attempt: int
) -> Dictionary:
	return {
		"world_seed": world_seed,
		"cell": cell,
		"style": style,
		"attempt": attempt,
	}


func _expected_sample_keys(theme: int) -> Array:
	var keys: Array = []
	for style in EXPECTED_STYLES[theme]:
		if style != int(CORRIDOR_STYLES[theme]):
			keys.append(_style_key(style))
	if theme == 2:
		keys.append(_corridor_key(theme, 1))
		keys.append(_corridor_key(theme, 2))
		keys.append(_corridor_key(theme, 3))
	else:
		keys.append(_corridor_key(theme, 1))
		keys.append(_corridor_key(theme, 2))
	return keys


func _style_key(style: int) -> String:
	return "style:%d:%s" % [style, STYLE_NAMES.get(style, "unknown")]


func _corridor_key(theme: int, axis: int) -> String:
	if theme == 2:
		match axis:
			1: return "corridor:horizontal"
			2: return "corridor:vertical"
			3: return "corridor:intersection"
		return ""
	match axis:
		1: return "corridor:x"
		2: return "corridor:z"
	return ""


func _theme_is_complete(theme_samples: Dictionary, theme: int) -> bool:
	for key in _expected_sample_keys(theme):
		if not theme_samples.has(key):
			return false
	return true


func _all_themes_complete(samples: Dictionary) -> bool:
	for theme in THEMES:
		if not _theme_is_complete(samples[theme], theme):
			return false
	return true

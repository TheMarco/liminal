class_name Chunk
extends Node3D
## One 12x12m cell, fully generated in _init from (seed, cell, theme).
## Theme 0: seedy Vegas hotel-casino. Theme 1: sterile Severance-style office.
## Theme 2: dripping sewer works. Theme 4: an airport terminal parked forever
## at 3 a.m. (3 was a derelict theme park, cut — ids are not renumbered).
## Theme 5: an abandoned asylum — the first theme dressed in downloaded CC0
## photo textures and models (ambientCG / Poly Haven) instead of pure math.
## All geometry is local; the ChunkManager places the node at the cell origin.

const S := 12.0
const H := 3.2       # vegas wall/ceiling height
const H2 := 6.4      # vegas grand hall ceiling
const HOFF := 3.0    # office ceiling height
const HSEW := 2.7    # sewer ceiling height
const HAIR := 5.0    # airport hall height
const HASY := 3.0    # asylum corridor height
const HSCH := 3.05   # school corridor height
const SCH_BAND := 1.42   # height of the red line that runs the whole school
const T := 0.15
const DOOR_TOP := 2.25
const AIR_DOOR := 3.15   # airport portal head height

# sewer waterway cross-section
const WATER_Y := -0.22   # water surface below the walkways
const CH_HW := 0.85      # half width of the channel invert
const CH_D := 0.48       # channel floor depth below the walkways
const BANK := 0.62       # horizontal run of each sloped bank (walkable angle)
const CH_CUT := CH_HW + BANK
const BAS0 := 3.0        # basin inner square
const BAS1 := 9.0
const BAS_D := 0.95      # basin floor depth

static var BOX := BoxMesh.new()
static var CYL := CylinderMesh.new()
static var SPH := SphereMesh.new()
static var TOR := TorusMesh.new()
static var QUAD := QuadMesh.new()
static var CONE := CylinderMesh.new()
static var _cone_ready := false

const ASY_PROP_NAMES := ["BarberShopChair_01", "Rockingchair_01", "SchoolChair_01",
	"medical_box", "metal_office_desk", "mounted_fluorescent_lights",
	"old_bed_frame", "vintage_crutches_01", "wheelchair_01"]
const CC0_PROP_NAMES := ["ArmChair_01", "Barrel_01", "Chandelier_03", "CoffeeCart_01",
	"CoffeeTable_01", "Lantern_01", "Ottoman_01", "WetFloorSign_01",
	"bar_chair_round_01", "barrel_03", "barrel_stove", "clipboard",
	"coffee_table_round_01", "drawer_cabinet", "fancy_picture_frame_01",
	"fancy_picture_frame_02", "hanging_industrial_lamp", "industrial_caged_sconce",
	"old_tyre", "plastic_crate_03", "potted_plant_01", "potted_plant_02",
	"power_box_01", "rusted_wheel_rim_01", "rusted_wheel_rim_02", "sofa_03",
	"steel_frame_shelves_01", "television_02", "trashbag", "vintage_grandfather_clock_01",
	"vintage_suitcase", "wall_clock", "wooden_crate_01", "wooden_crate_02",
	"wooden_ladder", "wooden_picnic_table"]

static var _prop_preloads_requested := false

var wseed: int
var cell: Vector2i
var theme: int
var body: StaticBody3D
var style: int
var ceil_h: float
var portal_dest := -1
var room_root: Vector2i        # the room this cell belongs to
var room_n := 1                # how many cells the room spans
var is_room_anchor := false    # only the anchor cell furnishes the room
# props are laid out in cell coords, then shifted onto the room centre


## Start glTF loading on worker threads while the title card is up. The first
## encounter with a new prop previously made streaming pay the full disk,
## decode and scene-import cost in one frame (hundreds of milliseconds for the
## heaviest casino sets). Retrieval still blocks if a player outruns the load,
## but in normal play the work is complete long before another floor is seen.
static func request_prop_preloads() -> void:
	if _prop_preloads_requested:
		return
	_prop_preloads_requested = true
	for mname in ASY_PROP_NAMES:
		ResourceLoader.load_threaded_request(
			"res://models/asylum/%s/%s_1k.gltf" % [mname, mname])
	for mname in CC0_PROP_NAMES:
		ResourceLoader.load_threaded_request(
			"res://models/cc0/%s/%s_1k.gltf" % [mname, mname])


func _init(p_seed: int, p_cell: Vector2i, p_theme := 0) -> void:
	if not _cone_ready:
		_cone_ready = true
		CONE.top_radius = 0.0
		CONE.bottom_radius = 0.5
		CONE.height = 1.0
	wseed = p_seed
	cell = p_cell
	theme = p_theme
	body = StaticBody3D.new()
	add_child(body)
	style = WorldGen.cell_style(wseed, cell, theme)
	room_root = WorldGen.room_id(wseed, cell)
	room_n = WorldGen.room_size(wseed, room_root)
	is_room_anchor = room_root == cell
	# ceiling follows the room, so a small room feels small and a hall soars
	ceil_h = WorldGen.room_height(wseed, room_root, theme)
	if WorldGen.corridor(wseed, cell) != 0:
		ceil_h = HSEW if theme == 2 else (3.5 if theme == 4 else \
			(HASY if theme == 5 else (HSCH if theme == 6 else HOFF)))
	_build_floor_ceiling()
	_build_walls()
	_build_lighting()
	_build_props()
	_maybe_probe()


## Real reflections for the rooms with mirror-like surfaces (marble, gold,
## glass). One static box-projected probe, rendered once at chunk build.
func _maybe_probe() -> void:
	# One probe covers a generated room. Multi-cell rooms used to create one in
	# every member chunk, rendering the same surrounding geometry four times.
	if not is_room_anchor:
		return
	var want := false
	if theme == 0:
		want = style == WorldGen.STYLE_GRAND or style == WorldGen.STYLE_SLOTS \
			or style == WorldGen.STYLE_BALLROOM
	elif theme == 2:
		want = style == WorldGen.SEWER_BASIN or style == WorldGen.SEWER_CISTERN
	elif theme == 4:
		want = style == WorldGen.AIR_GATE or style == WorldGen.AIR_FOODCOURT
	elif theme == 6:
		# The polished hall floor benefits from local cubemaps, but one in every
		# corridor cell recaptured almost the same scene. Alternate cells keep
		# the long reflection read at half the startup/rendering cost.
		want = style == WorldGen.SCH_CORRIDOR \
			and WorldGen.h(wseed, cell.x, cell.y, 1499) % 2 == 0
	if not want:
		return
	var probe := ReflectionProbe.new()
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	var span := _room_span()
	var rc := WorldGen.room_centre(wseed, room_root)
	var local_c := Vector3(rc.x - float(cell.x) * S,
		ceil_h / 2.0 - (0.7 if theme == 2 else 0.0),
		rc.y - float(cell.y) * S)
	probe.size = Vector3(span.x, ceil_h + (2.0 if theme == 2 else 0.6), span.y)
	probe.position = local_c
	probe.box_projection = true
	probe.interior = true
	probe.max_distance = 24.0
	add_child(probe)


func _r(salt: int) -> float:
	return WorldGen.r01(wseed, cell.x, cell.y, salt)


## A 72m maintenance district shares one finish palette. This gives long walks
## coherent eras of repainting and refitting instead of recoloring every room.
func _finish_variant() -> int:
	return WorldGen.finish_variant(wseed, cell, theme)


func _wall_h() -> float:
	return ceil_h


# --- primitive helpers -------------------------------------------------------

func _box(pos: Vector3, size: Vector3, mat: Material, collide := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = BOX
	mi.material_override = mat
	mi.position = pos
	mi.scale = size
	add_child(mi)
	if collide:
		_collider_box(pos, size)
	return mi


func _collider_box(pos: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	body.add_child(cs)


func _collider_cyl(pos: Vector3, radius: float, height: float) -> void:
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = radius
	sh.height = height
	cs.shape = sh
	cs.position = pos
	body.add_child(cs)


func _cyl(pos: Vector3, radius: float, height: float, mat: Material, collide := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = CYL
	mi.material_override = mat
	mi.position = pos
	mi.scale = Vector3(radius / 0.5, height / 2.0, radius / 0.5)
	add_child(mi)
	if collide:
		_collider_cyl(pos, radius, height)
	return mi


func _sphere(pos: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = SPH
	mi.material_override = mat
	mi.position = pos
	mi.scale = Vector3.ONE * (r / 0.5)
	add_child(mi)
	return mi


func _quad(pos: Vector3, size: Vector2, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = QUAD
	mi.material_override = mat
	mi.position = pos
	mi.scale = Vector3(size.x, size.y, 1.0)
	add_child(mi)
	return mi


func _mbox(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = BOX
	mi.material_override = mat
	mi.position = pos
	mi.scale = size
	parent.add_child(mi)
	return mi


func _mquad(parent: Node3D, pos: Vector3, size: Vector2, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = QUAD
	mi.material_override = mat
	mi.position = pos
	mi.scale = Vector3(size.x, size.y, 1.0)
	parent.add_child(mi)
	return mi


func _mcyl(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = CYL
	mi.material_override = mat
	mi.position = pos
	mi.scale = Vector3(radius / 0.5, height / 2.0, radius / 0.5)
	parent.add_child(mi)
	return mi


## Chamfered box — real objects catch light on their edges.
func _rbox(pos: Vector3, size: Vector3, mat: Material, r := 0.03, collide := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = RoundedBox.mesh(size, r)
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	if collide:
		_collider_box(pos, size)
	return mi


func _mrbox(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, r := 0.03) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = RoundedBox.mesh(size, r)
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


# --- structure ---------------------------------------------------------------

func _build_floor_ceiling() -> void:
	if theme == 2:
		_sewer_floor_ceiling()
		return
	if theme == 1:
		_box(Vector3(S / 2.0, -0.15, S / 2.0), Vector3(S, 0.3, S), Mats.office_carpet())
		_box(Vector3(S / 2.0, ceil_h + 0.15, S / 2.0), Vector3(S, 0.3, S), Mats.office_ceiling())
		return
	if theme == 4:
		_box(Vector3(S / 2.0, -0.15, S / 2.0), Vector3(S, 0.3, S), Mats.terrazzo_photo())
		_box(Vector3(S / 2.0, ceil_h + 0.15, S / 2.0), Vector3(S, 0.3, S), Mats.airport_ceiling())
		return
	if theme == 5:
		var fmat: Material = Mats.asy_floor()
		if style == WorldGen.ASY_CORRIDOR or style == WorldGen.ASY_DAYROOM \
				or style == WorldGen.ASY_OFFICE or style == WorldGen.ASY_CHAPEL:
			fmat = Mats.asy_checker()
		elif style == WorldGen.ASY_HYDRO:
			fmat = Mats.asy_tile()
		_box(Vector3(S / 2.0, -0.15, S / 2.0), Vector3(S, 0.3, S), fmat)
		_box(Vector3(S / 2.0, ceil_h + 0.15, S / 2.0), Vector3(S, 0.3, S), Mats.asy_ceiling())
		return
	if theme == 6:
		_box(Vector3(S / 2.0, -0.15, S / 2.0), Vector3(S, 0.3, S), _sch_floor_mat())
		_box(Vector3(S / 2.0, ceil_h + 0.15, S / 2.0), Vector3(S, 0.3, S), Mats.sch_ceiling())
		return
	var floor_mat: Material = Mats.marble_photo() if style == WorldGen.STYLE_GRAND \
		or style == WorldGen.STYLE_BALLROOM else Mats.carpet()
	_box(Vector3(S / 2.0, -0.15, S / 2.0), Vector3(S, 0.3, S), floor_mat)
	_box(Vector3(S / 2.0, ceil_h + 0.15, S / 2.0), Vector3(S, 0.3, S), Mats.ceiling())

	if style == WorldGen.STYLE_GRAND or style == WorldGen.STYLE_BALLROOM:
		# clerestory band between standard wall height and the raised ceiling
		var bh := ceil_h - H
		var by := H + bh / 2.0
		_box(Vector3(S / 2.0, by, T / 2.0), Vector3(S, bh, T), Mats.band_paint(), false)
		_box(Vector3(S / 2.0, by, S - T / 2.0), Vector3(S, bh, T), Mats.band_paint(), false)
		_box(Vector3(T / 2.0, by, S / 2.0), Vector3(T, bh, S), Mats.band_paint(), false)
		_box(Vector3(S - T / 2.0, by, S / 2.0), Vector3(T, bh, S), Mats.band_paint(), false)
		var neon: Material = Mats.neon_pink() if _r(31) < 0.5 else Mats.neon_amber()
		var ny := H + 0.18
		_box(Vector3(S / 2.0, ny, 0.35), Vector3(S - 1.0, 0.06, 0.08), neon, false)
		_box(Vector3(S / 2.0, ny, S - 0.35), Vector3(S - 1.0, 0.06, 0.08), neon, false)
		_box(Vector3(0.35, ny, S / 2.0), Vector3(0.08, 0.06, S - 1.0), neon, false)
		_box(Vector3(S - 0.35, ny, S / 2.0), Vector3(0.08, 0.06, S - 1.0), neon, false)


func _build_walls() -> void:
	for dir in 4:
		var info := WorldGen.edge_info(wseed, cell, dir, theme)
		var plane := (S - T / 2.0) if (dir == 0 or dir == 2) else (T / 2.0)
		if info["wall"]:
			_wall_seg(dir, plane, 0.0, S, 0.0, _wall_h())
			_wall_decor(dir, plane)
		elif not info["full_open"]:
			var a: float = info["t"] - info["w"] / 2.0
			var b: float = info["t"] + info["w"] / 2.0
			_wall_seg(dir, plane, 0.0, a, 0.0, _wall_h())
			_wall_seg(dir, plane, b, S, 0.0, _wall_h())
			_wall_seg(dir, plane, a, b, AIR_DOOR if theme == 4 else DOOR_TOP, _wall_h())
			_door_casing(dir, plane, a, b)
			if (dir == 0 or dir == 2) and info["exit_sign"]:
				if theme == 4:
					_air_portal_sign(dir, info["t"])
				else:
					_exit_sign(dir, info["t"])


func _wall_seg(dir: int, plane: float, from: float, to: float, y0: float, y1: float) -> void:
	var ln := to - from
	if ln < 0.05:
		return
	var c := (from + to) * 0.5
	var yc := (y0 + y1) * 0.5
	var hh := y1 - y0
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T * 0.5)
	var wmat: Material = Mats.wallpaper_variant(_finish_variant())
	if theme == 1:
		wmat = Mats.office_wall_variant(_finish_variant())
	elif theme == 2:
		# the older stretches of the works are brick, not cast concrete
		wmat = Mats.brick_sewer() if _r(49) < 0.4 else Mats.concrete()
	elif theme == 4:
		wmat = Mats.airport_wall_variant(_finish_variant())
	elif theme == 5:
		wmat = _asy_wall_mat()
	elif theme == 6:
		wmat = _sch_wall_mat()
	if dir < 2:
		_box(Vector3(plane, yc, c), Vector3(T, hh, ln), wmat)
	else:
		_box(Vector3(c, yc, plane), Vector3(ln, hh, T), wmat)
	if theme == 2:
		return
	if theme == 5:
		# tiled wainscot to shoulder height — unless the whole room is tiled
		if y0 <= 0.01 and not _asy_tiled_room():
			_strip(dir, inner + n * 0.03, 0.7, c, ln, 0.05, 1.4, Mats.asy_tile())
		return
	if theme == 6:
		# the red line, painted at the same height through the whole building,
		# and a rubber cove base under it
		if y0 <= 0.01:
			_strip(dir, inner + n * 0.02, SCH_BAND, c, ln, 0.04, 0.17, Mats.sch_red())
			_strip(dir, inner + n * 0.025, 0.06, c, ln, 0.05, 0.12, Mats.charcoal())
		return
	if theme == 4:
		# stainless kick guard where trolleys graze the wall
		if y0 <= 0.01:
			_strip(dir, inner + n * 0.025, 0.09, c, ln, 0.05, 0.18, Mats.steel())
		return
	if theme == 1:
		# offices: just a dark green baseboard
		if y0 <= 0.01:
			_strip(dir, inner + n * 0.02, 0.055, c, ln, 0.04, 0.11, Mats.base_green())
		return
	# vegas trim set: crown, baseboard, chair rail
	if y1 >= ceil_h - 0.01:
		_strip(dir, inner + n * 0.05, ceil_h - 0.05, c, ln, 0.1, 0.1, Mats.crown())
	if y0 <= 0.01:
		_strip(dir, inner + n * 0.028, 0.075, c, ln, 0.055, 0.15, Mats.darkwood())
		_strip(dir, inner + n * 0.02, 1.0, c, ln, 0.04, 0.08, Mats.darkwood())


func _strip(dir: int, off: float, y: float, c: float, ln: float, depth: float, height: float, mat: Material) -> void:
	if dir < 2:
		_box(Vector3(off, y, c), Vector3(depth, height, ln), mat, false)
	else:
		_box(Vector3(c, y, off), Vector3(ln, height, depth), mat, false)


func _door_casing(dir: int, plane: float, a: float, b: float) -> void:
	if theme == 4:
		# brushed-steel portal surround, airport-tall
		var sm := Mats.steel()
		if dir < 2:
			_box(Vector3(plane, AIR_DOOR * 0.5, a - 0.02), Vector3(T + 0.2, AIR_DOOR, 0.26), sm)
			_box(Vector3(plane, AIR_DOOR * 0.5, b + 0.02), Vector3(T + 0.2, AIR_DOOR, 0.26), sm)
			_box(Vector3(plane, AIR_DOOR + 0.12, (a + b) * 0.5), Vector3(T + 0.2, 0.26, b - a + 0.3), sm, false)
		else:
			_box(Vector3(a - 0.02, AIR_DOOR * 0.5, plane), Vector3(0.26, AIR_DOOR, T + 0.2), sm)
			_box(Vector3(b + 0.02, AIR_DOOR * 0.5, plane), Vector3(0.26, AIR_DOOR, T + 0.2), sm)
			_box(Vector3((a + b) * 0.5, AIR_DOOR + 0.12, plane), Vector3(b - a + 0.3, 0.26, T + 0.2), sm, false)
		return
	if theme == 2:
		# chunky cast-concrete jambs and lintel around the archway
		var jm := Mats.concrete()
		if dir < 2:
			_box(Vector3(plane, DOOR_TOP * 0.5, a - 0.02), Vector3(T + 0.3, DOOR_TOP, 0.34), jm)
			_box(Vector3(plane, DOOR_TOP * 0.5, b + 0.02), Vector3(T + 0.3, DOOR_TOP, 0.34), jm)
			_box(Vector3(plane, DOOR_TOP + 0.14, (a + b) * 0.5), Vector3(T + 0.3, 0.3, b - a + 0.38), jm, false)
		else:
			_box(Vector3(a - 0.02, DOOR_TOP * 0.5, plane), Vector3(0.34, DOOR_TOP, T + 0.3), jm)
			_box(Vector3(b + 0.02, DOOR_TOP * 0.5, plane), Vector3(0.34, DOOR_TOP, T + 0.3), jm)
			_box(Vector3((a + b) * 0.5, DOOR_TOP + 0.14, plane), Vector3(b - a + 0.38, 0.3, T + 0.3), jm, false)
		return
	if theme == 5:
		# chipped green steel frame, a size heavier than it needs to be
		var gm := Mats.asy_metal_green()
		if dir < 2:
			_box(Vector3(plane, DOOR_TOP * 0.5, a), Vector3(T + 0.16, DOOR_TOP, 0.2), gm, false)
			_box(Vector3(plane, DOOR_TOP * 0.5, b), Vector3(T + 0.16, DOOR_TOP, 0.2), gm, false)
			_box(Vector3(plane, DOOR_TOP + 0.09, (a + b) * 0.5), Vector3(T + 0.16, 0.18, b - a + 0.2), gm, false)
		else:
			_box(Vector3(a, DOOR_TOP * 0.5, plane), Vector3(0.2, DOOR_TOP, T + 0.16), gm, false)
			_box(Vector3(b, DOOR_TOP * 0.5, plane), Vector3(0.2, DOOR_TOP, T + 0.16), gm, false)
			_box(Vector3((a + b) * 0.5, DOOR_TOP + 0.09, plane), Vector3(b - a + 0.2, 0.18, T + 0.16), gm, false)
		return
	if theme == 6:
		# painted steel frame, and the door itself parked open against the wall
		var rm := Mats.sch_red()
		if dir < 2:
			_box(Vector3(plane, DOOR_TOP * 0.5, a), Vector3(T + 0.14, DOOR_TOP, 0.17), rm, false)
			_box(Vector3(plane, DOOR_TOP * 0.5, b), Vector3(T + 0.14, DOOR_TOP, 0.17), rm, false)
			_box(Vector3(plane, DOOR_TOP + 0.08, (a + b) * 0.5), Vector3(T + 0.14, 0.16, b - a + 0.17), rm, false)
		else:
			_box(Vector3(a, DOOR_TOP * 0.5, plane), Vector3(0.17, DOOR_TOP, T + 0.14), rm, false)
			_box(Vector3(b, DOOR_TOP * 0.5, plane), Vector3(0.17, DOOR_TOP, T + 0.14), rm, false)
			_box(Vector3((a + b) * 0.5, DOOR_TOP + 0.08, plane), Vector3(b - a + 0.17, 0.16, T + 0.14), rm, false)
		return
	var head_y := DOOR_TOP + 0.07
	var cmat: Material = Mats.paint_white() if theme == 1 else Mats.darkwood()
	if dir < 2:
		_box(Vector3(plane, DOOR_TOP * 0.5, a), Vector3(T + 0.12, DOOR_TOP, 0.16), cmat, false)
		_box(Vector3(plane, DOOR_TOP * 0.5, b), Vector3(T + 0.12, DOOR_TOP, 0.16), cmat, false)
		_box(Vector3(plane, head_y, (a + b) * 0.5), Vector3(T + 0.12, 0.14, b - a + 0.16), cmat, false)
	else:
		_box(Vector3(a, DOOR_TOP * 0.5, plane), Vector3(0.16, DOOR_TOP, T + 0.12), cmat, false)
		_box(Vector3(b, DOOR_TOP * 0.5, plane), Vector3(0.16, DOOR_TOP, T + 0.12), cmat, false)
		_box(Vector3((a + b) * 0.5, head_y, plane), Vector3(b - a + 0.16, 0.14, T + 0.12), cmat, false)


func _exit_sign(dir: int, t: float) -> void:
	# Only built by the canonical (east/north) owner of the edge.
	var y := DOOR_TOP - 0.17
	var base: Vector3
	var hsize: Vector3
	if dir == 0:
		base = Vector3(S, y, t)
		hsize = Vector3(0.09, 0.24, 0.62)
	else:
		base = Vector3(t, y, S)
		hsize = Vector3(0.62, 0.24, 0.09)
	_box(base, hsize, Mats.sign_housing(), false)
	for sside in [-1.0, 1.0]:
		var lb := Label3D.new()
		lb.text = "EXIT"
		lb.font_size = 96
		lb.pixel_size = 0.0016
		lb.outline_size = 0
		lb.modulate = Color(1.0, 0.22, 0.15)
		if dir == 0:
			lb.position = base + Vector3(sside * 0.055, 0, 0)
			lb.rotation.y = PI / 2.0 if sside > 0.0 else -PI / 2.0
		else:
			lb.position = base + Vector3(0, 0, sside * 0.055)
			lb.rotation.y = 0.0 if sside > 0.0 else PI
		add_child(lb)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.2, 0.15)
	l.light_energy = 0.4
	l.omni_range = 2.2
	l.position = base
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 12.0
	l.distance_fade_length = 6.0
	add_child(l)


# --- wall decoration ---------------------------------------------------------

func _wall_decor(dir: int, plane: float) -> void:
	var r := _r(40 + dir)
	if theme == 5:
		if r < 0.14:
			_asy_straitjacket(dir, plane)
		elif r < 0.30:
			_asy_scrawl(dir, plane)
		elif r < 0.40:
			_asy_crutches(dir, plane)
		elif r < 0.50:
			_asy_noticeboard(dir, plane)
		elif r < 0.60:
			_sewer_pipes(dir, plane)
		elif r < 0.68:
			_office_clock(dir, plane)
		return
	if theme == 6:
		if r < 0.20:
			_sch_noticeboard(dir, plane)
		elif r < 0.32:
			_sch_fountain(dir, plane)
		elif r < 0.42:
			_sch_case(dir, plane)
		elif r < 0.52:
			_office_clock(dir, plane)
		elif r < 0.62:
			_sch_poster(dir, plane)
		return
	if theme == 4:
		if r < 0.30:
			_air_adboxes(dir, plane)
		elif r < 0.42:
			_air_wall_fids(dir, plane)
		return
	if theme == 2:
		if r < 0.52:
			_sewer_pipes(dir, plane)
		elif r < 0.68:
			_sewer_stencil(dir, plane)
		elif r < 0.78:
			_sewer_panel(dir, plane)
		return
	if theme == 1:
		if r < 0.20:
			_office_door_decor(dir, plane)
		elif r < 0.30:
			_office_clock(dir, plane)
		elif r < 0.46:
			_filing_bank(dir, plane)
		elif r < 0.58:
			_office_poster(dir, plane)
		return
	if r < 0.24:
		_art(dir, plane)
	elif r < 0.5:
		_sconces(dir, plane)
	elif r < 0.62:
		_casino_neon(dir, plane)
	elif r < 0.70:
		_change_machine(dir, plane)


func _art(dir: int, plane: float) -> void:
	# a real gilt-framed oil painting, hung slightly askew
	var along := S / 2.0 + (_r(46 + dir) - 0.5) * 3.0
	var y := 1.72
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T / 2.0)
	var mname := "fancy_picture_frame_01" if _r(50 + dir) < 0.5 else "fancy_picture_frame_02"
	var scl := 1.8 if mname == "fancy_picture_frame_01" else 1.3
	var fr: Node3D
	if dir < 2:
		fr = _cc0_prop(mname, Vector3(inner + n * 0.03, y, along), PI / 2.0 * n, scl)
	else:
		fr = _cc0_prop(mname, Vector3(along, y, inner + n * 0.03), 0.0 if n > 0.0 else PI, scl)
	fr.rotate_object_local(Vector3(0, 0, 1), (_r(54 + dir) - 0.5) * 0.07)


func _sconces(dir: int, plane: float) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T * 0.5)
	for along in [S * 0.32, S * 0.68]:
		var wall_pos: Vector3
		var out: Vector3
		if dir < 2:
			wall_pos = Vector3(inner, 0, along)
			out = Vector3(n, 0, 0)
		else:
			wall_pos = Vector3(along, 0, inner)
			out = Vector3(0, 0, n)
		var plate_size := Vector3(0.06, 0.34, 0.13) if dir < 2 else Vector3(0.13, 0.34, 0.06)
		_box(wall_pos + out * 0.03 + Vector3(0, 1.78, 0), plate_size, Mats.brass(), false)
		_cyl(wall_pos + out * 0.12 + Vector3(0, 1.86, 0), 0.10, 0.17, Mats.shade(), false)
		_sphere(wall_pos + out * 0.12 + Vector3(0, 1.97, 0), 0.035, Mats.bulb())
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.75, 0.5)
		l.light_energy = 0.55
		l.omni_range = 4.5
		l.position = wall_pos + out * 0.3 + Vector3(0, 1.95, 0)
		l.shadow_enabled = false
		l.distance_fade_enabled = true
		l.distance_fade_begin = 14.0
		l.distance_fade_length = 6.0
		add_child(l)


## Decorative wood veneer door with chrome handle on an office wall.
func _office_door_decor(dir: int, plane: float) -> void:
	var along := S / 2.0 + (_r(46 + dir) - 0.5) * 5.0
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T / 2.0)
	var fc := inner + n * 0.02
	if dir < 2:
		_box(Vector3(fc, 1.06, along), Vector3(0.05, 2.1, 1.0), Mats.wood_door(), false)
		_cyl(Vector3(fc + n * 0.03, 1.05, along + 0.36), 0.02, 0.12, Mats.chrome(), false)
	else:
		_box(Vector3(along, 1.06, fc), Vector3(1.0, 2.1, 0.05), Mats.wood_door(), false)
		_cyl(Vector3(along + 0.36, 1.05, fc + n * 0.03), 0.02, 0.12, Mats.chrome(), false)


## Plain wall clock — the kind that makes time feel slower.
func _office_clock(dir: int, plane: float) -> void:
	var along := S / 2.0
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T / 2.0)
	var y := 2.25
	if dir < 2:
		_cc0_prop("wall_clock", Vector3(inner + n * 0.01, y, along), PI / 2.0 * n)
	else:
		_cc0_prop("wall_clock", Vector3(along, y, inner + n * 0.01), 0.0 if n > 0.0 else PI)


# --- lighting ----------------------------------------------------------------

func _build_lighting() -> void:
	if theme == 1:
		_office_lighting()
		return
	if theme == 5:
		_asy_lighting()
		return
	if theme == 2:
		_sewer_lighting()
		return
	if theme == 4:
		_air_lighting()
		return
	if theme == 6:
		_sch_lighting()
		return
	if style == WorldGen.STYLE_HALLWAY:
		_hall_lighting()
		return
	var is_spawn := cell == Vector2i.ZERO
	var dead := (not is_spawn) and _r(8) < 0.07
	var flicker := (not is_spawn) and (not dead) and _r(9) < 0.16
	var pmat: StandardMaterial3D
	if dead:
		pmat = Mats.panel_dead()
	elif flicker:
		pmat = Mats.panel_on().duplicate()
	else:
		pmat = Mats.panel_on()
	for p in [Vector2(3, 3), Vector2(9, 3), Vector2(3, 9), Vector2(9, 9)]:
		_troffer(Vector3(p.x, 0, p.y), Vector2(1.7, 0.8), pmat, Mats.sign_housing())

	var grand := style == WorldGen.STYLE_GRAND or style == WorldGen.STYLE_BALLROOM
	if grand:
		_chandelier()
	if dead:
		return

	var energy := 2.4 if grand else 1.35
	var light := _make_main_light(flicker, pmat, energy)
	light.light_color = Color.from_hsv(0.07 + 0.05 * _r(11), 0.25 + 0.35 * _r(12), 1.0)
	light.omni_range = 16.0 if grand else 11.0
	light.position = Vector3(S / 2.0, ceil_h - (1.4 if grand else 0.45), S / 2.0)
	light.shadow_enabled = true
	light.distance_fade_enabled = true
	light.distance_fade_begin = 24.0
	light.distance_fade_length = 8.0
	light.distance_fade_shadow = 18.0
	add_child(light)


## Hotel circulation is lit by a chain of warm flush mounts, not the four
## fluorescent panels used in gaming rooms.  Each fixture owns its light so
## highlights and falloff follow the visible architecture down the corridor.
func _hall_lighting() -> void:
	var cdir := WorldGen.corridor(wseed, cell)
	var along_x := cdir != 2
	var yw := 0.0 if along_x else PI / 2.0
	var o := Vector3(S / 2.0, 0, S / 2.0)
	var dead_i := -1
	var flick_i := -1
	if cell != Vector2i.ZERO and _r(8) < 0.10:
		dead_i = int(_r(18) * 2.99)
	elif cell != Vector2i.ZERO and _r(9) < 0.18:
		flick_i = int(_r(19) * 2.99)
	for i in 3:
		var t := -4.0 + 4.0 * float(i)
		var at := _wp(o, Vector3(t, ceil_h - 0.08, 0), yw)
		_cyl(at + Vector3(0, 0.025, 0), 0.27, 0.08, Mats.brass(), false)
		var lens_mat: StandardMaterial3D = Mats.panel_dead() if i == dead_i else Mats.panel_on()
		if i == flick_i:
			lens_mat = Mats.panel_on().duplicate()
		_cyl(at - Vector3(0, 0.035, 0), 0.20, 0.035, lens_mat, false)
		if i == dead_i:
			continue
		var light: OmniLight3D
		if i == flick_i:
			light = _make_main_light(true, lens_mat, 0.58)
		else:
			light = OmniLight3D.new()
			light.light_energy = 0.58
		light.light_color = Color(1.0, 0.72, 0.46)
		light.omni_range = 5.6
		light.position = at - Vector3(0, 0.30, 0)
		light.shadow_enabled = i == 1
		light.distance_fade_enabled = true
		light.distance_fade_begin = 20.0
		light.distance_fade_length = 7.0
		light.distance_fade_shadow = 15.0
		add_child(light)


func _office_lighting() -> void:
	if style == WorldGen.OFFICE_CORRIDOR:
		_office_corridor_lighting()
		return
	var is_spawn := cell == Vector2i.ZERO
	var dead := (not is_spawn) and _r(8) < 0.02
	var flicker := (not is_spawn) and (not dead) and _r(9) < 0.05
	var pmat: StandardMaterial3D
	if dead:
		pmat = Mats.panel_dead()
	elif flicker:
		pmat = Mats.office_panel().duplicate()
	else:
		pmat = Mats.office_panel()
	# dense, even grid of fluorescent troffers — shadowless corporate daylight
	for gx in [3.0, 9.0]:
		for gz in [2.1, 4.7, 7.3, 9.9]:
			_troffer(Vector3(gx, 0, gz), Vector2(1.15, 0.55), pmat, Mats.metal_gray())
	# AC diffuser grilles between the light rows
	for vp in [Vector2(6.0, 3.4), Vector2(6.0, 8.6)]:
		_box(Vector3(vp.x, ceil_h - 0.015, vp.y), Vector3(0.62, 0.03, 0.62), Mats.metal_gray(), false)
		for si in 4:
			_box(Vector3(vp.x, ceil_h - 0.035, vp.y - 0.21 + 0.14 * float(si)),
				Vector3(0.54, 0.012, 0.05), Mats.charcoal(), false)
	if dead:
		return
	var light := _make_main_light(flicker, pmat, 1.0)
	light.light_color = Color(0.93, 1.0, 0.95)
	light.omni_range = 12.5
	light.position = Vector3(S / 2.0, ceil_h - 0.5, S / 2.0)
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 24.0
	light.distance_fade_length = 8.0
	add_child(light)


## Corridor fixtures follow the actual lane instead of filling the entire
## 12m cell.  Besides reading as intentional architecture, this prevents
## light from leaking out of the reserved office volumes behind locked doors.
func _office_corridor_lighting() -> void:
	var cdir := WorldGen.corridor(wseed, cell)
	var along_x := cdir != 2
	var yw := 0.0 if along_x else PI / 2.0
	var o := Vector3(S / 2.0, 0, S / 2.0)
	var dead := _r(8) < 0.025
	var flicker := not dead and _r(9) < 0.07
	var pmat: StandardMaterial3D
	if dead:
		pmat = Mats.panel_dead()
	elif flicker:
		pmat = Mats.office_panel().duplicate()
	else:
		pmat = Mats.office_panel()
	for t in [-4.5, -1.5, 1.5, 4.5]:
		var at := _wp(o, Vector3(t, 0, 0), yw)
		_troffer(at, Vector2(1.15, 0.5) if along_x else Vector2(0.5, 1.15),
			pmat, Mats.metal_gray())
	# One supply and one return grille, both kept over the corridor rather than
	# in the inaccessible office strips.
	for t in [-3.0, 3.0]:
		var vp := _wp(o, Vector3(t, ceil_h - 0.018, 0.88 if t < 0.0 else -0.88), yw)
		var grille := _mbox(self, vp, Vector3(0.58, 0.032, 0.58), Mats.metal_gray())
		grille.rotation.y = yw
	if dead:
		return
	var light := _make_main_light(flicker, pmat, 0.82)
	light.light_color = Color(0.91, 1.0, 0.94)
	light.omni_range = 10.5
	light.position = Vector3(S / 2.0, ceil_h - 0.48, S / 2.0)
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 22.0
	light.distance_fade_length = 8.0
	add_child(light)


## Ceiling light fixture: recessed glowing lens inside a trim frame, instead
## of a bare emissive slab stuck to the tiles.
func _troffer(at: Vector3, lens: Vector2, pmat: Material, frame: Material) -> void:
	_box(Vector3(at.x, ceil_h - 0.055, at.z), Vector3(lens.x, 0.05, lens.y), pmat, false)
	var fx := lens.x / 2.0 + 0.055
	var fz := lens.y / 2.0 + 0.055
	_box(Vector3(at.x, ceil_h - 0.02, at.z - fz), Vector3(lens.x + 0.18, 0.035, 0.07), frame, false)
	_box(Vector3(at.x, ceil_h - 0.02, at.z + fz), Vector3(lens.x + 0.18, 0.035, 0.07), frame, false)
	_box(Vector3(at.x - fx, ceil_h - 0.02, at.z), Vector3(0.07, 0.035, lens.y + 0.18), frame, false)
	_box(Vector3(at.x + fx, ceil_h - 0.02, at.z), Vector3(0.07, 0.035, lens.y + 0.18), frame, false)


func _make_main_light(flicker: bool, pmat: StandardMaterial3D, energy: float) -> OmniLight3D:
	if not flicker:
		var l := OmniLight3D.new()
		l.light_energy = energy
		return l
	var fl := FlickerLight.new()
	fl.base_energy = energy
	fl.mats = [pmat]
	fl.rng_seed = WorldGen.h(wseed, cell.x, cell.y, 10)
	var bz := AudioStreamPlayer3D.new()
	bz.stream = SoundBank.buzz()
	bz.unit_size = 3.0
	bz.max_distance = 15.0
	bz.volume_db = -26.0
	bz.bus = "Hall"
	bz.autoplay = true
	bz.position = Vector3(S / 2.0, _wall_h() - 0.5, S / 2.0)
	add_child(bz)
	fl.buzz = bz
	return fl


func _chandelier() -> void:
	# a real ornate chandelier (CC0 model, hangs 1.04m below its origin) with
	# a warm bulb glowing in its heart
	var ch := _cc0_prop("Chandelier_03", Vector3(S / 2.0, ceil_h - 0.05, S / 2.0), _r(30) * TAU, 1.35)
	_asy_no_shadows(ch)
	_sphere(Vector3(S / 2.0, ceil_h - 0.95, S / 2.0), 0.13, Mats.bulb())


# --- furnishing --------------------------------------------------------------

func _build_props() -> void:
	portal_dest = WorldGen.portal(wseed, cell, theme)
	if portal_dest >= 0:
		_build_portal(portal_dest)
	# A large sewer basin is a bank of cell-sized treatment pools. Structural
	# dressing belongs to each pool, not only to the room anchor that owns the
	# shared ambience and larger set pieces.
	if not is_room_anchor and (style == WorldGen.SEWER_BASIN or style == WorldGen.SEWER_CISTERN):
		_sewer_basin_props()
		_sewer_mist()
	# one room is furnished once, by its anchor cell, around its true centre
	if not is_room_anchor:
		return
	var split := WorldGen.room_split(wseed, room_root, theme)
	if not split.is_empty():
		_partition(split[0], split[1])
		if portal_dest < 0:
			_small_room_props(split[0], split[1])
		return
	var rc := WorldGen.room_centre(wseed, room_root)
	var off := Vector3(rc.x - (float(cell.x) * S + S / 2.0), 0.0,
		rc.y - (float(cell.y) * S + S / 2.0))
	# these build against a specific wall of THIS cell — moving them to the
	# room centre would tear the glass, mezzanine or desk run off its wall
	if style == WorldGen.SEWER_BASIN or style == WorldGen.AIR_GATE or style == WorldGen.AIR_CHECKIN \
			or style == WorldGen.AIR_ESCALATOR or style == WorldGen.AIR_TRANSIT:
		off = Vector3.ZERO
	var n0 := get_child_count()
	var b0 := body.get_child_count()
	match style:
		WorldGen.STYLE_PILLARS:
			_pillars(ceil_h, Mats.brass())
			if _r(240) < 0.3:
				_blackjack(Vector3(6.0, 0, 6.0), 242)
		WorldGen.STYLE_SLOTS:
			_slots()
		WorldGen.STYLE_LOUNGE:
			_lounge()
			if _r(240) < 0.35:
				_blackjack(Vector3(9.4, 0, 4.6), 242)
		WorldGen.STYLE_GRAND:
			_pillars(ceil_h, Mats.marble_photo())
			if room_n >= 4:
				# A 24m casino hall needs more than a 12m column island. Two
				# abandoned tables give the enlarged floor a reason to exist.
				_blackjack(Vector3(1.6, 0, 1.6), 248)
				_blackjack(Vector3(10.4, 0, 10.4), 286)
			if _r(246) < 0.5:
				_velvet_ropes()
		WorldGen.STYLE_BALLROOM:
			_casino_ballroom()
		WorldGen.STYLE_HALLWAY:
			_hallway()
		WorldGen.STYLE_EMPTY:
			if portal_dest < 0 and _r(20) < 0.35:
				_planter(Vector3(2.6 + 6.8 * _r(21), 0, 2.6 + 6.8 * _r(22)))
			if portal_dest < 0 and _r(24) < 0.48:
				_casino_service_cart(Vector3(2.1 if _r(25) < 0.5 else 9.9, 0,
					2.1 if _r(26) < 0.5 else 9.9), 27)
		WorldGen.OFFICE_CORRIDOR:
			_office_corridor()
		WorldGen.OFFICE_CUBICLES:
			_office_cubicles()
		WorldGen.OFFICE_STORAGE:
			_office_storage()
		WorldGen.OFFICE_BREAK:
			_office_break()
		WorldGen.OFFICE_BOARDROOM:
			_office_boardroom()
		WorldGen.OFFICE_EMPTY:
			if portal_dest < 0 and _r(20) < 0.15:
				_planter(Vector3(2.6 + 6.8 * _r(21), 0, 2.6 + 6.8 * _r(22)))
			if _r(250) < 0.35:
				_copier(Vector3(3.0, 0, 8.8), 252)
			elif portal_dest < 0 and _r(254) < 0.62:
				_office_floor_files(Vector3(2.2 if _r(255) < 0.5 else 9.8, 0,
					2.1 if _r(256) < 0.5 else 9.9), 257)
		WorldGen.SEWER_TUNNEL:
			_sewer_tunnel_props()
			_sewer_mist()
			_sewer_sounds()
		WorldGen.SEWER_BASIN:
			_sewer_basin_props()
			_sewer_mist()
			_sewer_sounds()
		WorldGen.SEWER_PUMP:
			_sewer_pump_props()
			_sewer_mist()
			_sewer_sounds()
		WorldGen.SEWER_DRY:
			_sewer_dry_props()
			_sewer_mist()
			_sewer_sounds()
		WorldGen.SEWER_GALLERY:
			_sewer_gallery()
			_sewer_mist()
			_sewer_sounds()
		WorldGen.SEWER_CISTERN:
			_sewer_basin_props()
			_sewer_cistern()
			_sewer_mist()
			_sewer_sounds()
		WorldGen.AIR_GATE:
			_air_gate()
			_air_common()
		WorldGen.AIR_CONCOURSE:
			_air_concourse()
			_air_common()
		WorldGen.AIR_TRANSIT:
			_air_transit()
			_air_common()
		WorldGen.AIR_CHECKIN:
			_air_checkin()
			_air_common()
		WorldGen.AIR_BAGGAGE:
			_air_baggage()
			_air_common()
		WorldGen.AIR_ESCALATOR:
			_air_escalator()
			_air_common()
		WorldGen.AIR_HALL:
			_air_hall()
			_air_common()
		WorldGen.AIR_FOODCOURT:
			_air_foodcourt()
			_air_common()
		WorldGen.ASY_CELL:
			_asy_cell_props()
		WorldGen.ASY_WARD:
			_asy_ward()
			_asy_sounds()
		WorldGen.ASY_DAYROOM:
			_asy_dayroom()
			_asy_sounds()
		WorldGen.ASY_TREATMENT:
			_asy_treatment()
			_asy_sounds()
		WorldGen.ASY_HYDRO:
			_asy_hydro()
			_asy_sounds()
		WorldGen.ASY_OFFICE:
			_asy_office()
		WorldGen.ASY_CORRIDOR:
			_asy_corridor()
			if _r(779) < 0.35:
				_asy_sounds()
		WorldGen.ASY_CHAPEL:
			_asy_chapel()
			_asy_sounds()
		WorldGen.SCH_CORRIDOR:
			_sch_corridor()
		WorldGen.SCH_CLASSROOM:
			_sch_classroom()
		WorldGen.SCH_CAFETERIA:
			_sch_cafeteria()
		WorldGen.SCH_BATHROOM:
			_sch_bathroom()
		WorldGen.SCH_GYM:
			_sch_gym()
		WorldGen.SCH_LIBRARY:
			_sch_library()
		WorldGen.SCH_LAB:
			_sch_lab()
		WorldGen.SCH_ADMIN:
			_sch_admin()
		WorldGen.SCH_AUDITORIUM:
			_sch_auditorium()
	_shift_props(off, n0, b0)


## Move everything the prop pass just built onto the room centre — meshes,
## lights, sounds and colliders alike, whatever node they were parented to.
func _shift_props(off: Vector3, n0: int, b0: int) -> void:
	if off == Vector3.ZERO:
		return
	for i in range(n0, get_child_count()):
		var ch := get_child(i)
		if ch is Node3D:
			(ch as Node3D).position += off
	for i in range(b0, body.get_child_count()):
		var cs := body.get_child(i)
		if cs is Node3D:
			(cs as Node3D).position += off


func _pillars(h: float, mat: Material) -> void:
	var points := [Vector2(2.2, 2.2), Vector2(9.8, 2.2),
		Vector2(2.2, 9.8), Vector2(9.8, 9.8)]
	if style == WorldGen.STYLE_GRAND and room_n >= 4:
		# Local (6,6) is shifted to the 24x24 room centre after furnishing.
		# An eight-column perimeter grid leaves a generous central axis while
		# making the whole hall, not just its middle cell, feel supported.
		points = []
		for px in [-8.0, 0.0, 8.0]:
			for pz in [-8.0, 0.0, 8.0]:
				if px == 0.0 and pz == 0.0:
					continue
				points.append(Vector2(6.0 + px, 6.0 + pz))
	for p in points:
		_box(Vector3(p.x, 0.06, p.y), Vector3(0.95, 0.12, 0.95), Mats.darkwood())
		_cyl(Vector3(p.x, h / 2.0, p.y), 0.34, h, mat)
		for ring_y in [0.28, h - 0.28]:
			var tor := MeshInstance3D.new()
			tor.mesh = TOR
			tor.material_override = Mats.brass()
			tor.position = Vector3(p.x, ring_y, p.y)
			tor.scale = Vector3(0.5, 0.22, 0.5)
			add_child(tor)


# --- vegas: slots ------------------------------------------------------------

func _slots() -> void:
	var idx := 0
	for row in [[4.35, -1.0], [7.65, 1.0]]:
		var z: float = row[0]
		var fx: float = row[1]
		for i in 5:
			_slot_machine(3.4 + 1.3 * i, z, fx, idx)
			idx += 1
	# colored glow washing over each bank's player side
	var glow_cols := [Color(1.0, 0.35, 0.6), Color(0.45, 0.8, 1.0)]
	var glow_z := [3.0, 9.0]
	for gi in 2:
		var gl := OmniLight3D.new()
		gl.light_color = glow_cols[gi]
		gl.light_energy = 0.7
		gl.omni_range = 5.5
		gl.position = Vector3(S / 2.0, 2.3, glow_z[gi])
		gl.shadow_enabled = false
		gl.distance_fade_enabled = true
		gl.distance_fade_begin = 16.0
		gl.distance_fade_length = 8.0
		add_child(gl)
	# magenta ceiling cove around the slot floor
	var cy := ceil_h - 0.22
	_box(Vector3(S / 2.0, cy, 0.5), Vector3(S - 1.6, 0.05, 0.06), Mats.neon_pink(), false)
	_box(Vector3(S / 2.0, cy, S - 0.5), Vector3(S - 1.6, 0.05, 0.06), Mats.neon_pink(), false)
	_box(Vector3(0.5, cy, S / 2.0), Vector3(0.06, 0.05, S - 1.6), Mats.neon_pink(), false)
	_box(Vector3(S - 0.5, cy, S / 2.0), Vector3(0.06, 0.05, S - 1.6), Mats.neon_pink(), false)
	_slots_sign()
	var snd := SlotSounds.new()
	snd.position = Vector3(S / 2.0, 1.6, S / 2.0)
	add_child(snd)


## One machine: sculpted cabinet shell (shared ArrayMesh) with the full panel
## stack riding its sloped front, and a bonus wheel or marquee topper.
func _slot_machine(x: float, z: float, f: float, idx: int) -> void:
	var m := Node3D.new()
	m.position = Vector3(x, 0, z)
	if f < 0.0:
		m.rotation.y = PI
	add_child(m)
	var has_wheel := _r(72 + idx) < 0.5
	var neon: Material = Mats.neon_pink() if _r(84 + idx) < 0.5 else Mats.neon_cyan()
	var bodies: Array = [Mats.gold_mirror(), Mats.body_black(), Mats.body_red(), Mats.body_purple(), Mats.body_blue()]
	var bodymat: Material = bodies[int(_r(76 + idx) * 4.999)]

	var shell := MeshInstance3D.new()
	shell.mesh = Cabinet.mesh()
	shell.material_override = bodymat
	m.add_child(shell)
	for sx in [-1.0, 1.0]:
		_mbox(m, Vector3(sx * 0.30, 1.05, 0.21), Vector3(0.02, 1.8, 0.03), neon)
	_mrbox(m, Vector3(0, 0.24, 0.235), Vector3(0.34, 0.13, 0.06), Mats.sign_housing(), 0.015)
	_mquad(m, Vector3(0, 0.42, 0.278), Vector2(0.44, 0.26), Mats.ticker())
	for sx in [-1.0, 1.0]:
		_mbox(m, Vector3(sx * 0.19, 0.64, 0.272), Vector3(0.09, 0.14, 0.015), Mats.sign_housing())
	var deck := _mrbox(m, Vector3(0, 0.84, 0.30), Vector3(0.54, 0.045, 0.26), Mats.sign_housing(), 0.012)
	deck.rotation.x = 0.45
	var bmats: Array = [Mats.lamp_amber(), Mats.red_knob(), Mats.chrome(), Mats.lamp_red(), Mats.lamp_amber()]
	for bi in 5:
		var btn := _mcyl(m, Vector3(-0.17 + 0.077 * bi, 0.875, 0.345), 0.024, 0.02, bmats[bi])
		btn.rotation.x = 0.45
	_mbox(m, Vector3(0.19, 0.80, 0.315), Vector3(0.12, 0.09, 0.07), Mats.sign_housing())
	_mbox(m, Vector3(0.19, 0.815, 0.352), Vector3(0.07, 0.012, 0.01), Mats.lamp_green())
	var reels := _mquad(m, Vector3(0, 1.18, 0.335), Vector2(0.46, 0.40), Mats.slot_reels())
	reels.rotation.x = -0.107
	var pay := _mquad(m, Vector3(0, 1.66, 0.275), Vector2(0.46, 0.34), Mats.paytable())
	pay.rotation.x = -0.095
	var glass := _mquad(m, Vector3(0, 1.45, 0.315), Vector2(0.5, 1.0), Mats.glass())
	glass.rotation.x = -0.1
	_mrbox(m, Vector3(0, 2.19, -0.02), Vector3(0.54, 0.18, 0.40), Mats.sign_housing(), 0.02)
	_mquad(m, Vector3(0, 2.19, 0.185), Vector2(0.5, 0.16), Mats.ticker())
	_mcyl(m, Vector3(0, 2.33, -0.16), 0.035, 0.1, Mats.lamp_amber())
	_mcyl(m, Vector3(0, 2.42, -0.16), 0.03, 0.08, Mats.lamp_red())
	if has_wheel:
		_mbox(m, Vector3(0, 2.38, 0.0), Vector3(0.16, 0.35, 0.1), Mats.gold_mirror())
		_mquad(m, Vector3(0, 2.72, 0.06), Vector2(0.66, 0.66), Mats.slot_wheel())
		var ring := MeshInstance3D.new()
		ring.mesh = TOR
		ring.material_override = Mats.ring_pink() if _r(84 + idx) < 0.5 else Mats.ring_cyan()
		ring.position = Vector3(0, 2.72, 0.03)
		ring.scale = Vector3(0.36, 0.16, 0.36)
		ring.rotation.x = PI / 2.0
		m.add_child(ring)
		for sx in [-1.0, 1.0]:
			var wing := _mbox(m, Vector3(sx * 0.30, 2.62, -0.02), Vector3(0.1, 0.5, 0.08), Mats.gold_mirror())
			wing.rotation.z = -sx * 0.3
	else:
		_mrbox(m, Vector3(0, 2.50, 0.0), Vector3(0.54, 0.4, 0.14), Mats.slot_body(), 0.02)
		_mquad(m, Vector3(0, 2.50, 0.075), Vector2(0.5, 0.36), Mats.slot_screen())
		var arm := _mcyl(m, Vector3(0.33, 1.35, -0.02), 0.018, 0.34, Mats.chrome())
		arm.rotation.x = -0.4
		var knob := MeshInstance3D.new()
		knob.mesh = SPH
		knob.material_override = Mats.red_knob()
		knob.position = Vector3(0.33, 1.5, -0.09)
		knob.scale = Vector3.ONE * 0.09
		m.add_child(knob)
	if _r(60 + idx) < 0.85:
		var cyaw := (0.0 if f > 0.0 else PI) + (_r(66 + idx) - 0.5) * 0.6
		var cpos := Vector3(x + (_r(96 + idx) - 0.5) * 0.16, 0, z + f * 0.95)
		# a real worn bar stool pulled up to the machine
		_cc0_prop("bar_chair_round_01", cpos, cyaw)
		_collider_cyl(cpos + Vector3(0, 0.4, 0), 0.25, 0.8)
	_collider_box(Vector3(x, 1.42, z), Vector3(0.66, 2.85, 0.56))


## Upholstered swivel chair built in a yawed sub-node; the backrest sits on
## the local +z side.
func _chair_at(p: Vector3, yaw: float, mat: Material) -> void:
	var ch := Node3D.new()
	ch.position = p
	ch.rotation.y = yaw
	add_child(ch)
	_mcyl(ch, Vector3(0, 0.04, 0), 0.19, 0.05, Mats.chrome())
	_mcyl(ch, Vector3(0, 0.35, 0), 0.045, 0.6, Mats.chrome())
	_mcyl(ch, Vector3(0, 0.68, 0), 0.24, 0.12, mat)
	var back := _mrbox(ch, Vector3(0, 1.02, 0.26), Vector3(0.44, 0.55, 0.09), mat, 0.04)
	back.rotation.x = -0.1
	_collider_cyl(p + Vector3(0, 0.65, 0), 0.25, 1.3)


## Backlit SLOTS sign on the first solid wall of the room.
func _slots_sign() -> void:
	if _r(88) > 0.7:
		return
	for dir in 4:
		var info := WorldGen.edge_info(wseed, cell, dir, theme)
		if not info["wall"]:
			continue
		var plane := (S - T / 2.0) if (dir == 0 or dir == 2) else (T / 2.0)
		var n := -1.0 if (dir == 0 or dir == 2) else 1.0
		var inner := plane + n * (T * 0.5)
		var off := inner + n * 0.05
		var lb := Label3D.new()
		lb.text = "S L O T S"
		lb.font_size = 140
		lb.pixel_size = 0.0028
		lb.outline_size = 20
		lb.outline_modulate = Color(0.4, 0.05, 0.1)
		lb.modulate = Color(1.0, 0.78, 0.25)
		if dir < 2:
			lb.position = Vector3(off, 2.45, S / 2.0)
			lb.rotation.y = PI / 2.0 if n > 0.0 else -PI / 2.0
			_box(Vector3(off, 2.13, S / 2.0), Vector3(0.04, 0.05, 2.2), Mats.neon_amber(), false)
		else:
			lb.position = Vector3(S / 2.0, 2.45, off)
			lb.rotation.y = 0.0 if n > 0.0 else PI
			_box(Vector3(S / 2.0, 2.13, off), Vector3(2.2, 0.05, 0.04), Mats.neon_amber(), false)
		add_child(lb)
		return


const CASINO_NEON := [
	["C O C K T A I L S", Color(0.3, 1.0, 0.8)],
	["C A S H I E R", Color(1.0, 0.75, 0.2)],
	["B U F F E T", Color(1.0, 0.5, 0.2)],
	["K E N O", Color(0.55, 0.7, 1.0)],
	["R O O M S", Color(1.0, 0.4, 0.6)],
]


## Backlit neon lettering pointing at amenities that are never found.
func _casino_neon(dir: int, plane: float) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T * 0.5)
	var off := inner + n * 0.05
	var pick := int(_r(56 + dir) * (float(CASINO_NEON.size()) - 0.01))
	var txt: String = CASINO_NEON[pick][0]
	var colr: Color = CASINO_NEON[pick][1]
	var lb := Label3D.new()
	lb.text = txt
	lb.font_size = 120
	lb.pixel_size = 0.0026
	lb.outline_size = 18
	lb.outline_modulate = Color(colr.r * 0.22, colr.g * 0.22, colr.b * 0.22)
	lb.modulate = colr
	var tube := Mats.neon_col("c%d" % pick, colr)
	if dir < 2:
		lb.position = Vector3(off, 2.42, S / 2.0)
		lb.rotation.y = PI / 2.0 if n > 0.0 else -PI / 2.0
		_box(Vector3(off, 2.12, S / 2.0), Vector3(0.04, 0.045, 1.9), tube, false)
	else:
		lb.position = Vector3(S / 2.0, 2.42, off)
		lb.rotation.y = 0.0 if n > 0.0 else PI
		_box(Vector3(S / 2.0, 2.12, off), Vector3(1.9, 0.045, 0.04), tube, false)
	add_child(lb)
	var l := OmniLight3D.new()
	l.light_color = colr
	l.light_energy = 0.45
	l.omni_range = 4.0
	l.position = lb.position + Vector3(n * 0.35, -0.1, 0) if dir < 2 else lb.position + Vector3(0, -0.1, n * 0.35)
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 14.0
	l.distance_fade_length = 6.0
	add_child(l)


## Bill-change machine humming against the wall, screen still lit.
func _change_machine(dir: int, plane: float) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T * 0.5)
	var along := 2.4 + 7.2 * _r(58 + dir)
	var v := Node3D.new()
	if dir < 2:
		v.position = Vector3(inner + n * 0.30, 0, along)
		v.rotation.y = PI / 2.0 if n > 0.0 else -PI / 2.0
	else:
		v.position = Vector3(along, 0, inner + n * 0.30)
		v.rotation.y = 0.0 if n > 0.0 else PI
	add_child(v)
	_mrbox(v, Vector3(0, 0.95, 0), Vector3(0.75, 1.9, 0.5), Mats.slot_body(), 0.03)
	_mquad(v, Vector3(-0.12, 1.42, 0.253), Vector2(0.34, 0.24), Mats.ticker())
	_mrbox(v, Vector3(0.22, 1.38, 0.26), Vector3(0.16, 0.3, 0.03), Mats.sign_housing(), 0.008)
	for bi in 6:
		_mbox(v, Vector3(0.16 + 0.06 * float(bi % 2), 1.47 - 0.08 * float(bi / 2), 0.278),
			Vector3(0.04, 0.04, 0.01), Mats.charcoal())
	_mbox(v, Vector3(0, 0.98, 0.26), Vector3(0.5, 0.05, 0.03), Mats.chrome())
	_mrbox(v, Vector3(0, 0.62, 0.24), Vector3(0.44, 0.18, 0.06), Mats.sign_housing(), 0.015)
	var lb := Label3D.new()
	lb.text = "CHANGE"
	lb.font_size = 72
	lb.pixel_size = 0.0022
	lb.modulate = Color(1.0, 0.72, 0.2)
	lb.position = Vector3(0, 1.75, 0.26)
	v.add_child(lb)
	_collider_yaw_box(v.position + Vector3(0, 0.95, 0), Vector3(0.8, 1.9, 0.55), v.rotation.y)


## Blackjack table nobody deals anymore: baize, shoe, chips, three stools.
func _blackjack(p: Vector3, salt: int) -> void:
	_cyl(p + Vector3(0, 0.76, 0), 0.92, 0.06, Mats.felt_green(), false)
	var rim := MeshInstance3D.new()
	rim.mesh = TOR
	rim.material_override = Mats.darkwood()
	rim.position = p + Vector3(0, 0.775, 0)
	rim.scale = Vector3(1.24, 0.22, 1.24)
	add_child(rim)
	_cyl(p + Vector3(0, 0.38, 0), 0.15, 0.76, Mats.darkwood(), false)
	_cyl(p + Vector3(0, 0.05, 0), 0.48, 0.1, Mats.darkwood(), false)
	_collider_cyl(p + Vector3(0, 0.45, 0), 0.95, 0.9)
	# dealer side: chip rack and shoe
	_rbox(p + Vector3(0, 0.815, -0.45), Vector3(0.42, 0.035, 0.18), Mats.sign_housing(), 0.008, false)
	_rbox(p + Vector3(0.45, 0.83, -0.28), Vector3(0.16, 0.1, 0.24), Mats.body_black(), 0.02, false)
	# cards where the last hand stopped
	for i in 5:
		var ca := _box(p + Vector3((_r(salt + i) - 0.5) * 1.1, 0.795, (_r(salt + 9 + i) - 0.5) * 0.9),
			Vector3(0.063, 0.004, 0.088), Mats.paint_white(), false)
		ca.rotation.y = _r(salt + 17 + i) * TAU
	# chip stacks
	var chip_mats: Array = [Mats.red_knob(), Mats.body_black(), Mats.body_blue()]
	for i in 3:
		_cyl(p + Vector3(0.2 - 0.2 * float(i), 0.82, 0.32), 0.036,
			0.05 + 0.05 * _r(salt + 22 + i), chip_mats[i], false)
	# stools around the player arc
	for i in 3:
		var ang := PI * (0.3 + 0.2 * float(i)) + (_r(salt + 27 + i) - 0.5) * 0.2
		var cp := p + Vector3(cos(ang) * 1.4, 0, sin(ang) * 1.4)
		_chair_at(cp, atan2(cos(ang), sin(ang)) + (_r(salt + 31 + i) - 0.5) * 0.5, Mats.velvet())


## Brass posts and sagging red rope framing the grand hall's centre aisle.
func _velvet_ropes() -> void:
	for xr in [3.0, 9.0]:
		var pts := []
		for i in 4:
			pts.append(Vector3(xr, 0, 2.4 + 2.4 * float(i)))
		for i in 4:
			var pp: Vector3 = pts[i]
			_cyl(pp + Vector3(0, 0.5, 0), 0.028, 1.0, Mats.brass())
			_cyl(pp + Vector3(0, 0.015, 0), 0.15, 0.03, Mats.brass(), false)
			_sphere(pp + Vector3(0, 1.03, 0), 0.045, Mats.brass())
		for i in 3:
			var a: Vector3 = pts[i] + Vector3(0, 0.93, 0)
			var b: Vector3 = pts[i + 1] + Vector3(0, 0.93, 0)
			var mid := (a + b) / 2.0 - Vector3(0, 0.2, 0)
			var r1 := _beam(a, mid, 0.04, Mats.velvet())
			var r2 := _beam(mid, b, 0.04, Mats.velvet())
			r1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			r2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Landmark: the casino's forgotten ballroom. A clear marble dance floor,
## bandstand and perimeter supper tables make the whole 24m hall legible at a
## glance without filling its main circulation axis.
func _casino_ballroom() -> void:
	var c := Vector3(S / 2.0, 0, S / 2.0)
	# Inlaid dance floor and brass border.
	_box(c + Vector3(0, 0.012, 0.6), Vector3(10.2, 0.024, 8.2), Mats.marble_photo(), false)
	for sx in [-5.18, 5.18]:
		_box(c + Vector3(sx, 0.027, 0.6), Vector3(0.08, 0.03, 8.35), Mats.brass(), false)
	for sz in [-3.52, 4.72]:
		_box(c + Vector3(0, 0.027, sz), Vector3(10.35, 0.03, 0.08), Mats.brass(), false)
	# Low stage across the far side, curtain folds and an abandoned microphone.
	var stage := c + Vector3(0, 0, -8.0)
	_rbox(stage + Vector3(0, 0.22, 0), Vector3(9.2, 0.44, 2.7), Mats.darkwood(), 0.025)
	for i in 9:
		var x := -4.2 + 1.05 * float(i)
		_box(stage + Vector3(x, 2.45, -1.22), Vector3(0.58, 4.4, 0.10),
			Mats.velvet() if i % 2 == 0 else Mats.velvet2(), false)
	var mic := stage + Vector3(0.8, 0.44, 0.35)
	_cyl(mic + Vector3(0, 0.72, 0), 0.025, 1.44, Mats.chrome(), false)
	_sphere(mic + Vector3(0, 1.48, 0), 0.065, Mats.charcoal())
	_collider_box(stage + Vector3(0, 0.24, 0), Vector3(9.3, 0.48, 2.8))
	# Supper tables form a loose ring, leaving the dance floor empty.
	for i in 6:
		var ang := TAU * float(i) / 6.0 + PI / 6.0
		var tp := c + Vector3(cos(ang) * 8.1, 0, 0.9 + sin(ang) * 7.2)
		_cc0_prop("coffee_table_round_01", tp, ang)
		_collider_cyl(tp + Vector3(0, 0.26, 0), 0.67, 0.52)
		for j in 3:
			var ca := ang + TAU * float(j) / 3.0 + 0.35
			var cp := tp + Vector3(cos(ca) * 1.0, 0, sin(ca) * 1.0)
			_cc0_prop("bar_chair_round_01", cp, ca + PI)
			_collider_cyl(cp + Vector3(0, 0.38, 0), 0.25, 0.76)
	var title := Label3D.new()
	title.text = "THE SILVER ROOM"
	title.font_size = 140
	title.pixel_size = 0.003
	title.modulate = Color(1.0, 0.72, 0.22)
	title.position = stage + Vector3(0, 3.8, -1.30)
	add_child(title)


## Hotel corridor: a 3m lane of numbered, permanently locked rooms.  The
## guest-room strips behind the two walls are real reserved floor-plan volume:
## they may continue invisibly through several corridor cells, but no navigable
## opening can expose a door's back.  Actual room connections get a cased bay
## with return walls all the way to the canonical cell-edge doorway.
func _hallway() -> void:
	var cdir := WorldGen.corridor(wseed, cell)
	var along_x := cdir != 2
	var yw := 0.0 if along_x else PI / 2.0
	var o := Vector3(S / 2.0, 0, S / 2.0)
	# A fitted runner, inset from the walls so a dark carpet border remains.
	var run := _mbox(self, _wp(o, Vector3(0, 0.013, 0), yw),
		Vector3(12.0, 0.026, 2.18), Mats.carpet_red())
	run.rotation.y = yw

	var side_data := []
	for si in 2:
		var side := -1.5 if si == 0 else 1.5
		var sdir := (3 if si == 0 else 2) if along_x else (1 if si == 0 else 0)
		var info := WorldGen.edge_info(wseed, cell, sdir, theme)
		var bay := []
		if not info["wall"]:
			# Edge t runs in +x or +z.  Local corridor x runs toward -z after
			# the 90-degree rotation, hence the sign flip in a z-axis corridor.
			var bt: float = float(info["t"]) - 6.0 if along_x else 6.0 - float(info["t"])
			var bw := clampf(float(info["w"]) + 0.42, 2.05, 4.2)
			bay = [bt, bw]
		var doors := _hall_locked_doors(si, bay)
		_hall_wall_side(o, yw, side, doors, bay)
		side_data.append({"side": side, "doors": doors, "bay": bay})

	# A grandfather clock that no longer agrees with anything.  It is allowed
	# only on uninterrupted wall, never in an actual room bay or over a door.
	if _r(288) < 0.14:
		var csi := 0 if _r(290) < 0.5 else 1
		var ct := -3.9 + 7.8 * _r(289)
		if _hall_clear_at(ct, side_data[csi]["doors"], side_data[csi]["bay"], 0.62):
			var cside: float = side_data[csi]["side"] - signf(side_data[csi]["side"]) * 0.28
			var ckp := _wp(o, Vector3(ct, 0, cside), yw)
			var cky := yw + (0.0 if cside < 0.0 else PI)
			_cc0_prop("vintage_grandfather_clock_01", ckp, cky)
			_collider_yaw_box(ckp + Vector3(0, 1.1, 0), Vector3(0.66, 2.2, 0.46), cky)

	# Staggered sconces, moved to the nearest clean stretch when a generated bay
	# happens to claim their usual position.
	for si in 2:
		var sd: Dictionary = side_data[si]
		var t := _hall_sconce_t(si, sd["doors"], sd["bay"])
		if t > 90.0:
			continue
		var side: float = sd["side"] - signf(sd["side"]) * 0.14
		var wpp := _wp(o, Vector3(t, 0, side), yw)
		var outn := Vector3(0, 0, -signf(side)).rotated(Vector3.UP, yw)
		_box(wpp + Vector3(0, 1.78, 0), Vector3(0.1, 0.34, 0.1), Mats.brass(), false)
		_cyl(wpp + outn * 0.1 + Vector3(0, 1.86, 0), 0.10, 0.17, Mats.shade(), false)
		_sphere(wpp + outn * 0.1 + Vector3(0, 1.97, 0), 0.035, Mats.bulb())
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.70, 0.43)
		l.light_energy = 0.34
		l.omni_range = 3.8
		l.position = wpp + outn * 0.28 + Vector3(0, 1.95, 0)
		l.shadow_enabled = false
		l.distance_fade_enabled = true
		l.distance_fade_begin = 14.0
		l.distance_fade_length = 6.0
		add_child(l)


## Candidate locked rooms on one side of the hotel corridor.  A real bay owns
## its stretch of wall and suppresses any decorative door that would overlap.
func _hall_locked_doors(si: int, bay: Array) -> Array:
	var doors := []
	for di in 3:
		var t := -3.2 + 3.2 * float(di)
		if _r(270 + si * 4 + di) >= 0.78:
			continue
		if not bay.is_empty() and absf(t - float(bay[0])) < float(bay[1]) * 0.5 + 1.0:
			continue
		doors.append(t)
	return doors


func _hall_clear_at(t: float, doors: Array, bay: Array, clearance: float) -> bool:
	if not bay.is_empty() and absf(t - float(bay[0])) < float(bay[1]) * 0.5 + clearance:
		return false
	for dt in doors:
		if absf(t - float(dt)) < 0.62 + clearance:
			return false
	return true


func _hall_sconce_t(si: int, doors: Array, bay: Array) -> float:
	var candidates := [-1.6, 1.6, -4.55, 4.55]
	if si == 1:
		candidates = [1.6, -1.6, 4.55, -4.55]
	for t in candidates:
		if _hall_clear_at(float(t), doors, bay, 0.48):
			return float(t)
	return 99.0


## One complete side of the corridor shell.  Walls run the full 12m and are
## cut only for a filled locked door or for a return-walled real room bay.
func _hall_wall_side(o: Vector3, yw: float, side: float, doors: Array, bay: Array) -> void:
	var segs := [[-6.0, 6.0]]
	for dt in doors:
		segs = _cut_seg(segs, float(dt) - 0.61, float(dt) + 0.61)
	if not bay.is_empty():
		segs = _cut_seg(segs, float(bay[0]) - float(bay[1]) * 0.5,
			float(bay[0]) + float(bay[1]) * 0.5)
	for sg in segs:
		_hall_wall_run(o, yw, side, float(sg[0]), float(sg[1]))
	for dt in doors:
		_hall_header(o, yw, side, float(dt), 1.22)
		_hall_door(o, yw, float(dt), side,
			275 + (0 if side < 0.0 else 8) + int(round((float(dt) + 3.2) / 3.2)))
	if not bay.is_empty():
		var bt: float = bay[0]
		var bw: float = bay[1]
		_hall_header(o, yw, side, bt, bw)
		_hall_open_casing(o, yw, side, bt, bw)
		_hall_bay_returns(o, yw, side, bt, bw)


func _hall_wall_run(o: Vector3, yw: float, side: float, a: float, b: float) -> void:
	var ln := b - a
	if ln < 0.04:
		return
	var c := (a + b) * 0.5
	var wc := _wp(o, Vector3(c, ceil_h / 2.0, side), yw)
	var wl := _mbox(self, wc, Vector3(ln, ceil_h, 0.16),
		Mats.hall_wallpaper_variant(_finish_variant()))
	wl.rotation.y = yw
	_collider_yaw_box(wc, Vector3(ln, ceil_h, 0.16), yw)
	var inn := side - signf(side) * 0.11
	for spec in [[0.075, 0.15, 0.055, Mats.darkwood()],
		[1.0, 0.08, 0.04, Mats.darkwood()],
		[ceil_h - 0.05, 0.1, 0.05, Mats.crown()]]:
		var tr := _mbox(self, _wp(o, Vector3(c, spec[0], inn), yw),
			Vector3(ln, spec[1], spec[2]), spec[3])
		tr.rotation.y = yw


func _hall_header(o: Vector3, yw: float, side: float, t: float, width: float) -> void:
	var hh := ceil_h - DOOR_TOP
	if hh <= 0.02:
		return
	var hp := _wp(o, Vector3(t, DOOR_TOP + hh * 0.5, side), yw)
	var hmesh := _mbox(self, hp, Vector3(width, hh, 0.16),
		Mats.hall_wallpaper_variant(_finish_variant()))
	hmesh.rotation.y = yw
	_collider_yaw_box(hp, Vector3(width, hh, 0.16), yw)


## The recess connecting the narrow lane to a real canonical edge doorway.
## Its returns also compartmentalize the inaccessible guest-room strip.
func _hall_bay_returns(o: Vector3, yw: float, side: float, t: float, width: float) -> void:
	var outer := signf(side) * (S * 0.5 - T)
	var depth := absf(outer - side)
	var dc := (outer + side) * 0.5
	for edge in [t - width * 0.5, t + width * 0.5]:
		var wp := _wp(o, Vector3(edge, ceil_h * 0.5, dc), yw)
		var ret := _mbox(self, wp, Vector3(0.16, ceil_h, depth),
			Mats.hall_wallpaper_variant(_finish_variant()))
		ret.rotation.y = yw
		_collider_yaw_box(wp, Vector3(0.16, ceil_h, depth), yw)
	# Continue the runner into the doorway recess so it reads as intentional
	# circulation rather than a hole punched into the side of the corridor.
	var carpet := _mbox(self, _wp(o, Vector3(t, 0.014, dc), yw),
		Vector3(width, 0.028, depth), Mats.carpet_red())
	carpet.rotation.y = yw


func _hall_open_casing(o: Vector3, yw: float, side: float, t: float, width: float) -> void:
	var inn := side - signf(side) * 0.11
	for edge in [t - width * 0.5, t + width * 0.5]:
		var jamb := _mbox(self, _wp(o, Vector3(edge, DOOR_TOP * 0.5, inn), yw),
			Vector3(0.11, DOOR_TOP, 0.25), Mats.darkwood())
		jamb.rotation.y = yw
	var head := _mbox(self, _wp(o, Vector3(t, DOOR_TOP + 0.06, inn), yw),
		Vector3(width + 0.16, 0.12, 0.25), Mats.darkwood())
	head.rotation.y = yw


func _hall_door(o: Vector3, yw: float, t: float, side: float, salt: int) -> void:
	var inn := side - signf(side) * 0.11
	var v := Node3D.new()
	v.position = _wp(o, Vector3(t, 0, inn), yw)
	v.rotation.y = yw + (PI if side > 0.0 else 0.0)
	add_child(v)
	# A real slab in a real opening: rounded edges, deep jambs, panel moulding,
	# hinges and hardware.  Its collider seals the reserved room volume behind.
	_mrbox(v, Vector3(0, 1.10, 0.0), Vector3(1.04, 2.2, 0.075), Mats.wood_door(), 0.018)
	for py in [0.58, 1.35]:
		_mrbox(v, Vector3(0, py, 0.043), Vector3(0.72, 0.46, 0.018), Mats.darkwood(), 0.008)
		_mrbox(v, Vector3(0, py, 0.054), Vector3(0.58, 0.33, 0.012), Mats.wood_door(), 0.006)
	_mbox(v, Vector3(-0.575, 1.11, 0.0), Vector3(0.11, 2.24, 0.28), Mats.darkwood())
	_mbox(v, Vector3(0.575, 1.11, 0.0), Vector3(0.11, 2.24, 0.28), Mats.darkwood())
	_mbox(v, Vector3(0, 2.25, 0.0), Vector3(1.26, 0.12, 0.28), Mats.darkwood())
	for hy in [0.45, 1.7]:
		_mbox(v, Vector3(-0.515, hy, 0.055), Vector3(0.035, 0.12, 0.025), Mats.brass())
	_mbox(v, Vector3(0.36, 1.02, 0.058), Vector3(0.12, 0.22, 0.025), Mats.brass())
	_msphere(v, Vector3(0.36, 1.02, 0.095), 0.045, Mats.brass())
	_msphere(v, Vector3(0, 1.66, 0.09), 0.025, Mats.brass())
	_collider_yaw_box(_wp(o, Vector3(t, 1.1, inn), yw), Vector3(1.06, 2.2, 0.11), yw)
	var num := Label3D.new()
	num.text = "%d%02d" % [10 + WorldGen.h(wseed, cell.x + int(t * 3.0), cell.y, salt) % 20,
		WorldGen.h(wseed, cell.x, cell.y + int(t * 5.0), salt + 1) % 100]
	num.font_size = 44
	num.pixel_size = 0.0018
	num.modulate = Color(0.85, 0.7, 0.4)
	num.position = Vector3(0, 1.98, 0.09)
	v.add_child(num)
	if _r(salt + 2) < 0.22:
		_mcyl(v, Vector3(0.72, 0.025, 0.35), 0.16, 0.03, Mats.chrome())
		_msphere(v, Vector3(0.72, 0.075, 0.35), 0.09, Mats.chrome())


# --- vegas: lounge -----------------------------------------------------------

func _lounge() -> void:
	# a pair of real Victorian sofas facing off over a real coffee table
	_cc0_prop("sofa_03", Vector3(6, 0, 4.6), 0.0)
	_collider_box(Vector3(6, 0.55, 4.6), Vector3(2.75, 1.1, 0.95))
	_cc0_prop("sofa_03", Vector3(6, 0, 7.4), PI)
	_collider_box(Vector3(6, 0.55, 7.4), Vector3(2.75, 1.1, 0.95))
	_cc0_prop("CoffeeTable_01", Vector3(6, 0, 6), 0.0)
	_collider_box(Vector3(6, 0.27, 6), Vector3(1.55, 0.54, 1.0))
	if _r(26) < 0.55:
		var ay := -PI * 0.75 + (_r(27) - 0.5) * 0.4
		_cc0_prop("ArmChair_01", Vector3(8.9, 0, 8.7), ay)
		_collider_yaw_box(Vector3(8.9, 0.55, 8.7), Vector3(0.9, 1.1, 0.8), ay)
		if _r(28) < 0.5:
			_cc0_prop("Ottoman_01", Vector3(8.1, 0, 7.8), ay + (_r(29) - 0.5) * 0.8)
			_collider_box(Vector3(8.1, 0.3, 7.8), Vector3(0.9, 0.62, 0.65))
	var lp := Vector3(3.4, 0, 6.0)
	_cyl(lp + Vector3(0, 0.8, 0), 0.035, 1.6, Mats.brass(), false)
	_cyl(lp + Vector3(0, 1.68, 0), 0.21, 0.28, Mats.shade(), false)
	_sphere(lp + Vector3(0, 1.55, 0), 0.07, Mats.bulb())
	_collider_cyl(lp + Vector3(0, 0.9, 0), 0.24, 1.8)
	if _r(25) < 0.5:
		_planter(Vector3(9.2, 0, 9.2))
	# muffled PA muzak drifting from the lounge ceiling
	var mz := AudioStreamPlayer3D.new()
	mz.stream = SoundBank.muzak()
	mz.unit_size = 4.0
	mz.max_distance = 24.0
	mz.volume_db = -14.0
	mz.bus = "Hall"
	mz.position = Vector3(S / 2.0, ceil_h - 0.3, S / 2.0)
	add_child(mz)
	mz.ready.connect(func(): mz.play(randf() * 11.0))


func _sofa(center: Vector3, face: float) -> void:
	_rbox(center + Vector3(0, 0.33, 0), Vector3(2.2, 0.42, 0.95), Mats.velvet(), 0.06, false)
	_rbox(center + Vector3(0, 0.78, -face * 0.36), Vector3(2.2, 0.7, 0.24), Mats.velvet(), 0.07, false)
	_rbox(center + Vector3(-0.98, 0.62, 0), Vector3(0.24, 0.55, 0.95), Mats.velvet(), 0.07, false)
	_rbox(center + Vector3(0.98, 0.62, 0), Vector3(0.24, 0.55, 0.95), Mats.velvet(), 0.07, false)
	_rbox(center + Vector3(-0.44, 0.6, face * 0.06), Vector3(0.84, 0.14, 0.78), Mats.velvet2(), 0.055, false)
	_rbox(center + Vector3(0.44, 0.6, face * 0.06), Vector3(0.84, 0.14, 0.78), Mats.velvet2(), 0.055, false)
	for px in [-0.44, 0.44]:
		var pil := _rbox(center + Vector3(px, 0.93, -face * 0.28), Vector3(0.8, 0.44, 0.16), Mats.velvet2(), 0.06, false)
		pil.rotation.x = face * (0.12 + (WorldGen.r01(wseed, cell.x, cell.y, 57 + int(px * 10.0)) - 0.5) * 0.08)
	_collider_box(center + Vector3(0, 0.6, 0), Vector3(2.2, 1.2, 1.0))


func _planter(p: Vector3) -> void:
	# real potted plants; the office gets the sadder, squatter one
	var mname := "potted_plant_02" if theme == 1 else "potted_plant_01"
	_cc0_prop(mname, p, _r(23) * TAU)
	_collider_cyl(p + Vector3(0, 0.5, 0), 0.32, 1.0)


## A room-service cart abandoned after the glasses were poured. Its low,
## asymmetric silhouette gives otherwise empty casino rooms a lived-in past.
func _casino_service_cart(p: Vector3, salt: int) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = _r(salt) * TAU
	add_child(v)
	_mrbox(v, Vector3(0, 0.76, 0), Vector3(1.05, 0.07, 0.56), Mats.darkwood(), 0.025)
	_mrbox(v, Vector3(0, 0.28, 0), Vector3(0.92, 0.045, 0.46), Mats.darkwood(), 0.018)
	for sx in [-0.44, 0.44]:
		for sz in [-0.20, 0.20]:
			_mcyl(v, Vector3(sx, 0.40, sz), 0.018, 0.72, Mats.brass())
			_mcyl(v, Vector3(sx, 0.055, sz), 0.055, 0.05, Mats.charcoal())
	# Two glasses, one bottle, and a plate left slightly off square.
	for gx in [-0.22, 0.10]:
		_mcyl(v, Vector3(gx, 0.84, -0.06), 0.045, 0.13, Mats.glass_tint())
		_mcyl(v, Vector3(gx, 0.92, -0.06), 0.065, 0.018, Mats.glass_tint())
	_mcyl(v, Vector3(0.32, 0.91, 0.08), 0.045, 0.28, Mats.glass_tint())
	_mcyl(v, Vector3(-0.08, 0.805, 0.12), 0.18, 0.025, Mats.crown())
	_collider_yaw_box(p + Vector3(0, 0.42, 0), Vector3(1.08, 0.84, 0.6), v.rotation.y)


## Archive boxes and loose forms occupy a corner of some otherwise empty
## offices. The pile is broad enough to read, low enough not to become a wall.
func _office_floor_files(p: Vector3, salt: int) -> void:
	for i in 3:
		var v := Node3D.new()
		var ox := -0.30 if i != 1 else 0.30
		v.position = p + Vector3(ox, 0, -0.14)
		v.rotation.y = (_r(salt + i) - 0.5) * 0.34
		add_child(v)
		var y := 0.70 if i == 2 else 0.24
		_mrbox(v, Vector3(0, y, 0), Vector3(0.58, 0.46, 0.48), Mats.box_white(), 0.015)
		_mbox(v, Vector3(0, y + 0.235, 0), Vector3(0.5, 0.018, 0.4), Mats.paint_white())
	_asy_papers(p + Vector3(0.6, 0, 0.35), salt + 8, 6)
	_collider_box(p + Vector3(0, 0.42, 0), Vector3(1.25, 0.84, 1.0))


# --- office props ------------------------------------------------------------

const OFFICE_CORRIDOR_LABELS := ["ACCOUNTS", "ARCHIVES", "CONFERENCE B",
	"FACILITIES", "HUMAN RESOURCES", "PROCESSING", "RECORDS", "SUPPLY"]


## A continuous corporate corridor with real plan depth.  Locked doors seal
## inaccessible office/service volumes behind the side walls; genuine graph
## connections open into return-walled vestibules that reach the canonical
## cell-edge doorway.  Nothing ends short of a boundary or shifts between
## adjacent corridor cells, so the player can never walk around a facade.
func _office_corridor() -> void:
	var cdir := WorldGen.corridor(wseed, cell)
	var along_x := cdir != 2
	var yw := 0.0 if along_x else PI / 2.0
	var o := Vector3(S / 2.0, 0, S / 2.0)
	var lane_half := 1.85
	# A quieter carpet-tile lane makes the circulation spine readable and masks
	# the floor seam where vestibules branch toward actual rooms.
	var lane := _mbox(self, _wp(o, Vector3(0, 0.012, 0), yw),
		Vector3(S, 0.024, lane_half * 2.0 - 0.18), Mats.office_lane_carpet())
	lane.rotation.y = yw

	var side_data := []
	for si in 2:
		var side := -lane_half if si == 0 else lane_half
		var sdir := (3 if si == 0 else 2) if along_x else (1 if si == 0 else 0)
		var info := WorldGen.edge_info(wseed, cell, sdir, theme)
		var bay := []
		if not info["wall"]:
			# Edge t runs in world +x/+z. Local corridor x points toward -z after
			# the quarter-turn used by a z-axis corridor.
			var bt: float = float(info["t"]) - 6.0 if along_x else 6.0 - float(info["t"])
			var bw := clampf(float(info["w"]) + 0.38, 1.95, 3.15)
			bay = [bt, bw]
		var doors := _office_corridor_doors(si, bay)
		_office_corridor_wall_side(o, yw, side, doors, bay)
		side_data.append({"side": side, "doors": doors, "bay": bay})

	if _r(254) < 0.5:
		_office_dept_sign(along_x)
	# A wall directory or clock gives the lane a destination and is placed only
	# on structure that is not claimed by a locked door or a real vestibule.
	if _r(260) < 0.62:
		var dsi := 0 if _r(261) < 0.5 else 1
		var dt := _office_corridor_clear_t(dsi, side_data[dsi]["doors"],
			side_data[dsi]["bay"])
		if dt < 90.0:
			_office_corridor_directory(o, yw, float(side_data[dsi]["side"]), dt)
	# a wet floor sign guarding nothing, halfway down the lane
	if _r(256) < 0.16:
		var t2 := 2.5 + 7.0 * _r(258)
		var sp2 := _wp(o, Vector3(t2 - 6.0, 0, (_r(257) - 0.5) * 0.7), yw)
		_cc0_prop("WetFloorSign_01", sp2, _r(259) * TAU)
		_collider_box(sp2 + Vector3(0, 0.3, 0), Vector3(0.35, 0.6, 0.35))


## Locked private offices on one side of a corridor. A real vestibule owns
## its whole wall interval and suppresses any facade that would overlap it.
func _office_corridor_doors(si: int, bay: Array) -> Array:
	var doors := []
	for di in 3:
		var t := -3.55 + 3.55 * float(di)
		if _r(270 + si * 5 + di) >= 0.68:
			continue
		if not bay.is_empty() and absf(t - float(bay[0])) < float(bay[1]) * 0.5 + 0.92:
			continue
		doors.append(t)
	# Long stretches with no real connection still need at least one piece of
	# evidence that the inaccessible strip is occupied office volume.
	if doors.is_empty() and bay.is_empty():
		doors.append([-3.55, 0.0, 3.55][int(_r(279 + si) * 2.99)])
	return doors


func _office_corridor_clear(t: float, doors: Array, bay: Array, clearance: float) -> bool:
	if not bay.is_empty() and absf(t - float(bay[0])) < float(bay[1]) * 0.5 + clearance:
		return false
	for dt in doors:
		if absf(t - float(dt)) < 0.66 + clearance:
			return false
	return true


func _office_corridor_clear_t(si: int, doors: Array, bay: Array) -> float:
	var candidates := [-1.75, 1.75, -4.65, 4.65]
	if si == 1:
		candidates = [1.75, -1.75, 4.65, -4.65]
	for t in candidates:
		if _office_corridor_clear(float(t), doors, bay, 0.62):
			return float(t)
	return 99.0


## One complete side wall, cut only by a sealed door or by a real vestibule.
func _office_corridor_wall_side(o: Vector3, yw: float, side: float,
		doors: Array, bay: Array) -> void:
	var segs := [[-6.0, 6.0]]
	for dt in doors:
		segs = _cut_seg(segs, float(dt) - 0.63, float(dt) + 0.63)
	if not bay.is_empty():
		segs = _cut_seg(segs, float(bay[0]) - float(bay[1]) * 0.5,
			float(bay[0]) + float(bay[1]) * 0.5)
	for sg in segs:
		_office_corridor_wall_run(o, yw, side, float(sg[0]), float(sg[1]))
	for di in doors.size():
		var dt := float(doors[di])
		_office_corridor_header(o, yw, side, dt, 1.26)
		_office_corridor_door(o, yw, dt, side,
			285 + (0 if side < 0.0 else 12) + di)
	if not bay.is_empty():
		var bt: float = bay[0]
		var bw: float = bay[1]
		_office_corridor_header(o, yw, side, bt, bw)
		_office_corridor_open_casing(o, yw, side, bt, bw)
		_office_corridor_bay_returns(o, yw, side, bt, bw)


func _office_corridor_wall_run(o: Vector3, yw: float, side: float,
		a: float, b: float) -> void:
	var ln := b - a
	if ln < 0.04:
		return
	var c := (a + b) * 0.5
	var wc := _wp(o, Vector3(c, ceil_h * 0.5, side), yw)
	var wall := _mbox(self, wc, Vector3(ln, ceil_h, 0.15),
		Mats.office_wall_variant(_finish_variant()))
	wall.rotation.y = yw
	_collider_yaw_box(wc, Vector3(ln, ceil_h, 0.15), yw)
	var inn := side - signf(side) * 0.105
	var base := _mbox(self, _wp(o, Vector3(c, 0.055, inn), yw),
		Vector3(ln, 0.11, 0.045), Mats.base_green())
	base.rotation.y = yw


func _office_corridor_header(o: Vector3, yw: float, side: float,
		t: float, width: float) -> void:
	var hh := ceil_h - DOOR_TOP
	if hh <= 0.02:
		return
	var hp := _wp(o, Vector3(t, DOOR_TOP + hh * 0.5, side), yw)
	var head := _mbox(self, hp, Vector3(width, hh, 0.15),
		Mats.office_wall_variant(_finish_variant()))
	head.rotation.y = yw
	_collider_yaw_box(hp, Vector3(width, hh, 0.15), yw)


## Return walls connect the corridor shell to the actual cell-edge doorway and
## close the inaccessible strips on both sides of the vestibule.
func _office_corridor_bay_returns(o: Vector3, yw: float, side: float,
		t: float, width: float) -> void:
	var outer := signf(side) * (S * 0.5 - T)
	var depth := absf(outer - side)
	var dc := (outer + side) * 0.5
	for edge in [t - width * 0.5, t + width * 0.5]:
		var wp := _wp(o, Vector3(edge, ceil_h * 0.5, dc), yw)
		var ret := _mbox(self, wp, Vector3(0.15, ceil_h, depth),
			Mats.office_wall_variant(_finish_variant()))
		ret.rotation.y = yw
		_collider_yaw_box(wp, Vector3(0.15, ceil_h, depth), yw)
		# Baseboard on the vestibule face of each return.
		var inward := 0.105 if edge < t else -0.105
		var bp := _wp(o, Vector3(edge + inward, 0.055, dc), yw)
		var base := _mbox(self, bp, Vector3(0.045, 0.11, depth), Mats.base_green())
		base.rotation.y = yw
	var carpet := _mbox(self, _wp(o, Vector3(t, 0.013, dc), yw),
		Vector3(width, 0.026, depth), Mats.office_lane_carpet())
	carpet.rotation.y = yw


func _office_corridor_open_casing(o: Vector3, yw: float, side: float,
		t: float, width: float) -> void:
	var inn := side - signf(side) * 0.105
	for edge in [t - width * 0.5, t + width * 0.5]:
		var jamb := _mbox(self, _wp(o, Vector3(edge, DOOR_TOP * 0.5, inn), yw),
			Vector3(0.11, DOOR_TOP, 0.24), Mats.paint_white())
		jamb.rotation.y = yw
	var head := _mbox(self, _wp(o, Vector3(t, DOOR_TOP + 0.06, inn), yw),
		Vector3(width + 0.16, 0.12, 0.24), Mats.paint_white())
	head.rotation.y = yw


## A sealed office door installed in a real wall opening. The collider and
## opaque privacy glass make the facade honest even though the room is not
## generated; deep jambs make the wall thickness visible at grazing angles.
func _office_corridor_door(o: Vector3, yw: float, t: float,
		side: float, salt: int) -> void:
	var inn := side - signf(side) * 0.105
	var v := Node3D.new()
	v.position = _wp(o, Vector3(t, 0, inn), yw)
	v.rotation.y = yw + (PI if side > 0.0 else 0.0)
	add_child(v)
	var service := _r(salt) < 0.24
	var door_mat: Material = Mats.metal_gray() if service else Mats.wood_door()
	_mrbox(v, Vector3(0, 1.09, 0), Vector3(1.04, 2.18, 0.07), door_mat, 0.012)
	_mbox(v, Vector3(-0.575, 1.11, 0), Vector3(0.11, 2.23, 0.25), Mats.paint_white())
	_mbox(v, Vector3(0.575, 1.11, 0), Vector3(0.11, 2.23, 0.25), Mats.paint_white())
	_mbox(v, Vector3(0, 2.25, 0), Vector3(1.26, 0.12, 0.25), Mats.paint_white())
	if not service and _r(salt + 1) < 0.62:
		# Milky vision panel with a slim aluminium bead.
		_mrbox(v, Vector3(0, 1.58, 0.041), Vector3(0.43, 0.5, 0.014),
			Mats.office_privacy_glass(), 0.01)
		for sx in [-0.235, 0.235]:
			_mbox(v, Vector3(sx, 1.58, 0.052), Vector3(0.025, 0.55, 0.018), Mats.chrome())
		for sy in [1.295, 1.865]:
			_mbox(v, Vector3(0, sy, 0.052), Vector3(0.495, 0.025, 0.018), Mats.chrome())
	# Lever, latch plate, and a dead access-control reader.
	_mrbox(v, Vector3(0.36, 1.02, 0.06), Vector3(0.13, 0.2, 0.025), Mats.chrome(), 0.008)
	_msphere(v, Vector3(0.36, 1.02, 0.092), 0.035, Mats.chrome())
	_mrbox(v, Vector3(0.24, 1.02, 0.1), Vector3(0.25, 0.035, 0.035), Mats.chrome(), 0.012)
	_mrbox(v, Vector3(0.72, 1.28, 0.07), Vector3(0.12, 0.2, 0.035), Mats.charcoal(), 0.008)
	_mbox(v, Vector3(0.72, 1.34, 0.091), Vector3(0.055, 0.025, 0.008), Mats.lamp_red())
	_collider_yaw_box(_wp(o, Vector3(t, 1.09, inn), yw),
		Vector3(1.06, 2.18, 0.11), yw)
	var plate := _mrbox(v, Vector3(-0.78, 1.58, 0.075),
		Vector3(0.34, 0.24, 0.025), Mats.paint_white(), 0.006)
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lb := Label3D.new()
	lb.text = "ELECTRICAL" if service else OFFICE_CORRIDOR_LABELS[
		WorldGen.h(wseed, cell.x + int(t * 5.0), cell.y, salt + 2) % OFFICE_CORRIDOR_LABELS.size()]
	lb.font_size = 34
	lb.pixel_size = 0.00125
	lb.width = 245.0
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb.modulate = Color(0.06, 0.18, 0.12)
	lb.position = Vector3(-0.78, 1.58, 0.09)
	v.add_child(lb)


func _office_corridor_directory(o: Vector3, yw: float, side: float, t: float) -> void:
	var inn := side - signf(side) * 0.095
	var v := Node3D.new()
	v.position = _wp(o, Vector3(t, 1.55, inn), yw)
	v.rotation.y = yw + (PI if side > 0.0 else 0.0)
	add_child(v)
	_mrbox(v, Vector3(0, 0, 0), Vector3(0.76, 0.88, 0.045), Mats.charcoal(), 0.008)
	_mquad(v, Vector3(0, 0, 0.026), Vector2(0.69, 0.81), Mats.paint_white())
	var title := Label3D.new()
	title.text = "DIRECTORY"
	title.font_size = 50
	title.pixel_size = 0.0016
	title.modulate = Color(0.055, 0.19, 0.12)
	title.position = Vector3(0, 0.25, 0.035)
	v.add_child(title)
	var body_label := Label3D.new()
	body_label.text = "PROCESSING  4E\nARCHIVES      4F\nWELLNESS      4G\nSTAIRS        <--"
	body_label.font_size = 30
	body_label.pixel_size = 0.00145
	body_label.modulate = Color(0.12, 0.2, 0.16)
	body_label.position = Vector3(0, -0.09, 0.035)
	v.add_child(body_label)


## MDR-style desk cluster: cross divider, four desks facing outward, each
## with a CRT terminal, keyboard and chair. The room's reason to exist.
func _office_cubicles() -> void:
	var c := Vector3(S / 2.0, 0, S / 2.0)
	var span := _room_span()
	var centres := [c]
	if span.x > 12.1 and span.y > 12.1:
		centres = [c + Vector3(-5.4, 0, -5.4), c + Vector3(5.4, 0, -5.4),
			c + Vector3(-5.4, 0, 5.4), c + Vector3(5.4, 0, 5.4)]
	elif span.x > 12.1:
		centres = [c + Vector3(-5.6, 0, 0), c + Vector3(5.6, 0, 0)]
	elif span.y > 12.1:
		centres = [c + Vector3(0, 0, -5.6), c + Vector3(0, 0, 5.6)]
	for ci in centres.size():
		_office_cubicle_cluster(centres[ci], ci * 12)
	var snd := OfficeSounds.new()
	snd.position = c + Vector3(0, 1.2, 0)
	add_child(snd)


## One four-person work island. Large merged rooms arrange several of these
## from their true span rather than leaving three quarters of the floor empty.
func _office_cubicle_cluster(c: Vector3, qi_base: int) -> void:
	# cross divider
	_box(c + Vector3(0, 0.675, 0), Vector3(3.6, 1.35, 0.08), Mats.divider_gray())
	_box(c + Vector3(0, 0.675, 0), Vector3(0.08, 1.35, 3.6), Mats.divider_gray())
	# white cap rails
	_box(c + Vector3(0, 1.36, 0), Vector3(3.7, 0.04, 0.12), Mats.paint_white(), false)
	_box(c + Vector3(0, 1.36, 0), Vector3(0.12, 0.04, 3.7), Mats.paint_white(), false)
	var qi := 0
	for q in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]:
		_office_desk(c + Vector3(q.x * 1.5, 0, 0), Vector2(0, q.y), qi_base + qi)
		qi += 1
	# waste bin
	var bin_side := -1.0 if int(qi_base / 12) % 2 == 1 else 1.0
	_cyl(c + Vector3(1.7 * bin_side, 0.18, 1.7), 0.14, 0.36, Mats.charcoal())


func _office_desk(c: Vector3, d: Vector2, qi := 0) -> void:
	var dv := Vector3(d.x, 0, d.y)
	var deskc := c + dv * 1.05
	var top_size := Vector3(0.8, 0.035, 1.5) if d.x != 0.0 else Vector3(1.5, 0.035, 0.8)
	_rbox(deskc + Vector3(0, 0.73, 0), top_size, Mats.desk_white(), 0.012, false)
	# side panel legs
	var leg_off := Vector3(0, 0, 0.68) if d.x != 0.0 else Vector3(0.68, 0, 0)
	var leg_size := Vector3(0.74, 0.71, 0.04) if d.x != 0.0 else Vector3(0.04, 0.71, 0.74)
	_rbox(deskc + leg_off + Vector3(0, 0.355, 0), leg_size, Mats.desk_white(), 0.008, false)
	_rbox(deskc - leg_off + Vector3(0, 0.355, 0), leg_size, Mats.desk_white(), 0.008, false)
	_collider_box(deskc + Vector3(0, 0.4, 0), top_size * Vector3(1.0, 1.0, 1.0) + Vector3(0, 0.77, 0))
	# VT100-style terminal at the inner edge, screen facing the worker (outward)
	var yaw := atan2(dv.x, dv.z)
	_vt100(c + dv * 0.82, yaw + (_r(58 + qi) - 0.5) * 0.14)
	# the odd clipboard abandoned beside the terminal
	if _r(59 + qi) < 0.3:
		var side3 := Vector3(cos(yaw), 0, -sin(yaw)) * (0.4 + 0.1 * _r(61 + qi))
		_cc0_prop("clipboard", deskc + side3 + Vector3(0, 0.75, 0), _r(62 + qi) * TAU)
	_vt100_keyboard(c + dv * 1.25, yaw + (_r(62 + qi) - 0.5) * 0.25)
	# chair facing the desk, never perfectly parked
	_chair_at(c + dv * 1.95 + Vector3((_r(97 + qi) - 0.5) * 0.2, 0, 0), yaw + (_r(87 + qi) - 0.5) * 0.5, Mats.fabric_charcoal())


## Bank of steel filing cabinets, one drawer always left open.
func _filing_bank(dir: int, plane: float) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T * 0.5)
	var along := S / 2.0 + (_r(59 + dir) - 0.5) * 4.0
	var count := 3 + int(_r(60 + dir) * 1.99)
	var open_i := int(_r(61 + dir) * float(count) * 0.99)
	var open_j := int(_r(62 + dir) * 3.99)
	for i in count:
		var t := along + (float(i) - float(count - 1) / 2.0) * 0.5
		var v := Node3D.new()
		if dir < 2:
			v.position = Vector3(inner + n * 0.31, 0, t)
			v.rotation.y = PI / 2.0 if n > 0.0 else -PI / 2.0
		else:
			v.position = Vector3(t, 0, inner + n * 0.31)
			v.rotation.y = 0.0 if n > 0.0 else PI
		add_child(v)
		_mrbox(v, Vector3(0, 0.66, 0), Vector3(0.46, 1.32, 0.6), Mats.metal_gray(), 0.015)
		for j in 4:
			var dy := 0.18 + 0.31 * float(j)
			_mbox(v, Vector3(0, dy + 0.14, 0.302), Vector3(0.4, 0.27, 0.012), Mats.divider_gray())
			_mbox(v, Vector3(0, dy + 0.245, 0.315), Vector3(0.13, 0.022, 0.014), Mats.chrome())
			if i == open_i and j == open_j:
				_mbox(v, Vector3(0, dy + 0.13, 0.46), Vector3(0.4, 0.24, 0.32), Mats.metal_gray())
				_mbox(v, Vector3(0, dy + 0.23, 0.46), Vector3(0.34, 0.02, 0.26), Mats.box_white())
	var cc: Vector3
	var csize: Vector3
	if dir < 2:
		cc = Vector3(inner + n * 0.31, 0.66, along)
		csize = Vector3(0.65, 1.32, 0.5 * float(count) + 0.1)
	else:
		cc = Vector3(along, 0.66, inner + n * 0.31)
		csize = Vector3(0.5 * float(count) + 0.1, 1.32, 0.65)
	_collider_box(cc, csize)


const OFFICE_POSTERS := ["SAFETY IS EVERYONE'S JOB", "HAVE YOU FILED YOUR 4-19?",
	"THE BUILDING THANKS YOU", "PLEASE CONSERVE LIGHT", "TIDY DESK, TIDY MIND"]


## Framed motivational poster; the motivation has long since left.
func _office_poster(dir: int, plane: float) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T / 2.0)
	var along := S / 2.0 + (_r(63 + dir) - 0.5) * 5.0
	var v := Node3D.new()
	if dir < 2:
		v.position = Vector3(inner + n * 0.03, 1.7, along)
		v.rotation.y = PI / 2.0 if n > 0.0 else -PI / 2.0
	else:
		v.position = Vector3(along, 1.7, inner + n * 0.03)
		v.rotation.y = 0.0 if n > 0.0 else PI
	v.rotation.z = (_r(64 + dir) - 0.5) * 0.04
	add_child(v)
	_mbox(v, Vector3(0, 0, -0.008), Vector3(0.68, 0.94, 0.016), Mats.charcoal())
	_mquad(v, Vector3(0, 0, 0.004), Vector2(0.62, 0.88), Mats.paint_white())
	var hd := Label3D.new()
	hd.text = OFFICE_POSTERS[int(_r(65 + dir) * (float(OFFICE_POSTERS.size()) - 0.01))]
	hd.font_size = 30
	hd.pixel_size = 0.0016
	hd.width = 380.0
	hd.autowrap_mode = TextServer.AUTOWRAP_WORD
	hd.modulate = Color(0.1, 0.25, 0.16)
	hd.position = Vector3(0, 0.22, 0.01)
	v.add_child(hd)
	var bd := Label3D.new()
	bd.text = "a reminder from Facilities"
	bd.font_size = 16
	bd.pixel_size = 0.0014
	bd.modulate = Color(0.45, 0.48, 0.45)
	bd.position = Vector3(0, -0.3, 0.01)
	v.add_child(bd)


const OFFICE_ZONE_DEPTS := [
	["PROCESSING", "ACCOUNTS", "DATA SERVICES"],
	["ARCHIVES", "RECORDS", "DOCUMENT CONTROL"],
	["WELLNESS", "BREAK ROOMS", "HUMAN RESOURCES"],
]


## White acrylic department sign hung over the corridor.
func _office_dept_sign(along_x: bool) -> void:
	var v := Node3D.new()
	v.position = Vector3(S / 2.0, 2.55, S / 2.0)
	v.rotation.y = PI / 2.0 if along_x else 0.0
	add_child(v)
	var rod_h := ceil_h - 2.55 - 0.19
	for sx in [-0.55, 0.55]:
		_mcyl(v, Vector3(sx, 0.19 + rod_h / 2.0, 0), 0.012, rod_h, Mats.metal_gray())
	_mrbox(v, Vector3.ZERO, Vector3(1.6, 0.38, 0.05), Mats.paint_white(), 0.01)
	var zone := WorldGen.macro_zone(wseed, cell, theme)
	var labels: Array = OFFICE_ZONE_DEPTS[zone]
	for sside in [-1.0, 1.0]:
		var lb := Label3D.new()
		lb.text = labels[int(_r(255) * (float(labels.size()) - 0.01))]
		lb.font_size = 60
		lb.pixel_size = 0.0022
		lb.modulate = Color(0.08, 0.22, 0.14)
		lb.position = Vector3(0, 0, sside * 0.035)
		lb.rotation.y = 0.0 if sside > 0.0 else PI
		v.add_child(lb)


## Beige copier idling in a corner, one green LED refusing to die.
func _copier(p: Vector3, salt: int) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = (_r(salt) - 0.5) * 0.3
	add_child(v)
	_mrbox(v, Vector3(0, 0.5, 0), Vector3(1.05, 1.0, 0.62), Mats.crt_shell(), 0.03)
	var lid := _mrbox(v, Vector3(0, 1.03, -0.05), Vector3(0.95, 0.05, 0.5), Mats.crt_shell(), 0.015)
	lid.rotation.x = -0.18
	_mbox(v, Vector3(0.28, 0.96, 0.26), Vector3(0.4, 0.05, 0.1), Mats.crt_dark())
	_mbox(v, Vector3(0.42, 0.985, 0.26), Vector3(0.05, 0.012, 0.03), Mats.lamp_green())
	_mbox(v, Vector3(-0.62, 0.62, 0), Vector3(0.24, 0.03, 0.4), Mats.crt_shell())
	_mbox(v, Vector3(-0.6, 0.645, 0), Vector3(0.18, 0.015, 0.3), Mats.box_white())
	_collider_yaw_box(p + Vector3(0, 0.55, 0), Vector3(1.15, 1.1, 0.7), v.rotation.y)


## DEC VT100 lookalike, built in local space facing +Z under one pivot so the
## random desk-jitter yaw can never shear the screen out of its housing.
func _vt100(pos: Vector3, yaw: float) -> void:
	var p := Node3D.new()
	p.position = Vector3(pos.x, 0, pos.z)
	p.rotation.y = yaw
	add_child(p)
	var shell := Mats.crt_shell()
	var dark := Mats.crt_dark()
	# inset plinth, then the big beige housing (front face at z=0.10)
	_mrbox(p, Vector3(0, 0.7725, -0.05), Vector3(0.36, 0.05, 0.30), shell, 0.012)
	_mrbox(p, Vector3(0, 0.95, -0.08), Vector3(0.44, 0.30, 0.36), shell, 0.03)
	# broad bezel frame overlapping the housing front, opening 0.30 x 0.225
	_mrbox(p, Vector3(0, 1.0825, 0.125), Vector3(0.44, 0.035, 0.06), shell, 0.008)
	_mrbox(p, Vector3(0, 0.82, 0.125), Vector3(0.44, 0.04, 0.06), shell, 0.008)
	_mrbox(p, Vector3(-0.185, 0.9525, 0.125), Vector3(0.07, 0.225, 0.06), shell, 0.008)
	_mrbox(p, Vector3(0.185, 0.9525, 0.125), Vector3(0.07, 0.225, 0.06), shell, 0.008)
	# dark cavity behind the opening; the phosphor glass sits recessed in it
	_mrbox(p, Vector3(0, 0.9525, 0.095), Vector3(0.34, 0.26, 0.05), dark, 0.012)
	_mquad(p, Vector3(0, 0.9525, 0.121), Vector2(0.26, 0.195), Mats.crt())
	# dark trim strip across the top front, and a little model badge
	_mrbox(p, Vector3(0, 1.103, 0.03), Vector3(0.36, 0.012, 0.12), dark, 0.004)
	_mrbox(p, Vector3(0.13, 0.826, 0.155), Vector3(0.055, 0.016, 0.008), dark, 0.003)


## Matching wedge keyboard: beige base, dark key deck, rows of black caps.
func _vt100_keyboard(pos: Vector3, yaw: float) -> void:
	var p := Node3D.new()
	p.position = Vector3(pos.x, 0, pos.z)
	p.rotation.y = yaw
	add_child(p)
	_mrbox(p, Vector3(0, 0.766, 0), Vector3(0.42, 0.035, 0.17), Mats.crt_shell(), 0.01)
	_mrbox(p, Vector3(0, 0.7855, -0.01), Vector3(0.38, 0.014, 0.125), Mats.crt_dark(), 0.004)
	for row in 4:
		var rz := -0.058 + 0.026 * row
		var rx := row * 0.004 - 0.006
		for col in 12:
			_mbox(p, Vector3(rx - 0.154 + 0.028 * col, 0.799, rz), Vector3(0.024, 0.014, 0.02), Mats.charcoal())
	_mbox(p, Vector3(0, 0.799, 0.044), Vector3(0.13, 0.012, 0.018), Mats.charcoal())


func _office_storage() -> void:
	_shelf_unit(Vector3(3.5, 0, 6.0), false, 30)
	if _r(33) < 0.55:
		# a real steel rack (model ships 10x life size — scaled to 2.1m)
		_cc0_prop("steel_frame_shelves_01", Vector3(8.5, 0, 6.0), PI / 2.0, 0.1)
		_collider_box(Vector3(8.5, 1.1, 6.0), Vector3(0.6, 2.2, 1.15))
	else:
		_shelf_unit(Vector3(8.5, 0, 6.0), false, 34)
	if _r(36) < 0.45:
		var dy := (_r(37) - 0.5) * 0.2
		_cc0_prop("drawer_cabinet", Vector3(2.2, 0, 1.1), dy)
		_collider_yaw_box(Vector3(2.2, 0.95, 1.1), Vector3(1.2, 1.9, 0.55), dy)
	if _r(38) < 0.4:
		_shelf_unit(Vector3(6.0, 0, 2.0), true, 39)


func _shelf_unit(c: Vector3, along_x: bool, salt: int) -> void:
	var half := Vector3(1.2, 0, 0.3) if along_x else Vector3(0.3, 0, 1.2)
	for px in [-1.0, 1.0]:
		for pz in [-1.0, 1.0]:
			var corner := c + Vector3(half.x * px, 0, half.z * pz)
			_box(corner + Vector3(0, 1.1, 0), Vector3(0.05, 2.2, 0.05), Mats.metal_gray(), false)
	var shelf_size := Vector3(2.4, 0.04, 0.6) if along_x else Vector3(0.6, 0.04, 2.4)
	for sy in [0.5, 1.1, 1.7]:
		_box(c + Vector3(0, sy, 0), shelf_size, Mats.metal_gray(), false)
		for bi in 4:
			if WorldGen.r01(wseed, cell.x + bi, cell.y + int(sy * 10.0), salt) < 0.72:
				var t := -0.9 + 0.6 * bi
				var bpos := c + (Vector3(t, sy + 0.2, 0) if along_x else Vector3(0, sy + 0.2, t))
				var bx := _rbox(bpos, Vector3(0.5, 0.34, 0.45), Mats.box_white(), 0.01, false)
				bx.rotation.y = (WorldGen.r01(wseed, cell.x + bi, cell.y + int(sy * 7.0), salt + 1) - 0.5) * 0.14
	_collider_box(c + Vector3(0, 1.1, 0), Vector3(2.5, 2.2, 0.65) if along_x else Vector3(0.65, 2.2, 2.5))


func _office_break() -> void:
	var c := Vector3(S / 2.0, 0, S / 2.0)
	# round table with four chairs
	_cyl(c + Vector3(0, 0.72, 0), 0.55, 0.05, Mats.desk_white(), false)
	_cyl(c + Vector3(0, 0.36, 0), 0.06, 0.72, Mats.metal_gray(), false)
	_cyl(c + Vector3(0, 0.02, 0), 0.3, 0.04, Mats.metal_gray(), false)
	_collider_cyl(c + Vector3(0, 0.4, 0), 0.6, 0.8)
	for i in 4:
		var ang := TAU * float(i) / 4.0 + 0.4
		var cp := c + Vector3(cos(ang) * 1.15, 0, sin(ang) * 1.15)
		_chair_at(cp, ang + PI / 2.0 + (_r(98 + i) - 0.5) * 0.7, Mats.fabric_charcoal())
	# counter along the south wall with a coffee maker
	_rbox(Vector3(4.5, 0.45, 0.75), Vector3(3.0, 0.9, 0.6), Mats.desk_white(), 0.015)
	_rbox(Vector3(3.6, 1.08, 0.75), Vector3(0.3, 0.36, 0.3), Mats.charcoal(), 0.02, false)
	_box(Vector3(3.6, 1.02, 0.92), Vector3(0.05, 0.02, 0.04), Mats.lamp_red(), false)
	# water cooler in the corner
	var wc := Vector3(10.5, 0, 1.0)
	_rbox(wc + Vector3(0, 0.5, 0), Vector3(0.35, 1.0, 0.35), Mats.paint_white(), 0.02)
	_cyl(wc + Vector3(0, 1.22, 0), 0.14, 0.35, Mats.jug_blue(), false)
	# the catering cart that never gets restocked
	if _r(103) < 0.5:
		var cy2 := PI / 2.0 + (_r(104) - 0.5) * 0.3
		_cc0_prop("CoffeeCart_01", Vector3(10.4, 0, 8.6), cy2)
		_collider_yaw_box(Vector3(10.4, 0.85, 8.6), Vector3(2.2, 1.7, 1.1), cy2)
	# a dead CRT television on a low table, facing the chairs
	if _r(106) < 0.4:
		var tvp := Vector3(1.6, 0, 9.8)
		_cc0_prop("coffee_table_round_01", tvp, 0.0)
		_collider_cyl(tvp + Vector3(0, 0.25, 0), 0.66, 0.5)
		_cc0_prop("television_02", tvp + Vector3(0, 0.49, 0), PI * 0.78 + (_r(107) - 0.5) * 0.3)


## Landmark: a boardroom far larger than the company could have needed. The
## single long table and repeated empty chairs create a strong navigational
## silhouette; the live wall display makes it visible through several doors.
func _office_boardroom() -> void:
	var c := Vector3(S / 2.0, 0, S / 2.0)
	var ln := 11.5
	_rbox(c + Vector3(0, 0.75, 0), Vector3(ln, 0.10, 2.15), Mats.desk_white(), 0.045)
	for x in [-4.7, -1.6, 1.6, 4.7]:
		_rbox(c + Vector3(x, 0.38, 0), Vector3(0.18, 0.72, 1.65), Mats.metal_gray(), 0.025)
	_collider_box(c + Vector3(0, 0.48, 0), Vector3(ln, 0.96, 2.2))
	for side in [-1.0, 1.0]:
		for i in 8:
			var x := -4.9 + 1.4 * float(i)
			var cp := c + Vector3(x, 0, side * 1.75)
			_chair_at(cp, 0.0 if side < 0.0 else PI, Mats.fabric_charcoal())
	# One chair sits conspicuously far from the head of the table.
	_chair_at(c + Vector3(7.0, 0, 0), -PI / 2.0 + 0.18, Mats.fabric_charcoal())
	# Dark wall-sized presentation display with a stubborn status line.
	_box(c + Vector3(-8.9, 1.75, 0), Vector3(0.10, 2.3, 5.8), Mats.charcoal(), false)
	var screen := Label3D.new()
	screen.text = "QUARTER  48\nATTENDANCE  0"
	screen.font_size = 92
	screen.pixel_size = 0.0028
	screen.modulate = Color(0.42, 1.0, 0.66)
	screen.position = c + Vector3(-8.82, 1.78, 0)
	screen.rotation.y = PI / 2.0
	add_child(screen)
	# Real models break up the procedural table geometry at the room edges.
	_cc0_prop("drawer_cabinet", c + Vector3(8.8, 0, -7.7), -PI / 2.0)
	_collider_yaw_box(c + Vector3(8.8, 0.95, -7.7), Vector3(1.15, 1.9, 0.52), -PI / 2.0)
	for p in [c + Vector3(-8.5, 0, -8.0), c + Vector3(8.5, 0, 8.0)]:
		_cc0_prop("potted_plant_02", p, _r(118 + int(p.x)) * TAU)
		_collider_cyl(p + Vector3(0, 0.42, 0), 0.34, 0.84)
	var snd := OfficeSounds.new()
	snd.position = c + Vector3(0, 1.2, 0)
	add_child(snd)


# --- sewer -------------------------------------------------------------------

func _sewer_ch() -> Array:
	return [
		WorldGen.sewer_channel(wseed, cell, 0),
		WorldGen.sewer_channel(wseed, cell, 1),
		WorldGen.sewer_channel(wseed, cell, 2),
		WorldGen.sewer_channel(wseed, cell, 3),
	]


func _sewer_floor_ceiling() -> void:
	var ch := _sewer_ch()
	# cast concrete lid with cross beams
	_box(Vector3(S / 2.0, ceil_h + 0.15, S / 2.0), Vector3(S, 0.3, S), Mats.concrete())
	for t in [2.0, 6.0, 10.0]:
		_box(Vector3(S / 2.0, ceil_h - 0.11, t), Vector3(S, 0.24, 0.34), Mats.concrete(), false)
	if style == WorldGen.SEWER_BASIN or style == WorldGen.SEWER_CISTERN:
		_sewer_basin_structure(ch)
		return
	var a := 6.0 - CH_CUT
	var b := 6.0 + CH_CUT
	# corner slabs are always dry ground
	for xr in [[0.0, a], [b, S]]:
		for zr in [[0.0, a], [b, S]]:
			_floor_slab(xr[0], xr[1], zr[0], zr[1])
	# side tiles: water trough if that edge carries the channel
	var regions := [[b, S], [0.0, a], [b, S], [0.0, a]]
	for dir in 4:
		var t0: float = regions[dir][0]
		var t1: float = regions[dir][1]
		if ch[dir]:
			_channel_stub(dir, t0, t1)
		elif dir < 2:
			_floor_slab(t0, t1, a, b)
		else:
			_floor_slab(a, b, t0, t1)
	if ch[0] or ch[1] or ch[2] or ch[3]:
		_channel_junction(ch)
	else:
		_floor_slab(a, b, a, b)


func _floor_slab(x0: float, x1: float, z0: float, z1: float) -> void:
	if x1 - x0 < 0.05 or z1 - z0 < 0.05:
		return
	_box(Vector3((x0 + x1) / 2.0, -0.15, (z0 + z1) / 2.0),
		Vector3(x1 - x0, 0.3, z1 - z0), Mats.concrete_floor())


## Sloped concrete slab with matching collider. `lip` is the centre of the top
## edge; the surface descends `drop` over signed horizontal `run` along z
## (slope_dz) or x, extended `ext` past the toe to bury the seam.
func _slope_slab(lip: Vector3, slope_dz: bool, run: float, drop: float, ln: float, th: float, ext: float) -> void:
	var ang := atan2(drop, absf(run))
	var sn := signf(run)
	var base_len := sqrt(run * run + drop * drop)
	var mid := (base_len + ext) / 2.0
	var dc := cos(ang) * sn * mid - sin(ang) * sn * th / 2.0
	var dy := -sin(ang) * mid - cos(ang) * th / 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = BOX
	mi.material_override = Mats.concrete_floor()
	if slope_dz:
		mi.position = lip + Vector3(0, dy, dc)
		mi.rotation.x = ang * sn
		mi.scale = Vector3(ln, th, base_len + ext)
	else:
		mi.position = lip + Vector3(dc, dy, 0)
		mi.rotation.z = -ang * sn
		mi.scale = Vector3(base_len + ext, th, ln)
	add_child(mi)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = mi.scale
	cs.shape = sh
	cs.position = mi.position
	cs.rotation = mi.rotation
	body.add_child(cs)


## One straight trough stretch: sunken invert, two walkable banks, water.
func _trough(along_x: bool, t0: float, t1: float, flow: Vector2) -> void:
	var ln := t1 - t0
	var c := (t0 + t1) * 0.5
	var wm: MeshInstance3D
	if along_x:
		_box(Vector3(c, -CH_D - 0.075, 6.0), Vector3(ln, 0.15, CH_HW * 2.0 + 0.2), Mats.concrete_floor())
		_slope_slab(Vector3(c, 0, 6.0 - CH_CUT), true, BANK, CH_D, ln, 0.14, 0.1)
		_slope_slab(Vector3(c, 0, 6.0 + CH_CUT), true, -BANK, CH_D, ln, 0.14, 0.1)
		wm = _box(Vector3(c, WATER_Y - 0.02, 6.0), Vector3(ln, 0.04, 2.5), Mats.sewer_water(), false)
	else:
		_box(Vector3(6.0, -CH_D - 0.075, c), Vector3(CH_HW * 2.0 + 0.2, 0.15, ln), Mats.concrete_floor())
		_slope_slab(Vector3(6.0 - CH_CUT, 0, c), false, BANK, CH_D, ln, 0.14, 0.1)
		_slope_slab(Vector3(6.0 + CH_CUT, 0, c), false, -BANK, CH_D, ln, 0.14, 0.1)
		wm = _box(Vector3(6.0, WATER_Y - 0.02, c), Vector3(2.5, 0.04, ln), Mats.sewer_water(), false)
	wm.set_instance_shader_parameter("flow", flow)


func _channel_stub(dir: int, t0: float, t1: float) -> void:
	var along_x := dir < 2
	var sgn := WorldGen.sewer_flow(wseed, cell, dir)
	var flow := Vector2(sgn * 0.32, 0.0) if along_x else Vector2(0.0, sgn * 0.32)
	_trough(along_x, t0, t1, flow)
	if WorldGen.edge_info(wseed, cell, dir, theme)["wall"]:
		_culvert(dir)


## Where all channel stubs meet: shared pool tile, closed sides get banks.
func _channel_junction(ch: Array) -> void:
	var a := 6.0 - CH_CUT
	var b := 6.0 + CH_CUT
	_box(Vector3(6.0, -CH_D - 0.085, 6.0), Vector3(b - a, 0.17, b - a), Mats.concrete_floor())
	if not ch[0]:
		_slope_slab(Vector3(b, 0, 6.0), false, -BANK, CH_D, b - a, 0.14, 0.1)
	if not ch[1]:
		_slope_slab(Vector3(a, 0, 6.0), false, BANK, CH_D, b - a, 0.14, 0.1)
	if not ch[2]:
		_slope_slab(Vector3(6.0, 0, b), true, -BANK, CH_D, b - a, 0.14, 0.1)
	if not ch[3]:
		_slope_slab(Vector3(6.0, 0, a), true, BANK, CH_D, b - a, 0.14, 0.1)
	var fv := Vector2.ZERO
	for dir in 4:
		if ch[dir]:
			var sgn := WorldGen.sewer_flow(wseed, cell, dir)
			fv += Vector2(sgn, 0.0) if dir < 2 else Vector2(0.0, sgn)
	fv = fv.normalized() * 0.3 if fv.length() > 0.01 else Vector2(0.17, 0.13)
	var wm := _box(Vector3(6.0, WATER_Y - 0.02, 6.0), Vector3(b - a, 0.04, b - a), Mats.sewer_water(), false)
	wm.set_instance_shader_parameter("flow", fv)


## Barred opening where the channel slips under a wall.
func _culvert(dir: int) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var plane := (S - T / 2.0) if (dir == 0 or dir == 2) else (T / 2.0)
	var bar_p := plane + n * (T / 2.0 + 0.05)
	if dir < 2:
		_box(Vector3(plane, -0.04, 6.0), Vector3(T + 0.1, 0.16, CH_HW * 2.0 + 0.4), Mats.concrete(), false)
		for i in 5:
			_cyl(Vector3(bar_p, -0.26, 6.0 - 0.56 + 0.28 * float(i)), 0.024, 0.52, Mats.iron_dark(), false)
	else:
		_box(Vector3(6.0, -0.04, plane), Vector3(CH_HW * 2.0 + 0.4, 0.16, T + 0.1), Mats.concrete(), false)
		for i in 5:
			_cyl(Vector3(6.0 - 0.56 + 0.28 * float(i), -0.26, bar_p), 0.024, 0.52, Mats.iron_dark(), false)


## Basin room: sunken pool spanning the middle, walkways around it, channel
## stubs pouring in through gaps in the retaining walls.
func _sewer_basin_structure(ch: Array) -> void:
	var a := 6.0 - CH_CUT
	var b := 6.0 + CH_CUT
	if ch[1]:
		_floor_slab(0.0, BAS0, 0.0, a)
		_floor_slab(0.0, BAS0, b, S)
	else:
		_floor_slab(0.0, BAS0, 0.0, S)
	if ch[0]:
		_floor_slab(BAS1, S, 0.0, a)
		_floor_slab(BAS1, S, b, S)
	else:
		_floor_slab(BAS1, S, 0.0, S)
	if ch[3]:
		_floor_slab(BAS0, a, 0.0, BAS0)
		_floor_slab(b, BAS1, 0.0, BAS0)
	else:
		_floor_slab(BAS0, BAS1, 0.0, BAS0)
	if ch[2]:
		_floor_slab(BAS0, a, BAS1, S)
		_floor_slab(b, BAS1, BAS1, S)
	else:
		_floor_slab(BAS0, BAS1, BAS1, S)
	if ch[0]:
		_channel_stub(0, BAS1, S)
	if ch[1]:
		_channel_stub(1, 0.0, BAS0)
	if ch[2]:
		_channel_stub(2, BAS1, S)
	if ch[3]:
		_channel_stub(3, 0.0, BAS0)
	_box(Vector3(6.0, -BAS_D - 0.075, 6.0),
		Vector3(BAS1 - BAS0 + 0.3, 0.15, BAS1 - BAS0 + 0.3), Mats.concrete_floor())
	_basin_walls(ch)
	var wm := _box(Vector3(6.0, WATER_Y - 0.02, 6.0),
		Vector3(BAS1 - BAS0 + 0.1, 0.04, BAS1 - BAS0 + 0.1), Mats.sewer_water(), false)
	wm.set_instance_shader_parameter("flow", Vector2(0.1, 0.08))
	var rs := _basin_ramp_spot(ch)
	_basin_ramp(rs[0], rs[1])


func _basin_walls(ch: Array) -> void:
	var a := 6.0 - CH_CUT
	var b := 6.0 + CH_CUT
	for dir in 4:
		var w := (BAS1 + 0.075) if (dir == 0 or dir == 2) else (BAS0 - 0.075)
		if ch[dir]:
			_bwall(dir, w, BAS0, a)
			_bwall(dir, w, b, BAS1)
			# submerged step below the inlet trough
			if dir < 2:
				_box(Vector3(w, -(BAS_D + CH_D) / 2.0, 6.0), Vector3(0.15, BAS_D - CH_D, b - a), Mats.concrete(), true)
			else:
				_box(Vector3(6.0, -(BAS_D + CH_D) / 2.0, w), Vector3(b - a, BAS_D - CH_D, 0.15), Mats.concrete(), true)
		else:
			_bwall(dir, w, BAS0, BAS1)


func _bwall(dir: int, w: float, t0: float, t1: float) -> void:
	if t1 - t0 < 0.05:
		return
	var c := (t0 + t1) / 2.0
	if dir < 2:
		_box(Vector3(w, -BAS_D / 2.0, c), Vector3(0.15, BAS_D, t1 - t0), Mats.concrete())
	else:
		_box(Vector3(c, -BAS_D / 2.0, w), Vector3(t1 - t0, BAS_D, 0.15), Mats.concrete())


func _basin_ramp_spot(ch: Array) -> Array:
	var start := int(_r(70) * 3.99)
	var rdir := start
	for i in 4:
		var d := (start + i) % 4
		if not ch[d]:
			rdir = d
			break
	var lat := 3.9 if _r(71) < 0.5 else 8.1
	return [rdir, lat]


## Concrete ramp descending into the basin — the way back out of the water.
func _basin_ramp(rdir: int, lat: float) -> void:
	var run := BAS_D / tan(0.6)
	match rdir:
		0: _slope_slab(Vector3(BAS1, 0, lat), false, -run, BAS_D, 1.3, 0.16, 0.2)
		1: _slope_slab(Vector3(BAS0, 0, lat), false, run, BAS_D, 1.3, 0.16, 0.2)
		2: _slope_slab(Vector3(lat, 0, BAS1), true, -run, BAS_D, 1.3, 0.16, 0.2)
		3: _slope_slab(Vector3(lat, 0, BAS0), true, run, BAS_D, 1.3, 0.16, 0.2)


func _sewer_basin_props() -> void:
	var ch := _sewer_ch()
	var rs := _basin_ramp_spot(ch)
	# Prefer an inspection bridge between two closed sides. It crosses the
	# pool rather than pretending a walkway can end in an incoming waterway.
	var bridge_axis := -1  # 0 = along x, 1 = along z
	if not ch[0] and not ch[1]:
		bridge_axis = 0
	elif not ch[2] and not ch[3]:
		bridge_axis = 1
	for dir in 4:
		var segs := [[BAS0 + 0.05, BAS1 - 0.05]]
		if ch[dir]:
			segs = _cut_seg(segs, 6.0 - CH_CUT - 0.15, 6.0 + CH_CUT + 0.15)
		if rs[0] == dir:
			segs = _cut_seg(segs, rs[1] - 0.85, rs[1] + 0.85)
		if (bridge_axis == 0 and dir <= 1) or (bridge_axis == 1 and dir >= 2):
			segs = _cut_seg(segs, 5.28, 6.72)
		for sg in segs:
			_rail_run(dir, sg[0], sg[1])
	if bridge_axis >= 0:
		_sewer_basin_bridge(bridge_axis == 0)
	# ceiling drop pipes discharging into the pool
	var made := 0
	for dir in 4:
		if made >= 2 or ch[dir]:
			continue
		if not WorldGen.edge_info(wseed, cell, dir, theme)["wall"]:
			continue
		if _r(96 + dir) < 0.55:
			_outfall(dir, 4.6 if _r(97 + dir) < 0.5 else 7.4)
			made += 1


## Narrow grated inspection bridge over one treatment pool. The solid deck
## collider keeps it dependable while individual slats sell the open grating.
func _sewer_basin_bridge(along_x: bool) -> void:
	var length := BAS1 - BAS0
	var centre := (BAS0 + BAS1) * 0.5
	for i in 23:
		var t := lerpf(BAS0 + 0.16, BAS1 - 0.16, float(i) / 22.0)
		var p := Vector3(t, 0.055, centre) if along_x else Vector3(centre, 0.055, t)
		var sz := Vector3(0.12, 0.07, 1.08) if along_x else Vector3(1.08, 0.07, 0.12)
		_box(p, sz, Mats.iron_dark(), false)
	# rusted longitudinals visible beneath the grate
	for side in [-0.48, 0.48]:
		var bp := Vector3(centre, 0.015, centre + side) if along_x \
			else Vector3(centre + side, 0.015, centre)
		var bs := Vector3(length, 0.10, 0.08) if along_x \
			else Vector3(0.08, 0.10, length)
		_box(bp, bs, Mats.pipe_rust(), false)
	# handrails and posts along both exposed sides
	for side in [-0.58, 0.58]:
		for t in [BAS0 + 0.12, centre, BAS1 - 0.12]:
			var pp := Vector3(t, 0.48, centre + side) if along_x \
				else Vector3(centre + side, 0.48, t)
			_cyl(pp, 0.022, 0.88, Mats.iron_dark(), false)
		for ry in [0.52, 0.91]:
			var rp := Vector3(centre, ry, centre + side) if along_x \
				else Vector3(centre + side, ry, centre)
			var rz := Vector3(length, 0.05, 0.05) if along_x \
				else Vector3(0.05, 0.05, length)
			_box(rp, rz, Mats.iron_dark(), false)
	var deck_size := Vector3(length, 0.10, 1.12) if along_x \
		else Vector3(1.12, 0.10, length)
	_collider_box(Vector3(centre, 0.05, centre), deck_size)
	for side in [-0.58, 0.58]:
		var cp := Vector3(centre, 0.5, centre + side) if along_x \
			else Vector3(centre + side, 0.5, centre)
		var cs := Vector3(length, 1.0, 0.06) if along_x \
			else Vector3(0.06, 1.0, length)
		_collider_box(cp, cs)


func _cut_seg(segs: Array, c0: float, c1: float) -> Array:
	var out := []
	for sg in segs:
		if c1 <= sg[0] or c0 >= sg[1]:
			out.append(sg)
			continue
		if c0 > sg[0]:
			out.append([sg[0], c0])
		if c1 < sg[1]:
			out.append([c1, sg[1]])
	return out


func _rail_run(dir: int, t0: float, t1: float) -> void:
	if t1 - t0 < 0.5:
		return
	var w := (BAS1 + 0.16) if (dir == 0 or dir == 2) else (BAS0 - 0.16)
	var c := (t0 + t1) / 2.0
	var n := int(ceilf((t1 - t0) / 1.6))
	for i in n + 1:
		var t := lerpf(t0 + 0.05, t1 - 0.05, float(i) / float(n))
		var pp := Vector3(w, 0.475, t) if dir < 2 else Vector3(t, 0.475, w)
		_cyl(pp, 0.022, 0.95, Mats.iron_dark(), false)
	for ry in [0.93, 0.52]:
		if dir < 2:
			_box(Vector3(w, ry, c), Vector3(0.05, 0.05, t1 - t0), Mats.iron_dark(), false)
		else:
			_box(Vector3(c, ry, w), Vector3(t1 - t0, 0.05, 0.05), Mats.iron_dark(), false)
	if dir < 2:
		_collider_box(Vector3(w, 0.5, c), Vector3(0.06, 1.0, t1 - t0))
	else:
		_collider_box(Vector3(c, 0.5, w), Vector3(t1 - t0, 1.0, 0.06))


func _outfall(dir: int, along: float) -> void:
	var p: Vector3
	match dir:
		0: p = Vector3(BAS1 - 0.5, 0, along)
		1: p = Vector3(BAS0 + 0.5, 0, along)
		2: p = Vector3(along, 0, BAS1 - 0.5)
		3: p = Vector3(along, 0, BAS0 + 0.5)
	_cyl(Vector3(p.x, (1.55 + ceil_h) / 2.0, p.z), 0.15, ceil_h - 1.55, Mats.pipe_rust(), false)
	var tor := MeshInstance3D.new()
	tor.mesh = TOR
	tor.material_override = Mats.pipe_rust()
	tor.position = Vector3(p.x, 1.58, p.z)
	tor.scale = Vector3(0.24, 0.12, 0.24)
	add_child(tor)
	_box(Vector3(p.x, (1.55 + WATER_Y) / 2.0, p.z),
		Vector3(0.24, 1.55 - WATER_Y, 0.24), Mats.water_stream(), false)


# --- sewer: props ------------------------------------------------------------

func _sewer_tunnel_props() -> void:
	var members := _room_members()
	for mi in members.size():
		var member: Vector2i = members[mi]
		var mc := _room_member_local(member)
		var salt := 330 + mi * 24
		# Wet patches and abandoned debris live in dry corners, never on the
		# centre-line water graph that has to remain readable and walkable.
		for pi in 2:
			if WorldGen.r01(wseed, member.x, member.y, salt + pi) >= 0.62:
				continue
			var sx := -1.0 if WorldGen.r01(wseed, member.x, member.y, salt + 3 + pi) < 0.5 else 1.0
			var sz := -1.0 if WorldGen.r01(wseed, member.x, member.y, salt + 5 + pi) < 0.5 else 1.0
			var pp := mc + Vector3(sx * (3.4 + WorldGen.r01(wseed, member.x, member.y, salt + 7 + pi)),
				0.006, sz * (3.2 + 1.2 * WorldGen.r01(wseed, member.x, member.y, salt + 9 + pi)))
			_box(pp, Vector3(0.8 + WorldGen.r01(wseed, member.x, member.y, salt + 11 + pi),
				0.012, 0.65 + 0.7 * WorldGen.r01(wseed, member.x, member.y, salt + 13 + pi)),
				Mats.puddle(), false)
		if WorldGen.r01(wseed, member.x, member.y, salt + 15) < 0.28:
			_barrel(mc + Vector3(-4.25, 0, -4.15))
		if WorldGen.r01(wseed, member.x, member.y, salt + 16) < 0.24:
			_cc0_prop("trashbag", mc + Vector3(4.2, 0, -3.8),
				WorldGen.r01(wseed, member.x, member.y, salt + 17) * TAU)
		if WorldGen.r01(wseed, member.x, member.y, salt + 18) < 0.24:
			_chain(mc + Vector3(-3.8, 0, 3.2))
	# Wall-bound ladders cannot be shifted with a merged room's centre.
	if room_n == 1 and _r(84) < 0.16:
		_wall_ladder()


func _sewer_pump_props() -> void:
	var members := _room_members()
	for i in members.size():
		var member: Vector2i = members[i]
		var mc := _room_member_local(member)
		var sx := -1.0 if WorldGen.r01(wseed, member.x, member.y, 300) < 0.5 else 1.0
		var sz := -1.0 if WorldGen.r01(wseed, member.x, member.y, 301) < 0.5 else 1.0
		_sewer_pump_skid(mc + Vector3(3.7 * sx, 0, 3.7 * sz), sx, sz, 310 + i * 8)


## One complete pump train per occupied room cell. Keeping each skid in a dry
## corner preserves the central water graph and turns merged rooms into actual
## pump works instead of one machine marooned in a warehouse.
func _sewer_pump_skid(c: Vector3, sx: float, sz: float, salt: int) -> void:
	_box(c + Vector3(0, 0.07, 0), Vector3(2.6, 0.14, 1.8), Mats.concrete_floor())
	# horizontal tank on saddles
	var tk := _cyl(c + Vector3(0, 1.02, -0.25 * sz), 0.5, 1.9, Mats.pipe_green(), false)
	tk.rotation.z = PI / 2.0
	_collider_box(c + Vector3(0, 1.0, -0.25 * sz), Vector3(1.9, 1.05, 1.0))
	for support_x in [-0.6, 0.6]:
		_box(c + Vector3(support_x, 0.42, -0.25 * sz),
			Vector3(0.16, 0.84, 0.9), Mats.iron_dark(), false)
	for ex in [-0.95, 0.95]:
		_sphere(c + Vector3(ex, 1.02, -0.25 * sz), 0.48, Mats.pipe_green())
	# pump block and motor
	_box(c + Vector3(-0.5 * sx, 0.32, 0.55 * sz), Vector3(0.7, 0.5, 0.55), Mats.iron_dark())
	var mot := _cyl(c + Vector3(0.25 * sx, 0.42, 0.55 * sz), 0.19, 0.6, Mats.pipe_green(), false)
	mot.rotation.z = PI / 2.0
	# riser to the ceiling with a valve wheel
	_cyl(c + Vector3(0.9 * sx, (1.3 + ceil_h) / 2.0, -0.25 * sz),
		0.12, ceil_h - 1.3, Mats.pipe_rust(), false)
	var vw := MeshInstance3D.new()
	vw.mesh = TOR
	vw.material_override = Mats.iron_dark()
	vw.position = c + Vector3((0.9 - 0.17) * sx, 1.85, -0.25 * sz)
	vw.rotation.z = PI / 2.0
	vw.scale = Vector3(0.24, 0.24, 0.24)
	add_child(vw)
	# one stubborn status lamp makes the machinery legible through the mist
	_sphere(c + Vector3(-0.5 * sx, 0.63, 0.55 * sz), 0.045,
		Mats.lamp_green() if _r(salt) < 0.62 else Mats.lamp_red())
	# oily spill under the works
	_box(c + Vector3(0.1 * sx, 0.005, 0.3 * sz),
		Vector3(2.2, 0.01, 1.5), Mats.puddle(), false)


func _sewer_dry_props() -> void:
	var bx := 2.0 + 1.5 * _r(88)
	var bz := 2.0 + 1.5 * _r(89)
	if _r(90) < 0.5:
		bx = S - bx
	if _r(91) < 0.5:
		bz = S - bz
	_barrel(Vector3(bx, 0, bz))
	if _r(92) < 0.7:
		_barrel(Vector3(bx + 0.72, 0, bz + 0.25))
	if _r(93) < 0.5:
		_barrel(Vector3(bx - 0.3, 0, bz + 0.78))
	# workmen's junk that never got hauled out
	if _r(94) < 0.5:
		var cyaw := _r(95) * TAU
		var crate_name := "wooden_crate_01" if _r(189) < 0.45 else "wooden_crate_02"
		_cc0_prop(crate_name, Vector3(bx + 0.6, 0, bz - 1.3), cyaw)
		var crate_size := Vector3(0.86, 0.38, 0.44) if crate_name == "wooden_crate_01" \
			else Vector3(0.55, 0.47, 1.17)
		_collider_yaw_box(Vector3(bx + 0.6, crate_size.y * 0.5, bz - 1.3), crate_size, cyaw)
	if _r(180) < 0.4:
		var tp := Vector3(S - bx, 0.085, bz + (_r(181) - 0.5) * 3.0)
		var tyre := _cc0_prop("old_tyre", tp, _r(182) * TAU)
		tyre.rotation.x = PI / 2.0
		_collider_cyl(tp, 0.32, 0.18)
	if _r(183) < 0.35:
		_cc0_prop("trashbag", Vector3(bx - 1.1, 0, bz - 0.5), _r(184) * TAU)
	if _r(185) < 0.3:
		var lyaw := _r(186) * TAU
		_cc0_prop("wooden_ladder", Vector3(S - bx, 0, S - bz), lyaw)
		_collider_yaw_box(Vector3(S - bx, 0.65, S - bz), Vector3(1.0, 1.35, 0.55), lyaw)
	if _r(187) < 0.3:
		_cc0_prop("plastic_crate_03", Vector3(bx + 1.4, 0, bz + 1.1), _r(188) * TAU)
		_collider_box(Vector3(bx + 1.4, 0.13, bz + 1.1), Vector3(0.5, 0.27, 0.28))
	# More than one generation of maintenance debris: a stove, loose wheel rim
	# or hand lantern appears in the driest rooms, never in the water channel.
	if _r(190) < 0.24:
		var sp := Vector3(S - bx, 0, 2.0 if bz > 6.0 else 10.0)
		_cc0_prop("barrel_stove", sp, _r(191) * TAU)
		_collider_cyl(sp + Vector3(0, 0.43, 0), 0.32, 0.86)
	if _r(192) < 0.34:
		var rim_name := "rusted_wheel_rim_01" if _r(193) < 0.5 else "rusted_wheel_rim_02"
		var rp := Vector3(2.0 if bx > 6.0 else 10.0, 0.18, S - bz)
		var rim := _cc0_prop(rim_name, rp, _r(194) * TAU)
		rim.rotation.x = PI / 2.0
	if _r(195) < 0.28:
		var lp := Vector3(bx + 0.4, 0.48, bz - 0.2)
		_cc0_prop("Lantern_01", lp, _r(196) * TAU, 1.25)
		var ll := OmniLight3D.new()
		ll.position = lp + Vector3(0, 0.15, 0)
		ll.light_color = Color(1.0, 0.54, 0.22)
		ll.light_energy = 0.28
		ll.omni_range = 3.0
		ll.shadow_enabled = false
		ll.distance_fade_enabled = true
		ll.distance_fade_begin = 12.0
		ll.distance_fade_length = 5.0
		add_child(ll)


## Landmark: four treatment pools meet beneath a huge overhead manifold. The
## existing per-cell bridges keep every basin traversable; the shared pipe
## crown and control island make the 24m reservoir read as one place.
func _sewer_cistern() -> void:
	var c := Vector3(S / 2.0, 0, S / 2.0)
	# A compact central operator island, offset so the joins between pool decks
	# remain passable on both axes.
	var console := c + Vector3(2.2, 0, 2.2)
	_rbox(console + Vector3(0, 0.62, 0), Vector3(2.4, 1.24, 1.0), Mats.iron_dark(), 0.04)
	var face := _rbox(console + Vector3(0, 1.02, -0.51), Vector3(2.2, 0.48, 0.06), Mats.pipe_green(), 0.02, false)
	face.rotation.x = -0.18
	for i in 7:
		_sphere(console + Vector3(-0.85 + 0.28 * float(i), 1.06, -0.57), 0.035,
			Mats.lamp_green() if i == 2 else Mats.lamp_red())
	_collider_box(console + Vector3(0, 0.65, 0), Vector3(2.45, 1.3, 1.05))
	# Four enormous risers feed a square manifold just below the ceiling.
	for ox in [-5.2, 5.2]:
		for oz in [-5.2, 5.2]:
			var p := c + Vector3(ox, 0, oz)
			_cyl(p + Vector3(0, ceil_h * 0.5, 0), 0.24, ceil_h, Mats.pipe_rust(), false)
			var wheel := _cc0_prop("rusted_wheel_rim_01", p + Vector3(0.28, 1.35, 0), PI / 2.0, 1.7)
			wheel.rotation.z = PI / 2.0
	for oz in [-5.2, 5.2]:
		var px := _cyl(c + Vector3(0, ceil_h - 0.42, oz), 0.22, 10.4, Mats.pipe_green(), false)
		px.rotation.z = PI / 2.0
	for ox in [-5.2, 5.2]:
		var pz := _cyl(c + Vector3(ox, ceil_h - 0.42, 0), 0.22, 10.4, Mats.pipe_green(), false)
		pz.rotation.x = PI / 2.0
	# A pair of real industrial fixtures hangs over the control island.
	for dx in [-1.1, 1.1]:
		var lamp := _cc0_prop("industrial_caged_sconce",
			console + Vector3(dx, 1.85, -0.58), 0.0, 0.58)
		lamp.rotation.x = -PI / 2.0


func _barrel(p: Vector3) -> void:
	# real drums: battered red or faded blue, picked per spot
	var mname := "Barrel_01" if WorldGen.r01(wseed, int(p.x * 7.0), int(p.z * 7.0), 96) < 0.6 else "barrel_03"
	_cc0_prop(mname, p, WorldGen.r01(wseed, int(p.x * 5.0), int(p.z * 5.0), 97) * TAU)
	_collider_cyl(p + Vector3(0, 0.46, 0), 0.32, 0.92)


func _wall_ladder() -> void:
	for dir in 4:
		if not WorldGen.edge_info(wseed, cell, dir, theme)["wall"]:
			continue
		var n := -1.0 if (dir == 0 or dir == 2) else 1.0
		var plane := (S - T / 2.0) if (dir == 0 or dir == 2) else (T / 2.0)
		var inner := plane + n * (T / 2.0)
		var along := 2.0 + 2.0 * _r(85)
		if _r(86) < 0.5:
			along = S - along
		var off := inner + n * 0.13
		for sr in [-0.22, 0.22]:
			var rp := Vector3(off, ceil_h / 2.0, along + sr) if dir < 2 else Vector3(along + sr, ceil_h / 2.0, off)
			_cyl(rp, 0.025, ceil_h - 0.1, Mats.iron_dark(), false)
		var ry := 0.35
		while ry < ceil_h - 0.2:
			var rung := _cyl(Vector3(off, ry, along) if dir < 2 else Vector3(along, ry, off), 0.02, 0.5, Mats.iron_dark(), false)
			if dir < 2:
				rung.rotation.x = PI / 2.0
			else:
				rung.rotation.z = PI / 2.0
			ry += 0.32
		var hp := Vector3(inner + n * 0.45, ceil_h - 0.02, along) if dir < 2 else Vector3(along, ceil_h - 0.02, inner + n * 0.45)
		_box(hp, Vector3(0.8, 0.06, 0.8), Mats.iron_dark(), false)
		return


## Wall-hung service pipes: long horizontal runs with brackets, flanges and
## the odd vertical branch.
func _sewer_pipes(dir: int, plane: float) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T * 0.5)
	var count := 1 + int(_r(42 + dir) * 1.99)
	for i in count:
		var r := 0.075 if i == 0 else 0.05
		var y := 2.14 + 0.28 * float(i)
		var mat: Material = Mats.pipe_rust() if _r(43 + dir + i) < 0.55 else Mats.pipe_green()
		var off := inner + n * (r + 0.06)
		var pipe := _cyl(Vector3(off, y, S / 2.0) if dir < 2 else Vector3(S / 2.0, y, off), r, S, mat, false)
		if dir < 2:
			pipe.rotation.x = PI / 2.0
		else:
			pipe.rotation.z = PI / 2.0
		for t in [2.0, 6.0, 10.0]:
			var bp := Vector3(inner + n * (r + 0.06) / 2.0, y, t) if dir < 2 else Vector3(t, y, inner + n * (r + 0.06) / 2.0)
			_box(bp, Vector3(r + 0.12, 0.05, 0.05) if dir < 2 else Vector3(0.05, 0.05, r + 0.12), Mats.iron_dark(), false)
		if _r(45 + dir + i) < 0.6:
			var ft := 3.0 + 6.0 * _r(46 + dir + i)
			var tor := MeshInstance3D.new()
			tor.mesh = TOR
			tor.material_override = mat
			tor.position = Vector3(off, y, ft) if dir < 2 else Vector3(ft, y, off)
			if dir < 2:
				tor.rotation.x = PI / 2.0
			else:
				tor.rotation.z = PI / 2.0
			tor.scale = Vector3(r * 1.9, r * 1.5, r * 1.9)
			add_child(tor)
	if _r(47 + dir) < 0.35:
		var t2 := 2.2 + 2.0 * _r(48 + dir)
		if _r(49 + dir) < 0.5:
			t2 = S - t2
		var off2 := inner + n * 0.135
		_cyl(Vector3(off2, 1.07, t2) if dir < 2 else Vector3(t2, 1.07, off2), 0.075, 2.14, Mats.pipe_rust(), false)
		_sphere(Vector3(off2, 2.18, t2) if dir < 2 else Vector3(t2, 2.18, off2), 0.1, Mats.pipe_rust())


## Service gallery: the channel runs down a concrete slot barely two arms
## wide, pipes and cable trays on both walls, cage lamps overhead. Where a
## cross-channel passes, the walls open into rough archways.
func _sewer_gallery() -> void:
	var cdir := WorldGen.corridor(wseed, cell)
	var along_x := cdir != 2
	var yw := 0.0 if along_x else PI / 2.0
	var o := Vector3(S / 2.0, 0, S / 2.0)
	var perp := false
	if along_x:
		perp = WorldGen.sewer_channel(wseed, cell, 2) or WorldGen.sewer_channel(wseed, cell, 3)
	else:
		perp = WorldGen.sewer_channel(wseed, cell, 0) or WorldGen.sewer_channel(wseed, cell, 1)
	for si in 2:
		var side := -2.2 if si == 0 else 2.2
		var segs := [[-5.0, 5.0]]
		if perp:
			segs = _cut_seg(segs, -CH_CUT - 0.35, CH_CUT + 0.35)
		for sg in segs:
			var c0: float = sg[0]
			var c1: float = sg[1]
			var wc := _wp(o, Vector3((c0 + c1) / 2.0, ceil_h / 2.0, side), yw)
			var wl := _mbox(self, wc, Vector3(c1 - c0, ceil_h, 0.18), Mats.concrete())
			wl.rotation.y = yw
			_collider_yaw_box(wc, Vector3(c1 - c0, ceil_h, 0.18), yw)
		if perp:
			var lt := _mbox(self, _wp(o, Vector3(0, ceil_h - 0.4, side), yw),
				Vector3(CH_CUT * 2.0 + 0.75, 0.8, 0.18), Mats.concrete())
			lt.rotation.y = yw
			_collider_yaw_box(_wp(o, Vector3(0, ceil_h - 0.4, side), yw),
				Vector3(CH_CUT * 2.0 + 0.75, 0.8, 0.18), yw)
		# pipe runs and a cable tray on the lane face
		var inn := side - signf(side) * 0.24
		for pj in 2:
			var y := 1.9 + 0.3 * float(pj)
			var pmat: Material = Mats.pipe_rust() if _r(280 + si * 3 + pj) < 0.5 else Mats.pipe_green()
			var pp := _mcyl(self, _wp(o, Vector3(0, y, inn), yw), 0.05 + 0.03 * float(pj % 2), 9.6, pmat)
			pp.rotation = Vector3(0, yw, PI / 2.0)
		var tr := _mbox(self, _wp(o, Vector3(0, 1.45, inn), yw), Vector3(9.6, 0.05, 0.16), Mats.iron_dark())
		tr.rotation.y = yw
	# A flush service grate reconnects the two narrow banks without obstructing
	# travel along them. Keep it away from the central cross-channel opening.
	var bridge_t := -3.0 if _r(289) < 0.5 else 3.0
	_sewer_gallery_grate(o, yw, bridge_t)
	# lamps strung down the slot
	for t in [-3.0, 0.0, 3.0]:
		var lp := _wp(o, Vector3(t, 0, 0), yw)
		_cage_lamp(Vector2(lp.x, lp.z), false, t == 0.0 and _r(288) < 0.3, false)


func _sewer_gallery_grate(o: Vector3, yw: float, along: float) -> void:
	for i in 7:
		var x := along + lerpf(-0.48, 0.48, float(i) / 6.0)
		var bar := _mbox(self, _wp(o, Vector3(x, 0.045, 0), yw),
			Vector3(0.055, 0.07, 3.45), Mats.iron_dark())
		bar.rotation.y = yw
	for z in [-1.45, -0.5, 0.5, 1.45]:
		var brace := _mbox(self, _wp(o, Vector3(along, 0.025, z), yw),
			Vector3(1.08, 0.06, 0.055), Mats.pipe_rust())
		brace.rotation.y = yw
	# worn hazard paint just outside the load-bearing grate
	for ex in [-0.58, 0.58]:
		var edge := _mbox(self, _wp(o, Vector3(along + ex, 0.052, 0), yw),
			Vector3(0.055, 0.025, 3.45), Mats.lamp_amber())
		edge.rotation.y = yw
	_collider_yaw_box(_wp(o, Vector3(along, 0.04, 0), yw),
		Vector3(1.12, 0.09, 3.5), yw)


# --- sewer: lighting & sound -------------------------------------------------

func _sewer_lighting() -> void:
	var is_spawn := cell == Vector2i.ZERO
	var dead := (not is_spawn) and _r(8) < 0.06
	var flicker := (not is_spawn) and (not dead) and _r(9) < 0.22
	var spots := [Vector2(3.0, 3.2), Vector2(9.0, 3.2), Vector2(3.0, 8.8), Vector2(9.0, 8.8)]
	var i0 := int(_r(13) * 3.99)
	_cage_lamp(spots[i0], dead, flicker, true)
	_cage_lamp(spots[(i0 + 2) % 4], dead, false, false)
	if style == WorldGen.SEWER_PUMP:
		# the works always keep their own lamp burning
		_cage_lamp(Vector2(2.4, 2.4), false, false, false)
	if style == WorldGen.SEWER_BASIN:
		# a real industrial pendant over the water (visual — light is below)
		var pend := _cc0_prop("hanging_industrial_lamp", Vector3(6.0, ceil_h + 0.62, 6.0), _r(14) * TAU)
		_asy_no_shadows(pend)
	if dead:
		return
	# faint green fill so the water never crushes to black
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.5, 0.75, 0.6)
	fill.light_energy = 0.16
	fill.omni_range = 10.0
	fill.position = Vector3(6.0, 2.0, 6.0)
	fill.shadow_enabled = false
	fill.distance_fade_enabled = true
	fill.distance_fade_begin = 18.0
	fill.distance_fade_length = 8.0
	add_child(fill)


## Bare bulb in a wire cage on a conduit stem. The fixture itself never casts
## shadows — its umbra would paint giant discs on the ceiling.
func _cage_lamp(at: Vector2, dead: bool, flicker: bool, shadows: bool) -> void:
	var y := ceil_h - 0.38
	var stem := _cyl(Vector3(at.x, ceil_h - 0.17, at.y), 0.02, 0.34, Mats.iron_dark(), false)
	var cap := _cyl(Vector3(at.x, y + 0.05, at.y), 0.10, 0.09, Mats.iron_dark(), false)
	stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bmat: StandardMaterial3D = Mats.charcoal() if dead else Mats.bulb()
	if flicker:
		bmat = Mats.bulb().duplicate()
	var bulb := _sphere(Vector3(at.x, y - 0.03, at.y), 0.055, bmat)
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for ty in [0.02, 0.11]:
		var tor := MeshInstance3D.new()
		tor.mesh = TOR
		tor.material_override = Mats.iron_dark()
		tor.position = Vector3(at.x, y - ty, at.y)
		tor.scale = Vector3(0.11, 0.05, 0.11)
		tor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(tor)
	if dead:
		return
	var l: OmniLight3D
	if flicker:
		var fl := FlickerLight.new()
		fl.base_energy = 1.35
		fl.mats = [bmat]
		fl.rng_seed = WorldGen.h(wseed, cell.x, cell.y, 10)
		l = fl
	else:
		l = OmniLight3D.new()
		l.light_energy = 1.35
	l.light_color = Color(1.0, 0.76, 0.48)
	l.omni_range = 8.5
	# well below the cap, or its shadow umbra paints a huge disc on the ceiling
	l.position = Vector3(at.x, y - 0.34, at.y)
	l.shadow_enabled = shadows
	l.distance_fade_enabled = true
	l.distance_fade_begin = 20.0
	l.distance_fade_length = 8.0
	l.distance_fade_shadow = 14.0
	add_child(l)


func _sewer_sounds() -> void:
	var ch := _sewer_ch()
	if not (ch[0] or ch[1] or ch[2] or ch[3] or style == WorldGen.SEWER_BASIN):
		return
	var snd := SewerSounds.new()
	snd.rush_db = -10.0 if style == WorldGen.SEWER_BASIN else -16.0
	snd.position = Vector3(6.0, 0.4, 6.0)
	add_child(snd)


func _sewer_mist() -> void:
	var ch := _sewer_ch()
	if not (ch[0] or ch[1] or ch[2] or ch[3] or style == WorldGen.SEWER_BASIN):
		return
	# cold mist pooling knee-deep over the water
	if _r(266) < 0.65:
		var fv := FogVolume.new()
		fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
		fv.size = Vector3(11.0, 1.5, 11.0)
		fv.position = Vector3(6.0, 0.45, 6.0)
		var fm := FogMaterial.new()
		fm.density = 0.22
		fm.albedo = Color(0.6, 0.8, 0.66)
		fv.material = fm
		add_child(fv)


const SEWER_STENCILS := ["OUTFALL 3", "SEC C-12", "PUMP 7", "LEVEL -2",
	"NO ENTRY", "DRAIN 44", "FLOW >"]


## Faded paint stencilled straight onto the concrete, decades ago.
func _sewer_stencil(dir: int, plane: float) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T / 2.0)
	var along := S / 2.0 + (_r(66 + dir) - 0.5) * 6.0
	var lb := Label3D.new()
	lb.text = SEWER_STENCILS[int(_r(67 + dir) * (float(SEWER_STENCILS.size()) - 0.01))]
	lb.font_size = 150
	lb.pixel_size = 0.004
	lb.modulate = Color(0.72, 0.62, 0.28, 0.72)
	if dir < 2:
		lb.position = Vector3(inner + n * 0.02, 1.55, along)
		lb.rotation.y = PI / 2.0 if n > 0.0 else -PI / 2.0
	else:
		lb.position = Vector3(along, 1.55, inner + n * 0.02)
		lb.rotation.y = 0.0 if n > 0.0 else PI
	lb.rotation.z = (_r(68 + dir) - 0.5) * 0.05
	add_child(lb)


## Wall-mounted control cabinet: gauges, indicator lamps, conduit to nowhere.
## Half of them are a real breaker box instead.
func _sewer_panel(dir: int, plane: float) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T / 2.0)
	var along := S / 2.0 + (_r(69 + dir) - 0.5) * 5.0
	if _r(73 + dir) < 0.5:
		if dir < 2:
			_cc0_prop("power_box_01", Vector3(inner + n * 0.03, 1.45, along), PI / 2.0 * n)
		else:
			_cc0_prop("power_box_01", Vector3(along, 1.45, inner + n * 0.03), 0.0 if n > 0.0 else PI)
		return
	var v := Node3D.new()
	if dir < 2:
		v.position = Vector3(inner + n * 0.12, 1.35, along)
		v.rotation.y = PI / 2.0 if n > 0.0 else -PI / 2.0
	else:
		v.position = Vector3(along, 1.35, inner + n * 0.12)
		v.rotation.y = 0.0 if n > 0.0 else PI
	add_child(v)
	_mrbox(v, Vector3.ZERO, Vector3(0.72, 0.95, 0.2), Mats.pipe_green(), 0.02)
	_mbox(v, Vector3(0.1, 0, 0.102), Vector3(0.015, 0.8, 0.006), Mats.iron_dark())
	for gi in 2:
		var gx := -0.2 + 0.28 * float(gi)
		var g := _mcyl(v, Vector3(gx, 0.24, 0.115), 0.07, 0.03, Mats.paint_white())
		g.rotation.x = PI / 2.0
		var nd := _mbox(v, Vector3(gx, 0.26, 0.135), Vector3(0.008, 0.05, 0.005), Mats.charcoal())
		nd.rotation.z = (_r(70 + dir + gi) - 0.5) * 2.0
	var lamps: Array = [Mats.lamp_red(), Mats.lamp_amber(), Mats.lamp_green()]
	var lit := int(_r(71 + dir) * 2.99)
	for li in 3:
		var lmat: Material = lamps[li] if li == lit else Mats.charcoal()
		_mbox(v, Vector3(-0.2 + 0.2 * float(li), -0.12, 0.11), Vector3(0.05, 0.05, 0.02), lmat)
	_mcyl(v, Vector3(0.22, (ceil_h - 1.35) / 2.0 + 0.475, -0.02), 0.028, ceil_h - 1.35 - 0.95, Mats.iron_dark())
	_collider_yaw_box(v.position, Vector3(0.75, 0.95, 0.3), v.rotation.y)


## Chain hanging from a ceiling hook, swaying in air that never moves.
func _chain(p: Vector3) -> void:
	var links := 3 + int(_r(267) * 5.0)
	for i in links:
		var tor := MeshInstance3D.new()
		tor.mesh = TOR
		tor.material_override = Mats.iron_dark()
		tor.position = p + Vector3(0, ceil_h - 0.08 - 0.085 * float(i), 0)
		tor.rotation.x = PI / 2.0
		if i % 2 == 1:
			tor.rotation.y = PI / 2.0
		tor.scale = Vector3(0.055, 0.045, 0.055)
		tor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(tor)


# --- shared primitives -------------------------------------------------------

## Box strut from a to b — the workhorse for wheels, wires and legs.
func _beam(a: Vector3, b: Vector3, th: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = BOX
	mi.material_override = mat
	var d := b - a
	var up := Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT
	mi.transform = Transform3D(Basis.looking_at(d, up), (a + b) / 2.0)
	mi.scale = Vector3(th, th, d.length())
	add_child(mi)
	return mi


func _cone(base: Vector3, r: float, h: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = CONE
	mi.material_override = mat
	mi.position = base + Vector3(0, h / 2.0, 0)
	mi.scale = Vector3(r / 0.5, h, r / 0.5)
	add_child(mi)
	return mi


# --- airport -----------------------------------------------------------------

const AIR_DESTS := ["AMSTERDAM", "SINGAPORE", "DENVER", "REYKJAVIK", "OSAKA",
	"LIMA", "TBILISI", "PERTH", "MONTREAL", "DOHA", "HELSINKI", "ANCHORAGE",
	"MANAUS", "TAIPEI", "LAGOS", "ZURICH"]
const AIR_STATUS := ["DELAYED", "DELAYED", "ON TIME", "BOARDING", "DELAYED",
	"CANCELLED", "GATE WAIT", "DELAYED"]
const AIR_ZONE_SIGNS := [
	["Gates A1 - A22  >", "<  Gates B1 - B14", "Transfers", "Lounges  >"],
	["Departures  >", "<  Check-in", "Security", "Gates  >"],
	["Baggage Claim", "Exit  >", "<  Passport Control", "Trains to City"],
]


func _air_zone_sign(salt: int) -> String:
	var zone := WorldGen.macro_zone(wseed, cell, theme)
	var labels: Array = AIR_ZONE_SIGNS[zone]
	return labels[int(_r(salt) * (float(labels.size()) - 0.01))]


func _msphere(parent: Node3D, pos: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = SPH
	mi.material_override = mat
	mi.position = pos
	mi.scale = Vector3.ONE * (r / 0.5)
	parent.add_child(mi)
	return mi


func _collider_yaw_box(pos: Vector3, size: Vector3, yaw: float) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	cs.rotation.y = yaw
	body.add_child(cs)


func _collider_rot_box(pos: Vector3, size: Vector3, rot: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	cs.rotation = rot
	body.add_child(cs)


## Rotate a local offset into chunk space around an anchor's yaw.
func _wp(o: Vector3, local: Vector3, yaw: float) -> Vector3:
	return o + local.rotated(Vector3.UP, yaw)


## First solid edge, scanning from a hashed start — the anchor wall for gate
## glass, check-in backs and escalator mezzanines. -1 if the cell has none.
func _air_pick_wall(salt: int) -> int:
	return WorldGen.anchor_wall(wseed, cell, salt)


## Yaw that points a node's local +z at the given edge.
func _air_yaw_for(dir: int) -> float:
	match dir:
		0: return PI / 2.0
		1: return -PI / 2.0
		2: return 0.0
	return PI


func _gate_code() -> String:
	var letters := ["A", "B", "C", "D", "E"]
	return "%s%d" % [letters[int(_r(300) * 4.99)], 1 + int(_r(301) * 27.99)]


func _air_lighting() -> void:
	if style == WorldGen.AIR_TRANSIT:
		return  # transit corridors light themselves under the dropped bulkhead
	var is_spawn := cell == Vector2i.ZERO
	var dead := (not is_spawn) and _r(8) < 0.04
	var flicker := (not is_spawn) and (not dead) and _r(9) < 0.11
	var pmat: StandardMaterial3D
	if dead:
		pmat = Mats.panel_dead()
	elif flicker:
		pmat = Mats.air_panel().duplicate()
	else:
		pmat = Mats.air_panel()
	# long recessed light lines running the hall
	for gx in [3.0, 9.0]:
		for gz in [2.5, 6.0, 9.5]:
			_troffer(Vector3(gx, 0, gz), Vector2(2.6, 0.22), pmat, Mats.metal_gray())
	if dead:
		return
	var light := _make_main_light(flicker, pmat, 1.7)
	light.light_color = Color(0.85, 0.91, 1.0)
	light.omni_range = 14.5
	light.position = Vector3(S / 2.0, ceil_h - 0.6, S / 2.0)
	light.shadow_enabled = true
	light.distance_fade_enabled = true
	light.distance_fade_begin = 24.0
	light.distance_fade_length = 8.0
	light.distance_fade_shadow = 18.0
	add_child(light)


## Overhead wayfinding hung from the deck above: navy backlit box, yellow
## text both sides, twin drop rods.
func _hang_sign(pos: Vector3, yaw: float, text: String, top := 0.0) -> void:
	var v := Node3D.new()
	v.position = pos
	v.rotation.y = yaw
	add_child(v)
	var w := maxf(1.6, 0.115 * float(text.length()) + 0.55)
	var rod_h := maxf(0.1, (top if top > 0.0 else ceil_h) - pos.y - 0.275)
	for sx in [-w * 0.36, w * 0.36]:
		_mcyl(v, Vector3(sx, 0.275 + rod_h / 2.0, 0), 0.016, rod_h, Mats.charcoal())
	_mrbox(v, Vector3.ZERO, Vector3(w, 0.55, 0.09), Mats.sign_navy(), 0.015)
	for sside in [-1.0, 1.0]:
		var lb := Label3D.new()
		lb.text = text
		lb.font_size = 96
		lb.pixel_size = 0.0024
		lb.modulate = Color(0.96, 0.92, 0.5)
		lb.position = Vector3(0, 0, sside * 0.055)
		lb.rotation.y = 0.0 if sside > 0.0 else PI
		v.add_child(lb)


## Built by the canonical edge owner: a wayfinding sign hung just inside the
## portal, pointing deeper into a terminal that never ends.
func _air_portal_sign(dir: int, t: float) -> void:
	if style == WorldGen.AIR_TRANSIT:
		return  # would poke through the transit bulkhead
	var txt := _air_zone_sign(345 + dir)
	if dir == 0:
		_hang_sign(Vector3(S - 0.8, AIR_DOOR + 0.6, t), PI / 2.0, txt)
	else:
		_hang_sign(Vector3(t, AIR_DOOR + 0.6, S - 0.8), 0.0, txt)


## Departures board: charcoal housing, glowing glass, amber rows that list
## flights out of a place with no doors to the outside.
func _fids(parent: Node3D, lpos: Vector3, lyaw: float, big: bool, hang: bool) -> void:
	var v := Node3D.new()
	v.position = lpos
	v.rotation.y = lyaw
	parent.add_child(v)
	var w := 3.3 if big else 1.6
	var h := 1.7 if big else 1.0
	if hang:
		var rod_h := maxf(0.1, ceil_h - lpos.y - h / 2.0)
		for sx in [-w * 0.36, w * 0.36]:
			_mcyl(v, Vector3(sx, h / 2.0 + rod_h / 2.0, 0), 0.016, rod_h, Mats.charcoal())
	_mrbox(v, Vector3(0, 0, -0.045), Vector3(w, h, 0.13), Mats.charcoal(), 0.02)
	_mquad(v, Vector3(0, 0, 0.022), Vector2(w - 0.12, h - 0.12), Mats.screen_glow())
	var hd := Label3D.new()
	hd.text = "DEPARTURES"
	hd.font_size = 54 if big else 36
	hd.pixel_size = 0.0022 if big else 0.0018
	hd.modulate = Color(0.93, 0.96, 1.0)
	hd.position = Vector3(0, h / 2.0 - 0.17, 0.03)
	v.add_child(hd)
	var rows := 8 if big else 4
	var dest := ""
	var tim := ""
	var gate := ""
	var stat := ""
	for i in rows:
		var hsh := WorldGen.h(wseed, cell.x * 3 + i, cell.y - i, 350)
		dest += AIR_DESTS[hsh % AIR_DESTS.size()] + "\n"
		tim += "%02d:%02d\n" % [(hsh >> 3) % 24, ((hsh >> 8) % 12) * 5]
		gate += "%s%d\n" % [["A", "B", "C", "D"][(hsh >> 13) % 4], 1 + ((hsh >> 15) % 28)]
		stat += AIR_STATUS[(hsh >> 19) % AIR_STATUS.size()] + "\n"
	var xs := [-1.45, -0.1, 0.5, 0.95] if big else [-0.68, -0.15, 0.12, 0.34]
	var texts := [dest, tim, gate, stat]
	for ci in 4:
		var lb := Label3D.new()
		lb.text = texts[ci]
		lb.font_size = 40 if big else 24
		lb.pixel_size = 0.0018 if big else 0.0016
		lb.modulate = Color(1.0, 0.72, 0.18)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lb.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		lb.position = Vector3(xs[ci], h / 2.0 - 0.38, 0.03)
		v.add_child(lb)


func _air_wall_fids(dir: int, plane: float) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T / 2.0)
	var along := S / 2.0 + (_r(46 + dir) - 0.5) * 4.0
	var yaw := 0.0
	var pos: Vector3
	if dir < 2:
		yaw = PI / 2.0 if n > 0.0 else -PI / 2.0
		pos = Vector3(inner + n * 0.10, 2.5, along)
	else:
		yaw = 0.0 if n > 0.0 else PI
		pos = Vector3(along, 2.5, inner + n * 0.10)
	_fids(self, pos, yaw, false, false)


## Pair of backlit advertising lightboxes.
func _air_adboxes(dir: int, plane: float) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T / 2.0)
	var idx := int(_r(50 + dir) * 3.99)
	for k in 2:
		var along := S / 2.0 + (float(k) - 0.5) * 3.4
		var fc := inner + n * 0.05
		if dir < 2:
			_box(Vector3(fc, 1.9, along), Vector3(0.08, 1.92, 1.32), Mats.charcoal(), false)
			var q := _quad(Vector3(fc + n * 0.045, 1.9, along), Vector2(1.2, 1.8), Mats.adbox(idx + k))
			q.rotation.y = PI / 2.0 if n > 0.0 else -PI / 2.0
		else:
			_box(Vector3(along, 1.9, fc), Vector3(1.32, 1.92, 0.08), Mats.charcoal(), false)
			var q := _quad(Vector3(along, 1.9, fc + n * 0.045), Vector2(1.2, 1.8), Mats.adbox(idx + k))
			q.rotation.y = 0.0 if n > 0.0 else PI


## Row of n tandem seats on a shared beam, facing local +z.
func _seat_row(p: Vector3, yaw: float, n: int, salt: int) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = yaw
	add_child(v)
	var w := 0.62 * float(n)
	_mbox(v, Vector3(0, 0.33, 0.02), Vector3(w - 0.1, 0.07, 0.09), Mats.steel())
	for sx in [-w / 2.0 + 0.45, w / 2.0 - 0.45]:
		_mbox(v, Vector3(sx, 0.16, 0.0), Vector3(0.07, 0.32, 0.52), Mats.steel())
	for i in n:
		var sx := (float(i) - float(n - 1) / 2.0) * 0.62
		var pan := _mrbox(v, Vector3(sx, 0.435, 0.05), Vector3(0.55, 0.08, 0.5), Mats.seat_black(), 0.03)
		pan.rotation.x = -0.06
		var back := _mrbox(v, Vector3(sx, 0.78, -0.235), Vector3(0.55, 0.62, 0.08), Mats.seat_black(), 0.03)
		back.rotation.x = -0.22
	for i in n + 1:
		var ax := (float(i) - float(n) / 2.0) * 0.62
		_mrbox(v, Vector3(ax, 0.615, 0.02), Vector3(0.05, 0.035, 0.44), Mats.chrome(), 0.012)
		_mbox(v, Vector3(ax, 0.47, 0.2), Vector3(0.04, 0.26, 0.04), Mats.chrome())
	# something someone meant to come back for
	if _r(salt) < 0.28:
		var bx := (float(int(_r(salt + 1) * float(n))) - float(n - 1) / 2.0) * 0.62
		_mrbox(v, Vector3(bx, 0.53, 0.05), Vector3(0.32, 0.13, 0.38), Mats.luggage(_r(salt + 2)), 0.04)
	_collider_yaw_box(p + Vector3(0, 0.55, 0), Vector3(w + 0.1, 1.1, 0.62), yaw)


func _suitcase(p: Vector3, yaw: float, salt: int, lying := false) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = yaw
	add_child(v)
	var mat := Mats.luggage(_r(salt))
	var h := 0.6 + 0.18 * _r(salt + 1)
	if lying:
		_mrbox(v, Vector3(0, 0.14, 0), Vector3(0.46, 0.26, h), mat, 0.05)
		_collider_yaw_box(p + Vector3(0, 0.15, 0), Vector3(0.5, 0.3, h + 0.05), yaw)
	else:
		_mrbox(v, Vector3(0, h / 2.0 + 0.05, 0), Vector3(0.44, h, 0.25), mat, 0.05)
		for sx in [-0.09, 0.09]:
			_mcyl(v, Vector3(sx, h + 0.19, -0.07), 0.012, 0.3, Mats.chrome())
		_mbox(v, Vector3(0, h + 0.34, -0.07), Vector3(0.21, 0.028, 0.032), Mats.charcoal())
		for sx in [-0.16, 0.16]:
			var wh := _mcyl(v, Vector3(sx, 0.05, 0.1), 0.045, 0.045, Mats.rubber_black())
			wh.rotation.z = PI / 2.0
		_collider_yaw_box(p + Vector3(0, 0.45, 0), Vector3(0.5, 0.95, 0.3), yaw)


func _air_column(p: Vector2) -> void:
	_cyl(Vector3(p.x, ceil_h / 2.0, p.y), 0.34, ceil_h, Mats.paint_white())
	_cyl(Vector3(p.x, 0.09, p.y), 0.40, 0.18, Mats.steel(), false)
	_cyl(Vector3(p.x, ceil_h - 0.15, p.y), 0.40, 0.3, Mats.charcoal(), false)


func _air_bin(p: Vector3) -> void:
	_cyl(p + Vector3(0, 0.42, 0), 0.26, 0.84, Mats.steel())
	_cyl(p + Vector3(0, 0.855, 0), 0.22, 0.03, Mats.charcoal(), false)


## Nested baggage trolley (optionally a rank of them).
func _air_trolley(p: Vector3, yaw: float, salt: int, count := 1) -> void:
	for k in count:
		var v := Node3D.new()
		v.position = p + Vector3(0, 0, 0).rotated(Vector3.UP, yaw) + Vector3(sin(yaw), 0, cos(yaw)) * (0.55 * float(k))
		v.rotation.y = yaw
		add_child(v)
		var bs := _mbox(v, Vector3(0, 0.26, 0.05), Vector3(0.6, 0.045, 0.86), Mats.steel())
		bs.rotation.x = 0.07
		_mbox(v, Vector3(0, 0.47, 0.46), Vector3(0.58, 0.42, 0.035), Mats.steel())
		for sx in [-0.27, 0.27]:
			_mcyl(v, Vector3(sx, 0.66, -0.38), 0.02, 0.8, Mats.steel())
		var hb := _mcyl(v, Vector3(0, 1.05, -0.38), 0.022, 0.58, Mats.rubber_black())
		hb.rotation.z = PI / 2.0
		for sx in [-0.24, 0.24]:
			var wh := _mcyl(v, Vector3(sx, 0.075, 0.34), 0.075, 0.05, Mats.rubber_black())
			wh.rotation.z = PI / 2.0
		var wb := _mcyl(v, Vector3(0, 0.075, -0.34), 0.075, 0.05, Mats.rubber_black())
		wb.rotation.z = PI / 2.0
		if k == 0 and _r(salt + 7) < 0.4:
			_mrbox(v, Vector3(0, 0.42, 0.05), Vector3(0.44, 0.3, 0.6), Mats.luggage(_r(salt + 8)), 0.05)
	var dv := Vector3(sin(yaw), 0, cos(yaw))
	var cc := p + dv * (0.275 * float(count - 1))
	_collider_yaw_box(cc + Vector3(0, 0.55, 0), Vector3(0.7, 1.1, 1.1 + 0.55 * float(count - 1)), yaw)


## Chrome queue posts with retractable belts strung between them.
func _stanchion_line(a: Vector3, b: Vector3, n: int) -> void:
	for i in n:
		var t := float(i) / float(n - 1)
		var pp := a.lerp(b, t)
		_cyl(pp + Vector3(0, 0.49, 0), 0.028, 0.98, Mats.chrome())
		_cyl(pp + Vector3(0, 0.015, 0), 0.16, 0.03, Mats.chrome(), false)
		_cyl(pp + Vector3(0, 0.95, 0), 0.045, 0.06, Mats.charcoal(), false)
	for i in n - 1:
		var p0 := a.lerp(b, float(i) / float(n - 1)) + Vector3(0, 0.88, 0)
		var p1 := a.lerp(b, float(i + 1) / float(n - 1)) + Vector3(0, 0.88, 0)
		var bl := _beam(p0 + (p1 - p0) * 0.06, p1 - (p1 - p0) * 0.06, 0.045, Mats.rubber_black())
		bl.scale.y = 0.022
		bl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- airport: gate ------------------------------------------------------------

func _air_gate() -> void:
	var wdir := _air_pick_wall(310)
	var yw := _air_yaw_for(wdir) if wdir >= 0 else float(int(_r(311) * 3.99)) * PI / 2.0
	var o := Vector3(S / 2.0, 0, S / 2.0)
	var code := _gate_code()
	if wdir >= 0:
		_air_window_wall(o, yw)
	# carpet island under the lounge
	var cp := _wp(o, Vector3(0, 0.008, -1.2), yw)
	var cm := _mbox(self, cp, Vector3(10.6, 0.016, 6.6), Mats.airport_carpet())
	cm.rotation.y = yw
	# gate desk off to one side, facing the seats
	_air_gate_desk(o, yw, code)
	# seating rows facing the glass
	var ri := 0
	for rz in [0.7, -1.1, -2.9]:
		for rx in [-1.9, 1.9]:
			var flip := (ri == 3) and _r(312) < 0.5
			_seat_row(_wp(o, Vector3(rx, 0, rz), yw), yw + (PI if flip else 0.0), 4, 313 + ri)
			ri += 1
	# a bag that never boarded
	if _r(318) < 0.55:
		_suitcase(_wp(o, Vector3(-2.6 + 5.2 * _r(319), 0, 1.6), yw), _r(320) * TAU, 321)


## Full-height glass curtain wall 2.2m inside the anchor wall; the strip
## behind it is the night: black apron, taxiway lights, a docked jetway.
func _air_window_wall(o: Vector3, yw: float) -> void:
	var W := Node3D.new()
	W.position = o
	W.rotation.y = yw
	add_child(W)
	var gz := 3.8   # glass plane, local z
	# mullions and transoms
	for mx in [-5.95, -4.0, -2.0, 0.0, 2.0, 4.0, 5.95]:
		_mbox(W, Vector3(mx, ceil_h / 2.0, gz), Vector3(0.09, ceil_h, 0.14), Mats.charcoal())
	_mbox(W, Vector3(0, 0.06, gz), Vector3(S, 0.12, 0.14), Mats.charcoal())
	_mbox(W, Vector3(0, ceil_h - 0.07, gz), Vector3(S, 0.14, 0.14), Mats.charcoal())
	for ty in [1.35, 2.9]:
		_mbox(W, Vector3(0, ty, gz), Vector3(S, 0.07, 0.10), Mats.charcoal())
	# the glass itself — one thin sheet, one collider
	_mbox(W, Vector3(0, ceil_h / 2.0, gz), Vector3(S - 0.1, ceil_h - 0.2, 0.024), Mats.glass())
	_collider_yaw_box(_wp(o, Vector3(0, ceil_h / 2.0, gz), yw), Vector3(S, ceil_h, 0.1), yw)
	# dark soffit over the strip so no interior ceiling reads as "outside"
	_mbox(W, Vector3(0, ceil_h - 0.10, 4.85), Vector3(S, 0.06, 2.15), Mats.charcoal())
	# side caps close the strip ends
	for sx in [-5.9, 5.9]:
		_mbox(W, Vector3(sx, ceil_h / 2.0, 4.85), Vector3(0.1, ceil_h, 2.1), Mats.charcoal())
		_collider_yaw_box(_wp(o, Vector3(sx, ceil_h / 2.0, 4.85), yw), Vector3(0.12, ceil_h, 2.1), yw)
	# apron floor and the night beyond
	var ap := _mbox(W, Vector3(0, 0.012, 4.9), Vector3(S, 0.022, 2.15), Mats.asphalt())
	ap.rotation.y = 0.0
	var night := _mquad(W, Vector3(0, ceil_h / 2.0, 5.82), Vector2(S, ceil_h), Mats.apron_night())
	night.rotation.y = PI
	# taxiway edge lights receding along the strip
	for i in 5:
		var lx := -5.0 + 2.5 * float(i)
		_msphere(W, Vector3(lx, 0.06, 5.3), 0.045, Mats.lamp_blue())
	for li in 2:
		var l := OmniLight3D.new()
		l.light_color = Color(0.3, 0.55, 1.0)
		l.light_energy = 0.35
		l.omni_range = 3.5
		l.position = Vector3(-2.5 + 5.0 * float(li), 0.4, 5.2)
		l.shadow_enabled = false
		l.distance_fade_enabled = true
		l.distance_fade_begin = 16.0
		l.distance_fade_length = 8.0
		W.add_child(l)
	_air_jetway(W)
	# most gates have their aircraft still on stand
	if _r(322) < 0.6:
		_air_docked_plane(W)
	# boarding door set into the glass, sealed
	var dx := -2.6
	for jx in [dx - 0.7, dx + 0.7]:
		_mbox(W, Vector3(jx, 1.15, gz), Vector3(0.12, 2.3, 0.18), Mats.steel())
	_mbox(W, Vector3(dx, 2.36, gz), Vector3(1.52, 0.12, 0.18), Mats.steel())
	_mbox(W, Vector3(dx, 1.15, gz + 0.02), Vector3(1.3, 2.3, 0.05), Mats.charcoal())
	_mbox(W, Vector3(dx, 1.02, gz - 0.05), Vector3(0.8, 0.06, 0.05), Mats.steel())
	_mbox(W, Vector3(dx - 0.25, 1.7, gz + 0.05), Vector3(0.3, 0.4, 0.02), Mats.glass())


## A widebody parked at the stand, seen side-on through the glass. Forced
## perspective: the fuselage is a long cylinder whose centre sits BEHIND the
## night backdrop, so only its lit flank bulges into the strip — the rest is
## depth-culled, which reads as the hull curving away into the dark. Both
## ends run past the side caps, so the aircraft is bigger than the window.
func _air_docked_plane(W: Node3D) -> void:
	var fus_y := 2.3
	var fus_z := 5.95
	var fus := _mcyl(W, Vector3(0, fus_y, fus_z), 1.15, 12.4, Mats.jetway_body())
	fus.rotation.z = PI / 2.0
	fus.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# cabin windows above the centreline — a scatter of them still warm
	for i in 15:
		var wx := -5.6 + 0.8 * float(i)
		if _r(560 + i) < 0.25:
			continue
		var lit := _r(580 + i) < 0.4
		var wmat: Material = Mats.cabin_warm() if lit else Mats.screen_dark()
		var wnd := _mbox(W, Vector3(wx, fus_y + 0.28, 4.82), Vector3(0.10, 0.14, 0.03), wmat)
		wnd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# one engine pod slung ahead of the glassline, its wing lost in the dark
	var wing := _mbox(W, Vector3(2.6, 2.0, 5.55), Vector3(2.4, 0.1, 1.1), Mats.jetway_body())
	wing.rotation.y = 0.28
	wing.rotation.z = 0.05
	wing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var nac := _mcyl(W, Vector3(2.1, 1.28, 5.5), 0.52, 1.5, Mats.jetway_body())
	nac.rotation.z = PI / 2.0
	nac.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var intake := _mcyl(W, Vector3(1.33, 1.28, 5.5), 0.44, 0.05, Mats.screen_dark())
	intake.rotation.z = PI / 2.0
	intake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# anti-collision beacon flashing on the shoulder of the hull
	var bmat: StandardMaterial3D = Mats.lamp_red().duplicate()
	var bulb := _msphere(W, Vector3(0.8, fus_y + 0.9, 5.2), 0.055, bmat)
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bc := Beacon.new()
	bc.mat = bmat
	bc.phase = _r(590) * 1.4
	bc.light_color = Color(1.0, 0.12, 0.08)
	bc.omni_range = 4.0
	bc.position = Vector3(0.8, fus_y + 0.75, 4.95)
	bc.shadow_enabled = false
	bc.distance_fade_enabled = true
	bc.distance_fade_begin = 20.0
	bc.distance_fade_length = 8.0
	W.add_child(bc)
	# faint spill of cabin light onto the apron below the windows
	var spill := OmniLight3D.new()
	spill.light_color = Color(1.0, 0.8, 0.55)
	spill.light_energy = 0.2
	spill.omni_range = 3.2
	spill.position = Vector3(-1.5, fus_y, 4.9)
	spill.shadow_enabled = false
	spill.distance_fade_enabled = true
	spill.distance_fade_begin = 16.0
	spill.distance_fade_length = 6.0
	W.add_child(spill)


## The jetway out on the apron: ribbed telescoping tunnel on its wheel bogie,
## rotunda at the far end, red beacon still breathing.
func _air_jetway(W: Node3D) -> void:
	var J := Node3D.new()
	J.position = Vector3(-0.8, 1.95, 5.15)
	J.rotation.y = 0.06
	J.rotation.z = 0.08
	W.add_child(J)
	var tube := _mcyl(J, Vector3.ZERO, 0.5, 5.6, Mats.jetway_body())
	tube.rotation.z = PI / 2.0
	# accordion ribs over the telescoping midsection
	for i in 7:
		var rx := -1.9 + 0.5 * float(i)
		var tor := MeshInstance3D.new()
		tor.mesh = TOR
		tor.material_override = Mats.charcoal()
		tor.position = Vector3(rx, 0, 0)
		tor.rotation.z = PI / 2.0
		tor.scale = Vector3(0.72, 0.5, 0.72)
		J.add_child(tor)
	# dark window band along the tunnel
	_mbox(J, Vector3(0.6, 0.18, 0.55), Vector3(2.6, 0.34, 0.04), Mats.screen_dark())
	# rotunda cab at the far end
	_mrbox(J, Vector3(-3.1, -0.1, 0), Vector3(1.35, 1.6, 1.5), Mats.jetway_body(), 0.08)
	_mbox(J, Vector3(-3.1, 0.25, 0), Vector3(1.4, 0.4, 1.4), Mats.screen_dark())
	# service door end nearest the glass
	_mrbox(J, Vector3(2.85, -0.05, 0), Vector3(0.95, 1.9, 1.05), Mats.jetway_body(), 0.05)
	# wheel bogie
	_mbox(J, Vector3(-1.0, -1.25, 0), Vector3(0.16, 1.7, 0.16), Mats.charcoal())
	var axle := _mcyl(J, Vector3(-1.0, -2.05, 0), 0.04, 0.6, Mats.charcoal())
	axle.rotation.x = PI / 2.0
	for sz in [-0.26, 0.26]:
		var wh := _mcyl(J, Vector3(-1.0, -2.05, sz), 0.3, 0.18, Mats.rubber_black())
		wh.rotation.x = PI / 2.0
	# anti-collision beacon
	_msphere(J, Vector3(0.4, 0.6, 0), 0.05, Mats.lamp_red())
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.15, 0.1)
	l.light_energy = 0.22
	l.omni_range = 2.6
	l.position = Vector3(0.4, 0.85, 0)
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 18.0
	l.distance_fade_length = 8.0
	J.add_child(l)


func _air_gate_desk(o: Vector3, yw: float, code: String) -> void:
	var v := Node3D.new()
	v.position = _wp(o, Vector3(1.7, 0, 2.4), yw)
	v.rotation.y = yw
	add_child(v)
	_mbox(v, Vector3(0, 0.06, 0), Vector3(2.3, 0.12, 0.6), Mats.charcoal())
	_mrbox(v, Vector3(0, 0.56, 0), Vector3(2.3, 1.0, 0.58), Mats.desk_white(), 0.02)
	_mbox(v, Vector3(0, 1.08, 0), Vector3(2.36, 0.04, 0.66), Mats.steel())
	# two dead monitors on poles
	for mx in [-0.5, 0.5]:
		_mcyl(v, Vector3(mx, 1.2, 0.05), 0.02, 0.2, Mats.charcoal())
		_mrbox(v, Vector3(mx, 1.44, 0.05), Vector3(0.44, 0.3, 0.035), Mats.screen_dark(), 0.008)
	_collider_yaw_box(v.position + Vector3(0, 0.6, 0), Vector3(2.3, 1.2, 0.7), yw)
	# the lit gate sign overhead
	var sv := Node3D.new()
	sv.position = _wp(o, Vector3(1.7, 3.4, 1.7), yw)
	sv.rotation.y = yw
	add_child(sv)
	var rod_h := ceil_h - 3.4 - 0.34
	for sx in [-0.5, 0.5]:
		_mcyl(sv, Vector3(sx, 0.34 + rod_h / 2.0, 0), 0.016, rod_h, Mats.charcoal())
	_mrbox(sv, Vector3.ZERO, Vector3(1.5, 0.68, 0.1), Mats.sign_navy(), 0.015)
	for sside in [-1.0, 1.0]:
		var lb := Label3D.new()
		lb.text = "Gate %s" % code
		lb.font_size = 110
		lb.pixel_size = 0.0028
		lb.modulate = Color(0.96, 0.92, 0.5)
		lb.position = Vector3(0, 0.1, sside * 0.06)
		lb.rotation.y = 0.0 if sside > 0.0 else PI
		sv.add_child(lb)
		var st := Label3D.new()
		st.text = "FLIGHT CLOSED"
		st.font_size = 56
		st.pixel_size = 0.0024
		st.modulate = Color(1.0, 0.45, 0.25)
		st.position = Vector3(0, -0.2, sside * 0.06)
		st.rotation.y = 0.0 if sside > 0.0 else PI
		sv.add_child(st)


# --- airport: concourse -------------------------------------------------------

func _air_concourse() -> void:
	# belts run along the room's LONG axis and are cut to fit between its
	# walls, so a walkway never drives into masonry
	var span := _room_span()
	var along_x := span.x >= span.y
	var yw := 0.0 if along_x else PI / 2.0
	var run := (span.x if along_x else span.y) - 2.6
	var lat := span.y if along_x else span.x
	if run < 6.0:
		_air_hall()   # too short for a walkway; furnish it as a plain hall
		return
	var o := Vector3(S / 2.0, 0, S / 2.0)
	var pair := _r(321) < 0.55 and lat >= 10.0
	var offs := [-1.35, 1.35] if pair else [0.0]
	var flow0 := 1.0 if _r(322) < 0.5 else -1.0
	for i in offs.size():
		_travelator(_wp(o, Vector3(0, 0, offs[i]), yw), yw,
			flow0 * (1.0 if i == 0 else -1.0), 323 + i, minf(10.4, run))
		_hang_sign(o + Vector3(0, 3.55, 0), yw + PI / 2.0,
			_air_zone_sign(326))
	# a seat row parked against the quiet side, only if there is room beside
	# the belts for it
	var side := lat / 2.0 - 1.6
	if _r(327) < 0.55 and side >= (3.4 if pair else 2.8):
		var sp := _wp(o, Vector3(0.8, 0, side * (1.0 if _r(329) < 0.5 else -1.0)), yw)
		_seat_row(sp, yw + PI / 2.0, 5, 328)
	# clutter keeps to the margins, well clear of the belts
	var clut := minf(side, 4.5 if pair else 3.9)
	if clut >= 2.6:
		if _r(540) < 0.5:
			_air_bin(_wp(o, Vector3(-3.5 + 7.0 * _r(541), 0, clut * (1.0 if _r(542) < 0.5 else -1.0)), yw))
		if _r(543) < 0.2:
			_suitcase(_wp(o, Vector3(-3.0 + 6.0 * _r(544), 0, clut * (1.0 if _r(545) < 0.5 else -1.0)), yw),
				_r(546) * TAU, 547)


## One moving walkway: deck, animated belt, glass balustrades, and an Area3D
## that actually carries whoever stands on it.
func _travelator(p: Vector3, yaw: float, flow: float, salt: int, L := 8.4) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = yaw
	add_child(v)
	var BW := 1.15
	_mbox(v, Vector3(0, 0.055, 0), Vector3(L, 0.11, BW + 0.7), Mats.steel())
	var belt := _mbox(v, Vector3(0, 0.117, 0), Vector3(L - 1.0, 0.014, BW), Mats.belt())
	belt.set_instance_shader_parameter("speed", flow * 0.75)
	for e in [-1.0, 1.0]:
		var ramp := _mbox(v, Vector3(e * (L / 2.0 + 0.26), 0.048, 0), Vector3(0.64, 0.02, BW + 0.7), Mats.steel())
		ramp.rotation.z = -e * 0.16
		_mbox(v, Vector3(e * (L / 2.0 - 0.30), 0.115, 0), Vector3(0.5, 0.014, BW), Mats.caution_yellow())
	for szn in [-1.0, 1.0]:
		var z: float = szn * (BW / 2.0 + 0.16)
		_mbox(v, Vector3(0, 0.32, z), Vector3(L, 0.42, 0.06), Mats.steel())
		var bg := _mbox(v, Vector3(0, 0.78, z), Vector3(L - 0.3, 0.55, 0.024), Mats.glass())
		bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var bh := _mrbox(v, Vector3(0, 1.08, z), Vector3(L, 0.075, 0.09), Mats.rubber_black(), 0.03)
		bh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for e in [-1.0, 1.0]:
			_mrbox(v, Vector3(e * (L / 2.0 - 0.06), 0.6, z), Vector3(0.1, 0.98, 0.09), Mats.rubber_black(), 0.04)
		_collider_yaw_box(_wp(p, Vector3(0, 0.6, z), yaw), Vector3(L, 1.25, 0.1), yaw)
	# deck + end ramps the player can actually walk up
	_collider_yaw_box(p + Vector3(0, 0.065, 0), Vector3(L - 0.9, 0.13, BW + 0.5), yaw)
	for e in [-1.0, 1.0]:
		_collider_rot_box(_wp(p, Vector3(e * (L / 2.0 + 0.22), 0.05, 0), yaw),
			Vector3(0.95, 0.035, BW + 0.5), Vector3(0, yaw, -e * 0.16))
	var tv := Travelator.new()
	tv.dirv = Vector3(flow, 0, 0).rotated(Vector3.UP, yaw)
	tv.speed = 0.75
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(L - 1.6, 1.6, BW)
	cs.shape = sh
	tv.add_child(cs)
	tv.position = p + Vector3(0, 0.95, 0)
	tv.rotation.y = yaw
	add_child(tv)


## Transit corridor: three chained walkways in a complete low tube. Side room
## connections get finished portals into a narrow walking margin; every other
## stretch is continuous wall, so there is no cell-end route behind a facade.
func _air_transit() -> void:
	var cdir := WorldGen.corridor(wseed, cell)
	var along_x: bool
	if cdir != 0:
		along_x = cdir == 1
	else:
		along_x = WorldGen.r01(wseed, 0, cell.y, 511) < 0.5
	var yw := 0.0 if along_x else PI / 2.0
	var o := Vector3(S / 2.0, 0, S / 2.0)
	var wall_half := 5.2
	var wh := 3.5
	for k in 3:
		var off := (float(k) - 1.0) * 3.4
		var flow := 1.0 if k % 2 == 0 else -1.0
		_travelator(_wp(o, Vector3(0, 0, off), yw), yw, flow, 512 + k, 10.4)

	# A single architectural contract drives wall cuts, returns and dressing.
	for si in 2:
		var data := _air_transit_side_data(si, along_x, wall_half)
		_air_transit_wall_side(o, yw, float(data["side"]), wh, data["bay"])
		if _r(530 + si) < 0.62:
			var at := _air_transit_ad_t(si, data["bay"])
			if at < 90.0:
				var side: float = data["side"] - signf(float(data["side"])) * 0.1
				var q := _mquad(self, _wp(o, Vector3(at, 1.9, side), yw),
					Vector2(1.2, 1.8), Mats.adbox(int(_r(534 + si) * 3.99)))
				q.rotation.y = yw + (PI if side > 0.0 else 0.0)

	# The dropped lid now reaches the continuous walls. Side portal helpers add
	# their own small ceiling patches over the remaining boundary recess.
	var sof := _mbox(self, _wp(o, Vector3(0, wh + 0.06, 0), yw),
		Vector3(S, 0.12, wall_half * 2.0 + T), Mats.airport_ceiling())
	sof.rotation.y = yw
	# Low light lines under the bulkhead — the tall terminal above stays dark.
	var pmat := Mats.air_panel()
	for li in 2:
		var lane := -1.7 if li == 0 else 1.7
		for t in [-3.0, 0.0, 3.0]:
			var st := _mbox(self, _wp(o, Vector3(t, wh - 0.03, lane), yw),
				Vector3(2.2, 0.05, 0.16), pmat)
			st.rotation.y = yw
	var l := OmniLight3D.new()
	l.light_color = Color(0.85, 0.91, 1.0)
	l.light_energy = 1.2
	l.omni_range = 11.0
	l.position = o + Vector3(0, wh - 0.5, 0)
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 22.0
	l.distance_fade_length = 8.0
	add_child(l)
	# Wayfinding over the two genuine walking lanes, tucked under the lid.
	for ki in 2:
		var sl := -1.7 if ki == 0 else 1.7
		if _r(516 + ki) < 0.55:
			_hang_sign(_wp(o, Vector3(0, 2.8, sl), yw), yw + PI / 2.0,
					_air_zone_sign(518 + ki), wh)


func _air_transit_side_data(si: int, along_x: bool, wall_half: float) -> Dictionary:
	var side := -wall_half if si == 0 else wall_half
	var sdir := (3 if si == 0 else 2) if along_x else (1 if si == 0 else 0)
	var info := WorldGen.edge_info(wseed, cell, sdir, theme)
	var bay := []
	if not info["wall"]:
		var bt: float = float(info["t"]) - 6.0 if along_x else 6.0 - float(info["t"])
		var bw := clampf(float(info["w"]) + 0.3, 4.1, 6.5)
		bay = [bt, bw]
	return {"side": side, "bay": bay}


func _air_transit_wall_side(o: Vector3, yw: float, side: float,
		wh: float, bay: Array) -> void:
	var segs := [[-6.0, 6.0]]
	if not bay.is_empty():
		segs = _cut_seg(segs, float(bay[0]) - float(bay[1]) * 0.5,
			float(bay[0]) + float(bay[1]) * 0.5)
	for sg in segs:
		_air_transit_wall_run(o, yw, side, wh, float(sg[0]), float(sg[1]))
	if not bay.is_empty():
		var bt: float = bay[0]
		var bw: float = bay[1]
		_air_transit_header(o, yw, side, wh, bt, bw)
		_air_transit_open_casing(o, yw, side, bt, bw)
		_air_transit_bay_returns(o, yw, side, wh, bt, bw)


## Full-length wall run with modular aluminium reveals, a stainless kick plate
## and a baggage-cart bumper rail. Segmentation matches its collider exactly.
func _air_transit_wall_run(o: Vector3, yw: float, side: float,
		wh: float, a: float, b: float) -> void:
	var ln := b - a
	if ln < 0.04:
		return
	var c := (a + b) * 0.5
	var wc := _wp(o, Vector3(c, wh * 0.5, side), yw)
	var wall := _mbox(self, wc, Vector3(ln, wh, T),
		Mats.airport_wall_variant(_finish_variant()))
	wall.rotation.y = yw
	_collider_yaw_box(wc, Vector3(ln, wh, T), yw)
	var inn := side - signf(side) * (T * 0.5 + 0.022)
	var kick := _mbox(self, _wp(o, Vector3(c, 0.11, inn), yw),
		Vector3(ln, 0.22, 0.045), Mats.steel())
	kick.rotation.y = yw
	var bumper := _mbox(self, _wp(o, Vector3(c, 0.78, inn - signf(side) * 0.02), yw),
		Vector3(ln, 0.055, 0.075), Mats.rubber_black())
	bumper.rotation.y = yw
	for seam in [-4.0, -2.0, 0.0, 2.0, 4.0]:
		if seam <= a + 0.05 or seam >= b - 0.05:
			continue
		var reveal := _mbox(self, _wp(o, Vector3(seam, wh * 0.5, inn), yw),
			Vector3(0.028, wh, 0.035), Mats.metal_gray())
		reveal.rotation.y = yw


func _air_transit_header(o: Vector3, yw: float, side: float,
		wh: float, t: float, width: float) -> void:
	var hh := wh - AIR_DOOR
	if hh <= 0.02:
		return
	var hp := _wp(o, Vector3(t, AIR_DOOR + hh * 0.5, side), yw)
	var head := _mbox(self, hp, Vector3(width, hh, T),
		Mats.airport_wall_variant(_finish_variant()))
	head.rotation.y = yw
	_collider_yaw_box(hp, Vector3(width, hh, T), yw)


func _air_transit_open_casing(o: Vector3, yw: float, side: float,
		t: float, width: float) -> void:
	var inn := side - signf(side) * (T * 0.5 + 0.025)
	for edge in [t - width * 0.5, t + width * 0.5]:
		var jamb := _mbox(self, _wp(o, Vector3(edge, AIR_DOOR * 0.5, inn), yw),
			Vector3(0.2, AIR_DOOR, T + 0.2), Mats.steel())
		jamb.rotation.y = yw
	var lintel := _mbox(self, _wp(o, Vector3(t, AIR_DOOR + 0.1, inn), yw),
		Vector3(width + 0.22, 0.2, T + 0.2), Mats.steel())
	lintel.rotation.y = yw
	# Small backlit identifier fixed to the portal head, facing the transit lane.
	var v := Node3D.new()
	v.position = _wp(o, Vector3(t, AIR_DOOR - 0.16, inn - signf(side) * 0.04), yw)
	v.rotation.y = yw + (PI if side > 0.0 else 0.0)
	add_child(v)
	_mrbox(v, Vector3.ZERO, Vector3(minf(width - 0.35, 2.35), 0.23, 0.05),
		Mats.sign_navy(), 0.008)
	var lb := Label3D.new()
	lb.text = "CONCOURSE ACCESS"
	lb.font_size = 42
	lb.pixel_size = 0.00165
	lb.modulate = Color(0.96, 0.92, 0.5)
	lb.position = Vector3(0, 0, 0.031)
	v.add_child(lb)


## Short returns link the low transit shell to the actual cell-edge portal.
## They close the sliver behind adjacent panels and roof the recess at 3.5m.
func _air_transit_bay_returns(o: Vector3, yw: float, side: float,
		wh: float, t: float, width: float) -> void:
	var outer := signf(side) * (S * 0.5 - T)
	var depth := absf(outer - side)
	var dc := (outer + side) * 0.5
	for edge in [t - width * 0.5, t + width * 0.5]:
		var wp := _wp(o, Vector3(edge, wh * 0.5, dc), yw)
		var ret := _mbox(self, wp, Vector3(T, wh, depth),
			Mats.airport_wall_variant(_finish_variant()))
		ret.rotation.y = yw
		_collider_yaw_box(wp, Vector3(T, wh, depth), yw)
		var inward := T * 0.5 + 0.022 if edge < t else -(T * 0.5 + 0.022)
		var kick := _mbox(self, _wp(o, Vector3(edge + inward, 0.11, dc), yw),
			Vector3(0.045, 0.22, depth), Mats.steel())
		kick.rotation.y = yw
	var roof := _mbox(self, _wp(o, Vector3(t, wh + 0.06, dc), yw),
		Vector3(width, 0.12, depth), Mats.airport_ceiling())
	roof.rotation.y = yw
	var bl := OmniLight3D.new()
	bl.light_color = Color(0.85, 0.91, 1.0)
	bl.light_energy = 0.48
	bl.omni_range = 4.6
	bl.position = _wp(o, Vector3(t, wh - 0.38, dc), yw)
	bl.shadow_enabled = false
	bl.distance_fade_enabled = true
	bl.distance_fade_begin = 18.0
	bl.distance_fade_length = 6.0
	add_child(bl)


func _air_transit_ad_t(si: int, bay: Array) -> float:
	var raw := -3.0 + 6.0 * _r(532 + si)
	var candidates := [raw, -3.9, 3.9, 0.0]
	if si == 1:
		candidates = [raw, 3.9, -3.9, 0.0]
	for t in candidates:
		if bay.is_empty() or absf(float(t) - float(bay[0])) >= float(bay[1]) * 0.5 + 0.9:
			return float(t)
	return 99.0


# --- airport: check-in --------------------------------------------------------

func _air_checkin() -> void:
	var wdir := _air_pick_wall(360)
	var yw := _air_yaw_for(wdir) if wdir >= 0 else ((PI / 2.0) if _r(361) < 0.5 else 0.0)
	var o := Vector3(S / 2.0, 0, S / 2.0)
	for di in 3:
		_checkin_desk(o, yw, -3.6 + 3.6 * float(di), 365 + di * 4)
	# the big board hanging over the queue
	_fids(self, _wp(o, Vector3(0, 3.15, 1.1), yw), yw + PI, true, true)
	# serpentine of queue barriers holding a line for no one
	_stanchion_line(_wp(o, Vector3(-4.2, 0, 1.6), yw), _wp(o, Vector3(4.2, 0, 1.6), yw), 6)
	_stanchion_line(_wp(o, Vector3(4.2, 0, 0.4), yw), _wp(o, Vector3(-4.2, 0, 0.4), yw), 6)
	if _r(374) < 0.5:
		_stanchion_line(_wp(o, Vector3(-4.2, 0, -0.8), yw), _wp(o, Vector3(4.2, 0, -0.8), yw), 6)
	if _r(375) < 0.55:
		_air_trolley(_wp(o, Vector3(-4.6 + 9.2 * _r(376), 0, -2.6), yw), _r(377) * TAU, 378, 1)


func _checkin_desk(o: Vector3, yw: float, dx: float, salt: int) -> void:
	var v := Node3D.new()
	v.position = _wp(o, Vector3(dx, 0, 3.55), yw)
	v.rotation.y = yw
	add_child(v)
	# counter facing the queue (local -z)
	_mbox(v, Vector3(0.35, 0.06, 0), Vector3(1.9, 0.12, 0.68), Mats.charcoal())
	_mrbox(v, Vector3(0.35, 0.57, 0), Vector3(1.9, 1.02, 0.66), Mats.desk_white(), 0.02)
	_mbox(v, Vector3(0.35, 1.1, 0), Vector3(1.96, 0.04, 0.74), Mats.steel())
	_collider_yaw_box(_wp(v.position, Vector3(0.35, 0.6, 0), yw), Vector3(1.9, 1.2, 0.75), yw)
	# monitor on a pole, screen to the agent side
	_mcyl(v, Vector3(0.85, 1.55, 0.1), 0.025, 0.9, Mats.metal_gray())
	var lit := _r(salt) < 0.4
	_mrbox(v, Vector3(0.85, 2.1, 0.1), Vector3(0.5, 0.34, 0.04), Mats.screen_glow() if lit else Mats.screen_dark(), 0.008)
	if lit:
		var lb := Label3D.new()
		lb.text = "CLOSED"
		lb.font_size = 40
		lb.pixel_size = 0.002
		lb.modulate = Color(1.0, 0.5, 0.25)
		lb.position = Vector3(0.85, 2.1, 0.13)
		v.add_child(lb)
	# baggage scale and the belt that climbs into the wall housing
	_mbox(v, Vector3(-0.75, 0.17, 0.35), Vector3(0.8, 0.34, 0.95), Mats.steel())
	_mbox(v, Vector3(-0.75, 0.355, 0.35), Vector3(0.68, 0.02, 0.85), Mats.rubber_black())
	var stub := _mbox(v, Vector3(-0.75, 0.62, 1.25), Vector3(0.68, 0.05, 1.0), Mats.rubber_black())
	stub.rotation.x = -0.45
	_mbox(v, Vector3(-0.75, 1.0, 1.95), Vector3(0.92, 1.9, 0.5), Mats.steel())
	for fi in 4:
		_mbox(v, Vector3(-0.99 + 0.16 * float(fi), 1.25, 1.68), Vector3(0.14, 0.5, 0.02), Mats.rubber_black())
	_collider_yaw_box(_wp(v.position, Vector3(-0.75, 0.5, 0.8), yw), Vector3(0.9, 1.0, 2.0), yw)
	# position number hanging above
	var pn := Node3D.new()
	pn.position = _wp(o, Vector3(dx + 0.35, 3.0, 3.55), yw)
	pn.rotation.y = yw
	add_child(pn)
	var rod_h := ceil_h - 3.0 - 0.26
	_mcyl(pn, Vector3(0, 0.26 + rod_h / 2.0, 0), 0.014, rod_h, Mats.charcoal())
	_mrbox(pn, Vector3.ZERO, Vector3(0.5, 0.5, 0.08), Mats.sign_navy(), 0.012)
	for sside in [-1.0, 1.0]:
		var nl := Label3D.new()
		nl.text = "%02d" % (1 + (WorldGen.h(wseed, cell.x, cell.y, salt + 2) % 24))
		nl.font_size = 90
		nl.pixel_size = 0.0026
		nl.modulate = Color(0.96, 0.92, 0.5)
		nl.position = Vector3(0, 0, sside * 0.05)
		nl.rotation.y = 0.0 if sside > 0.0 else PI
		pn.add_child(nl)


# --- airport: baggage claim ---------------------------------------------------

func _air_baggage() -> void:
	var c := Vector3(S / 2.0, 0, S / 2.0)
	# static stainless rim
	var seg := 18
	for i in seg:
		var ang := TAU * float(i) / float(seg)
		var rp := c + Vector3(cos(ang) * 2.45, 0.26, sin(ang) * 2.45)
		var b := _box(rp, Vector3(0.88, 0.52, 0.16), Mats.steel(), false)
		b.rotation.y = -(ang + PI / 2.0)
		var lip := _box(rp + Vector3(cos(ang) * 0.07, 0.27, sin(ang) * 0.07), Vector3(0.9, 0.05, 0.2), Mats.steel(), false)
		lip.rotation.y = -(ang + PI / 2.0)
	for i in 8:
		var ang := TAU * float(i) / 8.0
		_collider_yaw_box(c + Vector3(cos(ang) * 2.45, 0.35, sin(ang) * 2.45),
			Vector3(1.95, 0.7, 0.2), -(ang + PI / 2.0))
	# the bed of slats, turning forever
	var sp := Spinner.new()
	sp.speed = 0.16 if _r(379) < 0.8 else 0.0
	sp.position = c + Vector3(0, 0.42, 0)
	add_child(sp)
	var slats := 26
	for i in slats:
		var ang := TAU * float(i) / float(slats)
		var sl := _mbox(sp, Vector3(cos(ang) * 1.8, 0, sin(ang) * 1.8), Vector3(1.0, 0.028, 0.5), Mats.rubber_black())
		sl.rotation.y = -ang + 0.35
	for i in 1 + int(_r(380) * 2.0):
		var ang := _r(381 + i) * TAU
		var bag := _mrbox(sp, Vector3(cos(ang) * 1.8, 0.15, sin(ang) * 1.8),
			Vector3(0.62, 0.26, 0.42), Mats.luggage(_r(383 + i)), 0.05)
		bag.rotation.y = _r(385 + i) * TAU
	# centre island
	_cyl(c + Vector3(0, 0.5, 0), 1.05, 1.0, Mats.metal_gray())
	_cone(c + Vector3(0, 1.0, 0), 1.15, 0.55, Mats.metal_gray())
	# feed chute descending from the ceiling void, mouth over the belt
	var duct := _box(c + Vector3(0, 1.86, -3.43), Vector3(1.15, 0.55, 3.6), Mats.steel(), false)
	duct.rotation.x = 0.5
	_collider_rot_box(c + Vector3(0, 1.86, -3.43), Vector3(1.15, 0.55, 3.6), Vector3(0.5, 0, 0))
	_box(c + Vector3(0, 3.7, -5.0), Vector3(1.25, 2.6, 0.85), Mats.steel())
	for fi in 5:
		var fl := _box(c + Vector3(-0.44 + 0.22 * float(fi), 0.85, -1.78), Vector3(0.2, 0.5, 0.02), Mats.rubber_black(), false)
		fl.rotation.x = 0.4
	# belt number totem, still lit
	var tot := Vector3(c.x - 3.4, 0, c.z - 2.4)
	_box(tot + Vector3(0, 1.35, 0), Vector3(0.55, 2.7, 0.2), Mats.charcoal())
	_quad(tot + Vector3(0, 1.9, 0.104), Vector2(0.42, 0.6), Mats.screen_glow())
	var num := Label3D.new()
	num.text = "%d" % (1 + (WorldGen.h(wseed, cell.x, cell.y, 386) % 8))
	num.font_size = 220
	num.pixel_size = 0.0022
	num.modulate = Color(0.96, 0.92, 0.5)
	num.position = tot + Vector3(0, 1.9, 0.12)
	add_child(num)
	_hang_sign(c + Vector3(0.5, 3.6, 0.5), float(int(_r(387) * 3.99)) * PI / 2.0, "Baggage Claim")
	# trolley rank and strays
	if _r(388) < 0.7:
		_air_trolley(Vector3(1.6 + 1.2 * _r(389), 0, 1.5), (_r(390) - 0.5) * 0.4, 391, 2 + int(_r(392) * 2.0))
	if _r(393) < 0.6:
		_suitcase(Vector3(2.2 + 7.6 * _r(394), 0, 8.6 + 1.6 * _r(395)), _r(396) * TAU, 397, _r(398) < 0.5)
	if room_n >= 2:
		_air_baggage_large_dressing(c)


## Seating and trolley ranks scale with a merged baggage hall while the main
## carousel remains the visual anchor. The added islands sit outside its sweep.
func _air_baggage_large_dressing(c: Vector3) -> void:
	var span := _room_span()
	var spots := []
	if span.x > 12.1:
		spots.append(c + Vector3(-7.2, 0, 0))
		spots.append(c + Vector3(7.2, 0, 0))
	if span.y > 12.1:
		spots.append(c + Vector3(0, 0, -7.2))
		spots.append(c + Vector3(0, 0, 7.2))
	for i in spots.size():
		var sp: Vector3 = spots[i]
		var face := atan2(c.x - sp.x, c.z - sp.z)
		_seat_row(sp, face, 4, 430 + i * 4)
	var tp := c + Vector3(span.x * 0.5 - 2.0, 0, -span.y * 0.5 + 2.0)
	_air_trolley(tp, PI * 0.25 + (_r(448) - 0.5) * 0.3, 449,
		2 + int(_r(450) * 1.99))
	if _r(451) < 0.75:
		_suitcase(tp + Vector3(-1.2, 0, 0.7), _r(452) * TAU, 453, _r(454) < 0.4)


# --- airport: escalators ------------------------------------------------------

func _air_escalator() -> void:
	var wdir := _air_pick_wall(390)
	if wdir < 0:
		_air_hall()
		return
	var yw := _air_yaw_for(wdir)
	var o := Vector3(S / 2.0, 0, S / 2.0)
	for cx in [-1.15, 1.15]:
		_escalator_flight(o, yw, cx)
	# mezzanine landing hugging the wall
	var lp := _wp(o, Vector3(0, 2.16, 4.48), yw)
	var lm := _mbox(self, lp, Vector3(5.6, 0.18, 2.75), Mats.steel())
	lm.rotation.y = yw
	_collider_yaw_box(lp, Vector3(5.6, 0.18, 2.75), yw)
	# glass rail along the landing front, gaps at the flight mouths
	for seg in [[-2.8, -1.77], [-0.53, 0.53], [1.77, 2.8]]:
		var sc: float = (seg[0] + seg[1]) / 2.0
		var sl: float = seg[1] - seg[0]
		_air_rail(_wp(o, Vector3(sc, 0, 3.14), yw), yw + PI / 2.0, sl)
	for sxn in [-2.77, 2.77]:
		_air_rail(_wp(o, Vector3(sxn, 0, 4.48), yw), yw, 2.7)
	# roller shutter sealing whatever the mezzanine led to; a solid backing
	# panel sits behind the ribs so no light stripes the wall through the gaps
	var bk := _mbox(self, _wp(o, Vector3(0, 3.55, 5.79), yw), Vector3(4.9, 2.6, 0.05), Mats.charcoal())
	bk.rotation.y = yw
	for i in 14:
		var rb := _mbox(self, _wp(o, Vector3(0, 2.42 + 0.17 * float(i), 5.72), yw), Vector3(4.9, 0.155, 0.06), Mats.metal_gray())
		rb.rotation.y = yw
		rb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for gxn in [-2.5, 2.5]:
		var gd := _mbox(self, _wp(o, Vector3(gxn, 3.55, 5.72), yw), Vector3(0.14, 2.6, 0.12), Mats.charcoal())
		gd.rotation.y = yw
		gd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_collider_yaw_box(_wp(o, Vector3(0, 3.55, 5.72), yw), Vector3(5.2, 2.7, 0.15), yw)
	var cl := Label3D.new()
	cl.text = "CLOSED FOR MAINTENANCE"
	cl.font_size = 40
	cl.pixel_size = 0.002
	cl.modulate = Color(0.85, 0.85, 0.85, 0.8)
	cl.position = _wp(o, Vector3(0, 3.3, 5.62), yw)
	cl.rotation.y = yw + PI
	add_child(cl)
	# support columns under the landing lip
	for sxn in [-2.5, 2.5]:
		var scp := _wp(o, Vector3(sxn, 1.05, 3.3), yw)
		_cyl(scp, 0.11, 2.1, Mats.steel())
	# out-of-service barrier across one flight
	var bx := -1.15 if _r(399) < 0.5 else 1.15
	_stanchion_line(_wp(o, Vector3(bx - 0.6, 0, -2.3), yw), _wp(o, Vector3(bx + 0.6, 0, -2.3), yw), 2)


## Landing-edge glass rail segment, centred at p, running along local x.
func _air_rail(p: Vector3, yaw: float, ln: float) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = yaw
	add_child(v)
	var gl := _mbox(v, Vector3(0, 2.72, 0), Vector3(ln, 0.9, 0.028), Mats.glass_tint())
	gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var hr := _mrbox(v, Vector3(0, 3.2, 0), Vector3(ln + 0.05, 0.07, 0.08), Mats.rubber_black(), 0.03)
	hr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_collider_yaw_box(p + Vector3(0, 2.85, 0), Vector3(ln, 1.3, 0.1), yaw)


## One frozen escalator flight rising toward local +z from z -1.1 to the
## landing at z 3.1, y 2.25. Steps are dressing; a hidden slope does the work.
func _escalator_flight(o: Vector3, yw: float, cx: float) -> void:
	var v := Node3D.new()
	v.position = _wp(o, Vector3(cx, 0, 0), yw)
	v.rotation.y = yw
	add_child(v)
	var ang := 0.475   # atan2(2.25, 4.38)
	# steps
	for i in 12:
		var sy := 0.1875 * float(i + 1)
		var sz := -1.1 + 0.36 * float(i) + 0.18
		_mbox(v, Vector3(0, sy - 0.11, sz), Vector3(1.0, 0.22, 0.38), Mats.charcoal())
		_mbox(v, Vector3(0, sy - 0.008, sz + 0.155), Vector3(0.96, 0.014, 0.05), Mats.caution_yellow())
	# landing plates
	_mbox(v, Vector3(0, 0.03, -1.62), Vector3(1.24, 0.06, 0.75), Mats.steel())
	_mbox(v, Vector3(0, 2.22, 3.03), Vector3(1.24, 0.07, 0.5), Mats.steel())
	# balustrades: skirt, tinted glass, black handrail. The thin pieces never
	# cast shadows — the room light would smear them into long streaks across
	# the walls.
	for sxn in [-0.62, 0.62]:
		var sk := _mbox(v, Vector3(sxn, 1.23, 0.95), Vector3(0.07, 0.5, 5.1), Mats.steel())
		sk.rotation.x = -ang
		var gl := _mbox(v, Vector3(sxn, 1.78, 0.95), Vector3(0.026, 0.75, 4.85), Mats.glass_tint())
		gl.rotation.x = -ang
		gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var hr := _mrbox(v, Vector3(sxn, 2.2, 0.95), Vector3(0.085, 0.075, 5.15), Mats.rubber_black(), 0.03)
		hr.rotation.x = -ang
		hr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# horizontal handrail stubs at both ends
		var s1 := _mrbox(v, Vector3(sxn, 0.98, -1.75), Vector3(0.085, 0.075, 0.6), Mats.rubber_black(), 0.03)
		s1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var s2 := _mrbox(v, Vector3(sxn, 3.2, 3.35), Vector3(0.085, 0.075, 0.5), Mats.rubber_black(), 0.03)
		s2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# newel posts
		_mbox(v, Vector3(sxn, 0.5, -1.95), Vector3(0.06, 0.96, 0.06), Mats.steel())
		_mbox(v, Vector3(sxn, 2.25 + 0.47, 3.45), Vector3(0.06, 0.96, 0.06), Mats.steel())
		_collider_rot_box(_wp(v.position, Vector3(sxn, 1.75, 0.95), yw),
			Vector3(0.1, 1.6, 5.1), Vector3(-ang, yw, 0))
	# truss cladding underneath
	var tr := _mbox(v, Vector3(0, 0.52, 0.95), Vector3(1.36, 0.4, 5.15), Mats.jetway_body())
	tr.rotation.x = -ang
	# the walkable slope
	_collider_rot_box(_wp(v.position, Vector3(0, 1.03, 0.95), yw),
		Vector3(1.15, 0.2, 4.95), Vector3(-ang, yw, 0))
	_collider_yaw_box(_wp(v.position, Vector3(0, 0.015, -1.62), yw), Vector3(1.24, 0.03, 0.8), yw)


# --- airport: hall & common ---------------------------------------------------

func _air_hall() -> void:
	# the overflow hall: seating for a delay that outlived its passengers
	# (a portal claims the middle of the room when one is open here)
	var span := _room_span()
	var mx := span.x / 2.0 - 2.4
	var mz := span.y / 2.0 - 2.4
	if portal_dest < 0 and _r(400) < 0.6 and mx > 0.5 and mz > 0.5:
		# rows sit square to the room and clear of its walls
		_seat_row(Vector3(S / 2.0 + (_r(401) - 0.5) * 2.0 * mx, 0,
			S / 2.0 + (_r(402) - 0.5) * 2.0 * mz),
			float(int(_r(403) * 3.99)) * PI / 2.0, 5, 404)
	if _r(405) < 0.4:
		_planter(Vector3(2.6 + 6.8 * _r(406), 0, 2.6 + 6.8 * _r(407)))
	if portal_dest < 0 and _r(408) < 0.3:
		# wet floor sign guarding a dry floor
		var p := Vector3(3.0 + 6.0 * _r(409), 0, 3.0 + 6.0 * _r(410))
		_cc0_prop("WetFloorSign_01", p, _r(411) * TAU)
		_collider_box(p + Vector3(0, 0.3, 0), Vector3(0.32, 0.62, 0.36))
	if portal_dest < 0 and _r(411) < 0.35:
		_fids(self, Vector3(2.5 + 7.0 * _r(412), 2.6, 2.5 + 7.0 * _r(413)),
			float(int(_r(414) * 3.99)) * PI / 2.0, true, true)


## Landmark: a shuttered food court. Three distinct concession fronts frame
## a sparse field of real tables; the central aisle stays clear enough to see
## the dead menu boards from the adjoining concourse.
func _air_foodcourt() -> void:
	var c := Vector3(S / 2.0, 0, S / 2.0)
	var names := ["SKYLINE GRILL", "COFFEE / TEA", "FRESH EXPRESS"]
	for i in 3:
		var x := -6.6 + 6.6 * float(i)
		var kp := c + Vector3(x, 0, -8.5)
		_rbox(kp + Vector3(0, 0.65, 0), Vector3(5.4, 1.3, 1.35), Mats.jetway_body(), 0.03)
		# Corrugated shutter, counter and a black menu strip.
		for sl in 8:
			_box(kp + Vector3(0, 1.22 + 0.22 * float(sl), 0.69),
				Vector3(5.0, 0.12, 0.04), Mats.metal_gray(), false)
		_rbox(kp + Vector3(0, 1.0, 1.0), Vector3(5.2, 0.12, 0.78), Mats.steel(), 0.025)
		_box(kp + Vector3(0, 3.45, 0.72), Vector3(4.7, 0.65, 0.08), Mats.charcoal(), false)
		var sign := Label3D.new()
		sign.text = names[i]
		sign.font_size = 96
		sign.pixel_size = 0.0025
		sign.modulate = Color(0.72, 0.88, 1.0) if i != 1 else Color(1.0, 0.72, 0.34)
		sign.position = kp + Vector3(0, 3.46, 0.78)
		add_child(sign)
		_collider_box(kp + Vector3(0, 1.3, 0), Vector3(5.5, 2.6, 1.5))
	# Four battered public tables, deliberately asymmetrical around the aisle.
	var table_offsets: Array[Vector3] = [Vector3(-5.4, 0, -1.8), Vector3(4.8, 0, -2.0),
		Vector3(-4.5, 0, 4.4), Vector3(5.6, 0, 4.0)]
	for i in 4:
		var tp: Vector3 = c + table_offsets[i]
		var yaw := (0.0 if i % 2 == 0 else PI / 2.0) + (_r(430 + i) - 0.5) * 0.15
		_cc0_prop("wooden_picnic_table", tp, yaw)
		_collider_yaw_box(tp + Vector3(0, 0.4, 0), Vector3(2.3, 0.8, 3.1), yaw)
	# Cleaning and service equipment gives the set piece a second read.
	var cartp := c + Vector3(8.0, 0, 7.6)
	_cc0_prop("CoffeeCart_01", cartp, -PI / 2.0)
	_collider_yaw_box(cartp + Vector3(0, 0.85, 0), Vector3(2.2, 1.7, 1.1), -PI / 2.0)
	var wetp := c + Vector3(0.8, 0, 5.2)
	_cc0_prop("WetFloorSign_01", wetp, _r(438) * TAU)
	_collider_box(wetp + Vector3(0, 0.3, 0), Vector3(0.32, 0.62, 0.36))
	_hang_sign(c + Vector3(0, 3.7, 6.4), 0.0, "FOOD COURT")


func _air_common() -> void:
	# structural columns in the open styles
	if style == WorldGen.AIR_CONCOURSE or style == WorldGen.AIR_HALL \
			or style == WorldGen.AIR_BAGGAGE or style == WorldGen.AIR_FOODCOURT:
		for p in [Vector2(1.7, 1.7), Vector2(10.3, 1.7), Vector2(1.7, 10.3), Vector2(10.3, 10.3)]:
			if WorldGen.r01(wseed, cell.x + int(p.x), cell.y + int(p.y), 330) < 0.5:
				_air_column(p)
	# random scatter never lands in cells with belts — a suitcase parked on a
	# moving walkway pins whoever it carries into it
	var has_belts := style == WorldGen.AIR_TRANSIT or style == WorldGen.AIR_CONCOURSE
	if not has_belts and _r(334) < 0.5:
		_air_bin(Vector3(2.6 + 6.8 * _r(335), 0, 2.6 + 6.8 * _r(336)))
	# a suitcase standing perfectly upright, no owner in any direction
	if not has_belts and style != WorldGen.AIR_ESCALATOR and _r(337) < 0.18:
		_suitcase(Vector3(2.6 + 6.8 * _r(338), 0, 2.6 + 6.8 * _r(339)), _r(340) * TAU, 341)
	# in baggage claim, someone's trunk lies open and picked through
	if style == WorldGen.AIR_BAGGAGE and _r(345) < 0.4:
		var vsp := Vector3(2.4 + 7.2 * _r(346), 0, 2.4 + 7.2 * _r(347))
		var vsy := _r(348) * TAU
		_cc0_prop("vintage_suitcase", vsp, vsy)
		_collider_yaw_box(vsp + Vector3(0, 0.3, 0), Vector3(1.62, 0.58, 0.26), vsy)
	# PA speakers live in the busy styles
	var wants_pa := style == WorldGen.AIR_GATE or style == WorldGen.AIR_CHECKIN \
		or style == WorldGen.AIR_BAGGAGE or style == WorldGen.AIR_FOODCOURT
	if wants_pa and _r(342) < 0.5:
		var snd := AirportSounds.new()
		snd.position = Vector3(S / 2.0, 0, S / 2.0)
		add_child(snd)


## Usable rectangle of this room, in metres, centred on room_centre. An
## L-shaped room reports only its root cell, since that is the largest part
## guaranteed to be free of walls.
func _room_members() -> Array:
	var out := []
	# Merges only reach one cell toward -x/-z, while a 2x2 hall reaches one
	# toward +x/+z. This small scan covers every legal generated room shape.
	for mx in range(room_root.x - 1, room_root.x + 2):
		for mz in range(room_root.y - 1, room_root.y + 2):
			var candidate := Vector2i(mx, mz)
			if WorldGen.room_id(wseed, candidate) == room_root:
				out.append(candidate)
	return out


## Local furnishing-space centre of one member cell. The later room-centre
## shift maps this point back onto that cell in world space, including L rooms.
func _room_member_local(member: Vector2i) -> Vector3:
	var rc := WorldGen.room_centre(wseed, room_root)
	return Vector3(6.0 + float(member.x) * S + S / 2.0 - rc.x, 0,
		6.0 + float(member.y) * S + S / 2.0 - rc.y)


func _room_span() -> Vector2:
	if room_n >= 4:
		return Vector2(24.0, 24.0)
	var mx := WorldGen.merge_dir(wseed, Vector2i(room_root.x - 1, room_root.y)) == 0
	var mz := WorldGen.merge_dir(wseed, Vector2i(room_root.x, room_root.y - 1)) == 2
	if mx and mz:
		return Vector2(12.0, 12.0)
	if mx:
		return Vector2(24.0, 12.0)
	if mz:
		return Vector2(12.0, 24.0)
	return Vector2(12.0, 12.0)


## Interior partition splitting a single-cell room in two, with a doorway
## through it — this is where the genuinely small rooms come from.
func _partition(along_x: bool, off: float) -> void:
	# slide the partition to a position that clears every doorway it meets;
	# if there is nowhere clean, this room simply does not get partitioned
	var chosen := WorldGen.partition_offset(wseed, cell, theme, along_x, off)
	if chosen < 0.0:
		# blocked on this axis — a partition across the other one may fit
		along_x = not along_x
		chosen = WorldGen.partition_offset(wseed, cell, theme, along_x, off)
	if chosen < 0.0:
		return
	off = chosen
	var wmat: Material = Mats.wallpaper_variant(_finish_variant())
	if theme == 1:
		wmat = Mats.office_wall_variant(_finish_variant())
	elif theme == 4:
		wmat = Mats.airport_wall_variant(_finish_variant())
	elif theme == 5:
		wmat = _asy_wall_mat()
	elif theme == 6:
		wmat = _sch_wall_mat()
	var h := ceil_h
	var dt := lerpf(2.6, 9.4, _r(620))     # doorway centre along the partition
	var dw := 1.15
	var segs := [[0.0, dt - dw / 2.0], [dt + dw / 2.0, S]]
	for sg in segs:
		var a: float = sg[0]
		var b: float = sg[1]
		if b - a < 0.05:
			continue
		var c := (a + b) * 0.5
		if along_x:
			_box(Vector3(c, h / 2.0, off), Vector3(b - a, h, 0.14), wmat)
		else:
			_box(Vector3(off, h / 2.0, c), Vector3(0.14, h, b - a), wmat)
	# header over the doorway, and a casing around it
	var head_h := h - DOOR_TOP
	if head_h > 0.05:
		if along_x:
			_box(Vector3(dt, DOOR_TOP + head_h / 2.0, off), Vector3(dw, head_h, 0.14), wmat)
		else:
			_box(Vector3(off, DOOR_TOP + head_h / 2.0, dt), Vector3(0.14, head_h, dw), wmat)
	var cmat: Material = Mats.paint_white() if theme == 1 else (Mats.steel() if theme == 4 else (Mats.asy_metal_green() if theme == 5 else \
		(Mats.sch_red() if theme == 6 else Mats.darkwood())))
	for sside in [-1.0, 1.0]:
		if along_x:
			_box(Vector3(dt + sside * dw / 2.0, DOOR_TOP / 2.0, off), Vector3(0.1, DOOR_TOP, 0.2), cmat, false)
		else:
			_box(Vector3(off, DOOR_TOP / 2.0, dt + sside * dw / 2.0), Vector3(0.2, DOOR_TOP, 0.1), cmat, false)
	if along_x:
		_box(Vector3(dt, DOOR_TOP + 0.06, off), Vector3(dw + 0.2, 0.12, 0.2), cmat, false)
	else:
		_box(Vector3(off, DOOR_TOP + 0.06, dt), Vector3(0.2, 0.12, dw + 0.2), cmat, false)


## Furniture scaled to a small room: a couple of pieces against the walls,
## never a set piece that would burst through the partition.
func _small_room_props(along_x: bool, off: float) -> void:
	var halves := [[0.6, off - 0.6], [off + 0.6, S - 0.6]]
	var idx := 0
	for hf in halves:
		var a: float = hf[0]
		var b: float = hf[1]
		if b - a < 2.0:
			idx += 1
			continue
		var t := lerpf(a + 0.9, b - 0.9, _r(630 + idx))
		var u := lerpf(2.0, 10.0, _r(634 + idx))
		var p := Vector3(u, 0, t) if along_x else Vector3(t, 0, u)
		var pick := _r(638 + idx)
		match theme:
			1:
				if pick < 0.45:
					_shelf_unit(p, along_x, 640 + idx * 3)
				elif pick < 0.8:
					_office_desk_small(p, _r(644 + idx) * TAU)
				else:
					_copier(p, 646 + idx)
			4:
				if pick < 0.5:
					_seat_row(p, _r(644 + idx) * TAU, 3, 648 + idx * 3)
				elif pick < 0.8:
					_air_bin(p)
				else:
					_suitcase(p, _r(645 + idx) * TAU, 652 + idx, false)
			6:
				if pick < 0.34:
					_sch_desk_row(p, PI / 2.0 if along_x else 0.0, 2, 640 + idx * 3)
				elif pick < 0.58:
					_shelf_unit(p, along_x, 642 + idx * 3)
				elif pick < 0.8:
					_sch_stack_chairs(p, _r(644 + idx) * TAU, 646 + idx)
				else:
					_sch_trolley(p, _r(645 + idx) * TAU)
			5:
				# bed runs along the partition so it cannot poke through it
				if pick < 0.4:
					_asy_bed(p, (PI / 2.0 if along_x else 0.0) + (PI if _r(650 + idx) < 0.5 else 0.0), 652 + idx)
				elif pick < 0.6:
					_asy_wheelchair(p, _r(644 + idx) * TAU)
				elif pick < 0.8:
					_asy_chair(p, _r(645 + idx) * TAU, _r(646 + idx) < 0.2)
				else:
					_asy_papers(p, 654 + idx, 5)
					_asy_medbox(p + Vector3(0.4, 0, 0.25), _r(656 + idx) * TAU)
			_:
				if pick < 0.4:
					_planter(p)
				elif pick < 0.75:
					_chair_at(p, _r(644 + idx) * TAU, Mats.velvet())
				else:
					_sofa(p + Vector3(0, 0, 0), 1.0)
		idx += 1


## A single desk with a terminal — for rooms too small for a cluster.
func _office_desk_small(p: Vector3, yaw: float) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = yaw
	add_child(v)
	_mrbox(v, Vector3(0, 0.73, 0), Vector3(1.4, 0.035, 0.72), Mats.desk_white(), 0.012)
	for sx in [-0.62, 0.62]:
		_mrbox(v, Vector3(sx, 0.355, 0), Vector3(0.04, 0.71, 0.66), Mats.desk_white(), 0.008)
	_collider_yaw_box(p + Vector3(0, 0.4, 0), Vector3(1.4, 0.8, 0.75), yaw)
	_vt100(p + Vector3(0, 0, 0), yaw)
	_chair_at(p + Vector3(sin(yaw) * 0.95, 0, cos(yaw) * 0.95), yaw + PI, Mats.fabric_charcoal())


# --- portals ------------------------------------------------------------------

## A swirling tear in the middle of the room, tinted for wherever it goes.
## The Area3D hands the player to main when they step in.
func _build_portal(dest: int) -> void:
	var c := Vector3(S / 2.0, 0, S / 2.0)
	var pt := Portal.new()
	pt.dest = dest
	pt.cellv = cell
	pt.position = c
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.0, 2.3, 1.0)
	cs.shape = sh
	cs.position = Vector3(0, 1.2, 0)
	pt.add_child(cs)
	add_child(pt)
	# the swirl itself — billboard quad, scaled in-shader
	var disc := MeshInstance3D.new()
	disc.mesh = QUAD
	disc.material_override = Mats.portal(dest)
	disc.position = Vector3(0, 1.35, 0)
	disc.scale = Vector3(2.3, 2.3, 1.0)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pt.add_child(disc)
	# glow pooled on the floor
	var fl := MeshInstance3D.new()
	fl.mesh = QUAD
	fl.material_override = Mats.portal_floor(dest)
	fl.position = Vector3(0, 0.03, 0)
	fl.rotation.x = -PI / 2.0
	fl.scale = Vector3(3.2, 3.2, 1.0)
	fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pt.add_child(fl)
	# three sparks in orbit
	var orb := Node3D.new()
	orb.position = Vector3(0, 1.35, 0)
	pt.add_child(orb)
	pt.sparks = orb
	for i in 3:
		var ang := TAU * float(i) / 3.0
		var sp := MeshInstance3D.new()
		sp.mesh = SPH
		sp.material_override = Mats.portal_spark(dest)
		sp.position = Vector3(cos(ang) * 1.15, sin(ang * 2.0) * 0.45, sin(ang) * 1.15)
		sp.scale = Vector3.ONE * 0.08
		sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		orb.add_child(sp)
	# light of the other place leaking through
	var l := OmniLight3D.new()
	l.light_color = Mats.PORTAL_COLS[dest][0]
	l.light_energy = 1.1
	l.omni_range = 6.5
	l.position = Vector3(0, 1.5, 0)
	l.shadow_enabled = false
	l.distance_fade_enabled = true
	l.distance_fade_begin = 22.0
	l.distance_fade_length = 8.0
	pt.add_child(l)
	var hum := AudioStreamPlayer3D.new()
	hum.stream = SoundBank.portal_hum()
	hum.unit_size = 3.0
	hum.max_distance = 18.0
	hum.volume_db = -9.0
	hum.bus = "Hall"
	hum.autoplay = true
	hum.position = Vector3(0, 1.35, 0)
	pt.add_child(hum)


# --- vegas: grand chandelier is above; shared below --------------------------


# --- asylum ------------------------------------------------------------------
# Downloaded CC0 kit: photo textures (ambientCG) on the structure, glTF props
# (Poly Haven) for beds, wheelchairs, chairs and desks; everything the models
# don't cover — restraint tables, ECT carts, tubs, straitjackets — is built
# from primitives dressed in the same textures.

const ASY_SCRAWLS := ["LET ME OUT", "THEY LISTEN AT NIGHT", "NO ONE LEFT",
	"I AM NOT SICK", "IT WATCHES THE DOOR", "ROOM 9 ROOM 9 ROOM 9",
	"DONT SLEEP HERE", "WHERE DID EVERYONE GO", "HE COUNTS US AT NIGHT",
	"THE TREATMENT HELPS", "ALL OF US ARE STILL HERE"]
const ASY_ZONE_SIGNS := [
	["WARD 3", "WARD 7", "SOLITARY", "DAY ROOM"],
	["HYDROTHERAPY", "TREATMENT", "NO ADMITTANCE", "SURGERY"],
	["ADMISSIONS", "RECORDS", "ADMINISTRATION", "VISITORS"],
]

static var _asy_scenes := {}
static var _cc0_scenes := {}


static func _prop_scene(path: String) -> PackedScene:
	var status := ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS \
			or status == ResourceLoader.THREAD_LOAD_LOADED:
		return ResourceLoader.load_threaded_get(path) as PackedScene
	return load(path) as PackedScene


## Instance a downloaded glTF prop. Scenes are load()-cached, so each model's
## meshes and textures exist once no matter how many chunks place it.
func _asy_model(mname: String, pos: Vector3, yaw: float) -> Node3D:
	var ps: PackedScene = _asy_scenes.get(mname)
	if ps == null:
		ps = _prop_scene("res://models/asylum/%s/%s_1k.gltf" % [mname, mname])
		_asy_scenes[mname] = ps
	var inst: Node3D = ps.instantiate()
	inst.position = pos
	inst.rotation.y = yaw
	add_child(inst)
	return inst


## Same, for the shared CC0 prop pool every theme draws from.
func _cc0_prop(mname: String, pos: Vector3, yaw: float, scl := 1.0) -> Node3D:
	var ps: PackedScene = _cc0_scenes.get(mname)
	if ps == null:
		ps = _prop_scene("res://models/cc0/%s/%s_1k.gltf" % [mname, mname])
		_cc0_scenes[mname] = ps
	var inst: Node3D = ps.instantiate()
	inst.position = pos
	inst.rotation.y = yaw
	if scl != 1.0:
		inst.scale = Vector3.ONE * scl
	add_child(inst)
	return inst


func _asy_tiled_room() -> bool:
	return style == WorldGen.ASY_TREATMENT or style == WorldGen.ASY_HYDRO


func _asy_wall_mat() -> Material:
	if _asy_tiled_room():
		return Mats.asy_tile()
	return Mats.asy_wall() if _r(47) < 0.72 else Mats.asy_wall_sick()


## Slide a wall-hugging prop along wall `dir` so it cannot block the doorway —
## a bed in front of a room's only door would seal it for good.
func _asy_wall_clear(dir: int, want: float, span: float) -> float:
	var info := WorldGen.edge_info(wseed, cell, dir, theme)
	if info["wall"] or info["full_open"]:
		return want
	var t: float = info["t"]
	var hw: float = float(info["w"]) * 0.5 + 0.6 + span * 0.5
	if absf(want - t) >= hw:
		return want
	var cand := t + hw if want >= t else t - hw
	if cand < 1.2 or cand > S - 1.2:
		cand = t + hw if cand < 1.2 else t - hw
	return clampf(cand, 1.2, S - 1.2)


func _asy_sounds() -> void:
	var snd := AsylumSounds.new()
	snd.position = Vector3(S / 2.0, 1.4, S / 2.0)
	add_child(snd)


func _asy_no_shadows(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_asy_no_shadows(c)


# --- asylum: lighting ---------------------------------------------------------

func _asy_lighting() -> void:
	var is_spawn := cell == Vector2i.ZERO
	var dead := (not is_spawn) and _r(8) < 0.13
	var flicker := (not is_spawn) and (not dead) and _r(9) < 0.30
	var pmat: StandardMaterial3D
	if dead:
		pmat = Mats.panel_dead()
	elif flicker:
		pmat = Mats.asy_panel().duplicate()
	else:
		pmat = Mats.asy_panel()
	var pts := [Vector2(3.6, 6.0), Vector2(8.4, 6.0)]
	if style == WorldGen.ASY_CORRIDOR:
		var cdir := WorldGen.corridor(wseed, cell)
		if cdir == 1:
			pts = [Vector2(2.4, 6.0), Vector2(6.0, 6.0), Vector2(9.6, 6.0)]
		else:
			pts = [Vector2(6.0, 2.4), Vector2(6.0, 6.0), Vector2(6.0, 9.6)]
	for pt in pts:
		_asy_fixture(Vector3(pt.x, 0, pt.y), pmat)
	if dead:
		return
	var tall := ceil_h > 4.0
	var light := _make_main_light(flicker, pmat, 1.8 if tall else 1.35)
	light.light_color = Color(0.8, 0.94, 0.72)
	light.omni_range = 13.5 if tall else 11.5
	light.position = Vector3(S / 2.0, ceil_h - 0.55, S / 2.0)
	light.shadow_enabled = true
	light.distance_fade_enabled = true
	light.distance_fade_begin = 22.0
	light.distance_fade_length = 8.0
	light.distance_fade_shadow = 16.0
	add_child(light)


## Real twin-tube fixture on rusted drop rods, lens panel underneath. Thin
## fixture parts must not cast — the room omni would smear them into streaks.
func _asy_fixture(at: Vector3, pmat: Material) -> void:
	var drop := 0.22
	var y := ceil_h - drop
	var fixture := _asy_model("mounted_fluorescent_lights", Vector3(at.x, y, at.z), 0.0)
	_asy_no_shadows(fixture)
	for dz in [-0.26, 0.26]:
		var rod := _cyl(Vector3(at.x, y + drop / 2.0, at.z + dz), 0.012, drop, Mats.asy_metal(), false)
		rod.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lens := _box(Vector3(at.x, y - 0.045, at.z), Vector3(0.8, 0.02, 0.55), pmat, false)
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- asylum: props ------------------------------------------------------------

## Rusty hospital bed frame (model) + a stained mattress most of the time.
func _asy_bed(p: Vector3, yaw: float, salt: int) -> void:
	_asy_model("old_bed_frame", p, yaw)
	_collider_yaw_box(p + Vector3(0, 0.6, 0), Vector3(0.95, 1.2, 2.05), yaw)
	if _r(salt) >= 0.8:
		return
	var v := Node3D.new()
	v.position = p
	v.rotation.y = yaw
	add_child(v)
	var mt := _mrbox(v, Vector3(0, 0.52, 0.03), Vector3(0.8, 0.15, 1.78), Mats.asy_cloth(), 0.05)
	mt.rotation.y = (_r(salt + 1) - 0.5) * 0.08
	if _r(salt + 2) < 0.5:
		_mrbox(v, Vector3(0, 0.63, -0.68), Vector3(0.52, 0.09, 0.34), Mats.asy_canvas(), 0.04)


## Wheeled stretcher, straps still across the mattress.
func _asy_gurney(p: Vector3, yaw: float, salt: int) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = yaw
	add_child(v)
	_mrbox(v, Vector3(0, 0.8, 0), Vector3(0.64, 0.05, 1.9), Mats.asy_metal(), 0.02)
	_mrbox(v, Vector3(0, 0.9, 0), Vector3(0.58, 0.13, 1.8), Mats.asy_cloth(), 0.05)
	for sz in [-0.38, 0.3]:
		_mbox(v, Vector3(0, 0.97, sz), Vector3(0.62, 0.02, 0.09), Mats.charcoal())
	for lx in [-0.26, 0.26]:
		for lz in [-0.78, 0.78]:
			_mcyl(v, Vector3(lx, 0.45, lz), 0.022, 0.72, Mats.asy_metal())
			_msphere(v, Vector3(lx, 0.07, lz), 0.07, Mats.charcoal())
	if _r(salt) < 0.4:
		# sheet hanging half off — someone left in a hurry
		var sh := _mrbox(v, Vector3(0.18, 0.78, 0.5), Vector3(0.5, 0.35, 0.03), Mats.asy_canvas(), 0.02)
		sh.rotation.z = 0.35
	_collider_yaw_box(p + Vector3(0, 0.55, 0), Vector3(0.7, 1.1, 1.95), yaw)


## The centrepiece: a fixed restraint table, leather straps buckled shut.
func _asy_restraint_table(p: Vector3, yaw: float) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = yaw
	add_child(v)
	_mbox(v, Vector3(0, 0.3, 0), Vector3(0.5, 0.6, 0.9), Mats.asy_metal())
	_mrbox(v, Vector3(0, 0.72, 0), Vector3(0.85, 0.09, 2.0), Mats.asy_metal(), 0.02)
	_mrbox(v, Vector3(0, 0.8, 0.04), Vector3(0.74, 0.08, 1.82), Mats.asy_canvas(), 0.04)
	_mrbox(v, Vector3(0, 0.86, -0.78), Vector3(0.4, 0.07, 0.26), Mats.asy_canvas(), 0.03)
	for sz in [-0.42, 0.08, 0.56]:
		_mbox(v, Vector3(0, 0.85, sz), Vector3(0.92, 0.02, 0.1), Mats.charcoal())
		_mbox(v, Vector3(0.42, 0.85, sz), Vector3(0.06, 0.03, 0.05), Mats.steel())
	for sx in [-0.44, 0.44]:
		var strap := _mbox(v, Vector3(sx, 0.6, 0.28), Vector3(0.025, 0.34, 0.09), Mats.charcoal())
		strap.rotation.x = (0.2 if sx > 0.0 else -0.15)
	_collider_yaw_box(p + Vector3(0, 0.45, 0), Vector3(0.9, 0.9, 2.0), yaw)


## Electroshock station: instrument cart, dial box, two paddles on a wire.
func _asy_ect(p: Vector3, yaw: float, salt: int) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = yaw
	add_child(v)
	for sy in [0.34, 0.72]:
		_mrbox(v, Vector3(0, sy, 0), Vector3(0.56, 0.03, 0.42), Mats.steel(), 0.01)
	for lx in [-0.25, 0.25]:
		for lz in [-0.17, 0.17]:
			_mcyl(v, Vector3(lx, 0.37, lz), 0.015, 0.7, Mats.chrome())
			_msphere(v, Vector3(lx, 0.05, lz), 0.05, Mats.charcoal())
	# the machine itself: a grey box, a white gauge, red pilot, bakelite dials
	_mrbox(v, Vector3(0, 0.87, 0), Vector3(0.5, 0.26, 0.34), Mats.metal_gray(), 0.02)
	var gauge := _mcyl(v, Vector3(-0.12, 0.9, 0.176), 0.06, 0.015, Mats.paint_white())
	gauge.rotation.x = PI / 2.0
	for di in 3:
		var knob := _mcyl(v, Vector3(0.06 + 0.11 * float(di), 0.84, 0.176), 0.025, 0.03, Mats.red_knob())
		knob.rotation.x = PI / 2.0
	_msphere(v, Vector3(0.18, 0.95, 0.17), 0.014, Mats.lamp_red())
	# paddles resting on the lower shelf, leads drooping back up to the box
	for px in [-0.12, 0.1]:
		_mcyl(v, Vector3(px, 0.39, 0.05), 0.05, 0.035, Mats.charcoal())
		_mcyl(v, Vector3(px, 0.42, 0.05), 0.012, 0.09, Mats.charcoal())
	# leads sagging from the paddles back up into the box
	_asy_wire(v, Vector3(-0.12, 0.46, 0.05), Vector3(-0.2, 0.87, -0.1))
	_asy_wire(v, Vector3(0.1, 0.46, 0.05), Vector3(0.2, 0.87, -0.1))
	_collider_yaw_box(p + Vector3(0, 0.5, 0), Vector3(0.62, 1.0, 0.5), yaw)


## Sagging two-segment cable between two local points.
func _asy_wire(parent: Node3D, a: Vector3, b: Vector3) -> void:
	var mid := (a + b) * 0.5 + Vector3(0, -0.14, 0.1)
	for seg in [[a, mid], [mid, b]]:
		var mi := MeshInstance3D.new()
		mi.mesh = BOX
		mi.material_override = Mats.rubber_black()
		var d: Vector3 = seg[1] - seg[0]
		var up := Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT
		mi.transform = Transform3D(Basis.looking_at(d, up), (seg[0] + seg[1]) / 2.0)
		mi.scale = Vector3(0.014, 0.014, d.length())
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)


func _asy_wheelchair(p: Vector3, yaw: float) -> void:
	_asy_model("wheelchair_01", p, yaw)
	_collider_yaw_box(p + Vector3(0, 0.55, 0), Vector3(0.85, 1.1, 1.1), yaw)


func _asy_chair(p: Vector3, yaw: float, tipped: bool) -> void:
	var ch := _asy_model("SchoolChair_01", p, yaw)
	if tipped:
		ch.position.y = 0.28
		ch.rotation.z = PI / 2.0 - 0.06
		return
	_collider_yaw_box(p + Vector3(0, 0.5, 0), Vector3(0.58, 1.0, 0.68), yaw)


func _asy_medbox(p: Vector3, yaw: float) -> void:
	_asy_model("medical_box", p, yaw)


func _asy_iv(p: Vector3) -> void:
	var v := Node3D.new()
	v.position = p
	add_child(v)
	_mcyl(v, Vector3(0, 0.95, 0), 0.017, 1.9, Mats.chrome())
	_mcyl(v, Vector3(0, 0.025, 0), 0.2, 0.05, Mats.asy_metal())
	_mbox(v, Vector3(0, 1.88, 0), Vector3(0.4, 0.02, 0.02), Mats.chrome())
	_mrbox(v, Vector3(0.16, 1.68, 0), Vector3(0.13, 0.24, 0.05), Mats.glass_tint(), 0.02)
	_asy_wire(v, Vector3(0.16, 1.56, 0), Vector3(0.05, 0.9, 0.06))
	_collider_cyl(p + Vector3(0, 0.95, 0), 0.2, 1.9)


## Claw-foot hydrotherapy tub; half of them still hold black water.
func _asy_tub(p: Vector3, yaw: float, salt: int) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = yaw
	add_child(v)
	_mrbox(v, Vector3(0, 0.36, 0), Vector3(0.8, 0.6, 1.7), Mats.paint_white(), 0.09)
	_mrbox(v, Vector3(0, 0.6, 0), Vector3(0.62, 0.18, 1.5), Mats.charcoal(), 0.05)
	# rust bleeding from the drain end
	_mbox(v, Vector3(0, 0.2, 0.83), Vector3(0.3, 0.4, 0.03), Mats.asy_metal())
	for fx in [-0.34, 0.34]:
		for fz in [-0.72, 0.72]:
			_msphere(v, Vector3(fx, 0.07, fz), 0.07, Mats.iron_dark())
	if _r(salt) < 0.55:
		var wq := _mquad(v, Vector3(0, 0.63, 0), Vector2(0.6, 1.46), Mats.puddle())
		wq.rotation.x = -PI / 2.0
	# taps
	_mcyl(v, Vector3(0.14, 0.75, -0.8), 0.025, 0.16, Mats.brass())
	_mcyl(v, Vector3(-0.14, 0.75, -0.8), 0.025, 0.16, Mats.brass())
	_collider_yaw_box(p + Vector3(0, 0.35, 0), Vector3(0.85, 0.7, 1.75), yaw)


func _asy_papers(p: Vector3, salt: int, count: int) -> void:
	for i in count:
		var q := MeshInstance3D.new()
		q.mesh = QUAD
		q.material_override = Mats.box_white()
		var a := _r(salt + i * 3) * TAU
		var rd := _r(salt + i * 3 + 1) * 1.3
		q.position = p + Vector3(cos(a) * rd, 0.012 + 0.003 * float(i), sin(a) * rd)
		q.rotation.x = -PI / 2.0
		q.rotation.z = _r(salt + i * 3 + 2) * TAU
		q.scale = Vector3(0.21, 0.3, 1.0)
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(q)


# --- asylum: wall decor -------------------------------------------------------

## A straitjacket on a wall hook, straps hanging loose.
func _asy_straitjacket(dir: int, plane: float) -> void:
	var along := S / 2.0 + (_r(46 + dir) - 0.5) * 5.0
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T / 2.0)
	var v := Node3D.new()
	if dir < 2:
		v.position = Vector3(inner, 0, along)
		v.rotation.y = PI / 2.0 * n
	else:
		v.position = Vector3(along, 0, inner)
		v.rotation.y = 0.0 if n > 0.0 else PI
	add_child(v)
	_mcyl(v, Vector3(0, 2.06, 0.045), 0.015, 0.09, Mats.iron_dark())
	var torso := _mrbox(v, Vector3(0, 1.6, 0.1), Vector3(0.52, 0.78, 0.15), Mats.asy_canvas(), 0.07)
	torso.rotation.z = (_r(48 + dir) - 0.5) * 0.1
	# arms wrapped across the front
	var arm := _mrbox(v, Vector3(0, 1.52, 0.185), Vector3(0.46, 0.13, 0.06), Mats.asy_canvas(), 0.04)
	arm.rotation.z = 0.28
	var arm2 := _mrbox(v, Vector3(0, 1.42, 0.2), Vector3(0.46, 0.13, 0.05), Mats.asy_canvas(), 0.04)
	arm2.rotation.z = -0.24
	for si in 3:
		var sx := -0.14 + 0.14 * float(si)
		var strap := _mbox(v, Vector3(sx, 1.02, 0.12), Vector3(0.045, 0.42, 0.015), Mats.asy_canvas())
		strap.rotation.x = (_r(50 + dir + si) - 0.5) * 0.25
		strap.rotation.z = (_r(53 + dir + si) - 0.5) * 0.2
		_mbox(v, Vector3(sx, 0.82, 0.12), Vector3(0.05, 0.03, 0.02), Mats.steel())


## Written by hand, by someone who was not well. Two hands share the walls:
## Rock Salt is the shaky block-capital marker, Caveat the fast desperate
## cursive — picked per wall so a corridor reads as years of different people.
static var _scrawl_fonts := {}


static func _scrawl_font(which: int) -> FontFile:
	var f: FontFile = _scrawl_fonts.get(which)
	if f == null:
		f = load("res://fonts/RockSalt-Regular.ttf" if which == 0
			else "res://fonts/Caveat-Regular.ttf")
		_scrawl_fonts[which] = f
	return f


func _asy_scrawl(dir: int, plane: float) -> void:
	var along := S / 2.0 + (_r(46 + dir) - 0.5) * 6.0
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T / 2.0)
	var lb := Label3D.new()
	lb.text = ASY_SCRAWLS[WorldGen.h(wseed, cell.x, cell.y, 55 + dir) % ASY_SCRAWLS.size()]
	# cursive runs smaller and tighter than the block marker, so it needs the
	# larger point size to end up the same height on the wall
	var hand := 0 if _r(60 + dir) < 0.55 else 1
	lb.font = _scrawl_font(hand)
	lb.font_size = 46 if hand == 0 else 86
	lb.pixel_size = 0.0035 * (1.0 + (_r(61 + dir) - 0.5) * 0.5)
	lb.width = 900.0
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD
	# this floor is near-black, and dark-on-dark writing may as well not exist —
	# a third of it is scratched THROUGH the paint, pale against the plaster
	var ink := _r(56 + dir)
	if ink < 0.42:
		lb.modulate = Color(0.34, 0.06, 0.05, 0.85)   # dried rust-red marker
	elif ink < 0.66:
		lb.modulate = Color(0.16, 0.15, 0.13, 0.9)    # charcoal, almost gone
	else:
		lb.modulate = Color(0.66, 0.64, 0.56, 0.92)   # scratched into the paint
	var y := 1.25 + _r(57 + dir) * 0.6
	if dir < 2:
		lb.position = Vector3(inner + n * 0.02, y, along)
		lb.rotation.y = PI / 2.0 * n
	else:
		lb.position = Vector3(along, y, inner + n * 0.02)
		lb.rotation.y = 0.0 if n > 0.0 else PI
	# a hand steadied against a wall still wanders off true
	lb.rotation.z = (_r(59 + dir) - 0.5) * 0.22
	add_child(lb)


## Cork noticeboard, duty rosters still pinned, one sheet hanging by a corner.
func _asy_noticeboard(dir: int, plane: float) -> void:
	var along := S / 2.0 + (_r(46 + dir) - 0.5) * 4.0
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T / 2.0)
	var v := Node3D.new()
	if dir < 2:
		v.position = Vector3(inner, 0, along)
		v.rotation.y = PI / 2.0 * n
	else:
		v.position = Vector3(along, 0, inner)
		v.rotation.y = 0.0 if n > 0.0 else PI
	add_child(v)
	_mbox(v, Vector3(0, 1.62, 0.025), Vector3(1.2, 0.85, 0.05), Mats.darkwood())
	_mbox(v, Vector3(0, 1.62, 0.045), Vector3(1.08, 0.73, 0.02), Mats.asy_cloth())
	for i in 4:
		var px := -0.35 + 0.24 * float(i)
		if _r(60 + dir + i) < 0.75:
			var sheet := _mbox(v, Vector3(px, 1.6 + (_r(63 + i) - 0.5) * 0.3, 0.062),
				Vector3(0.16, 0.22, 0.004), Mats.box_white())
			sheet.rotation.z = (_r(66 + dir + i) - 0.5) * (0.9 if i == 2 else 0.14)


func _asy_crutches(dir: int, plane: float) -> void:
	var along := S / 2.0 + (_r(46 + dir) - 0.5) * 5.5
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T / 2.0)
	var v := Node3D.new()
	if dir < 2:
		v.position = Vector3(inner + n * 0.22, 0, along)
		v.rotation.y = PI / 2.0 * n
	else:
		v.position = Vector3(along, 0, inner + n * 0.22)
		v.rotation.y = 0.0 if n > 0.0 else PI
	add_child(v)
	# instanced under the lean node directly — reparent() needs a live tree
	var ps: PackedScene = _asy_scenes.get("vintage_crutches_01")
	if ps == null:
		ps = load("res://models/asylum/vintage_crutches_01/vintage_crutches_01_1k.gltf")
		_asy_scenes["vintage_crutches_01"] = ps
	var m: Node3D = ps.instantiate()
	m.rotation = Vector3(0.17, 0.0, 0.0)
	v.add_child(m)


# --- asylum: rooms ------------------------------------------------------------

func _asy_cell_props() -> void:
	var bx := _asy_wall_clear(3, 2.6 + 6.8 * _r(760), 1.1)
	_asy_bed(Vector3(bx, 0, 1.35), PI if _r(761) < 0.5 else 0.0, 762)
	if _r(763) < 0.45:
		var bx2 := _asy_wall_clear(2, 2.6 + 6.8 * _r(764), 1.1)
		_asy_bed(Vector3(bx2, 0, S - 1.35), PI if _r(765) < 0.5 else 0.0, 766)
	if _r(767) < 0.4:
		_asy_wheelchair(Vector3(3.0 + 6.0 * _r(768), 0, 3.5 + 5.0 * _r(769)), _r(770) * TAU)
	if _r(771) < 0.5:
		_asy_chair(Vector3(2.5 + 7.0 * _r(772), 0, 3.5 + 5.0 * _r(773)), _r(774) * TAU, _r(775) < 0.25)
	if _r(776) < 0.55:
		_asy_papers(Vector3(4.0 + 4.0 * _r(777), 0, 4.0 + 4.0 * _r(778)), 780, 6)
	if _r(781) < 0.35:
		_asy_iv(Vector3(bx + 1.3, 0, 1.6))
	if _r(782) < 0.3:
		_asy_medbox(Vector3(3.0 + 6.0 * _r(783), 0, 4.0 + 4.0 * _r(784)), _r(785) * TAU)


## Two facing rows of beds down the room's long axis — a ward nobody closed.
func _asy_ward() -> void:
	var span := _room_span()
	var long_x := span.x >= span.y
	var L := maxf(span.x, span.y)
	var c := Vector3(S / 2.0, 0, S / 2.0)
	var nbeds := int((L - 3.0) / 2.6)
	var salt := 790
	for si in 2:
		var lat := -4.15 if si == 0 else 4.15
		for bi in nbeds:
			var along := -(L / 2.0 - 2.2) + 2.6 * float(bi) + (_r(salt) - 0.5) * 0.5
			salt += 1
			if _r(salt) < 0.18:
				salt += 3
				continue
			salt += 1
			var p := c + (Vector3(along, 0, lat) if long_x else Vector3(lat, 0, along))
			var yaw: float
			if long_x:
				yaw = 0.0 if lat > 0.0 else PI
			else:
				yaw = PI / 2.0 if lat > 0.0 else -PI / 2.0
			_asy_bed(p, yaw + (_r(salt) - 0.5) * 0.07, salt + 40)
			salt += 1
			if _r(salt) < 0.25:
				var ivoff := Vector3(1.35, 0, 0) if long_x else Vector3(0, 0, 1.35)
				_asy_iv(p + ivoff)
			salt += 1
	if _r(860) < 0.55:
		_asy_wheelchair(c + Vector3((_r(861) - 0.5) * 3.0, 0, (_r(862) - 0.5) * 3.0), _r(863) * TAU)
	if _r(864) < 0.6:
		_asy_papers(c + Vector3((_r(865) - 0.5) * 4.0, 0, (_r(866) - 0.5) * 4.0), 867, 7)
	if _r(868) < 0.35:
		_asy_gurney(c + Vector3((_r(869) - 0.5) * 2.0, 0, (_r(870) - 0.5) * 2.0), _r(871) * TAU, 872)


## The big common room: a therapy circle nobody dismissed, a rocking chair
## facing the wall, papers everywhere.
func _asy_dayroom() -> void:
	var c := Vector3(S / 2.0, 0, S / 2.0)
	var span := _room_span()
	var large := span.x > 12.1 or span.y > 12.1
	var base := _r(880) * TAU
	var chair_count := 11 if large else 7
	var circle_r := 4.1 if large else 2.3
	for i in chair_count:
		if _r(881 + i) < 0.2:
			continue
		var ang := base + TAU * float(i) / float(chair_count)
		var cp := c + Vector3(cos(ang) * circle_r, 0, sin(ang) * circle_r)
		var face := atan2(c.x - cp.x, c.z - cp.z)
		_asy_chair(cp, face + (_r(900 + i) - 0.5) * 0.5, _r(920 + i) < 0.15)
	if large:
		# Secondary activity islands stop the 24m dayroom reading as one chair
		# circle marooned in a warehouse-sized shell.
		_asy_dayroom_table(c + Vector3(-6.2, 0, 5.0), 940)
		_asy_dayroom_table(c + Vector3(6.2, 0, -5.0), 950)
	var rp := c + Vector3(7.6, 0, 7.9)
	var rock := _asy_model("Rockingchair_01", rp, PI * 0.83)
	rock.position.y = -0.1
	_collider_yaw_box(rp + Vector3(0, 0.5, 0), Vector3(0.72, 1.0, 0.85), PI * 0.83)
	if _r(902) < 0.6:
		_asy_wheelchair(c + Vector3(-6.2 * _r(903), 0, 5.0 * (_r(904) - 0.5)), _r(905) * TAU)
	_asy_papers(c + Vector3((_r(906) - 0.5) * 5.0, 0, (_r(907) - 0.5) * 5.0), 908, 9)
	if _r(909) < 0.5:
		_asy_gurney(c + Vector3(-5.5, 0, -5.0 * (_r(910) - 0.5)), _r(911) * TAU, 912)
	# a long-dead television would be too kind; a fallen noticeboard instead
	if _r(913) < 0.4:
		var fb := _box(c + Vector3(3.5 * (_r(914) - 0.5), 0.04, -4.5), Vector3(1.2, 0.06, 0.85), Mats.darkwood(), false)
		fb.rotation.y = _r(915) * TAU


## A scarred institutional table and three mismatched chairs, laid out as a
## smaller therapy or card-game group around the edge of a large dayroom.
func _asy_dayroom_table(c: Vector3, salt: int) -> void:
	_mrbox(self, c + Vector3(0, 0.72, 0), Vector3(1.55, 0.07, 1.0),
		Mats.asy_concrete(), 0.025)
	for sx in [-0.62, 0.62]:
		for sz in [-0.36, 0.36]:
			_cyl(c + Vector3(sx, 0.35, sz), 0.025, 0.7, Mats.asy_metal())
	_collider_box(c + Vector3(0, 0.4, 0), Vector3(1.6, 0.8, 1.05))
	for i in 3:
		var ang := TAU * float(i) / 3.0 + 0.35 + (_r(salt + i) - 0.5) * 0.2
		var cp := c + Vector3(cos(ang) * 1.25, 0, sin(ang) * 1.05)
		_asy_chair(cp, atan2(c.x - cp.x, c.z - cp.z), _r(salt + 5 + i) < 0.25)


func _asy_treatment() -> void:
	var c := Vector3(S / 2.0, 0, S / 2.0)
	var yaw := (PI / 2.0 if _r(920) < 0.5 else 0.0) + (_r(921) - 0.5) * 0.12
	_asy_restraint_table(c, yaw)
	var side := Vector3(cos(yaw), 0, -sin(yaw))
	_asy_ect(c + side * 1.5, yaw + PI / 2.0, 922)
	# surgical lamp aimed at the table
	_cyl(Vector3(c.x, ceil_h - 0.3, c.z), 0.02, 0.6, Mats.asy_metal(), false)
	var dish := _cyl(Vector3(c.x, ceil_h - 0.62, c.z), 0.3, 0.14, Mats.steel(), false)
	dish.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sphere(Vector3(c.x, ceil_h - 0.68, c.z), 0.07, Mats.bulb())
	var sp := SpotLight3D.new()
	sp.position = Vector3(c.x, ceil_h - 0.7, c.z)
	sp.rotation.x = -PI / 2.0
	sp.spot_angle = 38.0
	sp.spot_range = ceil_h
	sp.light_energy = 4.2
	sp.light_color = Color(0.95, 1.0, 0.88)
	sp.shadow_enabled = true
	sp.distance_fade_enabled = true
	sp.distance_fade_begin = 20.0
	sp.distance_fade_length = 8.0
	add_child(sp)
	# the barber chair in the corner is somehow worse than the table
	if _r(923) < 0.6:
		var bp := Vector3(2.2, 0, 2.4)
		var byaw := _r(924) * TAU
		_asy_model("BarberShopChair_01", bp, byaw)
		_collider_yaw_box(bp + Vector3(0, 0.7, 0), Vector3(0.8, 1.5, 1.35), byaw)
	if _r(925) < 0.6:
		_asy_medbox(c + side * -1.6 + Vector3(0, 0, 0.6), _r(926) * TAU)
	_asy_papers(c + Vector3(1.8, 0, 1.6), 927, 5)
	# floor drain
	var dr := _cyl(c + Vector3(0.9 * cos(yaw), 0.006, 0.7), 0.14, 0.012, Mats.iron_dark(), false)
	dr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _asy_hydro() -> void:
	var span := _room_span()
	var long_x := span.x >= span.y
	var L := maxf(span.x, span.y)
	var c := Vector3(S / 2.0, 0, S / 2.0)
	var ntubs := int((L - 3.0) / 2.5)
	var salt := 930
	# one row of tubs per 12m of width, offset to leave a walk lane
	var lats: Array = [-2.9, 2.9] if minf(span.x, span.y) > 12.1 else [2.6]
	for lat in lats:
		for ti in ntubs:
			var along := -(L / 2.0 - 2.4) + 2.5 * float(ti) + (_r(salt) - 0.5) * 0.3
			salt += 1
			if _r(salt) < 0.15:
				salt += 2
				continue
			salt += 1
			var p := c + (Vector3(along, 0, lat) if long_x else Vector3(lat, 0, along))
			_asy_tub(p, 0.0 if long_x else PI / 2.0, salt + 30)
			salt += 1
	for ci in 3:
		if _r(950 + ci) < 0.6:
			_chain(c + Vector3((_r(953 + ci) - 0.5) * 6.0, 0, (_r(956 + ci) - 0.5) * 6.0))
	if _r(960) < 0.5:
		_asy_wheelchair(c + Vector3(-3.5 * _r(961), 0, -3.0 * _r(962)), _r(963) * TAU)
	if _r(964) < 0.4:
		_asy_iv(c + Vector3(3.0 * (_r(965) - 0.5), 0, -2.5))


func _asy_office() -> void:
	var c := Vector3(S / 2.0, 0, S / 2.0)
	var yaw := [0.0, PI / 2.0, PI, -PI / 2.0][int(_r(970) * 3.99)] as float
	var dp := c + Vector3((_r(971) - 0.5) * 2.0, 0, (_r(972) - 0.5) * 2.0)
	_asy_model("metal_office_desk", dp, yaw)
	_collider_yaw_box(dp + Vector3(0, 0.4, 0), Vector3(2.0, 0.8, 0.95), yaw)
	var back := Vector3(sin(yaw), 0, cos(yaw))
	_asy_chair(dp + back * 0.95, yaw + PI + (_r(973) - 0.5) * 0.6, _r(974) < 0.3)
	_asy_medbox(dp + Vector3(0, 0.79, 0) + back * -0.1 + Vector3(cos(yaw) * 0.55, 0, -sin(yaw) * 0.55), yaw + 0.3)
	# papers drifted off the desk years ago
	_asy_papers(dp + back * 1.2, 975, 8)
	_asy_papers(c + Vector3(2.5 * (_r(976) - 0.5), 0, 2.5 * (_r(977) - 0.5)), 978, 6)
	# filing cabinets against the first solid wall
	for dir in 4:
		if WorldGen.edge_info(wseed, cell, dir, theme)["wall"]:
			_filing_bank(dir, (S - T / 2.0) if (dir == 0 or dir == 2) else (T / 2.0))
			break
	if _r(979) < 0.4:
		_asy_iv(c + Vector3(4.0, 0, -3.5 * (_r(980) - 0.5)))


## Landmark: an institutional chapel/assembly room. Long scarred pews point
## toward a tiny dais, while one wheelchair has been left in the centre aisle.
## The aisle itself remains a clean sightline and traversal route.
func _asy_chapel() -> void:
	var c := Vector3(S / 2.0, 0, S / 2.0)
	# Shallow dais and plain altar at the north end.
	var front := c + Vector3(0, 0, -8.0)
	_rbox(front + Vector3(0, 0.16, 0), Vector3(8.0, 0.32, 2.8), Mats.darkwood(), 0.025)
	_rbox(front + Vector3(0, 0.88, 0.1), Vector3(2.2, 1.45, 0.75), Mats.asy_concrete(), 0.035)
	_collider_box(front + Vector3(0, 0.48, 0), Vector3(8.1, 0.96, 2.9))
	# A stark wall cross; it is architecture, not a glowing quest marker.
	_box(front + Vector3(0, 3.45, -1.43), Vector3(0.30, 2.2, 0.09), Mats.darkwood(), false)
	_box(front + Vector3(0, 3.70, -1.43), Vector3(1.45, 0.28, 0.09), Mats.darkwood(), false)
	# Two banks of pews leave a generous central aisle.
	for row in 6:
		var z := -4.5 + 2.05 * float(row)
		for side in [-1.0, 1.0]:
			var p := c + Vector3(side * 3.65, 0, z)
			_rbox(p + Vector3(0, 0.54, 0), Vector3(5.6, 0.15, 0.66), Mats.darkwood(), 0.035, false)
			_rbox(p + Vector3(0, 0.92, -0.28), Vector3(5.6, 0.72, 0.12), Mats.darkwood(), 0.035, false)
			for sx in [-2.5, 0.0, 2.5]:
				_box(p + Vector3(sx, 0.30, 0), Vector3(0.10, 0.60, 0.58), Mats.iron_dark(), false)
			_collider_box(p + Vector3(0, 0.65, 0), Vector3(5.7, 1.3, 0.75))
	# Human-scale detail makes the symmetry feel abandoned rather than staged.
	_asy_wheelchair(c + Vector3(0.7, 0, 4.2), PI + 0.22)
	_asy_papers(c + Vector3(-0.8, 0, 6.5), 1101, 11)
	var rockp := front + Vector3(4.8, 0, 0.2)
	_asy_model("Rockingchair_01", rockp, -PI / 2.0)
	_collider_yaw_box(rockp + Vector3(0, 0.5, 0), Vector3(0.72, 1.0, 0.85), -PI / 2.0)


## A narrow but structurally complete ward corridor. Locked patient rooms are
## sealed volumes behind continuous masonry; actual graph connections become
## return-walled cross-passages to the canonical cell-edge doorway. The spacing
## stays irregular so this never acquires the office floor's modular rhythm.
func _asy_corridor() -> void:
	var cdir := WorldGen.corridor(wseed, cell)
	var along_x := cdir != 2
	var yw := 0.0 if along_x else PI / 2.0
	var o := Vector3(S / 2.0, 0, S / 2.0)
	var lane_half := 2.05
	var side_data := []
	for si in 2:
		var side := -lane_half if si == 0 else lane_half
		var sdir := (3 if si == 0 else 2) if along_x else (1 if si == 0 else 0)
		var info := WorldGen.edge_info(wseed, cell, sdir, theme)
		var bay := []
		if not info["wall"]:
			var bt: float = float(info["t"]) - 6.0 if along_x else 6.0 - float(info["t"])
			var bw := clampf(float(info["w"]) + 0.34, 1.9, 2.9)
			bay = [bt, bw]
		var doors := _asy_corridor_doors(si, bay)
		_asy_corridor_wall_side(o, yw, side, doors, bay)
		side_data.append({"side": side, "doors": doors, "bay": bay})

	# Abandoned transport is parked only against uninterrupted wall. It adds
	# history without blocking a real connection or floating in front of a door.
	for si in 2:
		var data: Dictionary = side_data[si]
		for di in 2:
			var t := _asy_corridor_prop_t(si, di, data["doors"], data["bay"])
			if t > 90.0:
				continue
			var side: float = (-1.42 if si == 0 else 1.42)
			var pp := _wp(o, Vector3(t, 0, side), yw)
			var rr := _r(724 + si * 5 + di)
			var park_yaw := yw + PI / 2.0
			if rr < 0.18:
				_asy_gurney(pp, park_yaw + (_r(726 + di) - 0.5) * 0.18,
					728 + si * 3 + di)
			elif rr < 0.3:
				_asy_bed(pp, park_yaw + (_r(729 + di) - 0.5) * 0.14,
					730 + si * 3 + di)
			elif rr < 0.46:
				_asy_wheelchair(pp, _r(731 + si * 3 + di) * TAU)
			elif rr < 0.59:
				_asy_iv(pp)
			elif rr < 0.76:
				_asy_papers(pp, 733 + si * 7 + di, 5)
	if _r(740) < 0.4:
		_asy_sign(o, yw)


func _asy_corridor_doors(si: int, bay: Array) -> Array:
	var doors := []
	# Offset the two sides and perturb the end positions slightly: real old wards
	# accrete rooms, unlike the perfectly repeated office grid.
	var positions := [-3.65, -0.15, 3.42] if si == 0 else [-3.28, 0.3, 3.78]
	for di in positions.size():
		var t: float = positions[di] + (_r(700 + si * 7 + di) - 0.5) * 0.26
		if _r(704 + si * 7 + di) >= 0.78:
			continue
		if not bay.is_empty() and absf(t - float(bay[0])) < float(bay[1]) * 0.5 + 0.9:
			continue
		doors.append(t)
	if doors.is_empty() and bay.is_empty():
		doors.append(float(positions[1]))
	return doors


func _asy_corridor_clear(t: float, doors: Array, bay: Array, clearance: float) -> bool:
	if not bay.is_empty() and absf(t - float(bay[0])) < float(bay[1]) * 0.5 + clearance:
		return false
	for dt in doors:
		if absf(t - float(dt)) < 0.62 + clearance:
			return false
	return true


func _asy_corridor_prop_t(si: int, index: int, doors: Array, bay: Array) -> float:
	var raw := -4.45 + 8.9 * _r(720 + si * 9 + index)
	var candidates := [raw, -4.65, 4.65, -1.72, 1.72]
	if (si + index) % 2 == 1:
		candidates = [raw, 4.65, -4.65, 1.72, -1.72]
	for t in candidates:
		if _asy_corridor_clear(float(t), doors, bay, 0.82):
			return float(t)
	return 99.0


## One complete masonry side, cut only for a filled locked door or for a real
## cross-passage. Wall, tile and collider share the exact same segmentation.
func _asy_corridor_wall_side(o: Vector3, yw: float, side: float,
		doors: Array, bay: Array) -> void:
	var segs := [[-6.0, 6.0]]
	for dt in doors:
		segs = _cut_seg(segs, float(dt) - 0.61, float(dt) + 0.61)
	if not bay.is_empty():
		segs = _cut_seg(segs, float(bay[0]) - float(bay[1]) * 0.5,
			float(bay[0]) + float(bay[1]) * 0.5)
	for sg in segs:
		_asy_corridor_wall_run(o, yw, side, float(sg[0]), float(sg[1]))
	for di in doors.size():
		var dt := float(doors[di])
		_asy_corridor_header(o, yw, side, dt, 1.22)
		_asy_corridor_door(o, yw, dt, side,
			750 + (0 if side < 0.0 else 14) + di)
	if not bay.is_empty():
		var bt: float = bay[0]
		var bw: float = bay[1]
		_asy_corridor_header(o, yw, side, bt, bw)
		_asy_corridor_open_casing(o, yw, side, bt, bw)
		_asy_corridor_bay_returns(o, yw, side, bt, bw)


func _asy_corridor_wall_run(o: Vector3, yw: float, side: float,
		a: float, b: float) -> void:
	var ln := b - a
	if ln < 0.04:
		return
	var c := (a + b) * 0.5
	var wc := _wp(o, Vector3(c, ceil_h * 0.5, side), yw)
	var wall := _mbox(self, wc, Vector3(ln, ceil_h, 0.18), _asy_wall_mat())
	wall.rotation.y = yw
	_collider_yaw_box(wc, Vector3(ln, ceil_h, 0.18), yw)
	var inn := side - signf(side) * 0.115
	var tile := _mbox(self, _wp(o, Vector3(c, 0.69, inn), yw),
		Vector3(ln, 1.38, 0.05), Mats.asy_tile())
	tile.rotation.y = yw
	var rail := _mbox(self, _wp(o, Vector3(c, 1.39, inn - signf(side) * 0.018), yw),
		Vector3(ln, 0.07, 0.07), Mats.asy_metal_green())
	rail.rotation.y = yw


func _asy_corridor_header(o: Vector3, yw: float, side: float,
		t: float, width: float) -> void:
	var hh := ceil_h - DOOR_TOP
	if hh <= 0.02:
		return
	var hp := _wp(o, Vector3(t, DOOR_TOP + hh * 0.5, side), yw)
	var head := _mbox(self, hp, Vector3(width, hh, 0.18), _asy_wall_mat())
	head.rotation.y = yw
	_collider_yaw_box(hp, Vector3(width, hh, 0.18), yw)


## These returns are the crucial illusion: they carry the corridor wall all the
## way to the real boundary opening and close both neighboring patient volumes.
func _asy_corridor_bay_returns(o: Vector3, yw: float, side: float,
		t: float, width: float) -> void:
	var outer := signf(side) * (S * 0.5 - T)
	var depth := absf(outer - side)
	var dc := (outer + side) * 0.5
	for edge in [t - width * 0.5, t + width * 0.5]:
		var wp := _wp(o, Vector3(edge, ceil_h * 0.5, dc), yw)
		var ret := _mbox(self, wp, Vector3(0.18, ceil_h, depth), _asy_wall_mat())
		ret.rotation.y = yw
		_collider_yaw_box(wp, Vector3(0.18, ceil_h, depth), yw)
		var tile_in := 0.115 if edge < t else -0.115
		var tile := _mbox(self, _wp(o, Vector3(edge + tile_in, 0.69, dc), yw),
			Vector3(0.05, 1.38, depth), Mats.asy_tile())
		tile.rotation.y = yw
		var rail := _mbox(self, _wp(o, Vector3(edge + tile_in, 1.39, dc), yw),
			Vector3(0.07, 0.07, depth), Mats.asy_metal_green())
		rail.rotation.y = yw
	var floor_strip := _mbox(self, _wp(o, Vector3(t, 0.013, dc), yw),
		Vector3(width, 0.026, depth), Mats.asy_checker())
	floor_strip.rotation.y = yw


func _asy_corridor_open_casing(o: Vector3, yw: float, side: float,
		t: float, width: float) -> void:
	var inn := side - signf(side) * 0.115
	for edge in [t - width * 0.5, t + width * 0.5]:
		var jamb := _mbox(self, _wp(o, Vector3(edge, DOOR_TOP * 0.5, inn), yw),
			Vector3(0.12, DOOR_TOP, 0.3), Mats.asy_metal_green())
		jamb.rotation.y = yw
	var lintel := _mbox(self, _wp(o, Vector3(t, DOOR_TOP + 0.065, inn), yw),
		Vector3(width + 0.18, 0.13, 0.3), Mats.asy_metal_green())
	lintel.rotation.y = yw


## Heavy ward door installed into an actual wall opening. The vision panel is
## backed by darkness: it suggests a lightless cell without exposing empty map.
func _asy_corridor_door(o: Vector3, yw: float, t: float,
		side: float, salt: int) -> void:
	var inn := side - signf(side) * 0.115
	var v := Node3D.new()
	v.position = _wp(o, Vector3(t, 0, inn), yw)
	v.rotation.y = yw + (PI if side > 0.0 else 0.0)
	add_child(v)
	_mrbox(v, Vector3(0, 1.06, 0), Vector3(1.0, 2.12, 0.09),
		Mats.asy_metal_green(), 0.012)
	_mbox(v, Vector3(-0.57, 1.09, 0), Vector3(0.12, 2.2, 0.3), Mats.asy_metal())
	_mbox(v, Vector3(0.57, 1.09, 0), Vector3(0.12, 2.2, 0.3), Mats.asy_metal())
	_mbox(v, Vector3(0, 2.22, 0), Vector3(1.26, 0.13, 0.3), Mats.asy_metal())
	# Opaque backing first, then dirty glass and a welded cross-mesh.
	_mrbox(v, Vector3(0, 1.65, 0.047), Vector3(0.34, 0.42, 0.02),
		Mats.charcoal(), 0.006)
	_mrbox(v, Vector3(0, 1.65, 0.061), Vector3(0.3, 0.38, 0.012),
		Mats.glass_tint(), 0.005)
	for bx in [-0.075, 0.075]:
		_mbox(v, Vector3(bx, 1.65, 0.071), Vector3(0.014, 0.4, 0.01), Mats.iron_dark())
	for by in [1.54, 1.65, 1.76]:
		_mbox(v, Vector3(0, by, 0.072), Vector3(0.32, 0.012, 0.01), Mats.iron_dark())
	# Food hatch, hinges and a lock whose key has long since disappeared.
	_mrbox(v, Vector3(0, 0.68, 0.057), Vector3(0.4, 0.17, 0.025),
		Mats.asy_metal(), 0.006)
	_mbox(v, Vector3(0, 0.59, 0.074), Vector3(0.13, 0.03, 0.025), Mats.steel())
	for hy in [0.42, 1.12, 1.82]:
		_mbox(v, Vector3(-0.49, hy, 0.045), Vector3(0.045, 0.14, 0.055), Mats.iron_dark())
	_mrbox(v, Vector3(0.35, 1.02, 0.066), Vector3(0.13, 0.22, 0.03),
		Mats.iron_dark(), 0.006)
	_msphere(v, Vector3(0.35, 1.02, 0.102), 0.035, Mats.steel())
	_collider_yaw_box(_wp(o, Vector3(t, 1.06, inn), yw),
		Vector3(1.02, 2.12, 0.13), yw)
	var num := Label3D.new()
	num.text = "%02d" % (WorldGen.h(wseed, cell.x + int(t * 3.0), cell.y, salt) % 40 + 1)
	num.font_size = 42
	num.pixel_size = 0.0018
	num.modulate = Color(0.82, 0.86, 0.77)
	num.position = Vector3(0, 1.98, 0.075)
	v.add_child(num)


func _asy_sign(o: Vector3, yw: float) -> void:
	var zone := WorldGen.macro_zone(wseed, cell, theme)
	var labels: Array = ASY_ZONE_SIGNS[zone]
	var txt: String = labels[WorldGen.h(wseed, cell.x, cell.y, 741) % labels.size()]
	var y := ceil_h - 0.55
	var v := Node3D.new()
	v.position = _wp(o, Vector3(0, y, 0), yw)
	v.rotation.y = yw
	add_child(v)
	_mbox(v, Vector3(0, 0.3, 0), Vector3(0.02, 0.3, 0.02), Mats.iron_dark())
	var plate := _mbox(v, Vector3(0, 0, 0), Vector3(1.5, 0.36, 0.05), Mats.asy_metal_green())
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for sside in [-1.0, 1.0]:
		var lb := Label3D.new()
		lb.text = txt
		lb.font_size = 60
		lb.pixel_size = 0.0022
		lb.modulate = Color(0.88, 0.92, 0.84)
		lb.position = Vector3(0, 0, sside * 0.035)
		lb.rotation.y = 0.0 if sside > 0.0 else PI
		v.add_child(lb)


# --- school -------------------------------------------------------------------
# One building painted over every summer. Cream block above a red line, a floor
# ground until it mirrors the strip lights, and locker runs down every corridor.
# The rooms are all the ones you remember and none of them are in use.


func _sch_tiled_room() -> bool:
	return style == WorldGen.SCH_BATHROOM


func _sch_wall_mat() -> Material:
	if _sch_tiled_room():
		return Mats.sch_tile()
	return Mats.sch_wall_variant(_finish_variant())


func _sch_floor_mat() -> Material:
	match style:
		WorldGen.SCH_GYM, WorldGen.SCH_AUDITORIUM:
			return Mats.sch_gymfloor()
		WorldGen.SCH_BATHROOM:
			return Mats.sch_tile()
		WorldGen.SCH_CAFETERIA, WorldGen.SCH_ADMIN:
			return Mats.sch_terrazzo()
	return Mats.sch_floor()


## Which way the corridor runs, as a unit vector in cell space.
func _sch_corridor_axis() -> int:
	return WorldGen.corridor(wseed, cell)


## Surface-mounted twin tube: a steel channel with a lens under it. Nothing
## here casts — the room light would rake the housings into streaks.
func _sch_strip(at: Vector3, along_x: bool, ln: float, pmat: Material) -> void:
	var y := ceil_h - 0.06
	var body_size := Vector3(ln, 0.09, 0.24) if along_x else Vector3(0.24, 0.09, ln)
	var housing := _box(Vector3(at.x, y, at.z), body_size, Mats.sch_trim(), false)
	housing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lens_size := Vector3(ln - 0.12, 0.03, 0.15) if along_x else Vector3(0.15, 0.03, ln - 0.12)
	var lens := _box(Vector3(at.x, y - 0.06, at.z), lens_size, pmat, false)
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _sch_lighting() -> void:
	var is_spawn := cell == Vector2i.ZERO
	# A school is maintained — the asylum is the one that gets to be pitch
	# dark. A dead cell here left rooms with nothing but ambient, which on
	# this floor is not enough to see the far wall by.
	var dead := (not is_spawn) and _r(8) < 0.02
	var flicker := (not is_spawn) and (not dead) and _r(9) < 0.12
	var pmat: StandardMaterial3D
	if dead:
		pmat = Mats.panel_dead()
	elif flicker:
		pmat = Mats.sch_panel().duplicate()
	else:
		pmat = Mats.sch_panel()
	var cdir := _sch_corridor_axis()
	if cdir != 0:
		# a single line of strips running the length of the passage, which is
		# what makes a school corridor read as endless
		var along_x := cdir == 1
		for t in [2.0, 6.0, 10.0]:
			var at := Vector3(t, 0, S / 2.0) if along_x else Vector3(S / 2.0, 0, t)
			_sch_strip(at, along_x, 2.6, pmat)
	elif style == WorldGen.SCH_GYM:
		for gx in [4.0, 12.0, 20.0]:
			for gz in [4.0, 12.0, 20.0]:
				_sch_strip(Vector3(gx, 0, gz), true, 3.2, pmat)
	else:
		for gx in [3.4, 8.6]:
			for gz in [3.0, 9.0]:
				_sch_strip(Vector3(gx, 0, gz), _r(60) < 0.5, 2.4, pmat)
	if dead:
		return
	var tall := ceil_h > 4.5
	var light := _make_main_light(flicker, pmat, 2.1 if tall else 1.5)
	light.light_color = Color(0.94, 0.97, 1.0)
	light.omni_range = 17.0 if tall else 12.0
	light.position = Vector3(S / 2.0, ceil_h - 0.5, S / 2.0)
	light.shadow_enabled = true
	light.distance_fade_enabled = true
	light.distance_fade_begin = 24.0
	light.distance_fade_length = 8.0
	light.distance_fade_shadow = 18.0
	add_child(light)


const SCH_ZONE_ROOMS := [
	["101", "103", "112", "204", "ART", "SCIENCE"],
	["MUSIC", "GYM", "CAFETERIA", "LIBRARY", "ART"],
	["FACULTY", "MAIN OFFICE", "COUNSELOR", "RECORDS"],
]


## The architectural contract for one side of a school hall. Coordinates are
## corridor-local: x follows the hall and z points toward its side rooms.
func _sch_corridor_side_data(si: int, along_x: bool) -> Dictionary:
	var side := -2.05 if si == 0 else 2.05
	var sdir := (3 if si == 0 else 2) if along_x else (1 if si == 0 else 0)
	var info := WorldGen.edge_info(wseed, cell, sdir, theme)
	var bay := []
	if not info["wall"]:
		var bt: float = float(info["t"]) - 6.0 if along_x else 6.0 - float(info["t"])
		var bw := clampf(float(info["w"]) + 0.62, 2.25, 2.9)
		bay = [bt, bw]
	return {"side": side, "bay": bay, "doors": _sch_corridor_doors(si, bay)}


## Long enclosed stretches get evidence of classrooms behind them. A genuine
## connection owns its interval and suppresses any locked-door facade nearby.
func _sch_corridor_doors(si: int, bay: Array) -> Array:
	var doors := []
	var positions := [-3.25, 3.3] if si == 0 else [-3.55, 3.0]
	for di in positions.size():
		var t: float = positions[di] + (_r(330 + si * 7 + di) - 0.5) * 0.24
		if _r(334 + si * 7 + di) >= 0.72:
			continue
		if not bay.is_empty() and absf(t - float(bay[0])) < float(bay[1]) * 0.5 + 0.95:
			continue
		doors.append(t)
	if doors.is_empty() and bay.is_empty():
		doors.append(float(positions[int(_r(348 + si) * 1.99)]))
	return doors


## A school corridor is about four metres across. The side strips are reserved
## classroom volume: continuous walls seal them, locked doors fill real cuts,
## and actual graph connections become cased, return-walled recesses.
func _sch_narrow() -> void:
	var along_x := _sch_corridor_axis() == 1
	var yw := 0.0 if along_x else PI / 2.0
	var o := Vector3(S / 2.0, 0, S / 2.0)
	for si in 2:
		var data := _sch_corridor_side_data(si, along_x)
		_sch_corridor_wall_side(o, yw, float(data["side"]), data["doors"], data["bay"])


func _sch_corridor_wall_side(o: Vector3, yw: float, side: float,
		doors: Array, bay: Array) -> void:
	var segs := [[-6.0, 6.0]]
	for dt in doors:
		segs = _cut_seg(segs, float(dt) - 0.62, float(dt) + 0.62)
	if not bay.is_empty():
		segs = _cut_seg(segs, float(bay[0]) - float(bay[1]) * 0.5,
			float(bay[0]) + float(bay[1]) * 0.5)
	for sg in segs:
		_sch_corridor_wall_run(o, yw, side, float(sg[0]), float(sg[1]))
	for di in doors.size():
		var dt := float(doors[di])
		_sch_corridor_header(o, yw, side, dt, 1.24)
		_sch_corridor_door(o, yw, dt, side,
			360 + (0 if side < 0.0 else 12) + di)
	if not bay.is_empty():
		var bt: float = bay[0]
		var bw: float = bay[1]
		_sch_corridor_header(o, yw, side, bt, bw)
		_sch_corridor_open_casing(o, yw, side, bt, bw)
		_sch_corridor_bay_returns(o, yw, side, bt, bw)
		_sch_corridor_bay_light(o, yw, side, bt)


func _sch_corridor_wall_run(o: Vector3, yw: float, side: float,
		a: float, b: float) -> void:
	var ln := b - a
	if ln < 0.04:
		return
	var c := (a + b) * 0.5
	var wc := _wp(o, Vector3(c, ceil_h * 0.5, side), yw)
	var wall := _mbox(self, wc, Vector3(ln, ceil_h, T),
		Mats.sch_wall_variant(_finish_variant()))
	wall.rotation.y = yw
	_collider_yaw_box(wc, Vector3(ln, ceil_h, T), yw)
	var inn := side - signf(side) * (T * 0.5 + 0.025)
	var band := _mbox(self, _wp(o, Vector3(c, SCH_BAND, inn), yw),
		Vector3(ln, 0.17, 0.04), Mats.sch_red())
	band.rotation.y = yw
	var base := _mbox(self, _wp(o, Vector3(c, 0.06, inn), yw),
		Vector3(ln, 0.12, 0.05), Mats.charcoal())
	base.rotation.y = yw


func _sch_corridor_header(o: Vector3, yw: float, side: float,
		t: float, width: float) -> void:
	var hh := ceil_h - DOOR_TOP
	if hh <= 0.02:
		return
	var hp := _wp(o, Vector3(t, DOOR_TOP + hh * 0.5, side), yw)
	var head := _mbox(self, hp, Vector3(width, hh, T),
		Mats.sch_wall_variant(_finish_variant()))
	head.rotation.y = yw
	_collider_yaw_box(hp, Vector3(width, hh, T), yw)


func _sch_corridor_open_casing(o: Vector3, yw: float, side: float,
		t: float, width: float) -> void:
	var inn := side - signf(side) * (T * 0.5 + 0.025)
	for edge in [t - width * 0.5, t + width * 0.5]:
		var jamb := _mbox(self, _wp(o, Vector3(edge, DOOR_TOP * 0.5, inn), yw),
			Vector3(0.17, DOOR_TOP, T + 0.14), Mats.sch_red())
		jamb.rotation.y = yw
	var lintel := _mbox(self, _wp(o, Vector3(t, DOOR_TOP + 0.08, inn), yw),
		Vector3(width + 0.17, 0.16, T + 0.14), Mats.sch_red())
	lintel.rotation.y = yw


## Close the dead classroom strips on both sides of a real connection and carry
## the red datum line and cove base all the way to its boundary doorway.
func _sch_corridor_bay_returns(o: Vector3, yw: float, side: float,
		t: float, width: float) -> void:
	var outer := signf(side) * (S * 0.5 - T)
	var depth := absf(outer - side)
	var dc := (outer + side) * 0.5
	for edge in [t - width * 0.5, t + width * 0.5]:
		var wp := _wp(o, Vector3(edge, ceil_h * 0.5, dc), yw)
		var ret := _mbox(self, wp, Vector3(T, ceil_h, depth),
			Mats.sch_wall_variant(_finish_variant()))
		ret.rotation.y = yw
		_collider_yaw_box(wp, Vector3(T, ceil_h, depth), yw)
		var inward := T * 0.5 + 0.025 if edge < t else -(T * 0.5 + 0.025)
		var band := _mbox(self, _wp(o, Vector3(edge + inward, SCH_BAND, dc), yw),
			Vector3(0.04, 0.17, depth), Mats.sch_red())
		band.rotation.y = yw
		var base := _mbox(self, _wp(o, Vector3(edge + inward, 0.06, dc), yw),
			Vector3(0.05, 0.12, depth), Mats.charcoal())
		base.rotation.y = yw


func _sch_corridor_bay_light(o: Vector3, yw: float, side: float, t: float) -> void:
	var outer := signf(side) * (S * 0.5 - T)
	var dc := (outer + side) * 0.5
	var bl := OmniLight3D.new()
	bl.light_color = Color(0.94, 0.97, 1.0)
	bl.light_energy = 0.72
	bl.omni_range = 5.8
	bl.shadow_enabled = false
	bl.distance_fade_enabled = true
	bl.distance_fade_begin = 18.0
	bl.distance_fade_length = 6.0
	bl.position = _wp(o, Vector3(t, ceil_h - 0.5, dc), yw)
	add_child(bl)


## A closed classroom door in a genuine opening: deep painted-steel jambs,
## opaque wired safety glass, a closer, lever and room plate. Its collider seals
## the reserved classroom volume behind it.
func _sch_corridor_door(o: Vector3, yw: float, t: float,
		side: float, salt: int) -> void:
	var inn := side - signf(side) * (T * 0.5 + 0.025)
	var v := Node3D.new()
	v.position = _wp(o, Vector3(t, 0, inn), yw)
	v.rotation.y = yw + (PI if side > 0.0 else 0.0)
	add_child(v)
	_mrbox(v, Vector3(0, 1.08, 0), Vector3(1.03, 2.16, 0.075),
		Mats.sch_door(), 0.01)
	_mbox(v, Vector3(-0.575, 1.1, 0), Vector3(0.12, 2.22, 0.26), Mats.sch_red())
	_mbox(v, Vector3(0.575, 1.1, 0), Vector3(0.12, 2.22, 0.26), Mats.sch_red())
	_mbox(v, Vector3(0, 2.24, 0), Vector3(1.27, 0.13, 0.26), Mats.sch_red())
	# Narrow safety-glass panel and its embedded wire grid.
	_mrbox(v, Vector3(0, 1.55, 0.043), Vector3(0.3, 0.68, 0.018),
		Mats.sch_wired_glass(), 0.006)
	for wx in [-0.09, 0.0, 0.09]:
		_mbox(v, Vector3(wx, 1.55, 0.055), Vector3(0.008, 0.64, 0.008), Mats.sch_trim())
	for wy in [1.37, 1.55, 1.73]:
		_mbox(v, Vector3(0, wy, 0.056), Vector3(0.28, 0.008, 0.008), Mats.sch_trim())
	# Lever set and a surface closer with its articulated arm.
	_mrbox(v, Vector3(0.35, 1.01, 0.055), Vector3(0.13, 0.2, 0.025),
		Mats.sch_trim(), 0.006)
	_mbox(v, Vector3(0.24, 1.01, 0.08), Vector3(0.25, 0.035, 0.035), Mats.sch_trim())
	_mrbox(v, Vector3(-0.27, 2.02, 0.05), Vector3(0.4, 0.1, 0.07),
		Mats.sch_trim(), 0.008)
	_mbox(v, Vector3(0.03, 2.04, 0.084), Vector3(0.31, 0.025, 0.025), Mats.sch_trim())
	_collider_yaw_box(_wp(o, Vector3(t, 1.08, inn), yw),
		Vector3(1.05, 2.16, 0.12), yw)
	var plate := _mrbox(v, Vector3(0.79, 1.7, 0.045),
		Vector3(0.3, 0.22, 0.025), Mats.sch_white(), 0.005)
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lb := Label3D.new()
	var zone := WorldGen.macro_zone(wseed, cell, theme)
	var labels: Array = SCH_ZONE_ROOMS[zone]
	lb.text = labels[WorldGen.h(wseed, cell.x + int(t * 4.0), cell.y, salt) % labels.size()]
	lb.font_size = 34
	lb.pixel_size = 0.00145
	lb.modulate = Color(0.16, 0.22, 0.24)
	lb.position = Vector3(0.79, 1.7, 0.061)
	v.add_child(lb)


func _sch_corridor_clear(t: float, doors: Array, bay: Array, clearance: float) -> bool:
	if not bay.is_empty() and absf(t - float(bay[0])) < float(bay[1]) * 0.5 + clearance:
		return false
	for dt in doors:
		if absf(t - float(dt)) < 0.63 + clearance:
			return false
	return true


func _sch_corridor_prop_t(si: int, salt: int, doors: Array, bay: Array,
		clearance: float) -> float:
	var raw := -3.8 + 7.6 * _r(salt)
	var candidates := [raw, -4.65, 4.65, -1.7, 1.7]
	if si == 1:
		candidates = [raw, 4.65, -4.65, 1.7, -1.7]
	for t in candidates:
		if _sch_corridor_clear(float(t), doors, bay, clearance):
			return float(t)
	return 99.0


## Locker banks use the exact same cuts as the architecture, so they finish at
## jambs rather than covering doors or jutting into a real classroom recess.
func _sch_passage_lockers(salt: int) -> void:
	var along_x := _sch_corridor_axis() == 1
	var depth := 0.42
	var hgt := 1.83
	for si in 2:
		var data := _sch_corridor_side_data(si, along_x)
		var side: float = data["side"]
		var doors: Array = data["doors"]
		var bay: Array = data["bay"]
		var segs := [[-5.6, 5.6]]
		for dt in doors:
			segs = _cut_seg(segs, float(dt) - 0.86, float(dt) + 0.86)
		if not bay.is_empty():
			segs = _cut_seg(segs, float(bay[0]) - float(bay[1]) * 0.5 - 0.28,
				float(bay[0]) + float(bay[1]) * 0.5 + 0.28)
		var mat: Material = Mats.sch_locker() if _r(salt + si) < 0.68 \
			else Mats.sch_locker_blue()
		var lo_local := side - signf(side) * (T * 0.5 + depth * 0.5)
		for sg in segs:
			var a: float = sg[0]
			var b: float = sg[1]
			if b - a < 1.0:
				continue
			if along_x:
				_sch_locker_run(true, S * 0.5 + lo_local, a + S * 0.5,
					b + S * 0.5, -signf(side), mat, depth, hgt, salt + si * 19)
			else:
				_sch_locker_run(false, S * 0.5 + lo_local, S * 0.5 - b,
					S * 0.5 - a, -signf(side), mat, depth, hgt, salt + si * 19)


## The bank itself: carcass, kick plinth, and two tiers of doors with vents
## and latches. One collider for the whole run, not forty.
func _sch_locker_run(along_x: bool, off: float, from: float, to: float,
		facing: float, mat: Material, depth: float, hgt: float, salt: int) -> void:
	var ln := to - from
	var plinth := 0.12
	var c := (from + to) * 0.5
	if along_x:
		_box(Vector3(c, plinth + (hgt - plinth) / 2.0, off), Vector3(ln, hgt - plinth, depth), mat, false)
		_box(Vector3(c, plinth / 2.0, off), Vector3(ln, plinth, depth - 0.06), Mats.charcoal(), false)
		_collider_box(Vector3(c, hgt / 2.0, off), Vector3(ln, hgt, depth))
	else:
		_box(Vector3(off, plinth + (hgt - plinth) / 2.0, c), Vector3(depth, hgt - plinth, ln), mat, false)
		_box(Vector3(off, plinth / 2.0, c), Vector3(depth - 0.06, plinth, ln), Mats.charcoal(), false)
		_collider_box(Vector3(off, hgt / 2.0, c), Vector3(depth, hgt, ln))
	var dw := 0.305
	var cnt := int(ln / dw)
	if cnt < 1:
		return
	var pad := (ln - float(cnt) * dw) * 0.5
	var face := off + facing * (depth * 0.5 + 0.012)
	for i in cnt:
		var t := from + pad + dw * (float(i) + 0.5)
		for tier in 2:
			var y := plinth + 0.44 + 0.85 * float(tier)
			var open := WorldGen.r01(wseed, cell.x * 61 + i, cell.y * 13 + tier, salt + 3) < 0.05
			var dm: Material = Mats.charcoal() if open else mat
			var fs := Vector3(dw - 0.018, 0.82, 0.024) if along_x else Vector3(0.024, 0.82, dw - 0.018)
			var fp := Vector3(t, y, face) if along_x else Vector3(face, y, t)
			_box(fp, fs, dm, false)
			if open:
				continue
			var vs := Vector3(dw * 0.5, 0.10, 0.012) if along_x else Vector3(0.012, 0.10, dw * 0.5)
			var vp := Vector3(t, y + 0.33, face + facing * 0.014) if along_x \
				else Vector3(face + facing * 0.014, y + 0.33, t)
			_box(vp, vs, Mats.charcoal(), false)
			var hs := Vector3(0.035, 0.13, 0.03) if along_x else Vector3(0.03, 0.13, 0.035)
			var hp := Vector3(t + dw * 0.3, y - 0.26, face + facing * 0.02) if along_x \
				else Vector3(face + facing * 0.02, y - 0.26, t + dw * 0.3)
			_box(hp, hs, Mats.sch_trim(), false)


func _sch_corridor() -> void:
	_sch_narrow()
	_sch_passage_lockers(300)
	var along_x := _sch_corridor_axis() == 1
	var yw := 0.0 if along_x else PI / 2.0
	var o := Vector3(S / 2.0, 0, S / 2.0)
	var side_data := [_sch_corridor_side_data(0, along_x),
		_sch_corridor_side_data(1, along_x)]
	# a bin, and sometimes something knocked over and left
	var si := 1 if _r(311) < 0.5 else 0
	var data: Dictionary = side_data[si]
	var t := _sch_corridor_prop_t(si, 310, data["doors"], data["bay"], 0.58)
	var side := -1.15 if si == 0 else 1.15
	var p := _wp(o, Vector3(t, 0, side), yw)
	if _r(312) < 0.62:
		if t < 90.0:
			_sch_bin(p)
	if _r(313) < 0.35:
		var si2 := 1 if _r(315) < 0.5 else 0
		var data2: Dictionary = side_data[si2]
		var t2 := _sch_corridor_prop_t(si2, 314, data2["doors"], data2["bay"], 0.92)
		if t2 < 90.0:
			var s2 := -1.1 if si2 == 0 else 1.1
			_sch_trolley(_wp(o, Vector3(t2, 0, s2), yw), _r(316) * TAU)
	if _r(317) < 0.3:
		var si3 := 1 if _r(319) < 0.5 else 0
		var data3: Dictionary = side_data[si3]
		var t3 := _sch_corridor_prop_t(si3, 318, data3["doors"], data3["bay"], 0.78)
		if t3 < 90.0:
			var s3 := -1.0 if si3 == 0 else 1.0
			_sch_stack_chairs(_wp(o, Vector3(t3, 0, s3), yw), _r(320) * TAU, 321)


## Wheeled steel bin, the kind parked by the doors and never emptied.
func _sch_bin(p: Vector3) -> void:
	_cyl(p + Vector3(0, 0.42, 0), 0.29, 0.84, Mats.sch_trim())
	_cyl(p + Vector3(0, 0.85, 0), 0.30, 0.05, Mats.charcoal(), false)


## Stacked plastic chairs, shoved against a wall at the end of term.
func _sch_stack_chairs(p: Vector3, yaw: float, salt: int) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = yaw
	add_child(v)
	var hue := 0.53 + 0.14 * _r(salt)
	var cm := Mats.sch_chair(hue)
	var n := 3 + int(_r(salt + 1) * 3.99)
	for i in n:
		var y := 0.42 + 0.115 * float(i)
		_mbox(v, Vector3(0, y, 0.02 * float(i)), Vector3(0.42, 0.03, 0.42), cm)
		_mbox(v, Vector3(0, y + 0.24, -0.19 + 0.02 * float(i)), Vector3(0.42, 0.44, 0.03), cm)
	for sx in [-0.17, 0.17]:
		for sz in [-0.17, 0.17]:
			_mcyl(v, Vector3(sx, 0.21, sz), 0.014, 0.42, Mats.sch_trim())
	_collider_yaw_box(p + Vector3(0, 0.5, 0), Vector3(0.5, 1.0, 0.5), yaw)


## Janitor's trolley — mop bucket on castors, handle, a bag hanging off it.
func _sch_trolley(p: Vector3, yaw: float) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = yaw
	add_child(v)
	_mbox(v, Vector3(0, 0.34, 0), Vector3(0.52, 0.44, 0.38), Mats.jug_blue())
	_mbox(v, Vector3(0, 0.60, -0.17), Vector3(0.5, 0.09, 0.05), Mats.charcoal())
	_mcyl(v, Vector3(0, 0.78, 0.16), 0.018, 0.9, Mats.sch_trim())
	_mcyl(v, Vector3(0.19, 1.15, 0.16), 0.06, 0.24, Mats.charcoal())
	for sx in [-0.2, 0.2]:
		for sz in [-0.14, 0.14]:
			_mcyl(v, Vector3(sx, 0.06, sz), 0.05, 0.04, Mats.charcoal())
	_collider_yaw_box(p + Vector3(0, 0.4, 0), Vector3(0.55, 0.8, 0.45), yaw)


## Yaw that sits a student facing the given wall, so the class faces the board
## rather than the back of the room.
##
## The convention here is +Z, not the usual -Z forward: a chair's backrest is
## modelled at local -Z, so whoever is sitting in it looks along local +Z.
## That means (sin yaw, cos yaw) is the direction the class is facing, and
## everything else in the room is laid out from that vector.
func _sch_face_yaw(dir: int) -> float:
	match dir:
		0: return PI / 2.0        # faces +x
		1: return -PI / 2.0       # faces -x
		2: return 0.0             # faces +z
	return PI                     # faces -z


## A solid wall to hang the front of the room on, or -1 if the cell has none.
func _sch_front_wall(salt: int) -> int:
	return WorldGen.anchor_wall(wseed, cell, salt)


## Student desk: a tray top on a tube frame, with a chair tucked under it.
func _sch_desk(p: Vector3, yaw: float, salt: int) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = yaw + (_r(salt) - 0.5) * 0.12
	add_child(v)
	_mbox(v, Vector3(0, 0.74, 0), Vector3(0.62, 0.035, 0.46), Mats.sch_desk())
	_mbox(v, Vector3(0, 0.60, -0.06), Vector3(0.54, 0.03, 0.34), Mats.sch_trim())
	for sx in [-0.26, 0.26]:
		for sz in [-0.18, 0.18]:
			_mcyl(v, Vector3(sx, 0.37, sz), 0.016, 0.74, Mats.sch_trim())
	_collider_yaw_box(p + Vector3(0, 0.4, 0), Vector3(0.64, 0.8, 0.5), yaw)
	if _r(salt + 1) < 0.22:
		_mbox(v, Vector3((_r(salt + 2) - 0.5) * 0.3, 0.765, 0.02),
			Vector3(0.2, 0.016, 0.28), Mats.box_white())
	# chair behind, pushed in or shoved aside
	var hue := 0.52 + 0.12 * _r(salt + 3)
	var cv := Node3D.new()
	cv.position = p - Vector3(sin(yaw) * 0.52, 0, cos(yaw) * 0.52)
	cv.rotation.y = yaw + (_r(salt + 4) - 0.5) * 0.8
	add_child(cv)
	var cm := Mats.sch_chair(hue)
	_mbox(cv, Vector3(0, 0.44, 0), Vector3(0.4, 0.03, 0.4), cm)
	_mbox(cv, Vector3(0, 0.68, -0.18), Vector3(0.4, 0.44, 0.03), cm)
	for sx in [-0.16, 0.16]:
		for sz in [-0.16, 0.16]:
			_mcyl(cv, Vector3(sx, 0.22, sz), 0.013, 0.44, Mats.sch_trim())


func _sch_desk_row(p: Vector3, yaw: float, n: int, salt: int) -> void:
	var rx := cos(yaw)
	var rz := -sin(yaw)
	for i in n:
		var d := (float(i) - float(n - 1) * 0.5) * 0.86
		_sch_desk(p + Vector3(rx * d, 0, rz * d), yaw, salt + i * 5)


## The board, the tray of stubs under it, and the strip of pinned work above.
func _sch_chalkboard(dir: int) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var plane := (S - T / 2.0) if (dir == 0 or dir == 2) else (T / 2.0)
	var inner := plane + n * (T / 2.0)
	var ln := 4.2
	var y := 1.55
	# slide off centre if a doorway is in the way, rather than hanging the
	# board across the opening
	var cen := S / 2.0
	var binfo := WorldGen.edge_info(wseed, cell, dir, theme)
	if not binfo["wall"]:
		var dt: float = binfo["t"]
		var need: float = float(binfo["w"]) * 0.5 + ln * 0.5 + 0.3
		if absf(cen - dt) < need:
			cen = dt + need if dt < S / 2.0 else dt - need
		cen = clampf(cen, ln * 0.5 + 0.3, S - ln * 0.5 - 0.3)
	var bm: Material = Mats.sch_board()
	var d0 := inner + n * 0.03
	if dir < 2:
		_box(Vector3(d0, y, cen), Vector3(0.05, 1.25, ln), bm, false)
		_box(Vector3(d0 + n * 0.02, y - 0.68, cen), Vector3(0.09, 0.05, ln), Mats.sch_trim(), false)
		for edge in [-1.0, 1.0]:
			_box(Vector3(d0, y, cen + edge * ln / 2.0), Vector3(0.07, 1.33, 0.06),
				Mats.sch_trim(), false)
	else:
		_box(Vector3(cen, y, d0), Vector3(ln, 1.25, 0.05), bm, false)
		_box(Vector3(cen, y - 0.68, d0 + n * 0.02), Vector3(ln, 0.05, 0.09), Mats.sch_trim(), false)
		for edge in [-1.0, 1.0]:
			_box(Vector3(cen + edge * ln / 2.0, y, d0), Vector3(0.06, 1.33, 0.07),
				Mats.sch_trim(), false)
	_sch_chalk(dir, cen, ln)
	# a row of work pinned above it, curling off the wall
	if _r(71) < 0.7:
		for i in 5:
			var t := cen - 1.7 + 0.85 * float(i)
			var py := 2.48
			var ps := Vector3(0.01, 0.3, 0.22) if dir < 2 else Vector3(0.22, 0.3, 0.01)
			var pp := Vector3(inner + n * 0.02, py, t) if dir < 2 else Vector3(t, py, inner + n * 0.02)
			_box(pp, ps, Mats.box_white(), false)


func _sch_classroom() -> void:
	var fw := _sch_front_wall(72)
	if fw < 0:
		fw = 3
	_sch_chalkboard(fw)
	var yaw := _sch_face_yaw(fw)
	# the direction the class looks — toward the board
	var fx := sin(yaw)
	var fz := cos(yaw)
	var c := Vector3(S / 2.0, 0, S / 2.0)
	# teacher's desk between the class and the board
	var td := c + Vector3(fx, 0, fz) * 3.5
	var tv := Node3D.new()
	tv.position = td
	tv.rotation.y = yaw + PI
	add_child(tv)
	_mbox(tv, Vector3(0, 0.75, 0), Vector3(1.5, 0.05, 0.72), Mats.sch_desk())
	_mbox(tv, Vector3(0, 0.37, 0.3), Vector3(1.44, 0.72, 0.08), Mats.sch_desk())
	for sx in [-0.7, 0.7]:
		_mbox(tv, Vector3(sx, 0.37, 0), Vector3(0.06, 0.74, 0.68), Mats.sch_desk())
	_collider_yaw_box(td + Vector3(0, 0.4, 0), Vector3(1.5, 0.8, 0.75), yaw)
	_chair_at(td + Vector3(fx, 0, fz) * 0.85, yaw + PI, Mats.fabric_charcoal())
	# rows of desks, filling back from the front
	var rows := 4
	for row in rows:
		var back := 0.4 + 1.5 * float(row)
		var origin := c + Vector3(fx, 0, fz) * (1.4 - back)
		_sch_desk_row(origin, yaw, 5, 80 + row * 20)
	if _r(74) < 0.5:
		_sch_screen(fw)
	# the stuff that accumulates down the side of every classroom
	var side := Vector3(fz, 0, -fx)          # perpendicular to the class's facing
	_sch_cupboard(c + side * 4.7 + Vector3(fx, 0, fz) * 1.2, yaw + PI / 2.0, 88)
	if _r(89) < 0.7:
		_sch_stack(c - side * 4.9, yaw + PI / 2.0, 90)
	_sch_bin(c + Vector3(fx, 0, fz) * 3.0 + side * 3.4)


## Steel storage cupboard, the tall kind with the dented doors.
func _sch_cupboard(p: Vector3, yaw: float, salt: int) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = yaw
	add_child(v)
	var hgt := 1.95
	_mbox(v, Vector3(0, hgt / 2.0, 0), Vector3(1.0, hgt, 0.46), Mats.sch_trim())
	for sx in [-0.25, 0.25]:
		_mbox(v, Vector3(sx, hgt / 2.0, 0.235), Vector3(0.47, hgt - 0.08, 0.02),
			Mats.metal_gray())
		_mbox(v, Vector3(sx + 0.19, 1.0, 0.25), Vector3(0.05, 0.16, 0.02), Mats.charcoal())
	_collider_yaw_box(p + Vector3(0, hgt / 2.0, 0), Vector3(1.0, hgt, 0.5), yaw)
	if _r(salt) < 0.5:
		for i in 3:
			_mbox(v, Vector3(-0.3 + 0.3 * float(i), hgt + 0.09, 0),
				Vector3(0.26, 0.18, 0.3), Mats.box_white())


## Left up from a lesson that was interrupted, or that nobody sat. The hand
## is the same shaky marker the asylum walls are written in — a school board
## is chalk, so it is pale on green, and half rubbed out with the side of a
## fist.
const SCH_CHALK := [
	"TODAY: FRIDAY\nTOMORROW: FRIDAY",
	"HOMEWORK\nfinish the corridor",
	"ATTENDANCE\n0 / 0 PRESENT",
	"DO NOT LOOK AT\nTHE BACK ROW",
	"SUBSTITUTE TEACHER\nAGAIN",
	"PERIOD 9\nPERIOD 9\nPERIOD 9",
	"WHO TURNED OFF\nTHE BELL?",
	"READ CHAPTER\nAGAIN",
	"TEST TOMORROW\n(there is no tomorrow)",
	"PLEASE REMAIN\nSEATED UNTIL",
	"IF YOU CAN READ THIS\nYOU ARE STILL HERE",
	"class of\n19__",
]


func _sch_chalk(dir: int, cen: float, ln: float) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var plane := (S - T / 2.0) if (dir == 0 or dir == 2) else (T / 2.0)
	var inner := plane + n * (T / 2.0)
	var lb := Label3D.new()
	lb.text = SCH_CHALK[WorldGen.h(wseed, cell.x, cell.y, 77) % SCH_CHALK.size()]
	var hand := 0 if _r(78) < 0.6 else 1
	lb.font = _scrawl_font(hand)
	lb.font_size = 46 if hand == 0 else 86
	lb.pixel_size = 0.0030 * (1.0 + (_r(79) - 0.5) * 0.3)
	lb.width = 1000.0
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD
	lb.modulate = Color(0.88, 0.90, 0.85, 0.72)   # chalk, and a dusty board
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var y := 1.62
	var t := cen + (_r(80) - 0.5) * (ln * 0.25)
	if dir < 2:
		lb.position = Vector3(inner + n * 0.06, y, t)
		lb.rotation.y = PI / 2.0 * n
	else:
		lb.position = Vector3(t, y, inner + n * 0.06)
		lb.rotation.y = 0.0 if n > 0.0 else PI
	lb.rotation.z = (_r(81) - 0.5) * 0.05
	add_child(lb)
	# the ghost of the last lesson, wiped with the side of a hand
	for i in 3:
		var sy := 1.15 + 0.42 * float(i)
		var sw := lerpf(0.6, 1.5, _r(82 + i))
		var st := cen + (_r(85 + i) - 0.5) * (ln - sw)
		var ss := Vector3(0.008, 0.3, sw) if dir < 2 else Vector3(sw, 0.3, 0.008)
		var sp := Vector3(inner + n * 0.045, sy, st) if dir < 2 \
			else Vector3(st, sy, inner + n * 0.045)
		var sm := _box(sp, ss, Mats.sch_chalkdust(), false)
		sm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Pull-down projector screen, half unrolled above the board.
func _sch_screen(dir: int) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var plane := (S - T / 2.0) if (dir == 0 or dir == 2) else (T / 2.0)
	var inner := plane + n * (T / 2.0)
	var drop := lerpf(0.3, 0.7, _r(75))
	var y := ceil_h - 0.35 - drop / 2.0
	var t := S / 2.0 + (_r(76) - 0.5) * 2.0
	if dir < 2:
		_box(Vector3(inner + n * 0.09, ceil_h - 0.3, t), Vector3(0.1, 0.1, 1.9), Mats.sch_trim(), false)
		_box(Vector3(inner + n * 0.09, y, t), Vector3(0.02, drop, 1.75), Mats.box_white(), false)
	else:
		_box(Vector3(t, ceil_h - 0.3, inner + n * 0.09), Vector3(1.9, 0.1, 0.1), Mats.sch_trim(), false)
		_box(Vector3(t, y, inner + n * 0.09), Vector3(1.75, drop, 0.02), Mats.box_white(), false)


## Folding table with the benches welded on — cafeteria, and nowhere else.
func _sch_caf_table(p: Vector3, yaw: float, salt: int) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = yaw
	add_child(v)
	var ln := 2.9
	_mbox(v, Vector3(0, 0.75, 0), Vector3(ln, 0.05, 0.76), Mats.sch_desk())
	for sz in [-0.72, 0.72]:
		_mbox(v, Vector3(0, 0.45, sz), Vector3(ln, 0.04, 0.28), Mats.sch_desk())
		for sx in [-ln * 0.32, ln * 0.32]:
			_mbox(v, Vector3(sx, 0.22, sz), Vector3(0.05, 0.44, 0.26), Mats.sch_trim())
	for sx in [-ln * 0.32, ln * 0.32]:
		_mbox(v, Vector3(sx, 0.37, 0), Vector3(0.07, 0.74, 0.1), Mats.sch_trim())
		_mbox(v, Vector3(sx, 0.06, 0), Vector3(0.09, 0.12, 1.5), Mats.sch_trim())
	_collider_yaw_box(p + Vector3(0, 0.4, 0), Vector3(ln, 0.8, 1.6), yaw)
	if _r(salt) < 0.4:
		_mbox(v, Vector3((_r(salt + 1) - 0.5) * 1.8, 0.785, (_r(salt + 2) - 0.5) * 0.4),
			Vector3(0.35, 0.03, 0.26), Mats.sch_chair(0.08))


func _sch_cafeteria() -> void:
	var span := _room_span()
	var big := span.x > 20.0 or span.y > 20.0
	var along_x := span.x >= span.y
	var yaw := 0.0 if along_x else PI / 2.0
	var cols := 3 if big else 2
	var rows := 3 if big else 2
	var pitch := 3.4
	for r in rows:
		for cc in cols:
			var u := (float(cc) - float(cols - 1) * 0.5) * pitch
			var w := (float(r) - float(rows - 1) * 0.5) * (pitch * 0.85)
			var p := Vector3(S / 2.0 + u, 0, S / 2.0 + w)
			_sch_caf_table(p, yaw, 400 + r * 30 + cc * 7)
	# the serving line against whichever wall is solid
	var sw := _sch_front_wall(410)
	if sw >= 0:
		_sch_servery(sw)


## Stainless serving counter with a sneeze guard and empty wells.
func _sch_servery(dir: int) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var plane := (S - T / 2.0) if (dir == 0 or dir == 2) else (T / 2.0)
	var inner := plane + n * (T / 2.0)
	var ln := 5.0
	var d := inner + n * 0.5
	var c := S / 2.0
	if dir < 2:
		_box(Vector3(d, 0.45, c), Vector3(0.9, 0.9, ln), Mats.sch_trim())
		_box(Vector3(d, 0.93, c), Vector3(1.0, 0.06, ln + 0.1), Mats.steel(), false)
		_box(Vector3(d - n * 0.1, 1.55, c), Vector3(0.03, 0.5, ln), Mats.glass(), false)
		for i in 3:
			_box(Vector3(d, 0.97, c - 1.5 + 1.5 * float(i)), Vector3(0.55, 0.05, 0.9),
				Mats.charcoal(), false)
	else:
		_box(Vector3(c, 0.45, d), Vector3(ln, 0.9, 0.9), Mats.sch_trim())
		_box(Vector3(c, 0.93, d), Vector3(ln + 0.1, 0.06, 1.0), Mats.steel(), false)
		_box(Vector3(c, 1.55, d - n * 0.1), Vector3(ln, 0.5, 0.03), Mats.glass(), false)
		for i in 3:
			_box(Vector3(c - 1.5 + 1.5 * float(i), 0.97, d), Vector3(0.9, 0.05, 0.55),
				Mats.charcoal(), false)


func _sch_bathroom() -> void:
	var sw := _sch_front_wall(500)
	if sw < 0:
		sw = 3
	# stalls along the front wall, sinks on the one to its left
	_sch_stalls(sw)
	_sch_sinks((sw + 2) % 4)


## A run of cubicles: partitions, doors ajar, gap at the floor.
func _sch_stalls(dir: int) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var plane := (S - T / 2.0) if (dir == 0 or dir == 2) else (T / 2.0)
	var inner := plane + n * (T / 2.0)
	var depth := 1.5
	var d := inner + n * depth * 0.5
	var pm := Mats.sch_chair(0.35)
	var cnt := 3
	var w := 1.05
	var start := S / 2.0 - float(cnt) * w * 0.5
	for i in cnt + 1:
		var t := start + w * float(i)
		if dir < 2:
			_box(Vector3(d, 1.25, t), Vector3(depth, 1.8, 0.05), pm, true)
		else:
			_box(Vector3(t, 1.25, d), Vector3(0.05, 1.8, depth), pm, true)
	for i in cnt:
		var t := start + w * (float(i) + 0.5)
		# pan and cistern against the wall
		var pp := Vector3(inner + n * 0.32, 0.2, t) if dir < 2 else Vector3(t, 0.2, inner + n * 0.32)
		_box(pp, Vector3(0.4, 0.4, 0.36) if dir < 2 else Vector3(0.36, 0.4, 0.4),
			Mats.sch_white(), false)
		var cp := Vector3(inner + n * 0.12, 0.75, t) if dir < 2 else Vector3(t, 0.75, inner + n * 0.12)
		_box(cp, Vector3(0.2, 0.4, 0.44) if dir < 2 else Vector3(0.44, 0.4, 0.2),
			Mats.sch_white(), false)
		# the door, swung part way open
		var ang := lerpf(0.25, 1.3, WorldGen.r01(wseed, cell.x + i, cell.y, 505))
		var dv := Node3D.new()
		var hinge := t - w * 0.5 + 0.04
		dv.position = Vector3(inner + n * depth, 1.25, hinge) if dir < 2 \
			else Vector3(hinge, 1.25, inner + n * depth)
		dv.rotation.y = (0.0 if dir < 2 else PI / 2.0) + ang * n
		add_child(dv)
		_mbox(dv, Vector3(0, 0, w * 0.5), Vector3(0.04, 1.6, w - 0.1), pm)


## Sinks under a long mirror, one tap dripping somewhere in the building.
func _sch_sinks(dir: int) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var plane := (S - T / 2.0) if (dir == 0 or dir == 2) else (T / 2.0)
	var inner := plane + n * (T / 2.0)
	var cnt := 3
	var w := 0.92
	var start := S / 2.0 - float(cnt) * w * 0.5
	var d := inner + n * 0.22
	# mirror band
	var mp := Vector3(inner + n * 0.02, 1.72, S / 2.0) if dir < 2 \
		else Vector3(S / 2.0, 1.72, inner + n * 0.02)
	_box(mp, Vector3(0.02, 0.9, float(cnt) * w) if dir < 2 else Vector3(float(cnt) * w, 0.9, 0.02),
		Mats.gold_mirror(), false)
	for i in cnt:
		var t := start + w * (float(i) + 0.5)
		var bp := Vector3(d, 0.86, t) if dir < 2 else Vector3(t, 0.86, d)
		_box(bp, Vector3(0.44, 0.16, 0.6) if dir < 2 else Vector3(0.6, 0.16, 0.44),
			Mats.sch_white(), true)
		var tp := Vector3(inner + n * 0.08, 1.06, t) if dir < 2 else Vector3(t, 1.06, inner + n * 0.08)
		_cyl(tp, 0.02, 0.16, Mats.chrome(), false)


func _sch_gym() -> void:
	var span := _room_span()
	var half := minf(span.x, span.y) * 0.5
	var c := Vector3(S / 2.0, 0, S / 2.0)
	# painted court, laid on the boards
	var lm := Mats.sch_red()
	var cl := half - 1.6
	for sx in [-cl, cl]:
		_box(c + Vector3(sx, 0.004, 0), Vector3(0.06, 0.008, cl * 2.0), lm, false)
	for sz in [-cl, cl]:
		_box(c + Vector3(0, 0.004, sz), Vector3(cl * 2.0, 0.008, 0.06), lm, false)
	_box(c + Vector3(0, 0.004, 0), Vector3(cl * 2.0, 0.008, 0.06), lm, false)
	_cyl(c + Vector3(0, 0.004, 0), 1.8, 0.008, lm, false)
	_cyl(c + Vector3(0, 0.006, 0), 1.66, 0.008, Mats.sch_gymfloor(), false)
	# a hoop at each end, and bleachers down one side
	for sgn in [-1.0, 1.0]:
		_sch_hoop(c + Vector3(0, 0, sgn * (half - 0.7)), 0.0 if sgn < 0.0 else PI)
	_sch_bleachers(c + Vector3(-(half - 1.3), 0, 0), PI / 2.0, minf(half * 1.5, 9.0))
	if _r(600) < 0.6:
		_sch_bleachers(c + Vector3(half - 1.3, 0, 0), -PI / 2.0, minf(half * 1.5, 9.0))


## Landmark: the school auditorium. A real raised stage and two disciplined
## seating banks give the hall a remembered orientation, while one displaced
## modelled chair breaks the procedural rhythm near the centre aisle.
func _sch_auditorium() -> void:
	var c := Vector3(S / 2.0, 0, S / 2.0)
	var stage := c + Vector3(0, 0, -8.2)
	_rbox(stage + Vector3(0, 0.32, 0), Vector3(15.5, 0.64, 3.5), Mats.sch_desk(), 0.025)
	_collider_box(stage + Vector3(0, 0.34, 0), Vector3(15.6, 0.68, 3.6))
	# Heavy red curtains, closed except for an uneasy centre gap.
	for side: float in [-1.0, 1.0]:
		for i in 6:
			var x := side * (1.0 + 1.15 * float(i))
			_box(stage + Vector3(x, 3.1, -1.58), Vector3(0.72, 5.3, 0.10),
				Mats.velvet() if i % 2 == 0 else Mats.velvet2(), false)
	# Lectern and a microphone left facing the empty seats.
	_rbox(stage + Vector3(-2.0, 1.05, 0.35), Vector3(1.1, 1.45, 0.65), Mats.darkwood(), 0.035)
	var stem := _cyl(stage + Vector3(1.6, 1.35, 0.35), 0.025, 1.9, Mats.charcoal(), false)
	stem.rotation.z = -0.12
	_sphere(stage + Vector3(1.72, 2.28, 0.35), 0.06, Mats.charcoal())
	# Six rows, split by the centre aisle. Seats are simplified into shared
	# row geometry so the landmark stays cheaper than a room full of glTFs.
	for row in 6:
		var z := -4.6 + 2.05 * float(row)
		for side in [-1.0, 1.0]:
			var row_c := c + Vector3(side * 4.2, 0, z)
			for col in 5:
				var x := (float(col) - 2.0) * 1.25
				var p := row_c + Vector3(x, 0, 0)
				_rbox(p + Vector3(0, 0.48, 0), Vector3(0.82, 0.10, 0.68),
					Mats.sch_chair(0.56 + 0.05 * _r(1200 + row * 10 + col)), 0.035, false)
				_rbox(p + Vector3(0, 0.83, -0.28), Vector3(0.82, 0.62, 0.10),
					Mats.sch_chair(0.58), 0.035, false)
			for bx in [-2.6, 2.6]:
				_box(row_c + Vector3(bx, 0.27, 0), Vector3(0.08, 0.54, 0.62), Mats.sch_trim(), false)
			_collider_box(row_c + Vector3(0, 0.58, 0), Vector3(6.0, 1.16, 0.78))
	var loose := c + Vector3(0.25, 0, 5.8)
	_asy_model("SchoolChair_01", loose, PI + 0.48)
	_collider_yaw_box(loose + Vector3(0, 0.5, 0), Vector3(0.58, 1.02, 0.7), PI + 0.48)
	# Exit boxes make the room recognizable from the rear doors.
	for x in [-7.6, 7.6]:
		var ex := Label3D.new()
		ex.text = "EXIT"
		ex.font_size = 84
		ex.pixel_size = 0.0022
		ex.modulate = Color(1.0, 0.22, 0.16)
		ex.position = c + Vector3(x, 2.4, 8.5)
		ex.rotation.y = PI
		add_child(ex)


## Backboard, ring, and the folded arms holding it off the wall.
func _sch_hoop(p: Vector3, yaw: float) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = yaw
	add_child(v)
	_mbox(v, Vector3(0, 3.05, 0), Vector3(1.8, 1.05, 0.05), Mats.sch_white())
	_mbox(v, Vector3(0, 2.86, 0), Vector3(0.59, 0.45, 0.02), Mats.sch_red())
	_mbox(v, Vector3(0, 2.62, 0.22), Vector3(0.45, 0.03, 0.45), Mats.sch_red())
	for sx in [-0.5, 0.5]:
		_mbox(v, Vector3(sx, 3.5, -0.5), Vector3(0.06, 0.06, 1.1), Mats.sch_trim())
	_mbox(v, Vector3(0, 3.05, -0.55), Vector3(0.08, 0.08, 1.1), Mats.sch_trim())
	# net, as a ring of short hanging strands
	for i in 8:
		var a := TAU * float(i) / 8.0
		_mcyl(v, Vector3(sin(a) * 0.2, 2.46, 0.22 + cos(a) * 0.2), 0.008, 0.3, Mats.box_white())


## Retractable bleachers, pulled out and left out.
func _sch_bleachers(p: Vector3, yaw: float, ln: float) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = yaw
	add_child(v)
	var tiers := 4
	for i in tiers:
		var y := 0.42 + 0.42 * float(i)
		var z := -0.4 - 0.62 * float(i)
		_mbox(v, Vector3(0, y, z), Vector3(ln, 0.06, 0.5), Mats.sch_desk())
		_mbox(v, Vector3(0, y - 0.21, z - 0.28), Vector3(ln, 0.42, 0.06), Mats.sch_trim())
	_collider_yaw_box(p + Vector3(-sin(yaw) * 1.5, 1.0, -cos(yaw) * 1.5),
		Vector3(ln, 2.0, 3.0), yaw)


func _sch_library() -> void:
	var span := _room_span()
	var along_x := span.x >= span.y
	var runs := 3 if maxf(span.x, span.y) > 20.0 else 2
	for i in runs:
		var u := (float(i) - float(runs - 1) * 0.5) * 3.2
		var p := Vector3(S / 2.0 + u, 0, S / 2.0) if along_x else Vector3(S / 2.0, 0, S / 2.0 + u)
		_sch_stack(p, 0.0 if along_x else PI / 2.0, 620 + i * 9)
	# a reading table off to one side
	var tp := Vector3(S / 2.0, 0, S / 2.0) + (Vector3(0, 0, 4.2) if along_x else Vector3(4.2, 0, 0))
	_sch_caf_table(tp, 0.0 if along_x else PI / 2.0, 640)


## A double-sided run of shelving, most of it still full.
func _sch_stack(p: Vector3, yaw: float, salt: int) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = yaw
	add_child(v)
	var ln := 4.4
	var hgt := 2.0
	_mbox(v, Vector3(0, hgt / 2.0, 0), Vector3(ln, hgt, 0.06), Mats.sch_desk())
	for sz in [-0.17, 0.17]:
		for sh in 4:
			var y := 0.42 + 0.46 * float(sh)
			_mbox(v, Vector3(0, y, sz), Vector3(ln, 0.04, 0.34), Mats.sch_desk())
			# books, in blocks with gaps where a shelf has been raided
			var x := -ln * 0.5 + 0.2
			var k := 0
			while x < ln * 0.5 - 0.3:
				var bw := lerpf(0.25, 0.7, WorldGen.r01(wseed, cell.x + k, cell.y + sh, salt))
				if WorldGen.r01(wseed, cell.x + k * 3, cell.y + sh, salt + 1) < 0.28:
					x += bw
					k += 1
					continue
				var bh := lerpf(0.24, 0.34, WorldGen.r01(wseed, k, sh, salt + 2))
				var hue := WorldGen.r01(wseed, k * 7, sh, salt + 3)
				_mbox(v, Vector3(x + bw * 0.5, y + 0.02 + bh * 0.5, sz), Vector3(bw, bh, 0.26),
					Mats.sch_chair(hue))
				x += bw + 0.03
				k += 1
	_mbox(v, Vector3(0, hgt - 0.02, 0), Vector3(ln, 0.05, 0.42), Mats.sch_desk())
	_collider_yaw_box(p + Vector3(0, hgt / 2.0, 0), Vector3(ln, hgt, 0.46), yaw)


func _sch_lab() -> void:
	var span := _room_span()
	var along_x := span.x >= span.y
	var yaw := 0.0 if along_x else PI / 2.0
	for i in 3:
		var u := (float(i) - 1.0) * 2.7
		var p := Vector3(S / 2.0, 0, S / 2.0) + (Vector3(0, 0, u) if along_x else Vector3(u, 0, 0))
		_sch_lab_bench(p, yaw, 700 + i * 11)
	var fw := _sch_front_wall(710)
	if fw >= 0:
		_sch_chalkboard(fw)


## Black-topped bench with a sink, gooseneck taps and stools.
func _sch_lab_bench(p: Vector3, yaw: float, salt: int) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = yaw
	add_child(v)
	var ln := 4.0
	_mbox(v, Vector3(0, 0.87, 0), Vector3(ln, 0.06, 0.78), Mats.charcoal())
	_mbox(v, Vector3(0, 0.45, 0), Vector3(ln - 0.15, 0.78, 0.66), Mats.sch_desk())
	# sink at one end, taps standing over it
	var sx := ln * 0.5 - 0.6
	_mbox(v, Vector3(sx, 0.855, 0), Vector3(0.5, 0.04, 0.42), Mats.sch_white())
	_mcyl(v, Vector3(sx - 0.3, 1.02, -0.22), 0.018, 0.28, Mats.chrome())
	for tx in [-ln * 0.28, 0.0, ln * 0.22]:
		_mcyl(v, Vector3(tx, 0.99, -0.28), 0.016, 0.2, Mats.pipe_green())
	_collider_yaw_box(p + Vector3(0, 0.45, 0), Vector3(ln, 0.9, 0.8), yaw)
	for i in 3:
		var ox := (float(i) - 1.0) * 1.2
		var sp := p + Vector3(cos(yaw) * ox, 0, -sin(yaw) * ox) \
			+ Vector3(sin(yaw), 0, cos(yaw)) * 0.75
		if WorldGen.r01(wseed, cell.x + i, cell.y, salt) < 0.2:
			continue
		_sch_stool(sp, salt + i)


func _sch_stool(p: Vector3, salt: int) -> void:
	var v := Node3D.new()
	v.position = p
	v.rotation.y = WorldGen.r01(wseed, cell.x, cell.y, salt) * TAU
	add_child(v)
	_mcyl(v, Vector3(0, 0.62, 0), 0.17, 0.05, Mats.sch_desk())
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI / 4.0
		_mcyl(v, Vector3(sin(a) * 0.13, 0.31, cos(a) * 0.13), 0.014, 0.62, Mats.sch_trim())
	_mcyl(v, Vector3(0, 0.28, 0), 0.15, 0.02, Mats.sch_trim())
	_collider_cyl(p + Vector3(0, 0.32, 0), 0.2, 0.64)


func _sch_admin() -> void:
	var fw := _sch_front_wall(800)
	# the counter you wait at, across the room
	var yaw := _sch_face_yaw(fw if fw >= 0 else 3)
	var c := Vector3(S / 2.0, 0, S / 2.0)
	var v := Node3D.new()
	v.position = c
	v.rotation.y = yaw
	add_child(v)
	_mbox(v, Vector3(0, 0.52, 0), Vector3(4.4, 1.04, 0.5), Mats.sch_desk())
	_mbox(v, Vector3(0, 1.08, 0), Vector3(4.6, 0.07, 0.66), Mats.sch_desk())
	_collider_yaw_box(c + Vector3(0, 0.55, 0), Vector3(4.4, 1.1, 0.55), yaw)
	var back := c - Vector3(sin(yaw), 0, cos(yaw)) * 2.4
	_office_desk_small(back, yaw + PI)
	_shelf_unit(back + Vector3(cos(yaw) * 2.2, 0, -sin(yaw) * 2.2), absf(cos(yaw)) > 0.5, 810)


# --- school: things on the walls ----------------------------------------------

## Cork board behind glass, layered with notices for terms already over.
func _sch_noticeboard(dir: int, plane: float) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T / 2.0)
	var along := S / 2.0 + (_r(900 + dir) - 0.5) * 3.4
	var w := lerpf(1.5, 2.4, _r(904 + dir))
	var y := 1.62
	var d0 := inner + n * 0.03
	var frame := Vector3(0.06, 1.25, w) if dir < 2 else Vector3(w, 1.25, 0.06)
	var fp := Vector3(d0, y, along) if dir < 2 else Vector3(along, y, d0)
	_box(fp, frame, Mats.sch_trim(), false)
	var cork := Vector3(0.02, 1.12, w - 0.1) if dir < 2 else Vector3(w - 0.1, 1.12, 0.02)
	var cp := Vector3(d0 + n * 0.03, y, along) if dir < 2 else Vector3(along, y, d0 + n * 0.03)
	_box(cp, cork, Mats.sch_cork(), false)
	for i in 6:
		var px := along + (WorldGen.r01(wseed, cell.x + i, cell.y, 908 + dir) - 0.5) * (w - 0.35)
		var py := y + (WorldGen.r01(wseed, cell.x, cell.y + i, 912 + dir) - 0.5) * 0.85
		var ps := Vector3(0.008, 0.26, 0.19) if dir < 2 else Vector3(0.19, 0.26, 0.008)
		var pp := Vector3(d0 + n * 0.05, py, px) if dir < 2 else Vector3(px, py, d0 + n * 0.05)
		_box(pp, ps, Mats.box_white(), false)


## Drinking fountain. Two of them, always, at the height of two different
## years of children.
func _sch_fountain(dir: int, plane: float) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T / 2.0)
	var along := S / 2.0 + (_r(920 + dir) - 0.5) * 3.0
	for pair in 2:
		var t := along + (float(pair) - 0.5) * 0.72
		var y := 0.86 if pair == 0 else 0.72
		var d0 := inner + n * 0.19
		var bs := Vector3(0.38, 0.36, 0.44) if dir < 2 else Vector3(0.44, 0.36, 0.38)
		var bp := Vector3(d0, y, t) if dir < 2 else Vector3(t, y, d0)
		_box(bp, bs, Mats.sch_white(), true)
		var ss := Vector3(0.34, 0.05, 0.4) if dir < 2 else Vector3(0.4, 0.05, 0.34)
		var sp := Vector3(d0, y + 0.19, t) if dir < 2 else Vector3(t, y + 0.19, d0)
		_box(sp, ss, Mats.chrome(), false)


## The trophy case by the front doors, still lit, still full.
func _sch_case(dir: int, plane: float) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T / 2.0)
	var along := S / 2.0 + (_r(930 + dir) - 0.5) * 2.6
	var w := 2.2
	var y := 1.5
	var depth := 0.34
	var d0 := inner + n * depth * 0.5
	var box := Vector3(depth, 1.9, w) if dir < 2 else Vector3(w, 1.9, depth)
	var bp := Vector3(d0, y, along) if dir < 2 else Vector3(along, y, d0)
	_box(bp, box, Mats.sch_trim(), true)
	var gs := Vector3(0.02, 1.7, w - 0.14) if dir < 2 else Vector3(w - 0.14, 1.7, 0.02)
	var gp := Vector3(inner + n * (depth + 0.01), y, along) if dir < 2 \
		else Vector3(along, y, inner + n * (depth + 0.01))
	_box(gp, gs, Mats.glass(), false)
	for sh in 3:
		var sy := 0.95 + 0.52 * float(sh)
		var ss := Vector3(depth - 0.08, 0.03, w - 0.16) if dir < 2 else Vector3(w - 0.16, 0.03, depth - 0.08)
		var sp := Vector3(d0, sy, along) if dir < 2 else Vector3(along, sy, d0)
		_box(sp, ss, Mats.sch_desk(), false)
		for i in 4:
			var tx := along + (float(i) - 1.5) * 0.48
			var hgt := lerpf(0.16, 0.3, WorldGen.r01(wseed, cell.x + i, cell.y + sh, 934))
			var tp := Vector3(d0, sy + 0.03 + hgt * 0.5, tx) if dir < 2 \
				else Vector3(tx, sy + 0.03 + hgt * 0.5, d0)
			_cyl(tp, 0.05, hgt, Mats.brass(), false)
			var cp2 := tp + Vector3(0, hgt * 0.5, 0)
			_sphere(cp2, 0.06, Mats.brass())


## A poster, curling at one corner: fire drill, periodic table, a motto.
func _sch_poster(dir: int, plane: float) -> void:
	var n := -1.0 if (dir == 0 or dir == 2) else 1.0
	var inner := plane + n * (T / 2.0)
	var along := S / 2.0 + (_r(940 + dir) - 0.5) * 4.0
	var y := lerpf(1.5, 2.0, _r(944 + dir))
	var w := lerpf(0.55, 0.9, _r(948 + dir))
	var h := w * 1.4
	var hue := _r(952 + dir)
	var ps := Vector3(0.012, h, w) if dir < 2 else Vector3(w, h, 0.012)
	var pp := Vector3(inner + n * 0.02, y, along) if dir < 2 else Vector3(along, y, inner + n * 0.02)
	var mi := _box(pp, ps, Mats.sch_chair(hue), false)
	mi.rotate_object_local(Vector3(1, 0, 0) if dir < 2 else Vector3(0, 0, 1),
		(_r(956 + dir) - 0.5) * 0.06)

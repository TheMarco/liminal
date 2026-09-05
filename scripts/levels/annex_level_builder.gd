extends "res://scripts/levels/chunk_level_builder.gd"

const MOISTURE_MASKS := [
	"res://textures/annex/moisture_mask_01.png",
	"res://textures/annex/moisture_mask_02.png",
	"res://textures/annex/moisture_mask_03.png",
	"res://textures/annex/moisture_mask_04.png",
	"res://textures/annex/moisture_mask_05.png",
	"res://textures/annex/moisture_mask_06.png",
	"res://textures/annex/moisture_mask_07.png",
	"res://textures/annex/moisture_mask_08.png",
]
const CARPET_DAMAGE_MASKS := [
	"res://textures/annex/carpet_damage_01.png",
	"res://textures/annex/carpet_damage_02.png",
	"res://textures/annex/carpet_damage_03.png",
	"res://textures/annex/carpet_damage_04.png",
	"res://textures/annex/carpet_damage_05.png",
	"res://textures/annex/carpet_damage_06.png",
	"res://textures/annex/carpet_damage_07.png",
	"res://textures/annex/carpet_damage_08.png",
]
static var _carpet_damage_quad: QuadMesh
static var _moisture_quad: QuadMesh

static func clear_runtime_cache() -> void:
	_carpet_damage_quad = null
	_moisture_quad = null


func _annex_floor_ceiling() -> void:
	scene.box(Vector3(WorldGen.CELL_SIZE / 2.0, -0.15, WorldGen.CELL_SIZE / 2.0), Vector3(WorldGen.CELL_SIZE, 0.3, WorldGen.CELL_SIZE),
		Mats.annex_carpet())
	scene.box(Vector3(WorldGen.CELL_SIZE / 2.0, ctx.ceiling_height + 0.15, WorldGen.CELL_SIZE / 2.0), Vector3(WorldGen.CELL_SIZE, 0.3, WorldGen.CELL_SIZE),
		Mats.annex_ceiling())
	_annex_carpet_damage()


func _annex_carpet_damage() -> void:
	# Production density: common enough to establish the damp Annex, sparse
	# enough that clean carpet still exists. The arrival cell always demonstrates
	# the treatment; every other choice remains deterministic per world cell.
	if ctx.cell != Vector2i.ZERO \
			and posmod(WorldGen.h(ctx.world_seed, ctx.cell.x, ctx.cell.y, 19391), 100) >= 38:
		return
	var asset_idx := posmod(WorldGen.h(
		ctx.world_seed, ctx.cell.x, ctx.cell.y, 19392), CARPET_DAMAGE_MASKS.size())
	const STAIN_SIZE := 5.4
	if _carpet_damage_quad == null:
		_carpet_damage_quad = QuadMesh.new()
		_carpet_damage_quad.size = Vector2(STAIN_SIZE, STAIN_SIZE)
		_carpet_damage_quad.orientation = PlaneMesh.FACE_Y
	var overlay := MeshInstance3D.new()
	overlay.mesh = _carpet_damage_quad
	var strength_roll := posmod(WorldGen.h(
		ctx.world_seed, ctx.cell.x, ctx.cell.y, 19393), 1000)
	var strength := 0.52 + float(strength_roll) / 1000.0 * 0.20
	overlay.material_override = Mats.annex_carpet_damage_overlay(
		CARPET_DAMAGE_MASKS[asset_idx])
	overlay.set_instance_shader_parameter("strength", strength)
	overlay.set_instance_shader_parameter("quarter_turns", float(posmod(
		WorldGen.h(ctx.world_seed, ctx.cell.x, ctx.cell.y, 19394), 4)))
	# Edge candidates touch a closed wall/baseboard without crossing the chunk.
	# The doorway test rejects the same footprint beside an open connection.
	var candidates := [
		Vector3(2.72, 0.012, 6.0), Vector3(9.28, 0.012, 6.0),
		Vector3(6.0, 0.012, 2.72), Vector3(6.0, 0.012, 9.28),
		Vector3(6.0, 0.012, 6.0),
	]
	var start := posmod(WorldGen.h(
		ctx.world_seed, ctx.cell.x, ctx.cell.y, 19395), candidates.size())
	var chosen := Vector3.INF
	for offset in candidates.size():
		var candidate: Vector3 = candidates[(start + offset) % candidates.size()]
		if not _annex_blocks_doorway(candidate, 0.0, STAIN_SIZE, STAIN_SIZE):
			chosen = candidate
			break
	if chosen == Vector3.INF:
		return
	overlay.position = chosen
	var half_size := STAIN_SIZE * 0.5
	var clearance := minf(minf(chosen.x - half_size, WorldGen.CELL_SIZE - chosen.x - half_size),
		minf(chosen.z - half_size, WorldGen.CELL_SIZE - chosen.z - half_size))
	var baseboard_creep := clearance <= 0.025
	overlay.set_meta("annex_carpet_damage", true)
	overlay.set_meta("annex_carpet_damage_asset", CARPET_DAMAGE_MASKS[asset_idx])
	overlay.set_meta("annex_carpet_damage_size", STAIN_SIZE)
	overlay.set_meta("annex_carpet_damage_strength", strength)
	overlay.set_meta("annex_carpet_edge_clearance", clearance)
	overlay.set_meta("annex_carpet_baseboard_creep", baseboard_creep)
	overlay.set_meta("annex_carpet_doorway_clear", true)
	overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	overlay.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	scene.add_node(overlay)


func _annex_moisture_tile(center: Vector2, mask_path: String,
		atlas_scale: Vector2, atlas_offset: Vector2, strength: float,
		quarter_turns: int, test_id: String) -> void:
	var tile_face := Chunk.ANNEX_CEILING_TILE - 0.09
	if _moisture_quad == null:
		_moisture_quad = QuadMesh.new()
		_moisture_quad.size = Vector2(tile_face, tile_face)
		_moisture_quad.orientation = PlaneMesh.FACE_Y
	var overlay := MeshInstance3D.new()
	overlay.mesh = _moisture_quad
	overlay.material_override = Mats.annex_moisture_overlay(mask_path)
	overlay.set_instance_shader_parameter("atlas_scale", atlas_scale)
	overlay.set_instance_shader_parameter("atlas_offset", atlas_offset)
	overlay.set_instance_shader_parameter("strength", strength)
	overlay.set_instance_shader_parameter("quarter_turns",
		float(posmod(quarter_turns, 4)))
	overlay.position = Vector3(center.x, ctx.ceiling_height - 0.012, center.y)
	overlay.set_meta("annex_moisture_tile", true)
	overlay.set_meta("annex_moisture_asset", mask_path)
	overlay.set_meta("annex_moisture_placement", test_id)
	overlay.set_meta("annex_moisture_tile_size", Chunk.ANNEX_CEILING_TILE)
	overlay.set_meta("annex_moisture_strength", strength)
	var world_x := float(ctx.cell.x) * WorldGen.CELL_SIZE + center.x
	var world_z := float(ctx.cell.y) * WorldGen.CELL_SIZE + center.y
	overlay.set_meta("annex_moisture_grid_error", maxf(
		absf(world_x - roundf(world_x / Chunk.ANNEX_CEILING_TILE) * Chunk.ANNEX_CEILING_TILE),
		absf(world_z - roundf(world_z / Chunk.ANNEX_CEILING_TILE) * Chunk.ANNEX_CEILING_TILE)))
	overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	overlay.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	scene.add_node(overlay)


func _annex_moisture_spot_clear(center: Vector2, fixtures: Array[Vector2]) -> bool:
	if not scene.annex_fixture_clear(Vector3(center.x, 0.0, center.y)):
		return false
	for fixture in fixtures:
		if center.distance_squared_to(fixture) < 0.01:
			return false
	return true


func _annex_moisture_damage(fixtures: Array[Vector2]) -> void:
	# Roughly one affected chunk in three; one quarter of those become a rare 2x2
	# leak. All choices derive from the world seed and cell, so streaming and
	# revisiting a location reproduce the same ceiling exactly.
	var roll := posmod(WorldGen.h(ctx.world_seed, ctx.cell.x, ctx.cell.y, 19401), 100)
	if ctx.cell != Vector2i.ZERO and roll >= 32:
		return
	var asset_idx := posmod(WorldGen.h(
		ctx.world_seed, ctx.cell.x, ctx.cell.y, 19402), MOISTURE_MASKS.size())
	var mask_path: String = MOISTURE_MASKS[asset_idx]
	var strength_roll := posmod(WorldGen.h(
		ctx.world_seed, ctx.cell.x, ctx.cell.y, 19403), 1000)
	var strength := 0.48 + float(strength_roll) / 1000.0 * 0.20
	var rotation := posmod(WorldGen.h(
		ctx.world_seed, ctx.cell.x, ctx.cell.y, 19404), 4)
	var wants_block := posmod(WorldGen.h(
		ctx.world_seed, ctx.cell.x, ctx.cell.y, 19405), 4) == 0
	var grid_span := 8 if wants_block else 9
	var candidate_count := grid_span * grid_span
	var start := posmod(WorldGen.h(
		ctx.world_seed, ctx.cell.x, ctx.cell.y, 19406), candidate_count)
	for attempt in candidate_count:
		var candidate := (start + attempt) % candidate_count
		var gx := candidate % grid_span + 1
		var gz := candidate / grid_span + 1
		var origin := Vector2(float(gx), float(gz)) * Chunk.ANNEX_CEILING_TILE
		if wants_block:
			var valid := true
			for qz in 2:
				for qx in 2:
					var center := origin + Vector2(float(qx), float(qz)) \
						* Chunk.ANNEX_CEILING_TILE
					if not _annex_moisture_spot_clear(center, fixtures):
						valid = false
			if not valid:
				continue
			var placement_id := "%s:%s:%s:2x2" % [
				ctx.world_seed, ctx.cell, asset_idx]
			for qz in 2:
				for qx in 2:
					_annex_moisture_tile(
						origin + Vector2(float(qx), float(qz)) * Chunk.ANNEX_CEILING_TILE,
						mask_path, Vector2(0.5, 0.5),
						Vector2(float(qx), float(qz)) * 0.5,
						strength, rotation, placement_id)
			return
		if not _annex_moisture_spot_clear(origin, fixtures):
			continue
		_annex_moisture_tile(origin, mask_path, Vector2.ONE, Vector2.ZERO,
			strength, rotation, "%s:%s:%s:1x1" % [
				ctx.world_seed, ctx.cell, asset_idx])
		return


func _annex_lighting() -> void:
	var is_spawn = ctx.cell == Vector2i.ZERO
	var axis = WorldGen.annex_corridor_axis(ctx.world_seed, ctx.cell)
	var dim_zone = WorldGen.annex_dim_zone(ctx.world_seed, ctx.cell)
	var light_gap = WorldGen.annex_light_gap(ctx.world_seed, ctx.cell)
	# The Annex no longer draws switched-off fixtures. Every troffer that exists
	# is steadily illuminated; darkness comes from sparse placement and weaker
	# local throw instead.
	var pmat = Mats.annex_panel()
	scene.set_chunk_meta("annex_dim_zone", dim_zone)
	scene.set_chunk_meta("annex_light_gap", light_gap)
	# Corridor fixtures form an unmistakable line into the distance. Rooms use
	# a four-panel grid. Dim zones reduce that to one or two fixtures; some
	# macro-blocks omit fixtures entirely for a genuine low-light stretch.
	var fixtures: Array[Vector2] = []
	if light_gap:
		fixtures = []
	elif dim_zone:
		if axis == 1 or axis == 2:
			fixtures = [Vector2(6.0, 6.0)]
		elif axis == 3:
			fixtures = [Vector2(3.0, 6.0), Vector2(9.0, 6.0)]
		else:
			fixtures = [Vector2(6.0, 6.0)]
	elif axis == 1:
		fixtures = [Vector2(2.0, 6.0), Vector2(6.0, 6.0), Vector2(10.0, 6.0)]
	elif axis == 2:
		fixtures = [Vector2(6.0, 2.0), Vector2(6.0, 6.0), Vector2(6.0, 10.0)]
	elif axis == 3:
		fixtures = [Vector2(3.0, 6.0), Vector2(9.0, 6.0),
			Vector2(6.0, 3.0), Vector2(6.0, 9.0)]
	else:
		fixtures = [Vector2(3.0, 3.0), Vector2(9.0, 3.0),
			Vector2(3.0, 9.0), Vector2(9.0, 9.0)]
	var built_fixtures = 0
	var built_fixture_centers: Array[Vector2] = []
	for pt in fixtures:
		var at = Vector3(
			_annex_tile_center(pt.x, ctx.cell.x),
			0.0,
			_annex_tile_center(pt.y, ctx.cell.y))
		if not scene.annex_fixture_clear(at):
			continue
		_annex_troffer(at, pmat)
		built_fixtures += 1
		built_fixture_centers.append(Vector2(at.x, at.z))
	var effective_gap = light_gap or built_fixtures == 0
	scene.set_chunk_meta("annex_light_gap", effective_gap)
	scene.set_chunk_meta("annex_ceiling_fixture_count", built_fixtures)
	_annex_moisture_damage(built_fixture_centers)
	if effective_gap:
		return
	var light = scene.main_light(false, pmat, 0.24 if dim_zone else 1.42)
	light.light_color = Color(1.0, 0.91, 0.64)
	light.omni_range = 7.4 if dim_zone else 12.8
	light.position = Vector3(WorldGen.CELL_SIZE / 2.0, ctx.ceiling_height - 0.46, WorldGen.CELL_SIZE / 2.0)
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 25.0
	light.distance_fade_length = 9.0
	scene.add_node(light)


## Snap a local fixture coordinate to the centre of the world-space drop-
## ceiling grid. Empirical in-game projection of the 2x2 source makes each
## visible tile exactly ANNEX_CEILING_TILE square.


func _annex_tile_center(local_v: float, cell_axis: int) -> float:
	var world_v = float(cell_axis) * WorldGen.CELL_SIZE + local_v
	# The imported ceiling map's visible grid intersections land at the former
	# half-tile phase. Whole multiples are the centres of the rendered squares.
	var snapped = roundf(world_v / Chunk.ANNEX_CEILING_TILE) * Chunk.ANNEX_CEILING_TILE
	return snapped - float(cell_axis) * WorldGen.CELL_SIZE


## One recessed fixture replaces one complete 1.2m ceiling tile. The outer
## frame is the exact tile footprint; the glowing lens is inset within it.


func _annex_troffer(at: Vector3, pmat: Material) -> void:
	var frame = Mats.annex_trim()
	var border = 0.035
	var lens_size = Chunk.ANNEX_CEILING_TILE - border * 2.0
	var lens = scene.box(
		Vector3(at.x, ctx.ceiling_height - 0.055, at.z),
		Vector3(lens_size, 0.05, lens_size), pmat, false)
	lens.set_meta("annex_ceiling_light_size", Chunk.ANNEX_CEILING_TILE)
	lens.set_meta("annex_ceiling_light_on", true)
	var world_x = float(ctx.cell.x) * WorldGen.CELL_SIZE + at.x
	var world_z = float(ctx.cell.y) * WorldGen.CELL_SIZE + at.z
	var grid_error = maxf(
		absf(world_x - roundf(world_x / Chunk.ANNEX_CEILING_TILE) * Chunk.ANNEX_CEILING_TILE),
		absf(world_z - roundf(world_z / Chunk.ANNEX_CEILING_TILE) * Chunk.ANNEX_CEILING_TILE))
	lens.set_meta("annex_ceiling_light_grid_error", grid_error)
	var edge = Chunk.ANNEX_CEILING_TILE * 0.5 - border * 0.5
	scene.box(Vector3(at.x, ctx.ceiling_height - 0.02, at.z - edge),
		Vector3(Chunk.ANNEX_CEILING_TILE, 0.035, border), frame, false)
	scene.box(Vector3(at.x, ctx.ceiling_height - 0.02, at.z + edge),
		Vector3(Chunk.ANNEX_CEILING_TILE, 0.035, border), frame, false)
	scene.box(Vector3(at.x - edge, ctx.ceiling_height - 0.02, at.z),
		Vector3(border, 0.035, lens_size), frame, false)
	scene.box(Vector3(at.x + edge, ctx.ceiling_height - 0.02, at.z),
		Vector3(border, 0.035, lens_size), frame, false)


## Reserve a small margin around each complete ceiling tile. The rectangles are
## populated by perimeter walls, corridor shells and full-height prop-pass
## architecture before lighting is generated.


func _annex_register_ceiling_obstruction(p: Vector3, width: float,
		depth: float, yaw: float, top: float) -> void:
	if ctx.theme != 2 or top < ctx.ceiling_height - 0.03:
		return
	var cs = absf(cos(yaw))
	var sn = absf(sin(yaw))
	var half_x = (cs * width + sn * depth) * 0.5
	var half_z = (sn * width + cs * depth) * 0.5
	scene.register_annex_ceiling_obstruction(Rect2(
		Vector2(p.x - half_x, p.z - half_z),
		Vector2(half_x * 2.0, half_z * 2.0)))


## Record an interior slab so later architecture can refuse to stand inside it,
## and ask whether a candidate would. Separate from the ceiling registry above,
## which only wants full-height pieces and only cares about tile coverage: a
## 1.08m half wall obstructs nothing overhead but is still solid to walk into.
func _annex_register_footprint(p: Vector3, yaw: float, width: float,
		depth: float, height: float) -> void:
	scene.register_annex_architecture_footprint(
		Chunk.plan_box(p, yaw, width, depth, height))


func _annex_footprint_free(p: Vector3, yaw: float, width: float,
		depth: float, height: float) -> bool:
	var candidate := Chunk.plan_box(p, yaw, width, depth, height)
	for placed in scene.annex_architecture_footprints():
		if Chunk.plan_box_overlap(candidate, placed) \
				> Chunk.FURNISHING_OVERLAP_TOL:
			return false
	return true


## A wall-like slab standing inside the approach zone of a generated doorway
## reads, from the other side of the opening, as a second offset doorframe with
## a light-leak gap beside the jamb — an "indented doorway". The route
## clearance system only protects the walk path, not the sightline, so test
## the slab's footprint against a zone projected into the room from every
## opening on this cell's edges and refuse to stand there. Columns are exempt:
## a small pier near a doorway reads as architecture, not as a broken frame.


func _annex_blocks_doorway(p: Vector3, yaw: float,
		width: float, depth: float) -> bool:
	const ZONE_DEPTH = 3.2
	const ZONE_MARGIN = 0.5
	var cs = absf(cos(yaw))
	var sn = absf(sin(yaw))
	var hx = (cs * width + sn * depth) * 0.5
	var hz = (sn * width + cs * depth) * 0.5
	var lo = Vector2(p.x - hx, p.z - hz)
	var hi = Vector2(p.x + hx, p.z + hz)
	for dir in 4:
		var info = scene.edge_info(ctx.cell, dir)
		if bool(info["wall"]):
			continue
		var a = float(info["t"]) - float(info["w"]) * 0.5 - ZONE_MARGIN
		var b = float(info["t"]) + float(info["w"]) * 0.5 + ZONE_MARGIN
		var zone_lo: Vector2
		var zone_hi: Vector2
		match dir:
			0:
				zone_lo = Vector2(WorldGen.CELL_SIZE - ZONE_DEPTH, a)
				zone_hi = Vector2(WorldGen.CELL_SIZE, b)
			1:
				zone_lo = Vector2(0.0, a)
				zone_hi = Vector2(ZONE_DEPTH, b)
			2:
				zone_lo = Vector2(a, WorldGen.CELL_SIZE - ZONE_DEPTH)
				zone_hi = Vector2(b, WorldGen.CELL_SIZE)
			3:
				zone_lo = Vector2(a, 0.0)
				zone_hi = Vector2(b, ZONE_DEPTH)
		if lo.x < zone_hi.x and hi.x > zone_lo.x \
				and lo.y < zone_hi.y and hi.y > zone_lo.y:
			return true
	return false


## Add one architectural slab as an atomic assembly. It is generated in the
## prop pass so the established doorway-clearance system can remove the whole
## slab, including its collider, if a seed places it across a route.


func _annex_block(p: Vector3, yaw: float, width: float, depth: float,
		height: float, kind: String, finish_override = -1,
		visual_owner = "self", attached_local_end = 0) -> Node3D:
	if kind == "annex_wall" or kind == "annex_half_wall":
		depth = maxf(depth, Chunk.ANNEX_WALL_T)
	if kind != "annex_column" and _annex_blocks_doorway(p, yaw, width, depth):
		return null
	# Columns are exempt from the doorway rule above by design, but not from this
	# one: interpenetrating architecture is a fault on any piece, and it is the
	# same test audit_prop_overlap.gd applies afterwards, so only a piece that
	# would fail the build is refused here.
	if not _annex_footprint_free(p, yaw, width, depth, height):
		return null
	var first = scene.collider_mark()
	var pivot = scene.furnishing_pivot(p, yaw, kind, false)
	var finish_idx = int(finish_override) \
		if int(finish_override) >= 0 else scene.finish_variant()
	var wallpapered = finish_idx >= 3
	pivot.set_meta("annex_architecture", kind)
	pivot.set_meta("annex_finish", finish_idx)
	pivot.set_meta("annex_wallpaper", wallpapered)
	pivot.set_meta("annex_visual_wall_owner", visual_owner)
	pivot.set_meta("annex_finish_inherited", int(finish_override) >= 0)
	pivot.set_meta("annex_baseboard_expected", true)
	var baseboard_count = 3 if attached_local_end != 0 else 4
	pivot.set_meta("annex_baseboard_expected_count", baseboard_count)
	if kind == "annex_wall" or kind == "annex_half_wall":
		pivot.set_meta("annex_partition_thickness", depth)
	var wall_mesh = scene.model_box(pivot, Vector3(0, height * 0.5, 0),
		Vector3(width, height, depth), Mats.annex_wall_variant(finish_idx))
	wall_mesh.set_meta("annex_architecture_wall", true)
	wall_mesh.set_meta("annex_finish", finish_idx)
	wall_mesh.set_meta("annex_wallpaper", wallpapered)
	scene.annex_wrap_local_baseboards(
		pivot, width, depth,
		attached_local_end < 0, attached_local_end > 0)
	_annex_register_ceiling_obstruction(p, width, depth, yaw, height)
	_annex_register_footprint(p, yaw, width, depth, height)
	if height < ctx.ceiling_height - 0.2:
		var cap_mat: Material = Mats.annex_half_wall_cap() \
			if kind == "annex_half_wall" else Mats.annex_trim()
		var cap = scene.model_box(pivot, Vector3(0, height + 0.025, 0),
			Vector3(width + 0.08, 0.05, depth + 0.08), cap_mat)
		if kind == "annex_half_wall":
			cap.set_meta("annex_half_wall_wood_cap", true)
			cap.set_meta("annex_wood_grain_axis", "local_x")
			cap.set_meta("annex_half_wall_cap_span", width + 0.08)
			cap.set_meta(
				"annex_half_wall_cap_reaches_owner",
				attached_local_end != 0)
	scene.collider_yaw_box(p + Vector3(0, height * 0.5, 0),
		Vector3(width, height, depth), yaw)
	scene.bind_furnishing_colliders(pivot, first)
	return pivot


## Replace one sufficiently deep wall mass with a raised rectangular tunnel.
## Four visible wall pieces and matching colliders leave an honest void. A
## fitted carpet strip covers its sill at waist height; the eye line passes
## through the opening, but its height is far below the standing capsule.


func _annex_tunnel_mass(p: Vector3, yaw: float, width: float,
		depth: float, height: float, finish_override = -1,
		visual_owner = "self") -> bool:
	if width < Chunk.ANNEX_TUNNEL_W + 0.8 \
			or depth < Chunk.ANNEX_TUNNEL_MIN_DEPTH \
			or _annex_blocks_doorway(p, yaw, width, depth):
		return false
	var first = scene.collider_mark()
	var pivot = scene.furnishing_pivot(p, yaw, "annex_wall_mass", false)
	pivot.set_meta("annex_architecture", "annex_wall_mass")
	pivot.set_meta("annex_tunnel", true)
	pivot.set_meta("annex_tunnel_kind", "annex_wall_mass")
	pivot.set_meta("annex_tunnel_path", "straight")
	pivot.set_meta("annex_tunnel_width", Chunk.ANNEX_TUNNEL_W)
	pivot.set_meta("annex_tunnel_sill", Chunk.ANNEX_TUNNEL_SILL)
	pivot.set_meta("annex_tunnel_height", Chunk.ANNEX_TUNNEL_H)
	pivot.set_meta("annex_tunnel_depth", depth)
	pivot.set_meta("annex_tunnel_carpeted", true)
	pivot.set_meta("annex_tunnel_crawlable", false)
	var finish_idx = int(finish_override) \
		if int(finish_override) >= 0 else scene.finish_variant()
	var wallpapered = finish_idx >= 3
	pivot.set_meta("annex_finish", finish_idx)
	pivot.set_meta("annex_wallpaper", wallpapered)
	pivot.set_meta("annex_visual_wall_owner", visual_owner)
	pivot.set_meta("annex_finish_inherited", int(finish_override) >= 0)
	pivot.set_meta("annex_baseboard_expected", true)
	pivot.set_meta("annex_baseboard_expected_count", 4)
	var wall_mat = Mats.annex_wall_variant(finish_idx)
	var side_w = (width - Chunk.ANNEX_TUNNEL_W) * 0.5
	var side_x = Chunk.ANNEX_TUNNEL_W * 0.5 + side_w * 0.5
	var opening_top = Chunk.ANNEX_TUNNEL_SILL + Chunk.ANNEX_TUNNEL_H
	var header_h = height - opening_top
	for side in [-1.0, 1.0]:
		var local = Vector3(side * side_x, height * 0.5, 0.0)
		var wall_piece = scene.model_box(pivot, local,
			Vector3(side_w, height, depth), wall_mat)
		wall_piece.set_meta("annex_tunnel_wall_piece", true)
		wall_piece.set_meta("annex_architecture_wall", true)
		wall_piece.set_meta("annex_finish", finish_idx)
		wall_piece.set_meta("annex_wallpaper", wallpapered)
		scene.collider_yaw_box(scene.world_point(p, local, yaw),
			Vector3(side_w, height, depth), yaw)
	var sill_local = Vector3(0.0, Chunk.ANNEX_TUNNEL_SILL * 0.5, 0.0)
	var sill = scene.model_box(pivot, sill_local,
		Vector3(Chunk.ANNEX_TUNNEL_W, Chunk.ANNEX_TUNNEL_SILL, depth), wall_mat)
	sill.set_meta("annex_tunnel_sill_piece", true)
	sill.set_meta("annex_architecture_wall", true)
	sill.set_meta("annex_finish", finish_idx)
	sill.set_meta("annex_wallpaper", wallpapered)
	scene.collider_yaw_box(scene.world_point(p, sill_local, yaw),
		Vector3(Chunk.ANNEX_TUNNEL_W, Chunk.ANNEX_TUNNEL_SILL, depth), yaw)
	var header_local = Vector3(0.0, opening_top + header_h * 0.5, 0.0)
	var header = scene.model_box(pivot, header_local,
		Vector3(Chunk.ANNEX_TUNNEL_W, header_h, depth), wall_mat)
	header.set_meta("annex_tunnel_header", true)
	header.set_meta("annex_architecture_wall", true)
	header.set_meta("annex_finish", finish_idx)
	header.set_meta("annex_wallpaper", wallpapered)
	scene.collider_yaw_box(scene.world_point(p, header_local, yaw),
		Vector3(Chunk.ANNEX_TUNNEL_W, header_h, depth), yaw)
	var carpet = scene.model_box(pivot,
		Vector3(0.0, Chunk.ANNEX_TUNNEL_SILL + 0.012, 0.0),
		Vector3(Chunk.ANNEX_TUNNEL_W, 0.024, depth), Mats.annex_carpet())
	carpet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	carpet.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	carpet.set_meta("annex_tunnel_carpet", true)
	scene.annex_wrap_local_baseboards(pivot, width, depth)
	_annex_register_ceiling_obstruction(p, width, depth, yaw, height)
	# The mass is always the first architecture in its room, so it only needs
	# recording; there is nothing yet for it to test against.
	_annex_register_footprint(p, yaw, width, depth, height)
	scene.bind_furnishing_colliders(pivot, first)
	return true


## A cross-corridor corner is the Annex's deepest recurring wall mass. Cut an
## L-shaped raised passage through it, joining its two corridor-facing sides.
## Unlike a straight cut, both mouths are guaranteed to open onto walkable
## corridor arms; the outer two faces remain solid against the neighbouring
## corridor shells. The turn sits near the outside corner, so narrow masses
## make a short peephole while thick masses make a genuinely long tunnel.


func _annex_cross_corner_tunnel(p: Vector3, yaw: float, width: float,
		depth: float, finish_idx: int) -> bool:
	var turn_inset = Chunk.ANNEX_TUNNEL_W * 0.5 + 0.40
	var u0 = turn_inset - Chunk.ANNEX_TUNNEL_W * 0.5
	var u1 = turn_inset + Chunk.ANNEX_TUNNEL_W * 0.5
	var v0 = u0
	var v1 = u1
	var tunnel_depth = minf(width - u0, depth - v0)
	if width <= u1 + 0.25 or depth <= v1 + 0.25 \
			or tunnel_depth < Chunk.ANNEX_TUNNEL_MIN_DEPTH:
		return false

	# This is permanent room topology, not dressing. Keeping it out of the
	# furnishing registry prevents the doorway-clearance cull from deleting
	# the very tunnel the intersection was selected to contain.
	var pivot = Node3D.new()
	pivot.position = p
	pivot.rotation.y = yaw
	scene.add_node(pivot)
	var wallpapered = finish_idx >= 3
	pivot.set_meta("annex_cross_corner", true)
	pivot.set_meta("annex_single_finish", true)
	pivot.set_meta("annex_deep_mass_candidate", true)
	pivot.set_meta("annex_deep_mass_depth", minf(width, depth))
	pivot.set_meta("annex_tunnel", true)
	pivot.set_meta("annex_tunnel_kind", "annex_cross_corner")
	pivot.set_meta("annex_tunnel_path", "L")
	pivot.set_meta("annex_tunnel_width", Chunk.ANNEX_TUNNEL_W)
	pivot.set_meta("annex_tunnel_sill", Chunk.ANNEX_TUNNEL_SILL)
	pivot.set_meta("annex_tunnel_height", Chunk.ANNEX_TUNNEL_H)
	pivot.set_meta("annex_tunnel_depth", tunnel_depth)
	pivot.set_meta("annex_tunnel_carpeted", true)
	pivot.set_meta("annex_tunnel_carpet_pieces", 2)
	pivot.set_meta("annex_tunnel_crawlable", false)
	pivot.set_meta("annex_finish", finish_idx)
	pivot.set_meta("annex_wallpaper", wallpapered)

	var wall_mat = Mats.annex_wall_variant(finish_idx)
	var opening_top = Chunk.ANNEX_TUNNEL_SILL + Chunk.ANNEX_TUNNEL_H
	var header_h = ctx.ceiling_height - opening_top
	# Full-height material below and above the aperture makes it a viewing
	# tunnel, never a crawl route. At eye height four rectangles tile the exact
	# complement of the L-shaped void without overlapping coplanar faces.
	var pieces: Array = [
		[
			Vector3(0.0, Chunk.ANNEX_TUNNEL_SILL * 0.5, 0.0),
			Vector3(width, Chunk.ANNEX_TUNNEL_SILL, depth),
		],
		[
			Vector3(0.0, opening_top + header_h * 0.5, 0.0),
			Vector3(width, header_h, depth),
		],
		[
			Vector3(0.0, Chunk.ANNEX_TUNNEL_SILL + Chunk.ANNEX_TUNNEL_H * 0.5,
				-depth * 0.5 + v0 * 0.5),
			Vector3(width, Chunk.ANNEX_TUNNEL_H, v0),
		],
		[
			Vector3(-width * 0.5 + u0 * 0.5,
				Chunk.ANNEX_TUNNEL_SILL + Chunk.ANNEX_TUNNEL_H * 0.5,
				-depth * 0.5 + (v0 + v1) * 0.5),
			Vector3(u0, Chunk.ANNEX_TUNNEL_H, v1 - v0),
		],
		[
			Vector3(-width * 0.5 + u0 * 0.5,
				Chunk.ANNEX_TUNNEL_SILL + Chunk.ANNEX_TUNNEL_H * 0.5,
				-depth * 0.5 + (v1 + depth) * 0.5),
			Vector3(u0, Chunk.ANNEX_TUNNEL_H, depth - v1),
		],
		[
			Vector3(-width * 0.5 + (u1 + width) * 0.5,
				Chunk.ANNEX_TUNNEL_SILL + Chunk.ANNEX_TUNNEL_H * 0.5,
				-depth * 0.5 + (v1 + depth) * 0.5),
			Vector3(width - u1, Chunk.ANNEX_TUNNEL_H, depth - v1),
		],
	]
	for piece in pieces:
		var local: Vector3 = piece[0]
		var size: Vector3 = piece[1]
		var wall_piece = scene.model_box(pivot, local, size, wall_mat)
		wall_piece.set_meta("annex_tunnel_wall_piece", true)
		wall_piece.set_meta("annex_architecture_wall", true)
		wall_piece.set_meta("annex_finish", finish_idx)
		wall_piece.set_meta("annex_wallpaper", wallpapered)
		scene.collider_yaw_box(scene.world_point(p, local, yaw), size, yaw)

	# Two non-overlapping strips carpet the full L. Their shared edge is a real
	# seam, not two coincident surfaces, so it cannot shimmer with distance.
	var carpet_specs: Array = [
		[
			Vector3(-width * 0.5 + (u0 + width) * 0.5,
				Chunk.ANNEX_TUNNEL_SILL + 0.012,
				-depth * 0.5 + (v0 + v1) * 0.5),
			Vector3(width - u0, 0.024, Chunk.ANNEX_TUNNEL_W),
		],
		[
			Vector3(-width * 0.5 + (u0 + u1) * 0.5,
				Chunk.ANNEX_TUNNEL_SILL + 0.012,
				-depth * 0.5 + (v1 + depth) * 0.5),
			Vector3(Chunk.ANNEX_TUNNEL_W, 0.024, depth - v1),
		],
	]
	for spec in carpet_specs:
		var carpet = scene.model_box(pivot, spec[0], spec[1], Mats.annex_carpet())
		carpet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		carpet.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		carpet.set_meta("annex_tunnel_carpet", true)

	# Only the two inner faces meet walkable corridor space. Wallpaper trim can
	# run beneath the raised apertures because the solid sill backs it.
	if true:
		scene.annex_local_baseboard(pivot,
			Vector3(width * 0.5 + Chunk.ANNEX_BASEBOARD_D * 0.5,
				Chunk.ANNEX_BASEBOARD_H * 0.5, 0.0),
			Vector3(Chunk.ANNEX_BASEBOARD_D, Chunk.ANNEX_BASEBOARD_H, depth))
		scene.annex_local_baseboard(pivot,
			Vector3(0.0, Chunk.ANNEX_BASEBOARD_H * 0.5,
				depth * 0.5 + Chunk.ANNEX_BASEBOARD_D * 0.5),
			Vector3(width, Chunk.ANNEX_BASEBOARD_H, Chunk.ANNEX_BASEBOARD_D))
	_annex_register_ceiling_obstruction(p, width, depth, yaw, ctx.ceiling_height)
	return true


func _annex_room_member_architecture() -> void:
	if ctx.room_size < 2 or ctx.portal_destination >= 0:
		return
	var c = Vector3(WorldGen.CELL_SIZE / 2.0, 0, WorldGen.CELL_SIZE / 2.0)
	if ctx.style == WorldGen.ANNEX_LOBBY and ctx.random01(523) < 0.72:
		var side_x = 3.2 if ctx.random01(524) < 0.5 else 8.8
		var side_z = 3.2 if ctx.random01(525) < 0.5 else 8.8
		_annex_block(Vector3(side_x, 0, side_z), 0.0,
			1.12, 1.12, ctx.ceiling_height, "annex_column")
	elif ctx.style == WorldGen.ANNEX_OPEN and ctx.random01(526) < 0.24:
		_annex_block(c + Vector3((ctx.random01(527) - 0.5) * 4.4, 0,
			(ctx.random01(528) - 0.5) * 4.4), 0.0,
			0.94, 0.94, ctx.ceiling_height, "annex_column")


func _annex_open() -> void:
	if ctx.cell == Vector2i.ZERO or ctx.portal_destination >= 0:
		return
	var c = Vector3(WorldGen.CELL_SIZE / 2.0, 0, WorldGen.CELL_SIZE / 2.0)
	var room_finish = scene.finish_variant()
	var roll = ctx.random01(520)
	# Open rooms stay empty often enough to preserve the level's restraint.
	# The other branches use the references' broad central wall masses, short
	# half-height dividers and occasional offset supports. A large pier leaves
	# multiple routes around it and reads as architecture, not a generic prop.
	if roll < 0.26:
		return
	if roll < 0.60:
		var mass_yaw = PI * 0.5 if ctx.random01(521) < 0.5 else 0.0
		var mass_width = lerpf(2.25, 3.15, ctx.random01(522))
		# These are wall masses, not slightly fat partitions. Their real depth
		# now drives the tunnel chance and the visible length of its carpeted
		# passage instead of being secretly forced to 2.10m only after a win.
		var mass_depth = lerpf(Chunk.ANNEX_TUNNEL_MIN_DEPTH, 4.20, ctx.random01(523))
		var mass_p = c + Vector3((ctx.random01(524) - 0.5) * 2.8, 0,
			(ctx.random01(525) - 0.5) * 2.8)
		var depth_weight = inverse_lerp(
			Chunk.ANNEX_TUNNEL_MIN_DEPTH, 4.20, mass_depth)
		var tunnel_chance = lerpf(0.72, 0.94, depth_weight)
		var tunneled = ctx.random01(534) < tunnel_chance \
			and _annex_tunnel_mass(
				mass_p, mass_yaw, mass_width, mass_depth, ctx.ceiling_height,
				room_finish, "open_room_mass")
		if not tunneled:
			_annex_block(mass_p, mass_yaw,
				mass_width, mass_depth, ctx.ceiling_height, "annex_wall_mass",
				room_finish, "open_room_mass")
	elif roll < 0.88:
		var yaw = PI / 2.0 if ctx.random01(529) < 0.5 else 0.0
		var side = -1.0 if ctx.random01(530) < 0.5 else 1.0
		var divider_width = lerpf(4.6, 5.4, ctx.random01(535))
		var attached = ctx.random01(536) < 0.58 \
			and _annex_attached_half_wall(537, divider_width, 1.08)
		if not attached:
			_annex_block(scene.world_point(c, Vector3(0, 0, side * 2.2), yaw), yaw,
				divider_width, Chunk.ANNEX_WALL_T, 1.08, "annex_half_wall",
				room_finish, "open_room_divider")
	elif roll < 0.97 and ctx.room_size >= 2:
		var along_x = ctx.random01(531) < 0.5
		for side in [-1.0, 1.0]:
			var p = c + (Vector3(side * 2.4, 0, 0) if along_x \
				else Vector3(0, 0, side * 2.4))
			_annex_block(p, 0.0, 1.04, 1.04, ctx.ceiling_height, "annex_column")
	else:
		_annex_block(c + Vector3((ctx.random01(532) - 0.5) * 2.0, 0,
			(ctx.random01(533) - 0.5) * 2.0), 0.0,
			1.08, 1.08, ctx.ceiling_height, "annex_column")


func _annex_maze() -> void:
	var c = Vector3(WorldGen.CELL_SIZE / 2.0, 0, WorldGen.CELL_SIZE / 2.0)
	var turn = PI / 2.0 if ctx.random01(530) < 0.5 else 0.0
	var side = -1.0 if ctx.random01(531) < 0.5 else 1.0
	var maze_finish = scene.finish_variant()
	_annex_block(scene.world_point(c, Vector3(-1.45, 0, side * 1.25), turn), turn,
		4.6, 0.22, ctx.ceiling_height, "annex_wall",
		maze_finish, "maze_assembly")
	if ctx.room_size >= 2:
		_annex_block(scene.world_point(c, Vector3(2.0, 0, -side * 1.55), turn + PI / 2.0),
			turn + PI / 2.0, 3.4, 0.22, ctx.ceiling_height, "annex_wall",
			maze_finish, "maze_assembly")


func _annex_long() -> void:
	var span = scene.room_span()
	var along_x = span.x >= span.y
	var yaw = 0.0 if along_x else PI / 2.0
	var c = Vector3(WorldGen.CELL_SIZE / 2.0, 0, WorldGen.CELL_SIZE / 2.0)
	var side = -1.0 if ctx.random01(540) < 0.5 else 1.0
	var long_finish = scene.finish_variant()
	# A shallow offset slab hides one side of the next opening while preserving
	# the long axis, producing the distant, ambiguous views in the reference.
	_annex_block(scene.world_point(c, Vector3(0, 0, side * 2.15), yaw), yaw,
		5.4, 0.22, ctx.ceiling_height, "annex_wall",
		long_finish, "long_room_wall")


func _annex_quiet() -> void:
	# The room is the prop. Keeping this branch explicit protects its emptiness.
	pass


## Sparse evidence that the Annex once had an ordinary use. Most rooms remain
## empty; the selected rooms get one readable idea rather than a grab-bag of
## unrelated props. Large chair heaps are limited to genuinely broad spaces.


func _annex_lived_in_dressing() -> void:
	if ctx.portal_destination >= 0 or ctx.style == WorldGen.ANNEX_PASSAGE:
		return
	# The Backrooms VR download is one baked environment, not a modular kit.
	# Its complete authored exit assembly was spatially extracted into a
	# standalone scene. Use it only as a rare sealed facade on an honest solid
	# wall: the procedural traversable openings retain their working door logic.
	if ctx.cell != Vector2i.ZERO \
			and (ctx.style == WorldGen.ANNEX_OPEN \
				or ctx.style == WorldGen.ANNEX_LONG \
				or ctx.style == WorldGen.ANNEX_LOBBY) \
			and ctx.random01(1617) < 0.18 \
			and _annex_exit_door(1618):
		return
	if ctx.random01(1620) < 0.12:
		_annex_air_conditioner(1621)
	if ctx.cell == Vector2i.ZERO:
		return
	var roll = ctx.random01(1630)
	# Quiet rooms stay the sparsest branch even after the lived-in pass.
	if ctx.style == WorldGen.ANNEX_QUIET:
		if roll < 0.12:
			_annex_chair_cluster(1, 1631, false)
		elif roll < 0.20:
			_annex_loose_boxes(1, 1632)
		elif roll < 0.30:
			_annex_school_chair_scatter(1, 1641)
		return
	if roll < 0.16:
		_annex_shelving(1633)
	elif roll < 0.32:
		_annex_loose_boxes(1 + int(ctx.random01(1634) * 2.99), 1635)
	elif roll < 0.48:
		_annex_chair_cluster(1, 1636, false)
	elif roll < 0.60:
		_annex_chair_cluster(2 + int(ctx.random01(1637) * 2.99), 1638, false)
	elif roll < 0.72:
		_annex_school_chair_scatter(
			1 + int(ctx.random01(1642) * 2.99), 1643)
	elif roll < 0.78 and ctx.room_size >= 2:
		_annex_chair_cluster(8 + int(ctx.random01(1639) * 2.99), 1640, true)
	# The Annex's broad openings mean its doorway clearance zones cover most
	# of a cell, so roughly half of everything rolled above is culled before
	# the player sees it. A second independent group lets a room read as used
	# rather than as one object in an empty box; the placement helpers still
	# refuse occupied spots and the cull still protects every route.
	var second = ctx.random01(1650)
	if second < 0.14:
		_annex_shelving(1651)
	elif second < 0.28:
		_annex_loose_boxes(1 + int(ctx.random01(1652) * 1.99), 1653)
	elif second < 0.40:
		_annex_chair_cluster(1, 1654, false)
	elif second < 0.46:
		_annex_school_chair_scatter(1 + int(ctx.random01(1655) * 1.99), 1656)


func _annex_wall_floor_point(dir: int, along: float, off: float,
		y = 0.0) -> Vector3:
	var plane = WorldGen.CELL_SIZE if dir == 0 or dir == 2 else 0.0
	var inward = -1.0 if dir == 0 or dir == 2 else 1.0
	var face = plane + inward * (Chunk.ANNEX_WALL_T * 0.5 + off)
	return Vector3(face, y, along) if dir < 2 \
		else Vector3(along, y, face)


func _annex_wall_has_utility(dir: int) -> bool:
	for node in scene.find_nodes("*", "Node3D", true, false):
		if node.has_meta("wall_utility_dir") \
				and int(node.get_meta("wall_utility_dir")) == dir:
			return true
	return false


func _annex_pick_solid_wall(salt: int, avoid_utilities = false,
		avoid_dir := -1) -> int:
	var start = posmod(WorldGen.h(ctx.world_seed, ctx.cell.x, ctx.cell.y, salt), 4)
	for step in 4:
		var dir = (start + step) % 4
		if dir == avoid_dir:
			continue
		if not bool(scene.edge_info(ctx.cell, dir)["wall"]):
			continue
		if avoid_utilities and _annex_wall_has_utility(dir):
			continue
		return dir
	return -1


## Extend a half-height divider inward from a real perimeter wall. The host
## wall is the visual owner: its finish/baseboard decision is inherited by the
## complete divider, the hidden end trim is omitted, and the wood cap overlaps
## the host by a few centimetres so neither treatment stops short at the join.


func _annex_attached_half_wall(salt: int, width: float,
		height: float) -> bool:
	var dir = _annex_pick_solid_wall(salt, true)
	if dir < 0:
		return false
	var along = lerpf(3.0, 9.0, ctx.random01(salt + 1))
	var face: Vector3
	var inward: Vector3
	var yaw = 0.0
	var attached_local_end = 0
	match dir:
		0:
			face = Vector3(WorldGen.CELL_SIZE - Chunk.ANNEX_WALL_T * 0.5, 0.0, along)
			inward = Vector3(-1.0, 0.0, 0.0)
			attached_local_end = 1
		1:
			face = Vector3(Chunk.ANNEX_WALL_T * 0.5, 0.0, along)
			inward = Vector3(1.0, 0.0, 0.0)
			attached_local_end = -1
		2:
			face = Vector3(along, 0.0, WorldGen.CELL_SIZE - Chunk.ANNEX_WALL_T * 0.5)
			inward = Vector3(0.0, 0.0, -1.0)
			yaw = PI * 0.5
			attached_local_end = -1
		_:
			face = Vector3(along, 0.0, Chunk.ANNEX_WALL_T * 0.5)
			inward = Vector3(0.0, 0.0, 1.0)
			yaw = PI * 0.5
			attached_local_end = 1
	const JOIN_OVERLAP = 0.045
	var p = face + inward * (width * 0.5 - JOIN_OVERLAP)
	# Match the host's rendered treatment, not its pre-junction raw finish.
	var finish_idx = int(scene.annex_resolved_wall_treatment(dir)["finish"])
	var divider = _annex_block(
		p, yaw, width, Chunk.ANNEX_WALL_T, height, "annex_half_wall",
		finish_idx, "boundary_wall_%d" % dir, attached_local_end)
	if divider == null:
		return false
	divider.set_meta("annex_attached_half_wall", true)
	divider.set_meta("annex_attached_wall_dir", dir)
	divider.set_meta("annex_attachment_overlap", JOIN_OVERLAP)
	divider.set_meta("annex_cap_continuous_to_owner", true)
	return true


func _annex_air_conditioner(salt: int) -> void:
	# Interactions are built after Annex dressing, so the lift facade does not
	# exist yet when the AC chooses a wall. Reserve its deterministic host wall
	# explicitly; otherwise the two independent wall-mounted assemblies can be
	# generated through one another.
	var elevator_wall := -1
	if WorldGen.elevator_cell(ctx.world_seed, ctx.cell, ctx.theme):
		elevator_wall = WorldGen.anchor_wall(
			ctx.world_seed, ctx.cell, 1701, ctx.theme)
	var dir = _annex_pick_solid_wall(salt, false, elevator_wall)
	if dir < 0:
		return
	var along = lerpf(3.0, 9.0, ctx.random01(salt + 1))
	var p = _annex_wall_floor_point(dir, along, 0.035, ctx.ceiling_height - 0.32)
	var pivot = Node3D.new()
	pivot.position = p
	pivot.rotation.y = scene.wall_facing(dir)
	pivot.set_meta("attributed_furnishing", "annex_air_conditioner")
	pivot.set_meta("annex_ac_mount", true)
	pivot.set_meta("annex_ac_dir", dir)
	scene.add_node(pivot)
	var unit = scene.attributed_prop_local(
		pivot, Chunk.OFFICE_AIR_CONDITIONER_PATH,
		-Chunk.OFFICE_AIR_CONDITIONER_CENTRE * Chunk.OFFICE_AIR_CONDITIONER_SCALE,
		0.0, Vector3.ONE * Chunk.OFFICE_AIR_CONDITIONER_SCALE)
	if unit == null:
		pivot.get_parent().remove_child(pivot)
		pivot.free()
		return
	unit.set_meta("authored_model", "annex_air_conditioner")


## Place the attributed double exit door as a sealed architectural facade.
## Its source-authored front points +Z, exactly the convention used by
## `_wall_facing`, and its rebased origin is centred on the frame at floor
## level. The 12cm stand-off seats the rear of the 20cm-deep frame against the
## room face without embedding its handles or sign in the wall.


func _annex_exit_door(salt: int) -> bool:
	var dir = _annex_pick_solid_wall(salt, true)
	if dir < 0:
		return false
	var along = 3.25 if ctx.random01(salt + 1) < 0.5 else 8.75
	var p = _annex_wall_floor_point(dir, along, 0.12)
	var pivot = scene.furnishing_pivot(
		p, scene.wall_facing(dir), "annex_exit_door", true)
	pivot.set_meta("attributed_furnishing", "annex_exit_door")
	pivot.set_meta("annex_sealed_exit", true)
	pivot.set_meta("annex_exit_wall_dir", dir)
	var authored = scene.attributed_prop_local(
		pivot, Chunk.ANNEX_EXIT_DOOR_PATH, Vector3.ZERO, 0.0)
	if authored == null:
		pivot.get_parent().remove_child(pivot)
		pivot.free()
		return false
	authored.set_meta("authored_model", "annex_exit_door")
	return true


func _annex_chair_cluster(count: int, salt: int, piled: bool) -> void:
	# "Piled" used to mean ten chairs physically intersecting one another.
	# Preserve the disordered group as a readable Annex detail, but keep every
	# chair floor-supported with enough space for its complete visual envelope.
	var target_count := mini(count, 4)
	var radius := 0.52 if target_count == 1 else 1.42
	var p = scene.free_floor_spot(salt, radius, 1.45 if piled else 1.25,
		0.96, 18)
	if p == Vector3.INF:
		return
	var base_yaw = ctx.random01(salt + 41) * TAU
	var first = scene.collider_mark()
	var kind = "annex_chair_scatter" if piled \
		else ("annex_single_chair" if count == 1 else "annex_chair_group")
	var group = scene.furnishing_pivot(p, base_yaw, kind)
	group.set_meta("attributed_furnishing", kind)
	group.set_meta("annex_chair_count", target_count)
	group.set_meta("annex_chairs_non_intersecting", true)
	var added = 0
	var offsets = [
		Vector3(-0.62, 0, -0.58),
		Vector3(0.62, 0, -0.56),
		Vector3(-0.62, 0, 0.58),
		Vector3(0.62, 0, 0.60),
	] if target_count > 1 else [Vector3.ZERO]
	for i in target_count:
		var local_yaw = (ctx.random01(salt + 50 + i) - 0.5) \
			* (0.34 if piled else 0.26)
		var inst = scene.attributed_prop_local(
			group, Chunk.ANNEX_CHAIR_PATH,
			offsets[i] - Chunk.ANNEX_CHAIR_CENTRE * Chunk.ANNEX_CHAIR_SCALE,
			local_yaw, Vector3.ONE * Chunk.ANNEX_CHAIR_SCALE)
		if inst == null:
			continue
		inst.set_meta("authored_model", "annex_dining_chair")
		var cp = scene.world_point(p, offsets[i] + Vector3(0, 0.47, 0), base_yaw)
		var chair_body_before := scene.collider_mark()
		scene.collider_yaw_box(cp, Vector3(0.52, 0.94, 0.62),
			base_yaw + local_yaw)
		var chair_collider := scene.collider_child(chair_body_before)
		chair_collider.set_meta("annex_chair_piece", i)
		added += 1
	if added == 0:
		group.get_parent().remove_child(group)
		group.free()
		return
	scene.bind_furnishing_colliders(group, first)


## Reuse the school's blue welded-frame chair as occasional Annex residue.
## Upright and side-laid chairs share one supported group; the tipped pose uses
## the imported chair's measured half-width (0.283m) as its floor lift.


func _annex_school_chair_scatter(count: int, salt: int) -> void:
	var radius = 0.46 if count == 1 else (0.78 if count == 2 else 1.02)
	var p = scene.free_floor_spot(salt, radius, 1.35, 1.05, 18)
	if p == Vector3.INF:
		return
	var base_yaw = ctx.random01(salt + 30) * TAU
	var first = scene.collider_mark()
	var kind = "annex_school_chair_single" if count == 1 \
		else "annex_school_chair_scatter"
	var group = scene.furnishing_pivot(p, base_yaw, kind)
	group.set_meta("attributed_furnishing", kind)
	group.set_meta("annex_school_chair_count", count)
	var offsets = [
		Vector3.ZERO,
		Vector3(-0.54, 0, 0.16),
		Vector3(0.54, 0, -0.14),
	]
	var added = 0
	var tipped_count = 0
	for i in mini(count, offsets.size()):
		var chair = scene.load_model("SchoolChair_01", Vector3.ZERO, 0.0)
		if chair == null:
			continue
		scene.adopt_local(group, chair)
		var local_yaw = (ctx.random01(salt + 40 + i) - 0.5) * 0.70
		chair.position = offsets[i] + Vector3(0, 0.002, 0)
		chair.rotation = Vector3(0, local_yaw, 0)
		var tipped = ctx.random01(salt + 50 + i) < 0.36
		if tipped:
			chair.position.y = 0.286
			chair.rotation.z = (PI / 2.0 - 0.06) \
				* (-1.0 if ctx.random01(salt + 60 + i) < 0.5 else 1.0)
			chair.set_meta("annex_school_chair_tipped", true)
			var tipped_pos = scene.world_point(p,
				offsets[i] + Vector3(0, 0.29, 0), base_yaw)
			scene.collider_yaw_box(tipped_pos, Vector3(1.03, 0.58, 0.70),
				base_yaw + local_yaw)
			tipped_count += 1
		else:
			var upright_pos = scene.world_point(p,
				offsets[i] + Vector3(0, 0.505, 0), base_yaw)
			scene.collider_yaw_box(upright_pos, Vector3(0.58, 1.01, 0.69),
				base_yaw + local_yaw)
		chair.set_meta("authored_model", "annex_school_chair")
		added += 1
	if added == 0:
		group.get_parent().remove_child(group)
		group.free()
		return
	group.set_meta("annex_school_chair_tipped_count", tipped_count)
	scene.bind_furnishing_colliders(group, first)


func _annex_loose_boxes(count: int, salt: int) -> void:
	var p = scene.free_floor_spot(salt, 0.52 if count == 1 else 0.78,
		1.20, 0.85, 16)
	if p == Vector3.INF:
		return
	var yaw = ctx.random01(salt + 20) * TAU
	var first = scene.collider_mark()
	var group = scene.furnishing_pivot(p, yaw, "annex_loose_boxes")
	group.set_meta("attributed_furnishing", "annex_loose_boxes")
	group.set_meta("annex_box_count", count)
	var offsets = [
		Vector3.ZERO,
		Vector3(0.38, 0, 0.09),
		Vector3(0.12, 0.30, -0.04),
	]
	var added = 0
	for i in mini(count, offsets.size()):
		var variant = posmod(
			WorldGen.h(ctx.world_seed, ctx.cell.x + i, ctx.cell.y - i, salt + 30),
			Chunk.OFFICE_BOX_VARIANTS.size())
		if scene.shelf_box(group, offsets[i],
				(ctx.random01(salt + 35 + i) - 0.5) * 0.26, variant,
				"annex_loose_box"):
			added += 1
	if added == 0:
		group.get_parent().remove_child(group)
		group.free()
		return
	scene.collider_yaw_box(p + Vector3(0.12, 0.36, 0),
		Vector3(1.04, 0.72, 0.76), yaw)
	scene.bind_furnishing_colliders(group, first)


func _annex_shelving(salt: int) -> void:
	var dir = _annex_pick_solid_wall(salt, true)
	if dir < 0:
		dir = _annex_pick_solid_wall(salt, false)
	if dir < 0:
		return
	var along = 3.15 if ctx.random01(salt + 1) < 0.5 else 8.85
	var p = _annex_wall_floor_point(dir, along, 0.49)
	var yaw = scene.wall_facing(dir)
	var site_clear := scene.floor_box_clear(p, yaw, 1.90, 0.68, 2.12) \
		and _annex_footprint_free(p, yaw, 1.90, 0.68, 2.12)
	if not site_clear:
		along = WorldGen.CELL_SIZE - along
		p = _annex_wall_floor_point(dir, along, 0.49)
		site_clear = scene.floor_box_clear(p, yaw, 1.90, 0.68, 2.12) \
			and _annex_footprint_free(p, yaw, 1.90, 0.68, 2.12)
	if not site_clear:
		return
	var first = scene.collider_mark()
	var shelf = scene.attributed_floor_prop(
		Chunk.ANNEX_SHELVING_PATH, p, yaw, Chunk.ANNEX_SHELVING_SCALE,
		Chunk.ANNEX_SHELVING_CENTRE, "annex_shelving", null, true)
	if shelf == null:
		return
	shelf.set_meta("annex_shelf_wall_dir", dir)
	var box_count = 0
	var box_slots = [
		Vector3(-0.52, Chunk.ANNEX_SHELVING_DECK_TOPS[0], 0.0),
		Vector3(0.02, Chunk.ANNEX_SHELVING_DECK_TOPS[0], 0.0),
		Vector3(0.48, Chunk.ANNEX_SHELVING_DECK_TOPS[1], 0.0),
		Vector3(-0.30, Chunk.ANNEX_SHELVING_DECK_TOPS[2], 0.0),
		Vector3(0.36, Chunk.ANNEX_SHELVING_DECK_TOPS[2], 0.0),
	]
	for i in box_slots.size():
		if ctx.random01(salt + 10 + i) >= 0.66:
			continue
		var variant = posmod(
			WorldGen.h(ctx.world_seed, ctx.cell.x + i, ctx.cell.y, salt + 50),
			Chunk.OFFICE_BOX_VARIANTS.size())
		if scene.shelf_box(shelf, box_slots[i],
				(ctx.random01(salt + 60 + i) - 0.5) * 0.12, variant,
				"annex_shelf_box"):
			box_count += 1
	shelf.set_meta("annex_shelf_box_count", box_count)
	scene.collider_yaw_box(p + Vector3(0, 1.05, 0),
		Vector3(1.90, 2.10, 0.68), yaw)
	scene.bind_furnishing_colliders(shelf, first)


func _annex_passage() -> void:
	var axis = WorldGen.annex_corridor_axis(ctx.world_seed, ctx.cell)
	if axis == 0:
		return
	var horizontal_width = WorldGen.annex_horizontal_width(ctx.world_seed, ctx.cell.y)
	var vertical_width = WorldGen.annex_vertical_width(ctx.world_seed, ctx.cell.x)
	var corridor_finish = WorldGen.annex_corridor_finish(ctx.world_seed)
	var corridor_mat = Mats.annex_wall_variant(corridor_finish)
	# Skirting is universal; the wallpaper flag still means papered.
	var corridor_baseboard = true
	var corridor_wallpapered = corridor_finish >= 3
	var marker = Node3D.new()
	marker.set_meta("annex_corridor_shell", axis)
	marker.set_meta("annex_horizontal_width", horizontal_width)
	marker.set_meta("annex_vertical_width", vertical_width)
	marker.set_meta("annex_corridor_finish", corridor_finish)
	scene.add_node(marker)
	# Each corridor run owns one of four stable widths. At an intersection the
	# four corner masses are sized independently, so a narrow hall can suddenly
	# release into a broad cross-axis without gaps or backing voids.
	if axis == 3:
		var block_width = (WorldGen.CELL_SIZE - vertical_width) * 0.5
		var block_depth = (WorldGen.CELL_SIZE - horizontal_width) * 0.5
		# Every major crossing demonstrates the peer-tunnel grammar once. Very
		# thick corners occasionally earn a second one; their L path is longer
		# automatically because it follows the real block dimensions.
		var primary_tunnel = posmod(
			WorldGen.h(ctx.world_seed, ctx.cell.x, ctx.cell.y, 2897), 4)
		var extra_tunnel = -1
		if minf(block_width, block_depth) >= 3.50 and ctx.random01(2898) < 0.46:
			extra_tunnel = posmod(
				primary_tunnel + 1
				+ posmod(WorldGen.h(ctx.world_seed, ctx.cell.x, ctx.cell.y, 2899), 3), 4)
		for xi in 2:
			var x = block_width * 0.5 if xi == 0 \
				else WorldGen.CELL_SIZE - block_width * 0.5
			for zi in 2:
				var z = block_depth * 0.5 if zi == 0 \
					else WorldGen.CELL_SIZE - block_depth * 0.5
				var corner_index = xi * 2 + zi
				var local_width = block_width if xi == zi else block_depth
				var local_depth = block_depth if xi == zi else block_width
				var corner_yaw = 0.0
				if xi == 1 and zi == 0:
					corner_yaw = -PI * 0.5
				elif xi == 0 and zi == 1:
					corner_yaw = PI * 0.5
				elif xi == 1 and zi == 1:
					corner_yaw = PI
				if (corner_index == primary_tunnel \
						or corner_index == extra_tunnel) \
						and _annex_cross_corner_tunnel(
							Vector3(x, 0.0, z), corner_yaw,
							local_width, local_depth, corridor_finish):
					continue
				# Each cross-corridor corner commits to one finish and one solid.
				# The former perpendicular "skins" were coplanar with this block,
				# causing the recurring bright vertical ridges seen in motion.
				var corner = scene.box(Vector3(x, ctx.ceiling_height * 0.5, z),
					Vector3(block_width, ctx.ceiling_height, block_depth), corridor_mat)
				corner.set_meta("annex_cross_corner", true)
				corner.set_meta("annex_deep_mass_candidate", true)
				corner.set_meta(
					"annex_deep_mass_depth", minf(block_width, block_depth))
				corner.set_meta("annex_single_finish", true)
				corner.set_meta("annex_finish", corridor_finish)
				corner.set_meta("annex_wallpaper", corridor_wallpapered)
				_annex_register_ceiling_obstruction(
					Vector3(x, 0.0, z), block_width, block_depth, 0.0, ctx.ceiling_height)
				# Both exposed faces inherit the corridor's one committed finish.
				# This prevents a straight wall from changing treatment as it
				# enters the solid corner at an intersection.
				if corridor_baseboard:
					var x_face = block_width if xi == 0 \
						else WorldGen.CELL_SIZE - block_width
					var x_sign = 1.0 if xi == 0 else -1.0
					scene.annex_baseboard_box(
						Vector3(
							x_face + x_sign * Chunk.ANNEX_BASEBOARD_D * 0.5,
							Chunk.ANNEX_BASEBOARD_H * 0.5, z),
						Vector3(Chunk.ANNEX_BASEBOARD_D,
							Chunk.ANNEX_BASEBOARD_H, block_depth))
					var z_face = block_depth if zi == 0 \
						else WorldGen.CELL_SIZE - block_depth
					var z_sign = 1.0 if zi == 0 else -1.0
					scene.annex_baseboard_box(
						Vector3(x, Chunk.ANNEX_BASEBOARD_H * 0.5,
							z_face + z_sign * Chunk.ANNEX_BASEBOARD_D * 0.5),
						Vector3(block_width,
							Chunk.ANNEX_BASEBOARD_H, Chunk.ANNEX_BASEBOARD_D))
		return
	# near/far_plane are the walkable corridor faces. The shell boxes are
	# centred half a wall thickness outside them, so their corridor faces land
	# exactly on the plane and stay flush with the intersection corner masses
	# (which own [0, block_width]). Centring the box ON the plane put every
	# shell face 15cm inside the corners' line, stepping the wall at each
	# passage-to-intersection junction.
	if axis == 1:
		var near_shell = WorldGen.CELL_SIZE * 0.5 - horizontal_width * 0.5 - Chunk.ANNEX_WALL_T * 0.5
		var far_shell = WorldGen.CELL_SIZE * 0.5 + horizontal_width * 0.5 + Chunk.ANNEX_WALL_T * 0.5
		_annex_corridor_side(true, near_shell, 3, corridor_finish)
		_annex_corridor_side(true, far_shell, 2, corridor_finish)
		if ctx.random01(560) < 0.11:
			var camera_dir = 3 if ctx.random01(561) < 0.5 else 2
			if scene.edge_info(ctx.cell, camera_dir)["wall"]:
				scene.security_camera_wall(camera_dir,
					near_shell if camera_dir == 3 else far_shell)
	else:
		var near_shell = WorldGen.CELL_SIZE * 0.5 - vertical_width * 0.5 - Chunk.ANNEX_WALL_T * 0.5
		var far_shell = WorldGen.CELL_SIZE * 0.5 + vertical_width * 0.5 + Chunk.ANNEX_WALL_T * 0.5
		_annex_corridor_side(false, near_shell, 1, corridor_finish)
		_annex_corridor_side(false, far_shell, 0, corridor_finish)
		if ctx.random01(560) < 0.11:
			var camera_dir = 1 if ctx.random01(561) < 0.5 else 0
			if scene.edge_info(ctx.cell, camera_dir)["wall"]:
				scene.security_camera_wall(camera_dir,
					near_shell if camera_dir == 1 else far_shell)


## Build one visible inner corridor wall. When its outer cell boundary opens
## into a room, the same opening is repeated here and connected with two return
## walls, creating a real short passage instead of exposing a fake backing bay.


func _annex_corridor_side(along_x: bool, plane: float, outer_dir: int,
		finish_idx: int) -> void:
	var info = scene.edge_info(ctx.cell, outer_dir)
	var toward = 1.0 if plane < WorldGen.CELL_SIZE * 0.5 else -1.0
	if info["wall"]:
		_annex_corridor_segment(along_x, plane, 0.0, WorldGen.CELL_SIZE, 0.0, ctx.ceiling_height,
			finish_idx, toward)
		scene.wall_utilities(outer_dir, plane, info)
		return
	# The shell repeats the outer boundary opening EXACTLY. The former clamps
	# let the two frames disagree by up to 70cm, which read from the wider side
	# as a second doorway floating inside the first.
	var a = float(info["t"]) - float(info["w"]) * 0.5
	var b = float(info["t"]) + float(info["w"]) * 0.5
	# The jamb these two runs present at the opening is part of the passage
	# frame, so it wears the passage's finish like the header and the returns.
	# Left on the corridor's own finish it was a plain vertical strip either
	# side of an otherwise papered doorway.
	var jamb_mat = Mats.annex_wall_variant(
		WorldGen.annex_wall_finish(ctx.world_seed, ctx.cell, outer_dir))
	_annex_corridor_segment(along_x, plane, 0.0, a, 0.0, ctx.ceiling_height,
		finish_idx, toward, jamb_mat)
	_annex_corridor_segment(along_x, plane, b, WorldGen.CELL_SIZE, 0.0, ctx.ceiling_height,
		finish_idx, toward, jamb_mat)
	scene.wall_utilities(outer_dir, plane, info)
	# This short connector is the continuation of the much longer room wall,
	# not an independently renovated strip. The room boundary therefore owns
	# the complete header/return treatment. Its material and skirting wrap
	# through the passage and stop only at the genuine inside corner where the
	# corridor shell begins. Letting the shell own the return made wallpaper
	# and the lower trim end on an apparently flat wall midway through a run.
	var boundary_finish = WorldGen.annex_wall_finish(
		ctx.world_seed, ctx.cell, outer_dir)
	var connection_uses_boundary = true
	var connection_finish = boundary_finish
	var connection_mat = Mats.annex_wall_variant(connection_finish)
	var connection_baseboard = true
	# The tunnel's underside is a soffit, not a wall plane: keep it plain so
	# wallpaper never lands on a surface the player reads as ceiling.
	var connection_soffit = Mats.annex_wall_variant(connection_finish % 3)
	var connection_marker = Node3D.new()
	connection_marker.set_meta("annex_corridor_connection", true)
	connection_marker.set_meta("annex_corridor_finish", finish_idx)
	connection_marker.set_meta("annex_boundary_finish", boundary_finish)
	connection_marker.set_meta("annex_connection_finish", connection_finish)
	connection_marker.set_meta("annex_visual_wall_owner", "corridor_shell")
	connection_marker.set_meta(
		"annex_connection_uses_boundary_finish", connection_uses_boundary)
	connection_marker.set_meta(
		"annex_connection_baseboards_expected",
		2 if connection_baseboard else 0)
	scene.add_node(connection_marker)
	var outer_plane = Chunk.ANNEX_WALL_T * 0.5 \
		if outer_dir == 1 or outer_dir == 3 \
		else WorldGen.CELL_SIZE - Chunk.ANNEX_WALL_T * 0.5
	# One solid mass above door height from the boundary wall to the corridor
	# face of the shell, replacing the shell's own floating header. Together
	# with the flanking returns this turns the doorway into a single straight
	# rectangular tunnel through one visually thick wall — no second frame, no
	# beam hanging behind the first, no ceiling slot over the passage.
	var boundary = 0.0 if outer_dir == 1 or outer_dir == 3 else WorldGen.CELL_SIZE
	var reach = boundary if bool(info["full_open"]) else outer_plane
	var shell_face = plane + toward * Chunk.ANNEX_WALL_T * 0.5
	var head_mid = (reach + shell_face) * 0.5
	var head_depth = absf(shell_face - reach)
	var head_y = (Chunk.DOOR_TOP + ctx.ceiling_height) * 0.5
	var head_h = ctx.ceiling_height - Chunk.DOOR_TOP
	# The band above the opening sits in each room's own wall plane, so it
	# takes that room's finish: the corridor's on the shell side, the room
	# boundary's on the far side. Wearing the passage finish on both made a
	# papered bar hang across an otherwise plain corridor wall.
	var corridor_mat = Mats.annex_wall_variant(finish_idx)
	var head_pos: Material = corridor_mat if toward > 0.0 else connection_mat
	var head_neg: Material = connection_mat if toward > 0.0 else corridor_mat
	var header: MeshInstance3D
	if along_x:
		header = scene.annex_wall_prism(
			Vector3((a + b) * 0.5, head_y, head_mid),
			Vector3(b - a, head_h, head_depth), true,
			true, true, connection_mat, connection_soffit, null,
			head_pos, head_neg)
		_annex_register_ceiling_obstruction(
			Vector3((a + b) * 0.5, 0.0, head_mid),
			b - a, head_depth, 0.0, ctx.ceiling_height)
	else:
		header = scene.annex_wall_prism(
			Vector3(head_mid, head_y, (a + b) * 0.5),
			Vector3(head_depth, head_h, b - a), false,
			true, true, connection_mat, connection_soffit, null,
			head_pos, head_neg)
		_annex_register_ceiling_obstruction(
			Vector3(head_mid, 0.0, (a + b) * 0.5),
			head_depth, b - a, 0.0, ctx.ceiling_height)
	header.set_meta("annex_corridor_connection_part", "header")
	header.set_meta("annex_corridor_finish", finish_idx)
	header.set_meta("annex_boundary_finish", boundary_finish)
	header.set_meta("annex_connection_finish", connection_finish)
	header.set_meta("annex_visual_wall_owner", "corridor_shell")
	header.set_meta(
		"annex_connection_uses_boundary_finish", connection_uses_boundary)
	# Returns sit fully OUTSIDE the opening span, so their faces are flush with
	# the jamb cuts at `a` and `b` — centring them ON the opening edge poked a
	# 15cm sliver past each jamb into the passage. They run from the boundary
	# side to the shell's strip face, abutting (never overlapping) the wall
	# segments' own cut faces, so the tunnel side reads as one flush plane.
	var shell_back = plane - toward * Chunk.ANNEX_WALL_T * 0.5
	var ret_depth = absf(reach - shell_back)
	var ret_mid = (reach + shell_back) * 0.5
	if along_x:
		for x in [a - Chunk.ANNEX_WALL_T * 0.5, b + Chunk.ANNEX_WALL_T * 0.5]:
			var return_wall = scene.annex_wall_prism(
				Vector3(x, ctx.ceiling_height * 0.5, ret_mid),
				Vector3(Chunk.ANNEX_WALL_T, ctx.ceiling_height, ret_depth), false,
				false, false, connection_mat)
			return_wall.set_meta(
				"annex_corridor_connection_part", "return")
			return_wall.set_meta("annex_corridor_finish", finish_idx)
			return_wall.set_meta("annex_boundary_finish", boundary_finish)
			return_wall.set_meta("annex_connection_finish", connection_finish)
			return_wall.set_meta("annex_visual_wall_owner", "corridor_shell")
			return_wall.set_meta(
				"annex_connection_uses_boundary_finish",
				connection_uses_boundary)
			_annex_register_ceiling_obstruction(
				Vector3(x, 0.0, ret_mid),
				Chunk.ANNEX_WALL_T, ret_depth, 0.0, ctx.ceiling_height)
		if connection_baseboard:
			var trim_a = scene.annex_baseboard_box(
				Vector3(a + Chunk.ANNEX_BASEBOARD_D * 0.5,
					Chunk.ANNEX_BASEBOARD_H * 0.5, ret_mid),
				Vector3(Chunk.ANNEX_BASEBOARD_D,
					Chunk.ANNEX_BASEBOARD_H, ret_depth))
			var trim_b = scene.annex_baseboard_box(
				Vector3(b - Chunk.ANNEX_BASEBOARD_D * 0.5,
					Chunk.ANNEX_BASEBOARD_H * 0.5, ret_mid),
				Vector3(Chunk.ANNEX_BASEBOARD_D,
					Chunk.ANNEX_BASEBOARD_H, ret_depth))
			for trim in [trim_a, trim_b]:
				trim.set_meta("annex_corridor_connection_baseboard", true)
				trim.set_meta("annex_connection_finish", connection_finish)
	else:
		for z in [a - Chunk.ANNEX_WALL_T * 0.5, b + Chunk.ANNEX_WALL_T * 0.5]:
			var return_wall = scene.annex_wall_prism(
				Vector3(ret_mid, ctx.ceiling_height * 0.5, z),
				Vector3(ret_depth, ctx.ceiling_height, Chunk.ANNEX_WALL_T), true,
				false, false, connection_mat)
			return_wall.set_meta(
				"annex_corridor_connection_part", "return")
			return_wall.set_meta("annex_corridor_finish", finish_idx)
			return_wall.set_meta("annex_boundary_finish", boundary_finish)
			return_wall.set_meta("annex_connection_finish", connection_finish)
			return_wall.set_meta("annex_visual_wall_owner", "corridor_shell")
			return_wall.set_meta(
				"annex_connection_uses_boundary_finish",
				connection_uses_boundary)
			_annex_register_ceiling_obstruction(
				Vector3(ret_mid, 0.0, z),
				ret_depth, Chunk.ANNEX_WALL_T, 0.0, ctx.ceiling_height)
		if connection_baseboard:
			var trim_a = scene.annex_baseboard_box(
				Vector3(ret_mid, Chunk.ANNEX_BASEBOARD_H * 0.5,
					a + Chunk.ANNEX_BASEBOARD_D * 0.5),
				Vector3(ret_depth, Chunk.ANNEX_BASEBOARD_H,
					Chunk.ANNEX_BASEBOARD_D))
			var trim_b = scene.annex_baseboard_box(
				Vector3(ret_mid, Chunk.ANNEX_BASEBOARD_H * 0.5,
					b - Chunk.ANNEX_BASEBOARD_D * 0.5),
				Vector3(ret_depth, Chunk.ANNEX_BASEBOARD_H,
					Chunk.ANNEX_BASEBOARD_D))
			for trim in [trim_a, trim_b]:
				trim.set_meta("annex_corridor_connection_baseboard", true)
				trim.set_meta("annex_connection_finish", connection_finish)


func _annex_corridor_segment(along_x: bool, plane: float, a: float, b: float,
		y0: float, y1: float, finish_idx: int, face_sign: float,
		cap_mat: Material = null) -> void:
	if b - a <= 0.02 or y1 - y0 <= 0.02:
		return
	var mat = Mats.annex_wall_variant(finish_idx)
	# Soffit only: the horizontal underside stays plain so wallpaper never
	# lands on a surface the player reads as ceiling.
	var reveal = Mats.annex_wall_variant(finish_idx % 3)
	var baseboard = true
	var wallpapered = finish_idx >= 3
	var wall_mesh: MeshInstance3D
	if along_x:
		wall_mesh = scene.annex_wall_prism(
			Vector3((a + b) * 0.5, (y0 + y1) * 0.5, plane),
			Vector3(b - a, y1 - y0, Chunk.ANNEX_WALL_T), true,
			not is_zero_approx(a), not is_equal_approx(b, WorldGen.CELL_SIZE), mat,
			reveal, cap_mat)
		_annex_register_ceiling_obstruction(
			Vector3((a + b) * 0.5, 0.0, plane),
			b - a, Chunk.ANNEX_WALL_T, 0.0, y1)
	else:
		wall_mesh = scene.annex_wall_prism(
			Vector3(plane, (y0 + y1) * 0.5, (a + b) * 0.5),
			Vector3(Chunk.ANNEX_WALL_T, y1 - y0, b - a), false,
			not is_zero_approx(a), not is_equal_approx(b, WorldGen.CELL_SIZE), mat,
			reveal, cap_mat)
		_annex_register_ceiling_obstruction(
			Vector3(plane, 0.0, (a + b) * 0.5),
			Chunk.ANNEX_WALL_T, b - a, 0.0, y1)
	wall_mesh.set_meta("annex_wall_thickness", Chunk.ANNEX_WALL_T)
	wall_mesh.set_meta("annex_wall_seam_safe", true)
	wall_mesh.set_meta("annex_wall_cap_min", not is_zero_approx(a))
	wall_mesh.set_meta("annex_wall_cap_max", not is_equal_approx(b, WorldGen.CELL_SIZE))
	wall_mesh.set_meta("annex_finish", finish_idx)
	wall_mesh.set_meta("annex_wallpaper", wallpapered)
	wall_mesh.set_meta("annex_visual_wall_owner", "corridor_shell")
	if y0 <= 0.01 and baseboard:
		var face = plane + face_sign * Chunk.ANNEX_WALL_T * 0.5
		if along_x:
			var xa = 0.0 if is_zero_approx(a) else Chunk.ANNEX_BASEBOARD_D
			var xb = 0.0 if is_equal_approx(b, WorldGen.CELL_SIZE) else Chunk.ANNEX_BASEBOARD_D
			scene.annex_baseboard_box(
				Vector3((a + b) * 0.5 + (xb - xa) * 0.5,
					Chunk.ANNEX_BASEBOARD_H * 0.5,
					face + face_sign * Chunk.ANNEX_BASEBOARD_D * 0.5),
				Vector3(b - a + xa + xb, Chunk.ANNEX_BASEBOARD_H,
					Chunk.ANNEX_BASEBOARD_D))
			# Carry the trim ACROSS an exposed end, so the wall's reveal at a
			# doorway is skirted like the faces either side of it.
			if not is_zero_approx(a):
				scene.annex_baseboard_box(
					Vector3(a - Chunk.ANNEX_BASEBOARD_D * 0.5,
						Chunk.ANNEX_BASEBOARD_H * 0.5, plane),
					Vector3(Chunk.ANNEX_BASEBOARD_D, Chunk.ANNEX_BASEBOARD_H,
						Chunk.ANNEX_WALL_T + Chunk.ANNEX_BASEBOARD_D * 2.0))
			if not is_equal_approx(b, WorldGen.CELL_SIZE):
				scene.annex_baseboard_box(
					Vector3(b + Chunk.ANNEX_BASEBOARD_D * 0.5,
						Chunk.ANNEX_BASEBOARD_H * 0.5, plane),
					Vector3(Chunk.ANNEX_BASEBOARD_D, Chunk.ANNEX_BASEBOARD_H,
						Chunk.ANNEX_WALL_T + Chunk.ANNEX_BASEBOARD_D * 2.0))
		else:
			var za = 0.0 if is_zero_approx(a) else Chunk.ANNEX_BASEBOARD_D
			var zb = 0.0 if is_equal_approx(b, WorldGen.CELL_SIZE) else Chunk.ANNEX_BASEBOARD_D
			scene.annex_baseboard_box(
				Vector3(face + face_sign * Chunk.ANNEX_BASEBOARD_D * 0.5,
					Chunk.ANNEX_BASEBOARD_H * 0.5,
					(a + b) * 0.5 + (zb - za) * 0.5),
				Vector3(Chunk.ANNEX_BASEBOARD_D, Chunk.ANNEX_BASEBOARD_H,
					b - a + za + zb))
			if not is_zero_approx(a):
				scene.annex_baseboard_box(
					Vector3(plane, Chunk.ANNEX_BASEBOARD_H * 0.5,
						a - Chunk.ANNEX_BASEBOARD_D * 0.5),
					Vector3(Chunk.ANNEX_WALL_T + Chunk.ANNEX_BASEBOARD_D * 2.0,
						Chunk.ANNEX_BASEBOARD_H, Chunk.ANNEX_BASEBOARD_D))
			if not is_equal_approx(b, WorldGen.CELL_SIZE):
				scene.annex_baseboard_box(
					Vector3(plane, Chunk.ANNEX_BASEBOARD_H * 0.5,
						b + Chunk.ANNEX_BASEBOARD_D * 0.5),
					Vector3(Chunk.ANNEX_WALL_T + Chunk.ANNEX_BASEBOARD_D * 2.0,
						Chunk.ANNEX_BASEBOARD_H, Chunk.ANNEX_BASEBOARD_D))


func _annex_lobby() -> void:
	var c = Vector3(WorldGen.CELL_SIZE / 2.0, 0, WorldGen.CELL_SIZE / 2.0)
	var yaw = PI / 2.0 if ctx.random01(550) < 0.5 else 0.0
	var lobby_finish = scene.finish_variant()
	# An asymmetrical deep mass plus one smaller support creates the framed,
	# layered sightlines in the references without turning the lobby into a
	# regular procedural column grid.
	var mass_p = scene.world_point(c, Vector3(-2.0, 0, -0.18), yaw)
	var lobby_depth = 3.60
	if ctx.random01(552) >= 0.88 \
			or not _annex_tunnel_mass(
				mass_p, yaw, 2.55, lobby_depth, ctx.ceiling_height,
				lobby_finish, "lobby_mass"):
		_annex_block(mass_p, yaw,
			2.55, lobby_depth, ctx.ceiling_height, "annex_wall_mass",
			lobby_finish, "lobby_mass")
	_annex_block(scene.world_point(c, Vector3(2.65, 0, 0.32), yaw), 0.0,
		1.10, 1.10, ctx.ceiling_height, "annex_column")
	if ctx.random01(551) < 0.92:
		var attached = ctx.random01(553) < 0.48 \
			and _annex_attached_half_wall(554, 5.1, 1.08)
		if not attached:
			_annex_block(scene.world_point(c, Vector3(0, 0, 1.9), yaw), yaw,
				5.1, Chunk.ANNEX_WALL_T, 1.08, "annex_half_wall",
				lobby_finish, "lobby_divider")


## Rare Backrooms furniture hoard. The pile is procedurally composed from a
## few existing CC0 furnishings and seeded wooden chairs, then treated as one
## atomic obstacle. Its centre sits at the middle of a 24x24 room, leaving a
## broad navigable perimeter and every doorway approach clear.


func _annex_furniture_pile() -> bool:
	if ctx.portal_destination >= 0 or ctx.room_size < 4 \
			or not WorldGen.annex_furniture_pile(ctx.world_seed, ctx.room_root):
		return false
	var span = scene.room_span()
	if span.x < 23.9 or span.y < 23.9:
		return false
	var centre = Vector3(span.x * 0.5, 0.0, span.y * 0.5)
	var yaw = floorf(ctx.random01(568) * 4.0) * PI * 0.5 \
		+ (ctx.random01(569) - 0.5) * 0.18
	var body0 = scene.collider_mark()
	var pile = scene.furnishing_pivot(centre, yaw, "annex_furniture_pile")
	pile.set_meta("annex_furniture_pile", true)
	pile.set_meta("annex_room_cells", ctx.room_size)

	# Heavy floor-supported core: a sofa, chair and cabinets give the loose
	# upper pieces a believable mass rather than a gravity-free sculpture.
	scene.cc0_prop_local(pile, "sofa_03", Vector3(-0.55, 0.0, 0.82),
		PI + (ctx.random01(570) - 0.5) * 0.16, 0.90)
	scene.cc0_prop_local(pile, "drawer_cabinet", Vector3(1.40, 0.0, -0.52),
		-PI * 0.5 + (ctx.random01(571) - 0.5) * 0.12, 0.92)
	scene.cc0_prop_local(pile, "ArmChair_01", Vector3(-1.58, 0.0, -0.74),
		0.42 + (ctx.random01(572) - 0.5) * 0.22, 0.94)
	scene.cc0_prop_local(pile, "Ottoman_01", Vector3(1.62, 0.0, 1.18),
		ctx.random01(573) * TAU, 0.92)

	# A shoved-in plywood cabinet and a tilted coffee table make the centre read
	# as accumulated office furniture rather than a lounge arrangement.
	scene.model_rounded_box(pile, Vector3(0.02, 0.76, -0.52),
		Vector3(1.52, 1.52, 0.72), Mats.wood_door(), 0.018)
	for sy in [-0.33, 0.10, 0.53]:
		scene.model_box(pile, Vector3(0.02, 0.76 + sy, -0.895),
			Vector3(1.30, 0.035, 0.025), Mats.darkwood())
	# Open bookcase on one flank.
	scene.model_box(pile, Vector3(1.34, 0.88, 0.27),
		Vector3(1.04, 1.76, 0.055), Mats.darkwood())
	for sx in [-0.50, 0.50]:
		scene.model_rounded_box(pile, Vector3(1.34 + sx, 0.88, 0.02),
			Vector3(0.065, 1.76, 0.56), Mats.wood_door(), 0.012)
	for shelf_y in [0.08, 0.55, 1.02, 1.49, 1.74]:
		scene.model_rounded_box(pile, Vector3(1.34, shelf_y, 0.02),
			Vector3(1.04, 0.055, 0.56), Mats.wood_door(), 0.012)
	# A full-height panel leans against the opposite side, making the heap read
	# wide even before the chairs and upholstery fill its silhouette.
	var leaning_panel = Node3D.new()
	leaning_panel.position = Vector3(-1.42, 1.03, 0.08)
	leaning_panel.rotation = Vector3(0.04, -0.32, -0.22)
	pile.add_child(leaning_panel)
	scene.model_rounded_box(leaning_panel, Vector3.ZERO,
		Vector3(1.22, 1.94, 0.085), Mats.wood_door(), 0.015)
	# Misaligned upholstery stacked through the middle.
	scene.model_rounded_box(pile, Vector3(-0.55, 1.18, 0.56),
		Vector3(1.34, 0.36, 0.84), Mats.velvet2(), 0.10)
	scene.model_rounded_box(pile, Vector3(-0.43, 1.51, 0.45),
		Vector3(1.10, 0.31, 0.76), Mats.velvet(), 0.09)
	var table = scene.cc0_prop_local(pile, "CoffeeTable_01",
		Vector3(0.25, 1.20, 0.0), ctx.random01(574) * TAU, 0.82)
	table.rotation.x = 0.10 + ctx.random01(575) * 0.13
	table.rotation.z = (ctx.random01(576) - 0.5) * 0.22
	var upper_table = scene.cc0_prop_local(pile, "coffee_table_round_01",
		Vector3(-0.22, 1.72, 0.18), ctx.random01(578) * TAU, 0.82)
	upper_table.rotation.x = -0.12
	upper_table.rotation.z = 0.16
	var television = scene.cc0_prop_local(pile, "television_02",
		Vector3(0.72, 1.45, -0.20), -0.55, 0.74)
	television.rotation.z = -0.10

	# Seeded dining chairs ring and crown the pile. They deliberately overlap
	# the core and one another, but never escape the aggregate collider.
	var chair_specs = [
		[Vector3(-1.92, 0.56, -1.32), Vector3(0.02, -0.55, 0.10)],
		[Vector3(1.84, 0.56, 1.38), Vector3(-0.02, 2.15, -0.12)],
		[Vector3(0.32, 0.56, -1.82), Vector3(0.04, 1.55, 0.14)],
		[Vector3(-1.05, 1.23, -0.20), Vector3(0.16, 0.48, 0.08)],
		[Vector3(0.90, 1.32, 0.18), Vector3(-0.13, 2.75, 0.13)],
		[Vector3(-1.36, 1.48, 0.78), Vector3(0.12, 0.18, 0.24)],
		[Vector3(1.38, 1.53, 0.72), Vector3(-0.10, 3.70, -0.26)],
		[Vector3(0.02, 1.84, -0.38), Vector3(0.18, 1.38, 0.20)],
		[Vector3(2.08, 0.56, -0.76), Vector3(0.03, 2.88, -0.14)],
		[Vector3(-2.10, 0.56, 0.72), Vector3(-0.02, -0.16, 0.12)],
		[Vector3(0.76, 1.78, 0.46), Vector3(-0.16, 4.36, -0.18)],
	]
	var chair_count = 9 + int(ctx.random01(577) * 2.99)
	for i in chair_count:
		var spec: Array = chair_specs[i]
		var pos: Vector3 = spec[0]
		pos += Vector3((ctx.random01(580 + i * 3) - 0.5) * 0.14,
			0.0, (ctx.random01(581 + i * 3) - 0.5) * 0.14)
		var rot: Vector3 = spec[1]
		rot.y += (ctx.random01(582 + i * 3) - 0.5) * 0.24
		_annex_pile_chair(pile, pos, rot)

	# One absurd floor lamp poking out of the top echoes the reference without
	# turning every hoard into the exact same silhouette.
	if ctx.random01(610) < 0.76:
		scene.model_cylinder(pile, Vector3(-0.22, 1.91, 0.12), 0.018, 1.14,
			Mats.metal_gray())
		scene.model_cylinder(pile, Vector3(-0.22, 1.35, 0.12), 0.17, 0.035,
			Mats.metal_gray())
		var shade = scene.model_cylinder(pile, Vector3(-0.22, 2.46, 0.12), 0.18, 0.16,
			Mats.shade())
		shade.rotation.z = 0.18

	# A single conservative collision volume is intentional: the hoard is a
	# pile, not a platforming course, and one group can be culled atomically.
	scene.collider_yaw_box(
		scene.world_point(centre, Vector3(0.0, 1.31, 0.0), yaw),
		Vector3(5.45, 2.62, 5.15), yaw)
	scene.bind_furnishing_colliders(pile, body0)
	return true


func _annex_pile_chair(parent: Node3D, pos: Vector3,
		rot: Vector3) -> void:
	var chair = Node3D.new()
	# Existing pile coordinates describe the old generated chair's seat plane
	# at y=.56. Rebase them to the floor and keep the supplied model's authored
	# centre correction inside the rotating chair pivot.
	chair.position = pos - Vector3(0, 0.56, 0)
	chair.rotation = rot
	parent.add_child(chair)
	var inst = scene.attributed_prop_local(
		chair, Chunk.ANNEX_CHAIR_PATH,
		-Chunk.ANNEX_CHAIR_CENTRE * Chunk.ANNEX_CHAIR_SCALE,
		0.0, Vector3.ONE * Chunk.ANNEX_CHAIR_SCALE)
	if inst == null:
		chair.get_parent().remove_child(chair)
		chair.free()
		return
	inst.set_meta("authored_model", "annex_dining_chair")

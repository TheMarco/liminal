class_name SurfaceWear
extends RefCounted
## Seeded, physical weathering. The pass runs on completed room geometry and
## never creates colliders, lights, labels, navigation or gameplay objects.
## Face patches are children of their actual support; model overlays reuse the
## original triangles. Both therefore survive furniture transforms correctly.

static var enabled := true # Also permits clean/reference captures in audits.
const MAX_PATCHES := 20
const MAX_PROP_MESHES := 24
const MAX_STRENGTH := 0.36
const PROP_SHADER := preload("res://shaders/prop_wear.gdshader")

enum Motif { SPILL, LEAK, MOLD, CRACK, SCUFF, REPAIR, ADHESIVE, SCORCH,
	DUST, RUST, MINERAL, MISSING_TILE, JOINT, ROOT, FOOTPRINT, VENT,
	WATERLINE, BURNS, PLASTER, TRAFFIC, RUB, LETTERING }

class Face:
	var mesh: MeshInstance3D
	var transform: Transform3D
	var center: Vector3
	var normal: Vector3
	var u: Vector3
	var v: Vector3
	var size: Vector2
	var material: String
	var role: String
	var salt: int

var ctx: ChunkBuildContext
var host: Node3D
var floors: Array[Face] = []
var walls: Array[Face] = []
var ceilings: Array[Face] = []
var skirtings: Array[Face] = []
var props: Array[Dictionary] = []
var growth_contacts: Array[Vector3] = []
var vents: Array[Vector3] = []
var annex_carpet_stains: Array[Vector3] = []
var wall_fixings: Array[Vector3] = []
var attempted_causes := {}
var placed_causes := {}
var patches := 0
var prop_meshes := 0
var lifted_finishes := 0
var district := 0
var age := 0.6


static func apply(chunk: Node3D, context: ChunkBuildContext) -> void:
	if not enabled:
		return
	var pass_ := SurfaceWear.new()
	pass_.host = chunk
	pass_.ctx = context
	pass_._build()


func _build() -> void:
	var district_cell := Vector2i(floori(float(ctx.room_root.x + 3) / 6.0),
		floori(float(ctx.room_root.y + 3) / 6.0))
	district = posmod(WorldGen.h(ctx.world_seed, district_cell.x,
		district_cell.y, 28001 + ctx.theme * 31), 3)
	# Age varies by district, but even the oldest district remains lightly worn.
	age = [0.16, 0.22, 0.28][district]
	if ctx.theme == 5:
		age *= 0.65 # The asylum already has peeling, cracked and stained textures.
	for child in host.get_children():
		_scan(child, Transform3D.IDENTITY, -1)
	for prop in props:
		var bounds := AABB()
		var first := true
		for entry: Dictionary in prop.meshes:
			# Imported furnishings can contain hundreds of meshes. Bounds and sort
			# keys are immutable during this pass; do this once, not in every
			# comparison of both overlay-allocation sorts.
			var local_bounds: AABB = entry.mesh.mesh.get_aabb()
			entry["local_bounds"] = local_bounds
			var b: AABB = entry.transform * local_bounds
			entry["wear_size_squared"] = b.size.length_squared()
			bounds = b if first else bounds.merge(b)
			first = false
		# Some builders keep an assembly pivot at (0,0,0) and author all of its
		# children in room coordinates. The geometry, not that pivot, locates wear.
		prop["foot"] = Vector3(bounds.get_center().x, bounds.position.y,
			bounds.get_center().z) if not first else prop.transform.origin
		prop["fixture_priority"] = _fixture_priority(prop.kind)
		prop["fixture_hash"] = _hash(prop.foot, 28401)
	# Stable physical ordering, independent of scene instance IDs/names.
	walls.sort_custom(func(a: Face, b: Face): return a.salt < b.salt)
	floors.sort_custom(func(a: Face, b: Face): return a.center.y > b.center.y)
	_architectural_wear()
	_threshold_wear()
	_root_damage()
	_vent_dust()
	_fixing_runoff()
	_fixture_wear()
	host.set_meta("surface_wear_summary", {"patches": patches,
		"prop_meshes": prop_meshes, "district": district,
		"attempted_causes": attempted_causes, "placed_causes": placed_causes})


func _hash(p: Vector3, salt: int) -> int:
	return posmod(WorldGen.h(ctx.world_seed,
		roundi((p.x + ctx.cell.x * 12.0) * 100.0),
		roundi((p.z + ctx.cell.y * 12.0) * 100.0),
		salt + roundi(p.y * 100.0) * 17 + ctx.theme * 379), 1000003)


func _roll(p: Vector3, salt: int) -> float:
	return float(_hash(p, salt) % 1000) / 1000.0


func _contains_any(value: String, needles: Array) -> bool:
	for needle: String in needles:
		if value.contains(needle):
			return true
	return false


func _kind(node: Node) -> String:
	if node.has_meta("wall_mounted_prison_door"):
		return "prison_door"
	for key in ["data_center_kind", "attributed_furnishing", "atomic_furnishing",
			"surface_wear_prop"]:
		if node.has_meta(key):
			return str(node.get_meta(key)).to_lower()
	if node.has_meta("office_workstation"):
		return "office_workstation"
	if node.has_meta("slot_machine"):
		return "slot_machine"
	if node.has_meta("pool_ladder"):
		return "pool_ladder"
	return ""


func _scan(node: Node, parent_transform: Transform3D, prop: int) -> void:
	# Batched fasteners and frames span empty space. Their combined bounds
	# are not a furnishing surface and must not displace the original meshes
	# (including imported models) from the existing wear budget.
	if node.has_meta("procedural_detail"):
		return
	# These are discoveries and interactions, not worn furnishing surfaces.
	if node.has_meta("charging_station") or node.has_meta("optional_vhs_set") \
			or node is VhsRitual or node is Light3D or node is CollisionObject3D:
		return
	var xf := parent_transform
	if node is Node3D:
		xf *= (node as Node3D).transform
	var kind := _kind(node)
	if not kind.is_empty() and (prop < 0 or kind != str(props[prop].kind)):
		if prop < 0 or _contains_any(kind, ["chair", "cooler", "air_condition", "plant", "travelator_plate"]):
			prop = props.size()
			props.append({"node": node, "transform": xf, "kind": kind, "meshes": []})
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if mesh.mesh != null:
			if mesh.has_meta("annex_carpet_damage"):
				annex_carpet_stains.append(xf.origin)
			if mesh.has_meta("bloom_growth"):
				# Real vine endpoints, rather than the empty parent at the origin.
				var box := mesh.mesh.get_aabb()
				growth_contacts.append(xf * Vector3(0, box.position.y, 0))
				growth_contacts.append(xf * Vector3(0, box.end.y, 0))
			var mat := mesh.material_override
			var name_ := mat.resource_name.to_lower() if mat != null else ""
			if prop >= 0:
				props[prop].meshes.append({"mesh": mesh, "transform": xf})
				if mesh.has_meta("data_center_cooling_pad"):
					_gather_faces(mesh, xf, name_)
			else:
				_gather_faces(mesh, xf, name_)
				var physical_size: Vector3 = (xf * mesh.mesh.get_aabb()).size
				if ctx.theme == 0 and name_ == "brass" and xf.origin.y < 1.7:
					props.append({"node": node, "transform": xf, "kind": "casino_brass",
						"meshes": [{"mesh": mesh, "transform": xf}]})
				elif ctx.theme == 8 and name_ in ["prison_iron", "prison_green"] \
						and physical_size.y > 0.5 and minf(physical_size.x, physical_size.z) < 0.15:
					props.append({"node": node, "transform": xf, "kind": "prison_bars",
						"meshes": [{"mesh": mesh, "transform": xf}]})
				if _contains_any(name_, ["pipe_rust", "prison_iron", "brutal_steel", "brass"]):
					var fixing_size := (xf * mesh.mesh.get_aabb()).size
					if fixing_size.length() < 0.6 and xf.origin.y > 0.4:
						wall_fixings.append(xf.origin)
				if _contains_any(name_, ["airport_glass", "mall_glass", "prison_glass"]):
					props.append({"node": node, "transform": xf, "kind": "glazing",
						"meshes": [{"mesh": mesh, "transform": xf}]})
				elif ctx.theme == 6 and name_ == "sch_red" and xf.origin.y < 0.025:
					props.append({"node": node, "transform": xf, "kind": "school_court_marking",
						"meshes": [{"mesh": mesh, "transform": xf}]})
				elif name_ == "metal_gray" and xf.origin.y > ctx.ceiling_height - 0.1:
					var size_ := (xf * mesh.mesh.get_aabb()).size
					if size_.x > 0.45 and size_.z > 0.45 and size_.y < 0.1:
						vents.append(xf.origin)
				elif ctx.theme == 0 and name_ == "brass" and xf.origin.y > ctx.ceiling_height - 0.13:
					var size_ := (xf * mesh.mesh.get_aabb()).size
					if size_.x > 0.4 and size_.z > 0.4:
						vents.append(xf.origin)
	for child in node.get_children():
		_scan(child, xf, prop)


func _gather_faces(mesh: MeshInstance3D, xf: Transform3D, mat: String) -> void:
	if mat.is_empty() or mat.begins_with("surface_wear"):
		return
	var wall_mat := _contains_any(mat, ["wall", "wallpaper", "plaster", "dado",
		"pool_tile", "pool_coping", "asy_tile", "sch_tile", "prison_tile", "brutal_structure", "annex_baseboard"])
	var floor_mat := _contains_any(mat, ["floor", "carpet", "terrazzo", "marble",
		"pool_tile", "pool_coping", "asy_checker", "sch_tile", "prison_tile"]) \
		or mesh.has_meta("data_center_cooling_pad")
	var ceiling_mat := mat.contains("ceiling")
	if not wall_mat and not floor_mat and not ceiling_mat:
		return
	var aabb := mesh.mesh.get_aabb()
	if mesh.mesh is BoxMesh:
		for axis in 3:
			for sign_ in [-1.0, 1.0]:
				var n := Vector3.ZERO
				n[axis] = sign_
				var local_center := aabb.get_center()
				local_center[axis] += aabb.size[axis] * sign_ * 0.5
				_add_face(mesh, xf, local_center, n, aabb.size, mat,
					wall_mat, floor_mat, ceiling_mat)
	elif mesh.mesh is QuadMesh and wall_mat:
		_add_face(mesh, xf, aabb.get_center(), Vector3.BACK, aabb.size,
			mat, wall_mat, floor_mat, ceiling_mat)


func _add_face(mesh: MeshInstance3D, xf: Transform3D, local_center: Vector3,
		local_normal: Vector3, local_size: Vector3, mat: String,
		wall_mat: bool, floor_mat: bool, ceiling_mat: bool) -> void:
	var n := (xf.basis.inverse().transposed() * local_normal).normalized()
	var center := xf * local_center
	var role := ""
	if floor_mat and n.y > 0.98 and center.y >= -0.02 and center.y < 1.6:
		role = "floor"
	elif ceiling_mat and n.y < -0.98 and center.y > 2.0:
		role = "ceiling"
	elif wall_mat and absf(n.y) < 0.02:
		role = "skirting" if mat == "annex_baseboard" else "wall"
	if role.is_empty():
		return
	# Reject perimeter back faces. Interior partitions retain both sides.
	if role in ["wall", "skirting"] and (center.x < 0.4 or center.x > 11.6 or center.z < 0.4 or center.z > 11.6):
		if n.dot(Vector3(6, center.y, 6) - center) < 0:
			return
	var lu := Vector3.RIGHT
	var lv := Vector3.UP
	if absf(local_normal.x) > 0.5:
		lu = Vector3.FORWARD if local_normal.x > 0 else Vector3.BACK
	elif absf(local_normal.y) > 0.5:
		lv = Vector3.FORWARD if local_normal.y > 0 else Vector3.BACK
	elif local_normal.z < 0:
		lu = Vector3.LEFT
	var u := xf.basis * lu
	var v := xf.basis * lv
	var size_ := Vector2(absf(lu.dot(local_size)) * u.length(),
		absf(lv.dot(local_size)) * v.length())
	var minimum := Vector2(0.3, 0.06) if role == "skirting" else Vector2(0.65, 0.65 if role == "wall" else 0.4)
	if size_.x < minimum.x or size_.y < minimum.y:
		return
	# A lintel is a real surface but not a place where luggage, shoes or low
	# damp leave marks. Keep those causes on walls that reach human height.
	if role == "wall" and center.y - size_.y * 0.5 > 1.6:
		return
	var f := Face.new()
	f.mesh = mesh
	f.transform = xf
	f.center = center
	f.normal = n
	f.u = u.normalized()
	f.v = v.normalized()
	f.size = size_
	f.material = mat
	f.role = role
	f.salt = _hash(center + n * 0.17, 28101)
	if role == "wall":
		walls.append(f)
	elif role == "floor":
		floors.append(f)
	elif role == "skirting":
		skirtings.append(f)
	else:
		ceilings.append(f)


func _patch(face: Face, at: Vector3, requested: Vector2, motif: int,
		ink: Color, cause: String, amount := 1.0, roughness := 0.94) -> MeshInstance3D:
	attempted_causes[cause] = int(attempted_causes.get(cause, 0)) + 1
	if patches >= MAX_PATCHES:
		return null
	var edge_margin := 0.025 if face.role == "skirting" else 0.08
	var size_ := Vector2(minf(requested.x, face.size.x - edge_margin),
		minf(requested.y, face.size.y - edge_margin))
	if size_.x < 0.16 or size_.y < (0.035 if face.role == "skirting" else 0.12):
		return null
	var margin := (face.size - size_) * 0.5 - Vector2.ONE * 0.015
	var delta := at - face.center
	var offset := Vector2(clampf(delta.dot(face.u), -margin.x, margin.x),
		clampf(delta.dot(face.v), -margin.y, margin.y))
	var center := face.center + face.u * offset.x + face.v * offset.y
	var quad := QuadMesh.new()
	quad.size = size_
	var mark := MeshInstance3D.new()
	mark.name = "SurfaceWear_%02d" % patches
	mark.mesh = quad
	var damp := motif == Motif.SPILL and not cause.begins_with("drink_spill")
	var mask_id := _hash(center, 28211) % 8 if damp else -1
	var material := Mats._shader("surface_wear_%d_%d" % [motif, mask_id],
		"res://shaders/surface_wear.gdshader")
	material.set_shader_parameter("motif", motif)
	material.set_shader_parameter("damp_spread", damp)
	if damp:
		material.set_shader_parameter("stain_mask",
			load("res://textures/annex/moisture_mask_%02d.png" % (mask_id + 1)))
	mark.material_override = material
	# Compensate the complete supporting transform (including model scale).
	mark.transform = face.transform.affine_inverse() * Transform3D(
		Basis(face.u, face.v, face.normal), center + face.normal * 0.006)
	var parameters := {"wear_seed": float(_hash(center, 28201) % 8192),
		"strength": clampf(age * amount, 0.0, MAX_STRENGTH), "patch_size": size_,
		"ink": ink, "surface_roughness": roughness, "tile_pitch": 0.0}
	if face.material.begins_with("pool_") and face.mesh.material_override is ShaderMaterial:
		var pitch: Variant = face.mesh.material_override.get_shader_parameter("tex_metres")
		if pitch != null:
			parameters.tile_pitch = float(pitch) * 0.1
	for parameter: String in parameters:
		mark.set_instance_shader_parameter(parameter, parameters[parameter])
	# The dummy headless renderer discards instance-uniform values. Retain the
	# applied configuration for deterministic audits; GPU captures verify readback.
	mark.set_meta("surface_wear_parameters", parameters)
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mark.set_meta("surface_wear_patch", true)
	mark.set_meta("surface_wear_motif", motif)
	mark.set_meta("surface_wear_cause", cause)
	mark.set_meta("surface_wear_size", size_)
	mark.set_meta("surface_wear_center", center)
	mark.set_meta("surface_wear_normal", face.normal)
	mark.set_meta("surface_wear_support_size", face.size)
	mark.set_meta("surface_wear_support_offset", offset)
	face.mesh.add_child(mark)
	patches += 1
	placed_causes[cause] = int(placed_causes.get(cause, 0)) + 1
	return mark


func _floor_patch(at: Vector3, size_: Vector2, motif: int, color: Color,
		cause: String, amount := 1.0, roughness := 0.94) -> void:
	for f in floors:
		var d := at - f.center
		if f.center.y > at.y + 0.2:
			continue
		if absf(d.dot(f.u)) > f.size.x * 0.5 - 0.12 or absf(d.dot(f.v)) > f.size.y * 0.5 - 0.12:
			continue
		_patch(f, at, size_, motif, color, cause, amount, roughness)
		return


func _nearest_wall(at: Vector3, distance_ := 1.5) -> Face:
	var best: Face = null
	var distance_squared := distance_ * distance_
	for f in walls:
		var delta := at - f.center
		var projected := f.center + f.u * clampf(delta.dot(f.u), -f.size.x * 0.5, f.size.x * 0.5) \
			+ f.v * clampf(delta.dot(f.v), -f.size.y * 0.5, f.size.y * 0.5)
		var d := at.distance_squared_to(projected)
		if d < distance_squared and delta.dot(f.normal) > -0.12:
			best = f
			distance_squared = d
	return best


func _architectural_wear() -> void:
	# Large readable interventions are deliberately sparse, with quiet walls
	# between clusters. The Annex keeps its existing ceiling/carpet masks.
	var n := mini(walls.size(), 1 + district)
	if ctx.theme == 2 and not annex_carpet_stains.is_empty():
		var source := annex_carpet_stains[0] + Vector3.UP * 0.7
		var damp_wall := _nearest_wall(source, 3.2)
		if damp_wall != null:
			walls.erase(damp_wall)
			walls.push_front(damp_wall)
	for i in n:
		var f := walls[i]
		var at := f.center + f.u * ((_roll(f.center, 28301) - 0.5) * f.size.x * 0.5)
		var low := Vector3(at.x, f.center.y - f.size.y * 0.5 + 0.28, at.z)
		if i == 0 and ctx.theme != 9:
			_patch(f, low - Vector3.UP * 0.15, Vector2(2.2, 0.24), Motif.JOINT,
				Color(0.095, 0.09, 0.06), "base_joint_dirt", 0.85)
		match ctx.theme:
			0:
				if i == 0 and _roll(at, 28304) < 0.35:
					_linked_leak(f, at, "hotel_old_leak", Color(0.22, 0.14, 0.065))
				else:
					_patch(f, low + Vector3.UP * 0.65, Vector2(1.8, 0.28), Motif.RUB,
						Color(0.15, 0.09, 0.055), "hotel_luggage_rub", 0.9)
				if i == 0 and district == 2 and _roll(at, 28306) < 0.22:
					_lifted_finish(f, at, "wallpaper")
			1:
				_patch(f, at, Vector2(1.0, 1.25), Motif.REPAIR if i % 2 == 0 else Motif.ADHESIVE,
					Color(0.80, 0.79, 0.68) if i % 2 == 0 else Color(0.31, 0.27, 0.16),
					"office_repaint" if i % 2 == 0 else "office_removed_notice", 0.65)
			2:
				if i == 0:
					if not annex_carpet_stains.is_empty():
						at = annex_carpet_stains[0] + Vector3.UP * f.center.y
					_linked_leak(f, at, "annex_connected_moisture", Color(0.28, 0.20, 0.065))
				else:
					_patch(f, low, Vector2(1.0, 0.85), Motif.MOLD,
						Color(0.095, 0.14, 0.045), "annex_damp_seam", 1.2)
				if i == 0 and _roll(at, 28306) < 0.22:
					var paper := f.material.ends_with("_3") or f.material.ends_with("_4")
					_lifted_finish(f, low + Vector3.UP * 0.5, "wallpaper" if paper else "paint")
			4:
				_patch(f, low + Vector3.UP * 0.55, Vector2(2.4, 0.24), Motif.RUB,
					Color(0.085, 0.09, 0.085), "airport_luggage_bumper", 1.15)
			5:
				var tile_damage := i == 0 and f.material.contains("tile") and _roll(at, 28307) < 0.18
				_patch(f, low + Vector3.UP * 0.7, Vector2(0.32, 0.32) if tile_damage else Vector2(0.9, 0.65),
					Motif.MISSING_TILE if tile_damage else Motif.REPAIR,
					Color(0.18, 0.17, 0.13) if tile_damage else Color(0.58, 0.61, 0.48),
					"asylum_exposed_mortar" if tile_damage else "asylum_scrubbed_patch", 1.0)
				if i == 0 and not f.material.contains("tile") and _roll(at, 28306) < 0.18:
					_lifted_finish(f, at, "plaster")
			6:
				_patch(f, at, Vector2(1.25, 1.0), Motif.ADHESIVE if i % 2 == 0 else Motif.REPAIR,
					Color(0.48, 0.40, 0.23) if i % 2 == 0 else Color(0.88, 0.84, 0.71),
					"school_poster_ghost" if i % 2 == 0 else "school_paint_repair", 0.75)
			7:
				_patch(f, Vector3(at.x, minf(2.25, at.y + 0.45), at.z), Vector2(1.65, 0.30), Motif.LETTERING,
					Color(0.35, 0.29, 0.17), "mall_removed_lettering", 0.85)
				if i == 0 and _roll(at, 28305) < 0.45:
					_linked_leak(f, at, "mall_failed_roof_repair", Color(0.32, 0.23, 0.10))
			8:
				_patch(f, low, Vector2(2.3, 0.62), Motif.WATERLINE,
					Color(0.68, 0.69, 0.59), "prison_low_salt", 1.1)
				_patch(f, low + Vector3.UP * 0.65, Vector2(0.85, 0.8), Motif.PLASTER,
					Color(0.52, 0.49, 0.35), "prison_old_paint_layers", 1.0)
			9:
				if f.center.y - f.size.y * 0.5 < 1.05 and f.center.y + f.size.y * 0.5 > 1.2:
					_patch(f, Vector3(at.x, 1.08, at.z), Vector2(2.2, 0.30), Motif.WATERLINE,
						Color(0.30, 0.38, 0.16), "pool_stagnant_waterline", 0.6)
				var missing := i == 0 and _roll(at, 28307) < 0.18
				_patch(f, low + Vector3.UP * 0.3, Vector2(0.38, 0.38),
					Motif.MISSING_TILE if missing else Motif.REPAIR,
					Color(0.59, 0.58, 0.51) if missing else Color(0.87, 0.85, 0.68),
					"pool_missing_mosaic" if missing else "pool_replacement_tiles", 0.7)
			10:
				_patch(f, at, Vector2(0.85, 2.1), Motif.CRACK,
					Color(0.12, 0.12, 0.105), "concrete_joint_crack", 1.0)
				_patch(f, at + Vector3.UP * 0.55, Vector2(0.55, 0.5), Motif.REPAIR,
					Color(0.46, 0.48, 0.44), "patched_cable_penetration", 1.1)
			11:
				_patch(f, low + Vector3.UP * 0.3, Vector2(2.6, 0.8), Motif.WATERLINE,
					Color(0.48, 0.46, 0.34), "bloom_old_flood_line", 0.9)
	# A single broad travel/repair mark remains visible through tape resolution.
	if not floors.is_empty():
		var f := floors[0]
		var at := f.center + f.u * ((_roll(f.center, 28320) - 0.5) * f.size.x * 0.45)
		if ctx.theme in [0, 1, 4, 6, 8, 10]:
			_patch(f, at, Vector2(2.4, 4.2), Motif.TRAFFIC,
				Color(0.12, 0.105, 0.075), "traffic_wear", 0.85, 0.83)
		if ctx.theme == 1:
			_patch(f, at + f.u * 1.8, Vector2(0.66, 0.66), Motif.REPAIR,
				Color(0.24, 0.29, 0.23), "replacement_carpet_square", 0.9)
		elif ctx.theme == 4:
			_patch(f, at + f.u * 1.2, Vector2(1.8, 0.7), Motif.ADHESIVE,
				Color(0.41, 0.37, 0.24), "airport_removed_floor_sign", 0.65, 0.55)
		elif ctx.theme == 7:
			_patch(f, at, Vector2(2.4, 1.8), Motif.FOOTPRINT,
				Color(0.70, 0.64, 0.45), "removed_kiosk_and_bolts", 1.0, 0.3)
		elif ctx.theme == 9:
			if f.center.y > 1.05:
				_patch(f, at, Vector2(1.1, 0.9), Motif.MINERAL,
					Color(0.70, 0.68, 0.53), "pool_dry_splash", 0.7)
		elif ctx.theme == 6 and ctx.style == WorldGen.SCH_GYM:
			_patch(f, at, Vector2(3.2, 2.5), Motif.DUST,
				Color(0.36, 0.25, 0.11), "gym_worn_varnish", 0.75, 0.82)
		elif ctx.theme == 11:
			_patch(f, at, Vector2(1.6, 1.8), Motif.SPILL,
				Color(0.14, 0.11, 0.075), "bloom_dried_residue", 1.0, 1.0)


func _linked_leak(f: Face, at: Vector3, cause: String, ink: Color) -> void:
	# Align all parts with one position on the real supporting wall, including
	# when the source is a carpet stain a few metres out from that wall.
	at -= f.normal * (at - f.center).dot(f.normal)
	var top := f.center.y + f.size.y * 0.5
	var bottom := f.center.y - f.size.y * 0.5
	_patch(f, Vector3(at.x, (top + bottom) * 0.5, at.z),
		Vector2(1.0, f.size.y - 0.1), Motif.LEAK, ink, cause + "_wall", 1.25)
	_floor_patch(Vector3(at.x, bottom + 0.1, at.z) + f.normal * 0.55,
		Vector2(1.6, 1.5), Motif.SPILL, ink, cause + "_floor", 1.1)
	_patch(f, Vector3(at.x, bottom + 0.16, at.z), Vector2(1.2, 0.32),
		Motif.MOLD, ink * Color(0.65, 0.85, 0.65), cause + "_skirting", 1.2)
	if ctx.theme == 2 and _roll(at, 28620) < 0.22:
		_swollen_skirting(f, at)
	for ceiling in ceilings:
		var target := Vector3(at.x, ceiling.center.y, at.z) + f.normal * 0.55
		var d := target - ceiling.center
		if absf(d.dot(ceiling.u)) < ceiling.size.x * 0.5 and absf(d.dot(ceiling.v)) < ceiling.size.y * 0.5:
			_patch(ceiling, target, Vector2(1.7, 1.3), Motif.SPILL, ink,
				cause + "_ceiling", 0.9)
			if ctx.theme == 7:
				_patch(ceiling, target, Vector2(1.9, 1.5), Motif.REPAIR,
					Color(0.69, 0.66, 0.54), "mall_roof_patch", 0.25)
			break


func _threshold_wear() -> void:
	if ctx.theme not in [1, 4, 6, 8] or _roll(Vector3.ZERO, 28630) > 0.55:
		return
	for step in 4:
		var dir := (step + _hash(Vector3.ZERO, 28631) % 4) % 4
		var edge: Dictionary = host._edge_info(ctx.cell, dir)
		if edge.wall or edge.full_open:
			continue
		var along := float(edge.t)
		var at := Vector3(11.3 if dir == 0 else 0.7, 0.1, along) if dir < 2 \
			else Vector3(along, 0.1, 11.3 if dir == 2 else 0.7)
		_floor_patch(at, Vector2(1.3, 0.8) if dir >= 2 else Vector2(0.8, 1.3),
			Motif.SCUFF, Color(0.19, 0.18, 0.15), "threshold_contact_wear", 0.7, 0.68)
		return


func _swollen_skirting(wall: Face, at: Vector3) -> void:
	for trim in skirtings:
		if trim.normal.dot(wall.normal) < 0.99:
			continue
		var target := Vector3(at.x, trim.center.y, at.z)
		var delta := target - trim.center
		if absf(delta.dot(trim.normal)) > 0.08 or absf(delta.dot(trim.u)) > trim.size.x * 0.5 - 0.25:
			continue
		var mark := _patch(trim, target, Vector2(0.45, 0.085), Motif.JOINT,
			Color(0.31, 0.27, 0.14), "annex_swollen_skirting", 0.5)
		if mark == null:
			return
		# A few millimetres of bowed trim, using the actual skirting finish.
		# It has no collision, cast shadow, or effect on the wall behind it.
		var size_: Vector2 = mark.get_meta("surface_wear_size")
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var uvs := PackedVector2Array()
		var indices := PackedInt32Array()
		for y in 3:
			for x in 9:
				var uv := Vector2(float(x) / 8.0, float(y) / 2.0)
				vertices.append(Vector3((uv.x - 0.5) * size_.x,
					(uv.y - 0.5) * size_.y, sin(uv.x * PI) * sin(uv.y * PI) * 0.004))
				normals.append(Vector3.BACK)
				uvs.append(Vector2(uv.x, 1.0 - uv.y))
		for y in 2:
			for x in 8:
				var i := y * 9 + x
				indices.append_array([i, i + 10, i + 1, i, i + 9, i + 10])
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mark.mesh = mesh
		mark.material_override = trim.mesh.material_override
		return


func _lifted_finish(face: Face, at: Vector3, type_: String) -> void:
	if lifted_finishes >= 1:
		return
	var ink := Color(0.50, 0.40, 0.22) if type_ in ["wallpaper", "paint"] else Color(0.53, 0.51, 0.43)
	var mark := _patch(face, at, Vector2(0.18, 0.30), Motif.PLASTER,
		ink, type_ + "_exposed_backing", 0.75)
	if mark == null:
		return
	lifted_finishes += 1
	# A small torn, bent flap, with a maximum 8 mm lift. Irregular silhouette
	# avoids the rectangular 'new tape stuck on a wall' read of a plain quad.
	var flap := MeshInstance3D.new()
	flap.name = "LiftedFinish"
	var vertices := PackedVector3Array([
		Vector3(-0.068, -0.14, 0.004), Vector3(0.045, -0.115, 0.004),
		Vector3(0.058, -0.035, 0.018), Vector3(0.036, 0.09, 0.025),
		Vector3(-0.008, 0.115, 0.022), Vector3(-0.047, 0.026, 0.013),
		Vector3(-0.017, -0.024, 0.016)])
	for i in vertices.size():
		vertices[i] *= Vector3(0.55, 0.55, 0.30)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([
		Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK,
		Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([6, 1, 0, 6, 2, 1,
		6, 3, 2, 6, 4, 3, 6, 5, 4, 6, 0, 5])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	flap.mesh = mesh
	if face.mesh.material_override is StandardMaterial3D:
		# Keep the same finish on the lifted face, including the Annex's world
		# triplanar texture. A contrasting flat colour reads like stuck-on tape.
		flap.material_override = face.mesh.material_override
	else:
		flap.material_override = Mats._std("surface_wear_flap_" + type_, func(m: StandardMaterial3D):
			m.albedo_color = Color(0.82, 0.74, 0.43) if type_ == "wallpaper" else Color(0.66, 0.68, 0.59)
			m.roughness = 0.96
			m.cull_mode = BaseMaterial3D.CULL_DISABLED)
	flap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flap.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mark.add_child(flap)


func _fixture_wear() -> void:
	props.sort_custom(func(a: Dictionary, b: Dictionary):
		return a.fixture_priority < b.fixture_priority if a.fixture_priority != b.fixture_priority \
			else a.fixture_hash < b.fixture_hash)
	var floor_marks := 0
	var glazing_leaks := 0
	var overlays: Array[Dictionary] = []
	for prop in props:
		var kind: String = prop.kind
		var xf: Transform3D = prop.transform
		var at: Vector3 = prop.foot
		var plumbing := _contains_any(kind, ["sink", "bath", "urinal", "toilet", "shower", "cooler", "cooling", "air_condition"])
		var seating := _contains_any(kind, ["chair", "seat", "desk", "workstation", "table", "bench", "sofa", "slot", "bed", "gurney", "wheelchair", "coffee_counter", "food_counter"])
		var plant := _contains_any(kind, ["plant", "fountain"])
		var rack := _contains_any(kind, ["rack", "data_center_control", "server"])
		if kind == "glazing" and ctx.theme == 4 and glazing_leaks < 1 \
				and _roll(at, 28414) < 0.16:
			_floor_patch(Vector3(at.x, 0.1, at.z), Vector2(1.4, 0.85), Motif.SPILL,
				Color(0.23, 0.22, 0.13), "airport_glazing_seep", 0.8, 0.32)
			glazing_leaks += 1
		if kind.contains("shutter") and floor_marks < 3:
			_floor_patch(at, Vector2(2.2, 0.9), Motif.JOINT,
				Color(0.18, 0.15, 0.085), "mall_shutter_bottom_dust", 1.1)
			floor_marks += 1
		if kind.contains("ladder") and ctx.theme == 9 and floor_marks < 3:
			_floor_patch(at + Vector3.UP * 1.6, Vector2(0.9, 0.8), Motif.RUST,
				Color(0.34, 0.17, 0.045), "pool_ladder_anchor_rust", 0.95)
			floor_marks += 1
		# Leave room for one complete fixture vignette; don't cut a leaking
		# fixture off halfway through because its room has five more sinks.
		var damp_fixture := (plumbing or plant) and _roll(at, 28415) < 0.28
		if floor_marks < 3 and patches <= MAX_PATCHES - 4 and (damp_fixture or seating or rack):
			if plumbing or plant:
				_floor_patch(at + Vector3.UP * 0.1, Vector2(1.1, 1.0), Motif.MINERAL,
					Color(0.56, 0.52, 0.35), "fixture_mineral_" + kind, 1.05)
				_floor_patch(at + Vector3(0.22, 0.12, 0.15), Vector2(1.35, 1.25), Motif.SPILL,
					Color(0.105, 0.12, 0.07), "fixture_seep_" + kind, 0.7, 0.25)
				var runoff := at + Vector3.UP * (-0.6 if at.y > 1.0 else 0.65)
				var wall := _nearest_wall(runoff)
				if wall != null:
					_patch(wall, runoff, Vector2(0.8, 1.3), Motif.RUST,
						Color(0.32, 0.15, 0.055), "plumbing_runoff_" + kind, 1.0)
					if ctx.theme in [1, 5, 6, 8]:
						_patch(wall, runoff - Vector3.UP * 0.3, Vector2(0.95, 0.5), Motif.MOLD,
							Color(0.07, 0.10, 0.045), "plumbing_grout_" + kind, 1.0)
			elif rack:
				_floor_patch(at + Vector3.UP * 0.1, Vector2(1.8, 1.2), Motif.DUST,
					Color(0.38, 0.36, 0.29), "rack_foot_dust", 0.65)
			else:
				_floor_patch(at + Vector3.UP * 0.1, Vector2(1.7, 1.4), Motif.SCUFF,
					Color(0.075, 0.065, 0.05), "furniture_floor_wear_" + kind, 1.2)
				if ctx.theme in [0, 1, 7] and _roll(at, 28409) < 0.24:
					_floor_patch(at + xf.basis.orthonormalized() * Vector3(0.55, 0.1, 0.25),
						Vector2(0.85, 0.70), Motif.SPILL, Color(0.20, 0.10, 0.035),
						"drink_spill_" + kind, 1.1)
			floor_marks += 1
		if prop_meshes >= MAX_PROP_MESHES:
			continue
		var profile := -1
		if kind == "glazing":
			profile = 5
		elif kind.contains("travelator_plate"):
			profile = 8
		elif kind == "school_court_marking":
			profile = 7
		elif rack or kind.contains("cooling"):
			profile = 3
		elif _contains_any(kind, ["locker", "gate", "bars", "door", "carousel", "railing", "rail", "ladder", "shutter", "brass", "queue_rope", "travelator"]):
			profile = 2
		elif plumbing or plant:
			profile = 6
		elif seating:
			profile = 0 if ctx.theme == 0 else 4
		elif _contains_any(kind, ["cart", "shelf", "counter", "cabinet", "telephone", "phone"]):
			profile = 1
		if profile >= 0:
			overlays.append({"prop": prop, "profile": profile})
	# First give each kind of fitting a turn. A bank of twelve rack copies must
	# not exhaust the draw budget before the room's cooling unit is reached.
	var treated := {}
	for entry in overlays:
		var kind: String = entry.prop.kind
		if not treated.has(kind):
			_prop_overlay(entry.prop, entry.profile, 2)
			treated[kind] = true
	for entry in overlays:
		if prop_meshes >= MAX_PROP_MESHES:
			break
		_prop_overlay(entry.prop, entry.profile, 2)


func _fixture_priority(kind: String) -> int:
	if _contains_any(kind, ["cooling", "air_condition", "sink", "urinal", "toilet", "shower_fixture", "hydro_bath"]):
		return 0
	if _contains_any(kind, ["plant", "fountain", "ladder", "coffee_counter", "food_counter", "break_table"]):
		return 1
	if _contains_any(kind, ["chair", "locker", "shutter", "glazing"]):
		return 2
	return 3


func _prop_overlay(prop: Dictionary, profile: int, limit: int) -> void:
	if prop_meshes >= MAX_PROP_MESHES:
		return
	var anchor: Transform3D = prop.transform
	# Use metres in the furnishing's orientation. Some raw primitives carry
	# their entire size in the root scale; retaining it here would make a thin
	# window and a cube both have 1x1x1 bounds and misidentify the glass face.
	var anchor_inverse: Transform3D = prop.get("wear_anchor_inverse",
		Transform3D.IDENTITY)
	var bounds := AABB()
	if prop.has("wear_bounds"):
		bounds = prop.wear_bounds
	else:
		anchor_inverse = Transform3D(anchor.basis.orthonormalized(),
			anchor.origin).affine_inverse()
		var has_bounds := false
		for entry: Dictionary in prop.meshes:
			var b: AABB = (anchor_inverse * entry.transform) * entry.local_bounds
			bounds = bounds.merge(b) if has_bounds else b
			has_bounds = true
		prop["wear_bounds"] = bounds
		prop["wear_anchor_inverse"] = anchor_inverse
	if prop.meshes.is_empty() or bounds.size.length_squared() < 0.02:
		return
	var seed_ := float(_hash(prop.foot, 28501) % 8192)
	var selected := 0
	# Preserve the original two sorts and their tie ordering. Only the costly
	# comparator arithmetic is cached, not the resulting order.
	prop.meshes.sort_custom(func(a: Dictionary, b: Dictionary):
		return a.wear_size_squared > b.wear_size_squared)
	for entry: Dictionary in prop.meshes:
		if prop_meshes >= MAX_PROP_MESHES or selected >= limit:
			break
		var mesh: MeshInstance3D = entry.mesh
		if mesh.material_overlay != null or mesh.has_meta("office_terminal_custom_screen"):
			continue
		# A per-mesh overlay must be safe for every surface of that mesh.
		var safe := true
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(surface)
			if source is ShaderMaterial or (source is BaseMaterial3D and
					(source.emission_enabled or (source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and profile != 5))):
				safe = false
				break
		if not safe:
			continue
		var overlay := ShaderMaterial.new()
		overlay.shader = PROP_SHADER
		overlay.resource_name = "surface_wear_prop_%d" % profile
		overlay.set_shader_parameter("mesh_to_prop", anchor_inverse * entry.transform)
		overlay.set_shader_parameter("bounds_min", bounds.position)
		overlay.set_shader_parameter("bounds_size", bounds.size.max(Vector3.ONE * 0.001))
		overlay.set_shader_parameter("wear_seed", seed_)
		var mesh_profile := profile
		var material := mesh.get_active_material(0)
		if profile == 6 and material != null and _contains_any(material.resource_name.to_lower(),
				["pipe_rust", "prison_iron", "prison_green", "asy_metal", "chrome"]):
			mesh_profile = 2
		overlay.set_shader_parameter("profile", mesh_profile)
		overlay.set_shader_parameter("strength", age * (0.65 if profile == 5 else 1.0))
		overlay.set_shader_parameter("casino", ctx.theme == 0)
		overlay.set_shader_parameter("infected", ctx.theme == 11)
		mesh.material_overlay = overlay
		mesh.set_meta("surface_wear_prop_overlay", true)
		mesh.set_meta("surface_wear_prop_kind", prop.kind)
		prop_meshes += 1
		selected += 1


func _root_damage() -> void:
	if ctx.theme != 11:
		return
	var chosen: Array[Vector3] = []
	for at in growth_contacts:
		if chosen.size() >= 2:
			break
		var close := false
		for previous in chosen:
			if at.distance_squared_to(previous) < 2.25:
				close = true
		if close:
			continue
		var wall := _nearest_wall(at, 0.5)
		if wall == null:
			continue
		_patch(wall, at, Vector2(1.6, 1.8), Motif.ROOT,
			Color(0.055, 0.07, 0.035), "bloom_root_pressure", 1.3, 0.6)
		if _roll(at, 28601) < 0.20:
			_lifted_finish(wall, at + Vector3.DOWN * 0.2, "plaster")
		_floor_patch(Vector3(at.x, 0.1, at.z) + wall.normal * 0.45,
			Vector2(1.25, 0.85), Motif.PLASTER, Color(0.52, 0.51, 0.39),
			"bloom_fallen_plaster", 1.15)
		chosen.append(at)


func _vent_dust() -> void:
	for i in mini(vents.size(), 1):
		var at := vents[i]
		for f in ceilings:
			var d := at - f.center
			if absf(d.dot(f.u)) < f.size.x * 0.5 and absf(d.dot(f.v)) < f.size.y * 0.5:
				_patch(f, at, Vector2(1.5, 1.2), Motif.DUST,
					Color(0.17, 0.14, 0.095),
					"casino_fixture_smoke" if ctx.theme == 0 else "vent_smoke_and_dust", 0.9)
				break


func _fixing_runoff() -> void:
	var count := 0
	for at in wall_fixings:
		if count >= 2:
			return
		var wall := _nearest_wall(at, 0.32)
		if wall == null:
			continue
		_patch(wall, at + Vector3.DOWN * 0.36, Vector2(0.32, 0.95),
			Motif.RUST, Color(0.31, 0.14, 0.04), "metal_fixing_runoff", 1.0)
		if ctx.theme == 10:
			_patch(wall, at, Vector2(0.65, 1.1), Motif.CRACK,
				Color(0.12, 0.115, 0.095), "concrete_mount_crack", 0.85)
		count += 1

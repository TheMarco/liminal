class_name ChunkSceneWriter
extends RefCounted
## Narrow construction capability passed to theme builders.
##
## It deliberately delegates to Chunk's proven geometry kernel during the
## migration. Once every theme uses this surface, those implementations can
## move without exposing Chunk internals or changing generated output.

var _host: Chunk
var _body: StaticBody3D


func _init(host: Chunk, body: StaticBody3D) -> void:
	_host = host
	_body = body


func add_node(node: Node) -> void:
	_host.add_child(node)


func box(pos: Vector3, size: Vector3, material: Material,
		collide := true) -> MeshInstance3D:
	return _host._box(pos, size, material, collide)


func occluder_wall(mesh: MeshInstance3D) -> void:
	_host.record_occluder_wall(mesh)


func model_box(parent: Node3D, pos: Vector3, size: Vector3,
		material: Material) -> MeshInstance3D:
	return _host._mbox(_model_parent(parent), pos, size, material)


func cylinder(pos: Vector3, radius: float, height: float,
		material: Material, collide := true) -> MeshInstance3D:
	return _host._cyl(pos, radius, height, material, collide)


func collider_box(pos: Vector3, size: Vector3) -> void:
	_host._collider_box(pos, size)


func collider_mark() -> int:
	return _body.get_child_count()


func furnishing_pivot(pos: Vector3, yaw: float, kind: String,
		floor_supported := true) -> Node3D:
	return _host._furnishing_pivot(pos, yaw, kind, floor_supported)


func bind_furnishing_colliders(pivot: Node3D, first: int) -> void:
	_host._bind_furnishing_colliders(pivot, first)


func attributed_prop_local(parent: Node3D, path: String, pos: Vector3,
		yaw: float, scale := Vector3.ONE) -> Node3D:
	return _host._attributed_prop_local(
		_model_parent(parent), path, pos, yaw, scale)


func main_light(flicker: bool, material: StandardMaterial3D,
		energy: float) -> OmniLight3D:
	return _host._make_main_light(flicker, material, energy)


func edge_info(at: Vector2i, dir: int) -> Dictionary:
	return _host._edge_info(at, dir)


func solid_wall(dir: int) -> bool:
	return _host._solid_wall(dir)


func wall_facing(dir: int) -> float:
	return _host._wall_facing(dir)


func wall_point(dir: int, along: float, offset: float,
		y := 0.0) -> Vector3:
	return _host._wall_pt(dir, along, offset, y)


func rounded_box(pos: Vector3, size: Vector3, mat: Material, r := 0.03,
		collide := true) -> MeshInstance3D:
	return _host._rbox(pos, size, mat, r, collide)

func model_rounded_box(parent: Node3D, pos: Vector3, size: Vector3,
		mat: Material, r := 0.03) -> MeshInstance3D:
	return _host._mrbox(_model_parent(parent), pos, size, mat, r)

func model_cylinder(parent: Node3D, pos: Vector3, radius: float, height: float,
		mat: Material) -> MeshInstance3D:
	return _host._mcyl(_model_parent(parent), pos, radius, height, mat)

func model_quad(parent: Node3D, pos: Vector3, size: Vector2,
		mat: Material) -> MeshInstance3D:
	return _host._mquad(_model_parent(parent), pos, size, mat)

func model_sphere(parent: Node3D, pos: Vector3, r: float,
		mat: Material) -> MeshInstance3D:
	return _host._msphere(_model_parent(parent), pos, r, mat)

func model_beam(parent: Node3D, a: Vector3, b: Vector3, th: float,
		mat: Material) -> MeshInstance3D:
	return _host._mbeam(_model_parent(parent), a, b, th, mat)

func sphere(pos: Vector3, r: float, mat: Material) -> MeshInstance3D:
	return _host._sphere(pos, r, mat)

func quad(pos: Vector3, size: Vector2, mat: Material) -> MeshInstance3D:
	return _host._quad(pos, size, mat)

func beam(a: Vector3, b: Vector3, th: float, mat: Material) -> MeshInstance3D:
	return _host._beam(a, b, th, mat)

func collider_cylinder(pos: Vector3, radius: float, height: float) -> void:
	_host._collider_cyl(pos, radius, height)

func collider_yaw_box(pos: Vector3, size: Vector3, yaw: float) -> void:
	_host._collider_yaw_box(pos, size, yaw)

func collider_rotated_box(pos: Vector3, size: Vector3,
		rot: Vector3) -> CollisionShape3D:
	return _host._collider_rot_box(pos, size, rot)

func world_point(o: Vector3, local: Vector3, yaw: float) -> Vector3:
	return _host._wp(o, local, yaw)

func yaw_for(dir: int) -> float:
	return _host._yaw_for(dir)

func adopt_local(parent: Node3D, child: Node3D) -> void:
	_host._adopt_local(_model_parent(parent), child)

func cut_segments(segs: Array, c0: float, c1: float) -> Array:
	return _host._cut_seg(segs, c0, c1)

func finish_variant() -> int:
	return _host._finish_variant()

func room_span() -> Vector2:
	return _host._room_span()

func room_members() -> Array[Vector2i]:
	return _host._room_members()

func floor_spot_clear(p: Vector3, radius: float, height := 0.9) -> bool:
	return _host._floor_spot_clear(p, radius, height)

func floor_box_clear(p: Vector3, yaw: float, width: float, depth: float,
		height := 0.9) -> bool:
	return _host._floor_box_clear(p, yaw, width, depth, height)

func free_floor_spot(salt: int, radius: float, inset := 2.4,
		height := 0.9, tries := 10) -> Vector3:
	return _host._free_floor_spot(salt, radius, inset, height, tries)

func load_model(mname: String, pos: Vector3, yaw: float) -> Node3D:
	return _host._load_model(mname, pos, yaw)

func cc0_prop(mname: String, pos: Vector3, yaw: float, scl := 1.0) -> Node3D:
	return _host._cc0_prop(mname, pos, yaw, scl)

func cc0_prop_local(parent: Node3D, mname: String, pos: Vector3,
		yaw: float, scl := 1.0) -> Node3D:
	return _host._cc0_prop_local(
		_model_parent(parent), mname, pos, yaw, scl)

func attributed_floor_prop(path: String, p: Vector3, yaw: float, scl: float,
		centre: Vector3, kind: String, parent: Node3D = null,
		group := false) -> Node3D:
	return _host._attributed_floor_prop(path, p, yaw, scl, centre, kind, parent, group)

func disable_shadows(n: Node) -> void:
	_host._disable_shadows(n)

func scattered_papers(p: Vector3, salt: int, count: int) -> void:
	_host._scattered_papers(p, salt, count)

func prop_scene(path: String) -> PackedScene:
	return Chunk._prop_scene(path)

func planter(p: Vector3) -> void:
	_host._planter(p)

func claim_furnishing_group(pivot: Node3D, kind: String,
		floor_supported := true) -> int:
	return _host._claim_furnishing_group(pivot, kind, floor_supported)

func find_nodes(pattern: String, type: String, recursive: bool,
		owned: bool) -> Array[Node]:
	return _host.find_children(pattern, type, recursive, owned)

func chunk_child(index: int) -> Node:
	return _host.get_child(index)

func chunk_child_count() -> int:
	return _host.get_child_count()

func set_chunk_meta(key: Variant, value: Variant) -> void:
	_host.set_meta(key, value)

func chunk_meta(key: Variant, default = null):
	return _host.get_meta(key, default)

func collider_child(index: int) -> Node:
	return _body.get_child(index)


func add_collision_shape(shape: CollisionShape3D) -> void:
	_body.add_child(shape)


func profile_stage(label: String, started_usec: int) -> void:
	_host._profile_stage(label, started_usec)


func model_cone(parent: Node3D, base: Vector3, radius: float, height: float,
		material: Material) -> MeshInstance3D:
	return _host._mcone(_model_parent(parent), base, radius, height, material)


func model_ellipsoid(parent: Node3D, pos: Vector3, scale: Vector3,
		material: Material) -> MeshInstance3D:
	return _host._mellipsoid(_model_parent(parent), pos, scale, material)


func annex_wall_prism(pos: Vector3, size: Vector3, along_x: bool,
		cap_min: bool, cap_max: bool, material: Material,
		soffit_material: Material = null, cap_material: Material = null,
		positive_material: Material = null,
		negative_material: Material = null) -> MeshInstance3D:
	return _host._annex_wall_prism(pos, size, along_x, cap_min, cap_max,
		material, soffit_material, cap_material, positive_material,
		negative_material)


func annex_baseboard_box(pos: Vector3, size: Vector3) -> MeshInstance3D:
	return _host._annex_baseboard_box(pos, size)


func annex_local_baseboard(parent: Node3D, pos: Vector3,
		size: Vector3) -> void:
	_host._annex_local_baseboard(_model_parent(parent), pos, size)


func annex_wrap_local_baseboards(parent: Node3D, width: float, depth: float,
		omit_min_x := false, omit_max_x := false) -> void:
	_host._annex_wrap_local_baseboards(
		_model_parent(parent), width, depth, omit_min_x, omit_max_x)


func annex_resolved_wall_treatment(dir: int) -> Dictionary:
	return _host._annex_resolved_wall_treatment(dir)


func register_annex_ceiling_obstruction(rect: Rect2) -> void:
	_host._annex_ceiling_obstructions.append(rect)


func register_annex_architecture_footprint(footprint: Dictionary) -> void:
	_host._annex_architecture_footprints.append(footprint)


func annex_architecture_footprints() -> Array[Dictionary]:
	return _host._annex_architecture_footprints.duplicate()


func annex_fixture_clear(at: Vector3) -> bool:
	return _host._annex_fixture_clear(at)


func wall_band_top() -> float:
	return _host._wall_band_top()


func wall_art_path(salt: int) -> String:
	return _host._wall_art_path(salt)


func wall_art_mount(pos: Vector3, yaw: float, dir: int, path: String,
		max_size: Vector2, tilt: float) -> Node3D:
	return _host._wall_art_mount(pos, yaw, dir, path, max_size, tilt)


func wall_art_chance() -> float:
	return _host._wall_art_chance()


func office_wall_art_layout(member: Vector2i, dir: int) -> Dictionary:
	return _host._office_wall_art_layout(member, dir)


func wall_utilities(dir: int, plane: float, info: Dictionary) -> void:
	_host._wall_utilities(dir, plane, info)


func wall_utility_mount(pos: Vector3, yaw: float, height: float,
		is_switch: bool) -> Node3D:
	return _host._wall_utility_mount(pos, yaw, height, is_switch)


func wall_clock(dir: int, plane: float) -> void:
	_host._wall_clock(dir, plane)


func troffer(at: Vector3, lens: Vector2, panel_material: Material,
		frame_material: Material) -> void:
	_host._troffer(at, lens, panel_material, frame_material)


func runtime_shortcut_clearance_rects() -> Array[Rect2]:
	return _host._runtime_shortcut_clearance_rects().duplicate()


func rope_barrier(pos: Vector3, yaw: float, kind: String) -> Node3D:
	return _host._rope_barrier(pos, yaw, kind)


func office_ibm_terminal(workstation: Node3D, desk_center: Vector3,
		yaw: float, index: int) -> bool:
	return _host._office_ibm_terminal(workstation, desk_center, yaw, index)


func filing_bank(dir: int, plane: float) -> void:
	_host._filing_bank(dir, plane)


func vt100(pos: Vector3, yaw: float) -> Node3D:
	return _host._vt100(pos, yaw)


func vt100_keyboard(pos: Vector3, yaw: float) -> Node3D:
	return _host._vt100_keyboard(pos, yaw)


func shelf_unit(center: Vector3, along_x: bool, salt: int) -> void:
	_host._shelf_unit(center, along_x, salt)


func shelf_box(parent: Node3D, pos: Vector3, yaw: float, variant: int,
		kind := "office_shelf_box") -> bool:
	return _host._shelf_box(
		_model_parent(parent), pos, yaw, variant, kind)


func chain(pos: Vector3) -> void:
	_host._chain(pos)


func small_desk(pos: Vector3, yaw: float) -> void:
	_host._small_desk(pos, yaw)


func waste_bin(pos: Vector3, yaw: float, kind: String) -> Node3D:
	return _host._waste_bin(pos, yaw, kind)


func chemistry_glassware(parent: Node3D, pos: Vector3, yaw: float,
		salt: int, full_set: bool, context: String) -> Node3D:
	return _host._chemistry_glassware(
		_model_parent(parent), pos, yaw, salt, full_set, context)


func cc0_floor_prop(model_name: String, pos: Vector3, yaw: float,
		scale: float, kind: String, collider_size: Vector3,
		collider_center := Vector3.ZERO) -> Node3D:
	return _host._cc0_floor_prop(model_name, pos, yaw, scale, kind,
		collider_size, collider_center)


func set_model_material(node: Node, material: Material) -> void:
	_host._set_model_material(node, material)


func task_chair(pos: Vector3, yaw: float) -> Node3D:
	return _host._task_chair(pos, yaw)


func security_camera(mount: Vector3, lens_yaw: float) -> void:
	_host._security_camera(mount, lens_yaw)


func surface_facing_box(dir: int, plane: float, offset: float, along: float,
		y: float, width: float, height: float, depth: float,
		material: Material, collide := false) -> MeshInstance3D:
	return _host._sfb(dir, plane, offset, along, y, width, height, depth,
		material, collide)


func security_camera_wall(dir: int, plane: float) -> void:
	_host._security_camera_wall(dir, plane)


func slot_machine_scene() -> PackedScene:
	return Chunk.cached_slot_machine_scene()


func asylum_scene(key: String, path: String) -> PackedScene:
	return Chunk.cached_asylum_scene(key, path)


func scrawl_font(which: int) -> FontFile:
	return Chunk.cached_scrawl_font(which)


func _model_parent(parent: Node3D) -> Node3D:
	return _host if parent == null else parent

extends SceneTree
## Contract audit for the environment-breath beat: Profile math, the surface
## renderer (geometry/collision fidelity against Profile.sample), and director
## actor-clear/start gating. Run in the primary worktree where
## scripts/environment_breath_surface.gd exists; assets are required for the
## director section. No saves, no live campaign, no audio.

const Profile := preload("res://scripts/environment_breath_profile.gd")
const Placement := preload("res://scripts/environment_breath_placement.gd")

const KINDS := ["breath", "travel", "ceiling"]
const SURFACE_PATH := "res://scripts/environment_breath_surface.gd"
const DIRECTOR_PATH := "res://scripts/environment_breath_director.gd"
const ROOM_OFFSET := Vector3(37.0, 0.0, -52.0)
const RAY_TOLERANCE := 0.025
const DELTA_TOLERANCE := 0.0005

var failures: Array[String] = []
var skipped: Array[String] = []
var Surface: Script = null
var Director: Script = null

func expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	_audit_profile()
	if FileAccess.file_exists(SURFACE_PATH):
		Surface = load(SURFACE_PATH)
		Director = load(DIRECTOR_PATH)
	if Surface == null:
		failures.append("renderer failed to load: " + SURFACE_PATH)
		skipped.append("director live section: start_event/chunk gating left to primary (renderer absent)")
	else:
		_audit_shader_reuse()
		for kind in KINDS:
			await _audit_renderer_kind(kind)
	await _audit_environments()
	await _audit_ceilings()
	_audit_director()
	if failures.is_empty():
		print("environment breath audit: PASS")
	else:
		for failure in failures:
			print("FAIL — " + failure)
	for note in skipped:
		print("SKIP — " + note)
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit(0 if failures.is_empty() else 1)


func _audit_shader_reuse() -> void:
	var source := Mats.office_wall() as ShaderMaterial
	var first: Node3D = Surface.new()
	var second: Node3D = Surface.new()
	var first_material := first.call("_wrap_native_shader", source) as ShaderMaterial
	var second_material := second.call("_wrap_native_shader", source) as ShaderMaterial
	expect(first_material.shader == second_material.shader \
		and first_material.shader != source.shader,
		"repeated Office effects rebuilt their morph shader")
	expect(first_material.get_shader_parameter("scenario_blend") == \
		source.get_shader_parameter("scenario_blend") \
		and second_material.get_shader_parameter("scenario_drywall_tex") == \
		source.get_shader_parameter("scenario_drywall_tex"),
		"cached morph shader lost source material parameters")
	first.free()
	second.free()

# Profile: pure math, no assets, no renderer. -------------------------------

func _audit_profile() -> void:
	expect(Profile.targets("breath", Vector2(3, 2), 0.35).size() == 1, "breath target count differs")
	expect(Profile.targets("travel", Vector2(3, 2), 0.35).size() == 7, "travel target count differs")
	for kind in KINDS:
		for endpoint in [0.0, 1.0]:
			for w in Profile.weights(kind, endpoint):
				expect(absf(w) < 0.000001, "%s weight nonzero at phase %s" % [kind, endpoint])
		for i in range(101):
			var weights := Profile.weights(kind, i / 100.0)
			var total := 0.0
			for w in weights:
				expect(is_finite(w) and w >= 0.0 and w <= 1.0, "%s weight out of range" % kind)
				total += w
			if kind == "travel":
				expect(total <= 1.0 + 0.0001, kind + " partition exceeds one")
	# Compact support: zero outside, finite inside, finite gradients.
	var target := Profile.targets("breath", Vector2(3, 2), 0.35)[0]
	expect(Profile.sample(target, Vector2(9, 9)) == Vector3.ZERO, "sample leaks outside support")
	expect(Profile.sample(target, Vector2(-9, 0.5)) == Vector3.ZERO, "sample leaks outside support")
	var center_height: float = Profile.sample(target, Vector2.ZERO).x
	expect(center_height > 0.2, "sample center height differs")
	for ix in range(-40, 41):
		for iy in [-10, -5, 0, 5, 10]:
			var s := Profile.sample(target, Vector2(ix * 0.1, iy * 0.1))
			expect(is_finite(s.x) and is_finite(s.y) and is_finite(s.z), "sample not finite")
			if absf(ix * 0.1) > 1.5 or absf(iy * 0.1) > 1.0:
				expect(s == Vector3.ZERO, "sample nonzero outside support")
			elif absf(ix * 0.1) < 1.4 and absf(iy * 0.1) < 0.9:
				expect(s.x >= 0.0, "sample height negative inside support")
	for kind in KINDS:
		expect(Profile.duration(kind) > 0.0 and is_finite(Profile.duration(kind)), "%s duration invalid" % kind)

# Renderer: geometry and collision fidelity. --------------------------------

func _make_room() -> Dictionary:
	var room := Node3D.new()
	room.position = ROOM_OFFSET
	root.add_child(room)
	var finish := StandardMaterial3D.new()
	finish.resource_name = "breath_audit_finish"
	finish.albedo_color = Color(0.62, 0.58, 0.52)
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(4, 3, 0.2)
	var wall := MeshInstance3D.new()
	wall.mesh = wall_mesh
	wall.position = Vector3(0, 1.5, 0)
	wall.material_override = finish
	room.add_child(wall)
	var band_mesh := BoxMesh.new()
	band_mesh.size = Vector3(4, 0.12, 0.05)
	var band := MeshInstance3D.new()
	band.mesh = band_mesh
	band.position = Vector3(0, 1.3, 0.13)
	band.material_override = finish
	room.add_child(band)
	var face := SurfaceWear.Face.new()
	face.mesh = wall
	face.transform = wall.transform
	face.center = Vector3(0, 1.5, 0.1)
	face.normal = Vector3.BACK
	face.u = Vector3.RIGHT
	face.v = Vector3.UP
	face.size = Vector2(4, 3)
	return {"room": room, "wall": wall, "band": band, "finish": finish,
		"wall_mesh": wall_mesh, "band_mesh": band_mesh, "face": face}

func _audit_renderer_kind(kind: String) -> void:
	var rig := _make_room()
	var room: Node3D = rig.room
	var wall: MeshInstance3D = rig.wall
	var band: MeshInstance3D = rig.band
	var face: SurfaceWear.Face = rig.face
	var size := Vector2(3.0, 2.0)
	var depth := 0.35
	var center := Vector3(0, 1.5, 0.1)
	var selection := {"face": face, "center": center, "size": size,
		"depth": depth, "companions": [{"mesh": band, "transform": band.transform}]}
	var targets := Profile.targets(kind, size, depth)
	var effect: Node3D = Surface.new()
	room.add_child(effect)
	var wall_cull := wall.extra_cull_margin
	var band_cull := band.extra_cull_margin
	var phase := 0.5
	var weights := Profile.weights(kind, phase)
	expect(effect.setup(selection, kind), "%s setup refused selection" % kind)
	effect.pose(weights)
	if not is_instance_valid(effect) or wall.mesh == rig.wall_mesh:
		failures.append("%s setup did not build GPU meshes" % kind)
		room.queue_free()
		return
	expect(wall.mesh is ArrayMesh and band.mesh is ArrayMesh, "%s meshes are not GPU blend meshes" % kind)
	# Native material mapping: original resources stay anchored on both meshes.
	expect(wall.material_override == rig.finish and band.material_override == rig.finish,
		"%s setup replaced the native material" % kind)
	var wall_count := (wall.mesh as ArrayMesh).get_blend_shape_count()
	var band_count := (band.mesh as ArrayMesh).get_blend_shape_count()
	expect(wall_count >= weights.size() and band_count >= weights.size(),
		"%s blend count %d/%d below weight count %d" % [kind, wall_count, band_count, weights.size()])
	effect.pose(weights)
	for i in weights.size():
		expect(absf(wall.get_blend_shape_value(i) - weights[i]) < 0.0001,
			"%s wall blend %d differs" % [kind, i])
		expect(absf(band.get_blend_shape_value(i) - weights[i]) < 0.0001,
			"%s band blend %d differs" % [kind, i])
	_verify_morphs(kind, wall, targets, center, face, true)
	_verify_morphs(kind, band, targets, center, face, false)
	# Collision: one body at most, rays match the posed surface, off at rest.
	var bodies := effect.find_children("*", "StaticBody3D", true, false)
	expect(bodies.size() <= 1, "%s effect owns %d collision bodies" % [kind, bodies.size()])
	expect(band.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"%s band gained colliders" % kind)
	effect.sync_collision()
	expect(effect.find_children("*", "StaticBody3D", true, false).size() == 1,
		"%s posed effect has no collision body" % kind)
	await physics_frame
	await physics_frame
	_verify_collider_rays(kind, room, center, face, targets, weights, true)
	var rest := PackedFloat32Array()
	rest.resize(weights.size())
	effect.pose(rest)
	effect.sync_collision()
	await physics_frame
	await physics_frame
	_verify_collider_rays(kind, room, center, face, targets, rest, false)
	effect.restore()
	expect(effect.originals_restored(), "%s restore incomplete" % kind)
	expect(wall.mesh == rig.wall_mesh and band.mesh == rig.band_mesh,
		"%s restore did not return original meshes" % kind)
	expect(wall.material_override == rig.finish and band.material_override == rig.finish,
		"%s restore did not return original materials" % kind)
	expect(wall.extra_cull_margin == wall_cull and band.extra_cull_margin == band_cull,
		"%s restore changed cull margins" % kind)
	for col in effect.find_children("*", "CollisionShape3D", true, false):
		expect((col as CollisionShape3D).disabled, "%s restore left a live collider" % kind)
	effect.queue_free()
	await process_frame
	expect(not is_instance_valid(effect),
		"%s effect did not free" % kind)
	room.queue_free()
	await process_frame
	expect(not is_instance_valid(room), "%s room did not free" % kind)

func _blend_vertices(mesh: ArrayMesh) -> Array:
	var out: Array = []
	for entry in mesh.surface_get_blend_shape_arrays(0):
		if not entry.is_empty():
			out.append(entry[Mesh.ARRAY_VERTEX])
	return out

func _verify_morphs(kind: String, node: MeshInstance3D, targets: Array[Dictionary],
		center: Vector3, face: SurfaceWear.Face, front_only: bool) -> void:
	var mesh := node.mesh as ArrayMesh
	var base: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var shapes := _blend_vertices(mesh)
	var base_normals: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	var blends := mesh.surface_get_blend_shape_arrays(0)
	expect(shapes.size() >= targets.size(), "%s %s blend arrays missing" % [kind, node.name])
	for k in targets.size():
		var deltas: PackedVector3Array = shapes[k]
		var normals: PackedVector3Array = blends[k][Mesh.ARRAY_NORMAL]
		expect(deltas.size() == base.size(), "%s %s shape %d vertex mismatch" % [kind, node.name, k])
		if deltas.size() != base.size():
			continue
		var checked := 0
		var interior := 0
		var step := 1
		for vi in range(0, base.size(), step):
			var room_point: Vector3 = node.transform * base[vi]
			if front_only and absf(room_point.z - center.z) > 0.001:
				continue
			var at := Vector2((room_point - center).dot(face.u), (room_point - center).dot(face.v))
			var expected: Vector3 = face.normal * Profile.sample(targets[k], at).x
			var sample := Profile.sample(targets[k], at)
			var expected_normal := (base_normals[vi] + Vector3(-sample.y, -sample.z, 0) * base_normals[vi].z).normalized()
			expect(normals[vi].is_finite() and normals[vi].dot(expected_normal) > 0.999, "%s shape %d surface normal differs" % [kind, k])
			checked += 1
			if expected.length() > 0.0001:
				interior += 1
			expect((deltas[vi] - base[vi] - expected).length() < DELTA_TOLERANCE,
				"%s %s shape %d vertex %d delta differs" % [kind, node.name, k, vi])
		expect(checked > 0, "%s %s shape %d has no checkable vertices" % [kind, node.name, k])
		if front_only: expect(interior > 0, "%s %s shape %d never rises" % [kind, node.name, k])

func _posed_height(targets: Array[Dictionary], weights: PackedFloat32Array, at: Vector2) -> float:
	var total := 0.0
	for k in mini(targets.size(), weights.size()):
		total += weights[k] * Profile.sample(targets[k], at).x
	return total

func _verify_collider_rays(kind: String, room: Node3D, center: Vector3, face: SurfaceWear.Face,
		targets: Array[Dictionary], weights: PackedFloat32Array, expect_hit: bool) -> void:
	var space := root.world_3d.direct_space_state
	for at in [Vector2.ZERO, Vector2(-1.0, -0.5), Vector2(1.0, 0.5)]:
		var plane_point: Vector3 = center + face.u * at.x + face.v * at.y
		var query := PhysicsRayQueryParameters3D.create(
			room.global_transform * (plane_point + face.normal * 1.9),
			room.global_transform * (plane_point - face.normal * 1.1))
		var hit := space.intersect_ray(query)
		if not expect_hit:
			expect(hit.is_empty(), "%s rest collider still hits at %s" % [kind, at])
			continue
		expect(not hit.is_empty(), "%s collider misses at %s" % [kind, at])
		if hit.is_empty():
			continue
		var expected_global: Vector3 = room.global_transform * (plane_point + face.normal * _posed_height(targets, weights, at))
		expect((hit.position - expected_global).length() < RAY_TOLERANCE,
			"%s collider off by %.3fm at %s" % [kind, (hit.position - expected_global).length(), at])

# Director: actor clearance and start gating. --------------------------------

func _audit_director() -> void:
	if Director == null:
		return
	var chunk := Chunk.new(1, Vector2i.ZERO, 1)
	root.add_child(chunk)
	var player := Player.new()
	root.add_child(player)
	player.set_physics_process(false)
	var director: Node = Director.new()
	root.add_child(director)
	director.set_physics_process(false)
	var candidates: Array = Placement.candidates(chunk, "breath")
	if candidates.is_empty():
		failures.append("director actor_clear: no breath candidate in office chunk")
		_verify_director_gates(director, chunk, player, {})
		chunk.queue_free()
		player.queue_free()
		director.queue_free()
		return
	var selection: Dictionary = candidates[0]
	var face: SurfaceWear.Face = selection.face
	director.selection = selection
	director.active_chunk = chunk
	director.player = player
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
	# Inside the swept body: the beat must withdraw.
	player.global_position = chunk.global_transform * (selection.center + face.normal * 0.3) - Vector3.UP * 0.9
	expect(not director.actor_clear(), "actor_clear ignores an actor in the bulge")
	# Well clear of the region: the beat may proceed.
	var size: Vector2 = selection.size
	player.global_position = chunk.global_transform * (selection.center + face.u * (size.x + 3.0) + face.normal * 3.0)
	expect(director.actor_clear(), "actor_clear blocks a clear room")
	# A fast approach into the region withdraws the beat before contact.
	if player is CharacterBody3D:
		player.global_position = chunk.global_transform * (selection.center + face.normal * 3.0) - Vector3.UP * 0.9
		(player as CharacterBody3D).velocity = chunk.global_basis * (face.normal * -8.0)
		expect(not director.actor_clear(), "actor_clear ignores swept velocity")
		(player as CharacterBody3D).velocity = Vector3.ZERO
	_verify_director_gates(director, chunk, player, selection)
	var ceilings := Placement.candidates(chunk, "ceiling")
	expect(not ceilings.is_empty(), "office fixture has no ceiling candidate")
	if not ceilings.is_empty():
		director.selection = ceilings[0]
		director.active_chunk = chunk
		var overhead: Vector3 = chunk.to_global(ceilings[0].center)
		player.global_position = Vector3(overhead.x, chunk._floor_h(), overhead.z)
		player.velocity = Vector3.ZERO
		expect(director.actor_clear(), "standing below a tall ceiling was rejected")
		player.global_position.y = overhead.y - 1.9
		expect(not director.actor_clear(), "ceiling ignored actor head entering bow")
		player.global_position.y = chunk._floor_h()
		player.velocity = Vector3.UP * 8.0
		expect(not director.actor_clear(), "ceiling ignored swept vertical approach")
		player.velocity = Vector3.ZERO
	chunk.queue_free()
	player.queue_free()
	director.queue_free()

func _verify_director_gates(director: Node, chunk: Chunk, player: Player, selection: Dictionary) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F6
	key.pressed = true
	director._unhandled_input(key)
	expect(director.events_started == 0 and director.active == null, "normal play accepts the breath preview key")
	if selection.is_empty():
		skipped.append("director start_event: no selection available; allow-gate and actor-gate cases left to primary")
		return
	var children_before := chunk.get_child_count()
	director.allowed = Callable()
	director.start_event(chunk, selection, "breath")
	expect(director.active == null and chunk.get_child_count() == children_before,
		"start_event ran without an allow gate")
	director.allowed = func() -> bool: return true
	var face: SurfaceWear.Face = selection.face
	player.global_position = chunk.global_transform * (selection.center + face.normal * 0.3) - Vector3.UP * 0.9
	director.start_event(chunk, selection, "breath")
	expect(director.active == null and chunk.get_child_count() == children_before,
		"start_event ran into an occupied bulge")
	director.debug_controls = true
	director.cooldown = 30.0
	director._unhandled_input(key)
	expect(director.cooldown == 0.0, "debug preview did not arm")
	director.debug_controls = false

# Real generated rooms: both live shapes, native materials and attached bands.
func _audit_environments() -> void:
	if Surface == null: return
	var max_setup := {"breath": 0.0, "travel": 0.0}
	var max_collision := 0.0
	var max_step := 0.0
	for theme in WorldGen.THEMES:
		var chunk: Chunk
		var choices: Array[Dictionary] = []
		for at in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			chunk = Chunk.new(WorldGen.level_seed(980712989, theme), at, theme)
			choices = Placement.candidates(chunk)
			if not choices.is_empty(): break
			chunk.free()
			chunk = null
		expect(chunk != null, "theme %d has no usable patch" % theme)
		if chunk == null: continue
		root.add_child(chunk)
		for kind in ["breath", "travel"]:
			var effect: Node3D = Surface.new()
			chunk.add_child(effect)
			var begin := Time.get_ticks_usec()
			effect.begin_setup(choices[0], kind)
			while not effect.prepared and not effect.failed:
				var step_start := Time.get_ticks_usec()
				effect.prepare_step()
				max_step = maxf(max_step, (Time.get_ticks_usec() - step_start) / 1000.0)
			expect(effect.prepared, "theme %d %s setup failed" % [theme, kind])
			max_setup[kind] = maxf(max_setup[kind], (Time.get_ticks_usec() - begin) / 1000.0)
			for phase in [0.25, 0.5, 0.75]:
				effect.pose(Profile.weights(kind, phase))
				for piece: Dictionary in effect.pieces:
					var node: MeshInstance3D = piece.node
					var from_mesh: Transform3D = effect.frame.affine_inverse() * Placement.relative(node, chunk)
					var mesh: ArrayMesh = node.mesh
					var base: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
					var shapes := mesh.surface_get_blend_shape_arrays(0)
					for vi in range(0, base.size(), maxi(1, base.size() / 100)):
						var point := from_mesh * base[vi]
						var posed := base[vi]
						for k in shapes.size(): posed += (shapes[k][Mesh.ARRAY_VERTEX][vi] - base[vi]) * effect.weights[k]
						var delta := from_mesh.basis * (posed - base[vi])
						expect((delta - Vector3(0, 0, effect.height_at(Vector2(point.x, point.y)))).length() < 0.0005, "theme %d %s geometry differs" % [theme, kind])
				begin = Time.get_ticks_usec()
				effect.sync_collision()
				max_collision = maxf(max_collision, (Time.get_ticks_usec() - begin) / 1000.0)
			effect.restore()
			expect(effect.originals_restored(), "theme %d %s restore failed" % [theme, kind])
			effect.free()
		chunk.queue_free()
		await process_frame
	print("11 environments / breath + travel: max setup ms ", max_setup, "; max preparation step ms ", max_step, "; max collision ms ", max_collision)

# Real ceiling candidates: fixture exclusion, world-space collision and exact
# restoration. A theme with no safe patch must skip rather than alter fixtures.
func _audit_ceilings() -> void:
	if Surface == null: return
	var covered: Array[int] = []
	var no_patch: Array[int] = []
	var max_step := 0.0
	for theme in WorldGen.THEMES:
		var chunk: Chunk
		var choices: Array[Dictionary] = []
		for at in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			chunk = Chunk.new(WorldGen.level_seed(980712989, theme), at, theme)
			choices = Placement.candidates(chunk, "ceiling")
			if not choices.is_empty(): break
			chunk.free()
			chunk = null
		if chunk == null:
			no_patch.append(theme)
			continue
		covered.append(theme)
		chunk.position = ROOM_OFFSET
		root.add_child(chunk)
		var choice := choices[0]
		var face: SurfaceWear.Face = choice.face
		expect(face.normal.y < -0.98, "ceiling selector returned a wall")
		expect(choice.center.y - choice.depth >= chunk._floor_h() + 2.25, "ceiling lost standing headroom")
		expect(choice.companions.is_empty(), "ceiling captured a fixture")
		# Force an attached fixture into the selected patch: it must no longer
		# be offered. This catches regressions in the exclusion volume.
		var fixture := MeshInstance3D.new()
		fixture.mesh = BoxMesh.new()
		fixture.mesh.size = Vector3(0.3, 0.1, 0.3)
		fixture.position = choice.center + Vector3.DOWN * 0.04
		chunk.add_child(fixture)
		for other in Placement.candidates(chunk, "ceiling"):
			expect(other.center.distance_to(choice.center) > 0.01, "ceiling selector ignored an attached fixture")
		fixture.free()
		var effect: Node3D = Surface.new()
		chunk.add_child(effect)
		effect.begin_setup(choice, "ceiling")
		while not effect.prepared and not effect.failed:
			var begin := Time.get_ticks_usec()
			effect.prepare_step()
			max_step = maxf(max_step, (Time.get_ticks_usec()-begin)/1000.0)
		expect(effect.prepared, "theme %d ceiling preparation failed" % theme)
		if effect.prepared:
			var weights := Profile.weights("ceiling", 0.5)
			effect.pose(weights)
			# Compare actual horizontal GPU vertices to the same height field
			# used by collision, including transformed/non-origin rooms.
			var node: MeshInstance3D = face.mesh
			var mesh: ArrayMesh = node.mesh
			var base: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var posed: PackedVector3Array = mesh.surface_get_blend_shape_arrays(0)[0][Mesh.ARRAY_VERTEX]
			var from_mesh: Transform3D = effect.frame.affine_inverse() * face.transform
			var moved := false
			for vi in base.size():
				var point := from_mesh * base[vi]
				var expected := Vector3(0, 0, effect.height_at(Vector2(point.x, point.y)))
				var delta := from_mesh.basis * (posed[vi] - base[vi])
				expect(delta.distance_to(expected) < 0.0005, "theme %d ceiling GPU geometry differs" % theme)
				moved = moved or delta.length() > 0.1
			expect(moved, "theme %d ceiling did not deform" % theme)
			effect.sync_collision()
			await physics_frame
			await physics_frame
			_verify_collider_rays("ceiling theme %d" % theme, chunk, choice.center, face, effect.targets, weights, true)
			effect.restore()
			expect(effect.originals_restored(), "theme %d ceiling restoration failed" % theme)
		effect.free()
		chunk.queue_free()
		await process_frame
	expect(covered.has(1), "Office ceiling not covered")
	print("Ceiling coverage: ", covered, "; safely skipped (no clear patch in five cells): ", no_patch, "; max preparation step ms ", max_step)

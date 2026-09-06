extends SceneTree
## Authored jetway: resources, depth staging, aircraft clearance and room bounds.
## godot --headless --path . --script tools/audit_airport_jetway.gd

var failures := 0
var shared_meshes := {}
var shared_materials := {}
var triangles := 0
var plane_triangles := 0


func _init() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("JETWAY_AUDIT: " + message)


func bounds(node: Node, parent_xf: Transform3D = Transform3D.IDENTITY) -> AABB:
	var xf := parent_xf
	if node is Node3D:
		xf *= node.transform
	var result := AABB()
	var have := false
	if node is MeshInstance3D and node.mesh != null:
		result = xf * node.mesh.get_aabb()
		have = true
	for child in node.get_children():
		var b := bounds(child, xf)
		if b.size == Vector3.ZERO:
			continue
		result = result.merge(b) if have else b
		have = true
	return result


func inspect_asset(j: Node3D) -> void:
	check(j.get_meta("authored_asset", "") == Chunk.AIRPORT_JETWAY_PATH, "Wrong asset path")
	var meshes := j.find_children("*", "MeshInstance3D", true, false)
	check(meshes.size() == 2, "Expected structure and separate glazing")
	var total := 0
	for mi: MeshInstance3D in meshes:
		check(mi.mesh.get_surface_count() == 1, "Extra material surface")
		var mat := mi.mesh.surface_get_material(0) as StandardMaterial3D
		if shared_meshes.has(mi.name):
			check(shared_meshes[mi.name] == mi.mesh, "Instances duplicate mesh resources")
			check(shared_materials[mi.name] == mat, "Instances duplicate material resources")
		else:
			shared_meshes[mi.name] = mi.mesh
			shared_materials[mi.name] = mat
		var arrays := mi.mesh.surface_get_arrays(0)
		total += arrays[Mesh.ARRAY_INDEX].size() / 3
		if mi.name == "JetwayStructure":
			check(mat != null and mat.albedo_texture != null and mat.normal_texture != null,
				"Structure PBR maps are missing")
		elif mi.name == "JetwayGlazing":
			check(mat != null and mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED,
				"Glazing became opaque")
	check(total > 0 and total <= 9000, "Triangle budget exceeded")
	triangles = total


func run() -> void:
	check(Chunk._prop_preload_paths().has(Chunk.AIRPORT_JETWAY_PATH), "Startup preload missing")
	check(Chunk.theme_prop_paths(4).has(Chunk.AIRPORT_JETWAY_PATH), "Airport preload missing")
	check(Chunk._prop_preload_paths().has(Chunk.AIRPORT_PLANE_PATH), "Aircraft startup preload missing")
	check(Chunk.theme_prop_paths(4).has(Chunk.AIRPORT_PLANE_PATH), "Aircraft airport preload missing")
	var ws := WorldGen.level_seed(4242, 4)
	var chunk := Chunk.new(ws, Vector2i.ZERO, 4)
	var placements := 0
	for ceiling in [3.2, 3.5, 3.8, 4.4, 6.2]:
		var context := ChunkBuildContext.new(ws, Vector2i.ZERO, 4, WorldGen.AIR_GATE,
			ceiling, Vector2i.ZERO, 1, true, 0, ChunkBuildSpec.new())
		var builder = Chunk.AIRPORT_LEVEL_BUILDER.new(context, chunk._scene_writer)
		for yaw in [0.0, PI / 2.0, PI, PI * 1.5]:
			var wall := Node3D.new()
			wall.position = Vector3(6, 0, 6)
			wall.rotation.y = yaw
			chunk.add_child(wall)
			var before := chunk.body.get_child_count()
			builder._air_jetway(wall)
			check(chunk.body.get_child_count() == before, "Sealed exterior prop adds collision")
			check(wall.get_child_count() == 1, "Expected one complete jetway assembly")
			var j := wall.get_child(0) as Node3D
			inspect_asset(j)
			var jb := bounds(j)
			check(jb.position.y >= 0.0 and jb.position.y < .06, "Jetway does not meet apron")
			check(jb.end.y <= ceiling - .13, "Jetway intersects the soffit")
			check(jb.position.z > 3.87 and jb.end.z < 4.74, "Jetway exceeds foreground depth")
			builder._air_docked_plane(wall)
			var plane := wall.get_child(1) as Node3D
			check(chunk.body.get_child_count() == before, "Aircraft adds exterior collision")
			inspect_plane(plane)
			var pb := bounds(plane)
			check(pb.position.y >= 0.0 and pb.position.y < .06, "Aircraft gear does not meet apron")
			check(pb.end.y <= ceiling - .13, "Aircraft fin intersects the soffit")
			check(pb.position.z - jb.end.z > .025, "Jetway intersects the aircraft")
			check(pb.end.z < 5.80, "Aircraft intersects night backdrop")
			var report := chunk.airport_apron_setpiece_audit()
			check(int(report.violations) == 0, "Exterior setpiece crosses a room boundary")
			wall.free()
			placements += 1
	chunk.free()
	# Also exercise actual generated gate placement and the existing apron audit.
	var generated := 0
	var generated_jetways := 0
	for x in range(-5, 6):
		for z in range(-5, 6):
			var cell := Vector2i(x, z)
			var c := Chunk.new(ws, cell, 4)
			var report := c.airport_apron_setpiece_audit()
			check(int(report.violations) == 0, "Generated apron overflows at %s" % cell)
			generated_jetways += c.find_children("AirportJetway", "Node3D", true, false).size()
			generated += 1
			c.free()
	check(generated_jetways > 0, "Generated gate placement was not exercised")
	shared_meshes.clear()
	shared_materials.clear()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("JETWAY_AUDIT: %d orientations/heights, %d generated chunks, %d jetways, %d jetway / %d aircraft triangles, failures=%d" % [
		placements, generated, generated_jetways, triangles, plane_triangles, failures])
	quit(1 if failures else 0)


func inspect_plane(plane: Node3D) -> void:
	check(plane.get_meta("authored_asset", "") == Chunk.AIRPORT_PLANE_PATH, "Aircraft asset missing")
	var meshes := plane.find_children("*", "MeshInstance3D", true, false)
	check(meshes.size() == 1, "Expected one baked aircraft mesh")
	for mi: MeshInstance3D in meshes:
		check(mi.mesh.get_surface_count() == 1, "Aircraft uses extra material surfaces")
		check(mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			"Compressed aircraft casts oversized scenery shadows")
		var mat := mi.mesh.surface_get_material(0) as StandardMaterial3D
		check(mat != null and mat.albedo_texture != null and mat.normal_texture != null,
			"Aircraft PBR atlas missing")
		if shared_meshes.has("aircraft"):
			check(shared_meshes.aircraft == mi.mesh and shared_materials.aircraft == mat,
				"Aircraft instances duplicate resources")
		else:
			shared_meshes.aircraft = mi.mesh
			shared_materials.aircraft = mat
		var arrays := mi.mesh.surface_get_arrays(0)
		plane_triangles = arrays[Mesh.ARRAY_INDEX].size() / 3
		check(plane_triangles > 0 and plane_triangles <= 12000, "Aircraft triangle budget exceeded")

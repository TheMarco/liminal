extends SceneTree
## Supplied casino bar: resource wiring, single-unit placement against a
## wall, and at most two bars per large room.
## godot --headless --path . --script tools/audit_casino_bar.gd

var failures := 0


func _init() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CASINO_BAR: " + message)


func local_transform(node: Node3D, ancestor: Node3D) -> Transform3D:
	var transform := Transform3D.IDENTITY
	var current: Node3D = node
	while current != ancestor:
		transform = current.transform * transform
		current = current.get_parent() as Node3D
	return transform


func visual_bounds(root: Node3D) -> AABB:
	var bounds := AABB()
	var found := false
	for mesh_instance: MeshInstance3D in root.find_children(
			"*", "MeshInstance3D", true, false):
		var actual := local_transform(mesh_instance, root) * mesh_instance.mesh.get_aabb()
		bounds = bounds.merge(actual) if found else actual
		found = true
	return bounds


func run() -> void:
	var path := Chunk.CASINO_BAR_PATH
	check(ResourceLoader.exists(path), "missing imported GLB")
	check(Chunk._prop_preload_paths().has(path), "missing startup preload")
	check(Chunk.theme_prop_paths(0).has(path), "missing Vegas preload")

	var packed := load(path) as PackedScene
	check(packed != null, "GLB failed to load")
	if packed == null:
		quit(1)
		return
	var source := packed.instantiate() as Node3D
	var source_bounds := visual_bounds(source)
	check(absf(source_bounds.position.x + 3.0) < 0.02
		and absf(source_bounds.end.x - 3.0) < 0.02,
		"bar is not 6m wide and centred: %s" % source_bounds)
	check(absf(source_bounds.position.y) < 0.02, "bar is not floor aligned: %s" % source_bounds)
	check(absf(source_bounds.end.y - 3.34) < 0.03,
		"arched sign height changed: %s" % source_bounds)
	source.free()

	var chunk := Chunk.new(WorldGen.level_seed(4242, 0), Vector2i.ZERO, 0)
	var first := chunk.get_child_count()
	var body_first := chunk.body.get_child_count()
	var at := Vector3(6, 0, 6)
	chunk._level_builder._casino_bar_at(at, 0.0)
	check(chunk.get_child_count() == first + 1, "bar must be one atomic furnishing")
	var pivot := chunk.get_child(first) as Node3D
	check(pivot.get_meta("attributed_furnishing", "") == "casino_bar",
		"bar pivot lost its fixture tag")
	var lights := 0
	var tagged := 0
	for node in pivot.find_children("*", "Light3D", true, false):
		lights += 1
		if str(node.get_meta("visible_source", "")) != "":
			tagged += 1
		check((node as Light3D).light_energy <= 3.0,
			"bar light left at blowout energy: %.1f" % (node as Light3D).light_energy)
	check(lights == 12, "bar accent light count changed: %d" % lights)
	check(tagged == lights, "untagged bar lights: %d of %d" % [lights - tagged, lights])
	check(chunk.body.get_child_count() == body_first + 1,
		"bar must own one whole-unit collider")
	if chunk.body.get_child_count() == body_first + 1:
		var collider := chunk.body.get_child(body_first) as CollisionShape3D
		var shape := collider.shape as BoxShape3D
		check(shape != null and shape.size.is_equal_approx(Vector3(6.0, 2.6, 3.4)),
			"bar collider changed: %s" % (shape.size if shape != null else "none"))
	chunk.free()

	var pop_path := Chunk.CASINO_POPUP_PATH
	check(ResourceLoader.exists(pop_path), "missing popup GLB")
	check(Chunk._prop_preload_paths().has(pop_path), "missing popup startup preload")
	check(Chunk.theme_prop_paths(0).has(pop_path), "missing popup Vegas preload")
	var pop_packed := load(pop_path) as PackedScene
	check(pop_packed != null, "popup GLB failed to load")
	if pop_packed == null:
		quit(1)
		return
	var pop_source := pop_packed.instantiate() as Node3D
	var pop_bounds := visual_bounds(pop_source)
	check(absf(pop_bounds.position.x + 1.63) < 0.02
		and absf(pop_bounds.end.x - 1.63) < 0.02,
		"popup is not 3.26m wide and centred: %s" % pop_bounds)
	check(absf(pop_bounds.position.y) < 0.02, "popup is not floor aligned: %s" % pop_bounds)
	check(absf(pop_bounds.end.y - 2.6) < 0.03,
		"popup height changed: %s" % pop_bounds)
	pop_source.free()

	var pop_chunk := Chunk.new(WorldGen.level_seed(4242, 0), Vector2i.ZERO, 0)
	var pop_first := pop_chunk.get_child_count()
	var pop_body_first := pop_chunk.body.get_child_count()
	pop_chunk._level_builder._casino_popup_bar_at(at, 0.0)
	check(pop_chunk.get_child_count() == pop_first + 1,
		"popup must be one atomic furnishing")
	var pop_pivot := pop_chunk.get_child(pop_first) as Node3D
	check(pop_pivot.get_meta("attributed_furnishing", "") == "casino_popup_bar",
		"popup pivot lost its fixture tag")
	var pop_lights := 0
	var pop_tagged := 0
	for node in pop_pivot.find_children("*", "Light3D", true, false):
		pop_lights += 1
		if str(node.get_meta("visible_source", "")) != "":
			pop_tagged += 1
		check((node as Light3D).light_energy <= 0.35,
			"popup light left at blowout energy: %.1f" % (node as Light3D).light_energy)
	for node in pop_pivot.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var mat := mesh_instance.mesh.surface_get_material(surface)
			if mat is StandardMaterial3D and (mat as StandardMaterial3D).emission_enabled:
				check((mat as StandardMaterial3D).emission_energy_multiplier <= 0.65,
					"popup emission uncapped on %s" % str(mesh_instance.name))
	check(pop_lights == 4, "popup accent light count changed: %d" % pop_lights)
	check(pop_tagged == pop_lights, "untagged popup lights: %d of %d" % [pop_lights - pop_tagged, pop_lights])
	check(pop_chunk.body.get_child_count() == pop_body_first + 1,
		"popup must own one whole-unit collider")
	if pop_chunk.body.get_child_count() == pop_body_first + 1:
		var pop_collider := pop_chunk.body.get_child(pop_body_first) as CollisionShape3D
		var pop_shape := pop_collider.shape as BoxShape3D
		check(pop_shape != null and pop_shape.size.is_equal_approx(Vector3(3.26, 2.0, 2.76)),
			"popup collider changed: %s" % (pop_shape.size if pop_shape != null else "none"))
	pop_chunk.free()

	var per_room := {}
	var styles := {}
	var total := 0
	var pop_room := {}
	var pop_styles := {}
	var pop_total := 0
	for base in [454890253, 777001]:
		var ws := WorldGen.level_seed(base, 0)
		for x in range(-8, 9):
			for z in range(-8, 9):
				var cell := Vector2i(x, z)
				var room := Chunk.new(ws, cell, 0)
				var n := int(room.authored_furnishing_counts().get("casino_bar", 0))
				if n > 0:
					var root: Vector2i = WorldGen.room_id(ws, cell)
					var key := "%d:%s" % [base, str(root)]
					per_room[key] = int(per_room.get(key, 0)) + n
					styles[key] = room.style
					total += n
				var m := int(room.authored_furnishing_counts().get("casino_popup_bar", 0))
				if m > 0:
					var proot: Vector2i = WorldGen.room_id(ws, cell)
					var pkey := "%d:%s" % [base, str(proot)]
					pop_room[pkey] = int(pop_room.get(pkey, 0)) + m
					pop_styles[pkey] = room.style
					pop_total += m
				room.free()
	for key in per_room:
		check(int(per_room[key]) <= 2,
			"room %s holds %d bars, at most two" % [key, int(per_room[key])])
		check(int(styles[key]) == WorldGen.STYLE_GRAND \
			or int(styles[key]) == WorldGen.STYLE_BALLROOM,
			"room %s style %d is not a large room" % [key, int(styles[key])])
	check(total > 0, "no bars placed on sampled floors")
	for key in pop_room:
		check(int(pop_room[key]) <= 1,
			"room %s holds %d popup bars, at most one" % [key, int(pop_room[key])])
		check(int(pop_styles[key]) == WorldGen.STYLE_SLOTS \
			or int(pop_styles[key]) == WorldGen.STYLE_LOUNGE \
			or int(pop_styles[key]) == WorldGen.STYLE_PILLARS \
			or int(pop_styles[key]) == WorldGen.STYLE_EMPTY,
			"room %s style %d is not a small room" % [key, int(pop_styles[key])])
	check(pop_total > 0, "no popup bars placed on sampled floors")
	print("CASINO_BAR: %s bars=%d rooms=%d popups=%d prooms=%d failures=%d" % [
		"PASS" if failures == 0 else "FAIL", total, per_room.size(),
		pop_total, pop_room.size(), failures])
	quit(1 if failures else 0)

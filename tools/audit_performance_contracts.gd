extends "res://tools/lib/audit_base.gd"
## Regression contracts for shadow proxies and staggered room retirement.
## These verify lifecycle/motion safety; GPU speed needs a native renderer.
const CAROUSEL = preload("res://scripts/airport_carousel_motion.gd")


func run() -> void:
	await _bloom_shadow_lifecycle()
	await _carousel_shadow_cadence()
	await _retirement_lifecycle()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	finish("performance lifecycle contracts")


func _mesh() -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.position = Vector3(0.3, 0.7, -0.2)
	return mesh


func _settle() -> void:
	await process_frame
	await process_frame


func _bloom_shadow_lifecycle() -> void:
	var host := Node3D.new()
	host.position = Vector3(12, 2, -5)
	host.rotation.y = 0.7
	var pulse := BloomPulse.new()
	pulse.position = Vector3(1, 0, 2)
	pulse.set_process(false)
	var source := _mesh()
	pulse.add_child(source)
	host.add_child(pulse)
	root.add_child(host)
	# Godot enables script processing when the node enters the tree.
	pulse.set_process(false)
	await _settle()
	var twins := host.find_children("StillShadow*", "MeshInstance3D", true, false)
	expect(twins.size() == 1, "Bloom did not create exactly one shadow twin")
	if twins.size() == 1:
		var twin := twins[0] as MeshInstance3D
		var pose := twin.global_transform
		expect(pose.is_equal_approx(source.global_transform), "Bloom shadow lost its transformed parent/mesh offset")
		expect(source.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			and twin.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			and twin.gi_mode == GeometryInstance3D.GI_MODE_DISABLED,
			"Bloom still renders moving shadows or a visible/GI duplicate")
		pulse._process(0.4)
		expect(not source.global_transform.is_equal_approx(pose), "Bloom fixture did not animate")
		expect(twin.global_transform.is_equal_approx(pose), "Bloom shadow followed the animated scale")
		pulse.free()
		await _settle()
		expect(not is_instance_valid(twin), "removed Bloom piece left an orphan shadow")
	host.free()


func _carousel_shadow_cadence() -> void:
	var motion := CAROUSEL.new()
	motion.position = Vector3(-6, 0, 11)
	motion.rotation.y = 0.4
	motion.set_process(false)
	var carrier := Node3D.new()
	carrier.set_meta("carousel_path_offset", 1.2)
	var source := _mesh()
	carrier.add_child(source)
	motion.add_child(carrier)
	motion.place_luggage()
	root.add_child(motion)
	motion.set_process(false)
	await _settle()
	expect(motion._shadow_twins.size() == 1, "carousel did not create exactly one luggage twin")
	if motion._shadow_twins.size() == 1:
		var twin_root := motion._shadow_twins[0][1] as Node3D
		var twin := twin_root.get_child(0) as MeshInstance3D
		var pose := twin.global_transform
		expect(pose.is_equal_approx(source.global_transform), "carousel shadow lost the luggage mesh offset")
		expect(source.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			and twin.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			and twin.gi_mode == GeometryInstance3D.GI_MODE_DISABLED,
			"carousel still renders continuous shadows or a visible/GI duplicate")
		motion._process(0.1)
		expect(not source.global_transform.is_equal_approx(pose), "carousel fixture did not animate")
		expect(twin.global_transform.is_equal_approx(pose), "carousel shadow moved before its update interval")
		motion._process(0.39)
		expect(twin.global_transform.is_equal_approx(pose), "carousel shadow updated before half a second")
		motion._process(0.02)
		expect(twin.global_transform.is_equal_approx(source.global_transform), "carousel shadow did not catch up after half a second")
		motion.free()
		expect(not is_instance_valid(twin_root), "carousel removal left orphan shadow geometry")
	else:
		motion.free()


func _retirement_lifecycle() -> void:
	var manager := ChunkManager.new()
	manager.set_process(false)
	root.add_child(manager)
	manager.set_process(false)
	var retired: Array[Chunk] = []
	for index in 3:
		var cell := Vector2i(index, 0)
		var chunk := Chunk.new(99173, cell, 2, null, true)
		manager.add_child(chunk)
		chunk.visible = false
		manager._retire(cell, chunk)
		retired.append(chunk)
		expect(chunk.process_mode == Node.PROCESS_MODE_DISABLED, "retired room kept processing")
	for index in 3:
		manager._free_one_retired()
		await _settle()
		for other in 3:
			expect(is_instance_valid(retired[other]) == (other > index), "room retirement did not free exactly one queued room")
	expect(manager._retired.is_empty(), "retirement queue retained deleted rooms")
	manager._free_one_retired()
	# Reinstall before the queue drains: the old collision must be gone when
	# observers receive chunk_built, rather than one deferred frame later.
	var cell := Vector2i(4, 0)
	var old := Chunk.new(99173, cell, 2, null, true)
	var old_body := StaticBody3D.new()
	old.add_child(old_body)
	manager.add_child(old)
	manager._retire(cell, old)
	var old_body_id := old_body.get_instance_id()
	var observed := {"built": false, "old_gone": false}
	manager.chunk_built.connect(func(_chunk: Chunk):
		observed.built = true
		observed.old_gone = not is_instance_id_valid(old_body_id))
	var replacement := Chunk.new(99173, cell, 2)
	manager._install_chunk(cell, replacement)
	expect(observed.built and observed.old_gone, "reinstall exposed both old and new room collision")
	expect(manager.chunks.get(cell) == replacement and manager._retired.is_empty(), "reinstall retained stale room state")
	manager.free()

extends "res://tools/lib/audit_base.gd"
## Focused runtime contract for ChargingStation.nearest_to().

func _station_at(parent: Node, position: Vector3, is_broken := false) -> ChargingStation:
	var station := ChargingStation.new()
	station.broken = is_broken
	parent.add_child(station)
	station.position = position
	return station


func _expect_nearest(observer: Node3D, expected: ChargingStation, label: String) -> void:
	expect(ChargingStation.nearest_to(observer) == expected, label)


func run() -> void:
	var mainroot := Node3D.new()
	get_root().add_child(mainroot)
	var observer := Node3D.new()
	var off_tree_observer := Node3D.new()
	mainroot.add_child(observer)
	observer.position = Vector3.ZERO
	expect(ChargingStation.nearest_to(off_tree_observer) == null, "off-tree observer returned a station")

	var near := _station_at(mainroot, Vector3(3, 0, 4))
	var far := _station_at(mainroot, Vector3(0, 0, 10))
	var broken := _station_at(mainroot, Vector3(1, 0, 0), true)
	await process_frame
	_expect_nearest(observer, near, "nearest healthy station was not selected")

	near.visible = false
	_expect_nearest(observer, far, "hidden station was not skipped")
	near.visible = true
	near.broken = true
	_expect_nearest(observer, far, "broken station was not skipped")
	near.broken = false
	_expect_nearest(observer, near, "restored station was not selected")
	near.queue_free()
	_expect_nearest(observer, far, "queued station was not skipped immediately")
	await process_frame
	_expect_nearest(observer, far, "queued station remained after a frame")

	mainroot.remove_child(far)
	_expect_nearest(observer, null, "detached station remained eligible")
	mainroot.add_child(far)
	_expect_nearest(observer, far, "re-added station was not eligible")

	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	get_root().add_child(viewport)
	var preview := _station_at(viewport, Vector3(0, 0, 1))
	await process_frame
	_expect_nearest(observer, far, "isolated viewport station leaked into main world")
	viewport.remove_child(preview)
	mainroot.add_child(preview)
	preview.global_position = Vector3(0, 0, 1)
	_expect_nearest(observer, preview, "reparented preview station was not selected")
	observer.position = Vector3(0, 0, 9)
	_expect_nearest(observer, far, "observer near far station selected wrong station")

	broken.queue_free()
	preview.queue_free()
	far.queue_free()
	viewport.queue_free()
	off_tree_observer.queue_free()
	observer.queue_free()
	mainroot.queue_free()
	await process_frame
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	finish("charging-station locator filtering, lifecycle, and world isolation")

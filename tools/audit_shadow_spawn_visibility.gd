extends "res://tools/lib/audit_base.gd"
## A sightline to a hound's head can clear an Office partition while its body
## stays hidden. A wall close to the target used to pass the spawn ray as well.


func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var actor := Player.new()
	world.add_child(actor)
	actor.set_physics_process(false)
	actor.set_process(false)
	actor.teleport(Vector3(2, 0, 6))
	var manager := ShadowFigures.new()
	manager.player = actor
	world.add_child(manager)
	manager.set_physics_process(false)
	var ground := Vector3(8, 0, 6)
	await physics_frame
	expect(manager._spawn_body_visible(ground), "open spawn sightline was rejected")
	var wall := _wall(world, Vector3(7.5, 1.4, 6), Vector3(0.2, 2.8, 4))
	await physics_frame
	expect(not manager._spawn_body_visible(ground),
		"wall beside spawn was treated as transparent")
	wall.queue_free()
	await physics_frame
	var partition := _wall(world, Vector3(5, 0.675, 6),
		Vector3(0.2, 1.35, 4))
	await physics_frame
	expect(manager._clear_line(actor.cam.global_position,
		ground + Vector3.UP * 1.4),
		"test partition unexpectedly blocked the old head sightline")
	expect(not manager._spawn_body_visible(ground),
		"hound body was accepted behind a low Office partition")
	partition.queue_free()
	await teardown_game(world)
	finish("shadow spawn visibility")


func _wall(parent: Node, at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.position = at
	body.add_child(collider)
	parent.add_child(body)
	return body

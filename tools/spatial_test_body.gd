class_name SpatialTestBody
extends CharacterBody3D
## Scripted actor stand-in for spatial safety tests. Same capsule dimensions
## as the player (which EnemyTraversal also uses), driven by planar velocity
## with real gravity and move_and_slide so guard/token behavior is proven
## against genuine physics, not scripted positions.

var planar_velocity := Vector3.ZERO
var gravity := 9.8


static func create() -> SpatialTestBody:
	var body := SpatialTestBody.new()
	body.floor_snap_length = 0.1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = Player.BODY_RADIUS
	capsule.height = Player.BODY_HEIGHT
	shape.shape = capsule
	shape.position = Vector3(0.0, Player.BODY_HEIGHT * 0.5, 0.0)
	body.add_child(shape)
	return body


func _physics_process(dt: float) -> void:
	velocity.x = planar_velocity.x
	velocity.z = planar_velocity.z
	velocity.y -= gravity * dt
	move_and_slide()

class_name Travelator
extends Area3D
## Moving-walkway drive: anything standing in the detection volume is carried
## along at belt speed. The player's own controller never knows — we shift
## position directly, so walking with or against the belt just adds up.

var dirv := Vector3.RIGHT
var speed := 0.75


func _physics_process(dt: float) -> void:
	for b in get_overlapping_bodies():
		if b is CharacterBody3D:
			b.global_position += dirv * speed * dt

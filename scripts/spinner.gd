class_name Spinner
extends Node3D
## Endless slow rotation about local Y — baggage carousels that never stop
## delivering nothing.

var speed := 0.22


func _process(dt: float) -> void:
	rotate_y(speed * dt)

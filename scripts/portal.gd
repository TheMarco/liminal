class_name Portal
extends Area3D
## A held-open tear between two liminal spaces. Stepping in hands the player
## to whichever world this one leads to; three sparks orbit while it waits.

var dest := 0
var cellv := Vector2i.ZERO
var sparks: Node3D


func _ready() -> void:
	body_entered.connect(_on_body)


func _on_body(b: Node3D) -> void:
	if b is CharacterBody3D:
		get_tree().call_group("portal_listener", "_on_portal", dest, cellv)


func _process(dt: float) -> void:
	if sparks != null:
		sparks.rotate_y(1.4 * dt)

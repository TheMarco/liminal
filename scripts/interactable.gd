class_name Interactable
extends Area3D
## Small ray-target used by terminals, doors and elevator panels. Interaction
## lives on a separate physics layer so it never changes player collision.

signal activated(actor: Node)

var prompt_text := "E — interact"
var enabled := true


func _init() -> void:
	collision_layer = 2
	collision_mask = 0
	monitoring = false
	monitorable = true


func add_box(size: Vector3, centre := Vector3.ZERO) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = centre
	add_child(cs)
	return cs


func interact(actor: Node) -> void:
	if enabled:
		activated.emit(actor)

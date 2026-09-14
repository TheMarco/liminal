class_name Interactable
extends Area3D
## Small ray-target used by terminals, doors and elevator panels. Interaction
## lives on a separate physics layer so it never changes player collision.

signal activated(actor: Node)
signal focus_entered
signal focus_exited

var prompt_text := "E — interact"
var enabled := true
## Optional spatial/access rule, checked both for focus and activation.
var access_check: Callable
## Evaluated only while the player is aiming here, so prerequisites can change
## without ticking every interactable or requiring the player to look away.
var prompt_provider: Callable


func get_prompt() -> String:
	return str(prompt_provider.call()) if prompt_provider.is_valid() else prompt_text


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


func can_interact(actor: Node) -> bool:
	return enabled and (not access_check.is_valid() or bool(access_check.call(actor)))


func interact(actor: Node) -> void:
	if can_interact(actor):
		activated.emit(actor)


func set_focused(value: bool) -> void:
	if value:
		focus_entered.emit()
	else:
		focus_exited.emit()

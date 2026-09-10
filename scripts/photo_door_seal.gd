class_name PhotoDoorSeal
extends Node3D
## A real aperture filled by an eye-only wall with its own physics body.
## Raising the camera removes only the visual seal. Photograph resolution
## removes collision too; no chunk swap, prop teleport or second room render.

var photo_id := ""
var obstruction := false
var obstruction_depth := 0.55
var theme := 7
var dir := 0
var width := 3.2
var height := 2.55
var centre := Vector3.ZERO # chunk-local threshold, at floor height
var opened := false
var preview_ready := false
var fill: Node3D
var barrier: StaticBody3D
var frame: Array[Node3D] = []


func set_preview_ready(value: bool) -> void:
	preview_ready = value
	if not opened and fill != null:
		_set_layers(fill, PhotoAnomaly.EYE_ONLY_LAYER if value else 1)
	for node in frame:
		node.visible = obstruction or opened or value
		_set_layers(node, 1 if opened or obstruction else PhotoAnomaly.PHOTO_LAYER)


func open() -> void:
	opened = true
	if barrier != null:
		# Remove the whole barrier's participation immediately. Deferred shape
		# deletion alone can leave one frame of invisible collision.
		barrier.collision_layer = 0
		barrier.collision_mask = 0
	if fill != null:
		fill.visible = false
	for node in frame:
		node.visible = true
		_set_layers(node, 1)


func _set_layers(node: Node, layers: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = layers
	if node is GeometryInstance3D and layers != 1:
		(node as GeometryInstance3D).cast_shadow = \
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_set_layers(child, layers)


func reveal_descriptor() -> Dictionary:
	if obstruction:
		return {"kind": "prop", "ghost": PhotoObstruction.ghost(fill), "nodes": frame}
	return {"kind": "door", "edge_center": to_global(centre),
		"opening_height": height,
		"edge": {"dir": dir, "after": {"kind": "open", "w": width}},
		"nodes": frame}

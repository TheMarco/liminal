class_name SeamActorProxy
extends Node3D
## Render-only mapped twin of one figure across a hidden seam (spec 6.4).
## One actor owns AI, collision, health, animation, and sound; the proxy
## samples the same skeleton pose and material state every frame. It runs
## no AI, holds no collision, advances no animation, and emits no audio.
## While the pair straddles the seam, complementary half-space clips join
## the original's approach half to the proxy's continuation half exactly
## at the plane, so no silhouette ever doubles and none ever gaps.

var figure: ShadowFigure
var link: TraversalLink
## True while the figure stands on side A (proxy renders in B space).
var from_a := true
var walker: ShadowWalkerVisual


func attach(p_figure: ShadowFigure, p_link: TraversalLink,
		p_from_a: bool) -> void:
	figure = p_figure
	link = p_link
	from_a = p_from_a
	walker = ShadowWalkerVisual.new()
	walker.proxy_mode = true
	walker.model_index = figure.walker_model_index
	add_child(walker)
	sync()


func mapping() -> Transform3D:
	return link.mapping() if from_a else link.inverse_mapping()


func alive() -> bool:
	return is_instance_valid(figure) and is_instance_valid(link) \
		and link.enabled and is_instance_valid(figure._walker) \
		and is_instance_valid(walker)


## Mirror the figure's current rendered state. Returns false when the
## pairing dissolved (freed figure, disabled link) and the proxy should go.
func sync() -> bool:
	if not alive():
		return false
	global_transform = mapping() * figure.global_transform
	walker.mirror_from(figure._walker)
	var frame := link.endpoint_b if from_a else link.endpoint_a
	walker.set_seam_clip(keep_negative(frame), true)
	return true


## Keep the approach half (local z >= 0): the original's side.
static func keep_positive(frame: Transform3D) -> Vector4:
	var n := frame.basis.z
	return Vector4(n.x, n.y, n.z, -frame.origin.dot(n))


## Keep the continuation half (local z <= 0): the proxy's side.
static func keep_negative(frame: Transform3D) -> Vector4:
	var n := -frame.basis.z
	return Vector4(n.x, n.y, n.z, -frame.origin.dot(n))

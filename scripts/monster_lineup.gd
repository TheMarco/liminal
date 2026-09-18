class_name MonsterLineup
extends Node3D
## Dev prototype: every roster monster in a circle, walking in place and
## facing the player spawn, so new models can be inspected live in any
## level. Spawned by main.gd for --lineup; not part of normal play.

var _visuals: Array[ShadowWalkerVisual] = []


## Centre of the circle in world space; each monster faces `watch`.
func configure(centre: Vector3, watch: Vector3) -> void:
	var count := ShadowWalkerVisual.model_count()
	var radius := 2.0 + float(count) * 0.32
	for i in count:
		var ang := TAU * (float(i) + 0.5) / float(count)
		var visual := ShadowWalkerVisual.new()
		visual.model_index = i
		visual.position = centre + Vector3(cos(ang) * radius, 0, sin(ang) * radius)
		add_child(visual)
		var to: Vector3 = watch - visual.position
		visual.rotation.y = atan2(to.x, to.z)
		visual.set_ground_speed(visual.walk_cycle_speed())
		visual.set_manifestation(1.0)
		_visuals.append(visual)


func _process(dt: float) -> void:
	for visual in _visuals:
		if is_instance_valid(visual):
			visual.animate(dt, true)

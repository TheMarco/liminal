class_name MonsterLineup
extends Node3D
## Dev prototype: every roster monster in a circle as passive ShadowFigures
## (suppressed: they burn and fade under the flashlight but never advance),
## walking in place and facing the player spawn, so new models can be
## inspected live in any level. Spawned by main.gd for --lineup; not part of
## normal play.

const BASE_RADIUS := 2.0
const SLOT_RADIUS := 0.32
const MIN_RADIUS := 1.0
const BODY_RADIUS := 0.55
const CLEAR_MASK := 1

var _figs: Array[ShadowFigure] = []
var _centre := Vector3.ZERO
var _player: Player


## Centre of the circle in world space; each monster faces the player at
## `watch`. Spawning waits for the first physics frame so the wall checks
## query a live space.
func configure(centre: Vector3, _watch: Vector3, player: Player) -> void:
	_centre = centre
	_player = player
	_spawn_deferred()


func _spawn_deferred() -> void:
	await get_tree().physics_frame
	var count := ShadowWalkerVisual.model_count()
	var full := BASE_RADIUS + float(count) * SLOT_RADIUS
	for i in count:
		var ang := TAU * (float(i) + 0.5) / float(count)
		var fig := ShadowFigure.new()
		fig.walker_model_index = i
		fig.suppressed = true
		fig.player = _player
		fig.position = _find_spot(ang, full)
		add_child(fig)
		var tag := Label3D.new()
		tag.text = "%d %s" % [i, (ShadowWalkerVisual.MODEL_PATHS[i] as String)
			.get_base_dir().get_file()]
		tag.position = Vector3(0.0, 2.4, 0.0)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.font_size = 48
		tag.pixel_size = 0.008
		tag.modulate = Color(1.0, 1.0, 1.0, 0.85)
		tag.outline_size = 8
		tag.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
		fig.add_child(tag)
		_figs.append(fig)


func _process(dt: float) -> void:
	for fig in _figs:
		if is_instance_valid(fig) and fig._walker != null:
			fig._walker.set_ground_speed(fig._walker.walk_cycle_speed())
			fig._walker.animate(dt, true)


## Walk the slot toward the centre until a capsule-free spot turns up, then
## nearby angles; the last resort overlaps near the centre rather than
## dropping a monster from the demo.
func _find_spot(ang: float, full: float) -> Vector3:
	var r := full
	while r >= MIN_RADIUS:
		var at := _centre + Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		if _spot_free(at):
			return at
		r -= 0.5
	for offset in [0.15, -0.15, 0.3, -0.3]:
		var sidestep := _centre + Vector3(
			cos(ang + offset) * 2.0, 0.0, sin(ang + offset) * 2.0)
		if _spot_free(sidestep):
			return sidestep
	return _centre + Vector3(cos(ang) * 0.8, 0.0, sin(ang) * 0.8)


func _spot_free(at: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	# Both probes must clear the floor slab: a sphere dipping below y=0
	# reports every slot as blocked and piles the ring onto the fallback.
	for probe in [[0.55, 0.5], [1.25, BODY_RADIUS]]:
		var query := PhysicsShapeQueryParameters3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = float(probe[1])
		query.shape = sphere
		query.transform = Transform3D(
			Basis(), at + Vector3(0.0, float(probe[0]), 0.0))
		query.collision_mask = CLEAR_MASK
		query.collide_with_areas = false
		query.collide_with_bodies = true
		if not space.intersect_shape(query, 1).is_empty():
			return false
	return true

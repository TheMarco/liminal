class_name SeamAudioBridge
extends RefCounted
## Positional audio across one hidden seam (spec 6.4). Tracked 3D emitters
## are repositioned to their apparent position along the shortest audible
## direct-or-link path; attenuation follows total path length through the
## engine's own distance falloff. Crossings duck briefly so the apparent
## jump never pops, without restarting any voice. Global ambience and
## music are untouched: these effects stay on one floor.
##
## Wiring contract: SpatialTraversal notifies an attached bridge itself
## (set_audio_bridge) with every batch that transfers; direct
## notify_crossed() calls stay allowed. The figure manager ticks update()
## once per physics frame while links are live.

## Duck depth and length: a 150ms dip that reads as motion, not a mute.
const DUCK_DB := 14.0
const DUCK_SECONDS := 0.15

var _tracks: Array = [] # {emitter, owner, offset, base_db}
var _duck := 0.0


func track(emitter: AudioStreamPlayer3D, owner: Node3D) -> void:
	sweep()
	for t in _tracks:
		if t["emitter"] == emitter:
			return
	_tracks.append({"emitter": emitter, "owner": owner,
		"offset": owner.global_transform.affine_inverse() \
			* emitter.global_position,
		"base_db": emitter.volume_db})


func untrack(emitter: AudioStreamPlayer3D) -> void:
	_tracks = _tracks.filter(func(t: Dictionary) -> bool:
		return t["emitter"] != emitter)


func sweep() -> void:
	_tracks = _tracks.filter(func(t: Dictionary) -> bool:
		return is_instance_valid(t["emitter"]) \
			and is_instance_valid(t["owner"]))


func track_count() -> int:
	sweep()
	return _tracks.size()


func duck_level() -> float:
	return _duck


func notify_crossed() -> void:
	_duck = 1.0


func update(listener: Vector3, links: Array,
		space: PhysicsDirectSpaceState3D, dt: float) -> void:
	_duck = maxf(0.0, _duck - dt / DUCK_SECONDS)
	sweep()
	for t in _tracks:
		var emitter: AudioStreamPlayer3D = t["emitter"]
		var owner: Node3D = t["owner"]
		var true_pos: Vector3 = owner.global_transform \
			* (t["offset"] as Vector3)
		var path := SpatialQuery.audio_path(space, listener, true_pos,
			links)
		emitter.global_position = path["position"]
		emitter.volume_db = float(t["base_db"]) - DUCK_DB * _duck

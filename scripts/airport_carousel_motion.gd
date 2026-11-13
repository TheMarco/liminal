extends Node3D
## Luggage follows the authored racetrack. The oval shell never rotates.
const HALF_STRAIGHT := 2.0
const OUTER_RADIUS := 1.5
const PATH_RADIUS := 0.684 * OUTER_RADIUS / 1.04
const BELT_HEIGHT := 0.665
const FIXTURE_LIFT := 0.511 * (BELT_HEIGHT / 0.415 - 1.0)
const END_SHIFT := HALF_STRAIGHT - 1.16
const PATH_LENGTH := 4.0 * HALF_STRAIGHT + TAU * PATH_RADIUS
const SHADOW_STEP_SECONDS := 0.5
var speed := 0.115
var travel := 0.0
var _shadow_twins: Array = []
var _shadow_clock := 0.0


static func path_pose(distance: float) -> Vector3:
	var d := fposmod(distance, PATH_LENGTH)
	var arc := PI * PATH_RADIUS
	if d < arc:
		var a := d / PATH_RADIUS
		return Vector3(PATH_RADIUS * cos(a), a, HALF_STRAIGHT + PATH_RADIUS * sin(a))
	d -= arc
	if d < 2.0 * HALF_STRAIGHT:
		return Vector3(-PATH_RADIUS, PI, HALF_STRAIGHT - d)
	d -= 2.0 * HALF_STRAIGHT
	if d < arc:
		var a := PI + d / PATH_RADIUS
		return Vector3(PATH_RADIUS * cos(a), a, -HALF_STRAIGHT + PATH_RADIUS * sin(a))
	d -= arc
	return Vector3(PATH_RADIUS, TAU, -HALF_STRAIGHT + d)


func place_luggage() -> void:
	for item in get_children():
		if item is Node3D and item.has_meta("carousel_path_offset"):
			var pose := path_pose(travel + float(item.get_meta("carousel_path_offset")))
			item.position = Vector3(pose.x, BELT_HEIGHT + 0.018, pose.z)
			item.rotation.y = -pose.y


func _ready() -> void:
	_split_shadows.call_deferred()


## Luggage creeps at about 11 cm/s. As ordinary shadow casters, each suitcase
## made every hall light in range re-render its whole shadow map on every
## frame (about 2,600 draw calls with one carousel hall in view). The visible
## cases still move every frame; shadow-only twins follow twice a second, a
## 6 cm step that the soft fixture shadows hide.
func _split_shadows() -> void:
	if not is_inside_tree():
		return
	for item in get_children():
		if not (item is Node3D and item.has_meta("carousel_path_offset")):
			continue
		var carrier := item as Node3D
		var twin_root := Node3D.new()
		twin_root.name = "LuggageShadow"
		add_child(twin_root)
		twin_root.transform = carrier.transform
		var to_carrier := carrier.global_transform.affine_inverse()
		for found in carrier.find_children("*", "MeshInstance3D", true, false):
			var source := found as MeshInstance3D
			if source.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
					or source.mesh == null:
				continue
			var twin := MeshInstance3D.new()
			twin.mesh = source.mesh
			twin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			twin.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
			twin_root.add_child(twin)
			twin.transform = to_carrier * source.global_transform
			source.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_shadow_twins.append([carrier, twin_root])


func _process(delta: float) -> void:
	if speed == 0.0:
		return
	travel = fposmod(travel + speed * delta, PATH_LENGTH)
	place_luggage()
	_shadow_clock += delta
	if _shadow_clock >= SHADOW_STEP_SECONDS:
		_shadow_clock = 0.0
		for pair in _shadow_twins:
			if is_instance_valid(pair[0]) and is_instance_valid(pair[1]):
				(pair[1] as Node3D).transform = (pair[0] as Node3D).transform

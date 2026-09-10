extends Node3D
## Luggage follows the authored racetrack. The oval shell never rotates.
const HALF_STRAIGHT := 2.0
const OUTER_RADIUS := 1.5
const PATH_RADIUS := 0.684 * OUTER_RADIUS / 1.04
const BELT_HEIGHT := 0.665
const FIXTURE_LIFT := 0.511 * (BELT_HEIGHT / 0.415 - 1.0)
const END_SHIFT := HALF_STRAIGHT - 1.16
const PATH_LENGTH := 4.0 * HALF_STRAIGHT + TAU * PATH_RADIUS
var speed := 0.115
var travel := 0.0


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


func _process(delta: float) -> void:
	if speed == 0.0:
		return
	travel = fposmod(travel + speed * delta, PATH_LENGTH)
	place_luggage()

extends SceneTree
## Small adversarial cases independent of procedural room seeds.

const Props = preload("res://scripts/nostalgia_props.gd")
var failures: Array[String] = []
var checks := 0

class TestRoom extends Node3D:
	var theme := 0
	var doors: Array[Rect2] = []
	func _doorway_clearance_rects() -> Array[Rect2]:
		return doors

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func wall(room: Node3D, at: Vector3, size: Vector3, tagged := true) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = size
	mesh.position = at
	mesh.set_meta("fixture_backing_wall", tagged)
	room.add_child(mesh)

func run() -> void:
	for bounds in [Props.BOUNDS[4], Props.BOUNDS[5], Chunk.CHANGE_MACHINE_BOUNDS]:
		for theme in [0, 1]:
			for dir in 4:
				var room := TestRoom.new()
				room.theme = theme
				var plane := 11.925 if dir in [0, 2] else .075
				wall(room, Vector3(plane, 1.5, 6) if dir < 2 else Vector3(6, 1.5, plane),
					Vector3(.15, 3, 8) if dir < 2 else Vector3(8, 3, .15))
				var site := Props.machine_site(room, bounds)
				check(not site.is_empty(), "no site theme=%d wall=%d" % [theme, dir])
				if not site.is_empty():
					var xf := Transform3D(Basis(Vector3.UP, site.yaw), site.at)
					var expected: Vector3 = [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK][dir]
					check(xf.basis.z.is_equal_approx(expected), "front faces wall theme=%d dir=%d" % [theme, dir])
					var rear := xf * Vector3(0, .8, bounds.position.z)
					var gap := .057 if theme == 0 else .002
					var wall_face := 11.85 if dir in [0, 2] else .15
					var actual_gap := absf((rear.x if dir < 2 else rear.z) - wall_face)
					check(absf(actual_gap - gap) < .0001, "rear pulled away from wall: %f" % actual_gap)
				room.free()
		var empty := TestRoom.new()
		check(Props.machine_site(empty, bounds).is_empty(), "accepted open room edge")
		wall(empty, Vector3(6, 1.5, .075), Vector3(8, 3, .15), false)
		check(Props.machine_site(empty, bounds).is_empty(), "mistook untagged furniture for wall")
		empty.free()
		var header := TestRoom.new()
		wall(header, Vector3(6, 2.75, .075), Vector3(8, .5, .15))
		check(Props.machine_site(header, bounds).is_empty(), "accepted door header as rear support")
		header.free()
		var painted := TestRoom.new()
		painted.theme = 1
		wall(painted, Vector3(6, 1.5, .075), Vector3(8, 3, .15))
		var paint := MeshInstance3D.new()
		paint.mesh = QuadMesh.new()
		paint.mesh.size = Vector2(8, 3)
		paint.position = Vector3(6, 1.5, .156)
		paint.set_meta("surface_wear_patch", true)
		painted.add_child(paint)
		check(not Props.machine_site(painted, bounds).is_empty(), "wall repaint treated as a solid obstacle")
		painted.free()
		var blocked := TestRoom.new()
		wall(blocked, Vector3(6, 1.5, .075), Vector3(8, 3, .15))
		blocked.doors = [Rect2(0, 0, 12, 3)]
		check(Props.machine_site(blocked, bounds).is_empty(), "blocked doorway approach was accepted")
		blocked.free()
		var narrow := TestRoom.new()
		wall(narrow, Vector3(6, 1.5, .075), Vector3(.4, 3, .15))
		check(Props.machine_site(narrow, bounds).is_empty(), "partial rear wall was accepted")
		narrow.free()
	print("MACHINE_WALL_PLACEMENT: %d checks, failures=%s" % [checks, failures])
	quit(0 if failures.is_empty() else 1)

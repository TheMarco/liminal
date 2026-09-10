extends SceneTree
## Structural audit for reference-authored nostalgia fixtures.

const SEEDS := [240721, 7, 918273]
const NostalgiaProps = preload("res://scripts/nostalgia_props.gd")
var failures := 0
var checks := 0
var seen := {}

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("NOSTALGIA_PROPS_AUDIT: " + message)

func meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for child in node.find_children("*", "MeshInstance3D", true, false):
		if child.mesh != null: out.append(child as MeshInstance3D)
	return out

func asset_audit() -> void:
	for id in NostalgiaProps.IDS.size():
		var path := NostalgiaProps.path_for(id)
		check(ResourceLoader.exists(path), "missing %s" % path)
		check(Chunk.theme_prop_paths(NostalgiaProps.THEMES[id]).has(path), "missing theme preload")
		check(Chunk._prop_preload_paths().has(path), "missing global preload")
		var scene := load(path) as PackedScene
		check(scene != null, "could not load %s" % path)
		if scene == null: continue
		var node := scene.instantiate()
		var second := scene.instantiate()
		check(meshes(node)[0].mesh == meshes(second)[0].mesh, "mesh resource not shared")
		second.free()
		var tris := 0
		var surfaces := 0
		for mi in meshes(node):
			var xf := Transform3D.IDENTITY
			var current: Node3D = mi
			while current != node:
				xf = current.transform * xf
				current = current.get_parent()
			var actual: AABB = xf * mi.mesh.get_aabb()
			check(NostalgiaProps.BOUNDS[id].grow(.002).encloses(actual), "visual bounds exceed placement envelope: " + NostalgiaProps.IDS[id])
			surfaces += mi.mesh.get_surface_count()
			for s in mi.mesh.get_surface_count():
				var a := mi.mesh.surface_get_arrays(s)
				if a.size() > Mesh.ARRAY_INDEX and a[Mesh.ARRAY_INDEX] != null:
					tris += a[Mesh.ARRAY_INDEX].size() / 3
		var limits := [4000,4500,4000,4500,4000,4000,4000]
		check(tris <= limits[id], "%s exceeds triangle budget: %d" % [NostalgiaProps.IDS[id], tris])
		check(surfaces <= 2, "%s has too many surfaces: %d" % [NostalgiaProps.IDS[id], surfaces])
		node.free()

func sweep() -> void:
	for seed in SEEDS:
		for theme in [0, 1, 6, 7]:
			var ws := WorldGen.level_seed(seed, theme)
			for x in range(-4, 5):
				for z in range(-4, 5):
					var chunk := Chunk.new(ws, Vector2i(x,z), theme)
					for node in chunk.find_children("*", "Node3D", true, false):
						if not node.has_meta("nostalgia_prop"): continue
						var id := int(node.get_meta("nostalgia_prop"))
						seen[id] = int(seen.get(id, 0)) + 1
						check(id >= 0 and id < NostalgiaProps.BOUNDS.size(), "invalid fixture id")
						if id == 6:
							check(is_equal_approx(node.position.y, .7875), "projector not on measured desk top")
							check(node.get_parent().get_meta("atomic_furnishing", "") == "school_teacher_station", "projector detached from teacher station")
							continue
						if id in [0, 2]:
							check(wall_behind(chunk, node, id), "fixture %s lacks full solid wall behind its back" % NostalgiaProps.IDS[id])
						var parent := node.get_parent()
						parent.remove_child(node)
						var group := int(node.get_meta("furnishing_group", -1))
						var disabled: Array[CollisionShape3D] = []
						for collider in chunk.body.find_children("*", "CollisionShape3D", true, false):
							if group >= 0 and int(collider.get_meta("furnishing_group", -2)) == group:
								(collider as CollisionShape3D).disabled = true
								disabled.append(collider as CollisionShape3D)
						var geometry := ChargingStationPlacement.new(chunk)
						var b: AABB = NostalgiaProps.BOUNDS[id].grow(.035)
						b.size.y -= .095
						b.position.y = .06
						var approach := AABB(Vector3(b.position.x,.06,b.end.z), Vector3(b.size.x,minf(1.8,b.size.y),.90))
						check(geometry.clear(node.position, node.rotation.y, false, chunk._doorway_clearance_rects(), b, approach), "fixture %s overlaps" % NostalgiaProps.IDS[id])
						for collider in disabled: collider.disabled = false
						parent.add_child(node)
					chunk.free()
	for id in NostalgiaProps.IDS.size():
		check(seen.has(id), "fixture %s never appeared in seeded sample" % NostalgiaProps.IDS[id])

func run() -> void:
	asset_audit()
	sweep()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("NOSTALGIA_PROPS_AUDIT: %s checks=%d failures=%d seen=%s" % ["PASS" if failures == 0 else "FAIL", checks, failures, seen])
	quit(1 if failures else 0)

# Probe behind both back corners at foot and head height. A facing reversal,
# missing wall, partial doorway or freestanding island fails independently
# of the placement candidate enumeration.
func wall_behind(chunk: Chunk, node: Node3D, id: int) -> bool:
	var bounds: AABB = NostalgiaProps.BOUNDS[id]
	var normal := node.basis.z.normalized()
	for x in [bounds.position.x + .01, bounds.end.x - .01]:
		for y in [.10, bounds.end.y - .02]:
			var back: Vector3 = node.transform * Vector3(x, y, bounds.position.z)
			var found := false
			for wall in NostalgiaProps.backing_walls(chunk):
				for step in range(1, 31):
					if wall.has_point(back - normal * float(step) * .01):
						found = true
						break
				if found: break
			if not found: return false
	return true

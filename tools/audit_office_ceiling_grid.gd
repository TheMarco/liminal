extends SceneTree
## Verifies that office ceiling fixtures land on the same world lattice as the
## tiled ceiling.  This is intentionally a small, deterministic integration
## audit rather than a visual test.

const PITCH := 0.75
const SEAM_OFFSET := 0.375
const EPS := 0.002
const S := WorldGen.CELL_SIZE

var failures := 0
var lights := 0
var vents := 0
var corridors := 0
var dead_rooms := 0
var dead_corridors := 0
var flicker_rooms := 0
var flicker_corridors := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("OFFICE_CEILING_GRID_AUDIT: " + message)

func _init() -> void:
	call_deferred("run")

func _fixture_nodes(chunk: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for node in chunk.find_children("*", "MeshInstance3D", true, false):
		if node.has_meta("office_ceiling_fixture"):
			result.append(node as MeshInstance3D)
	return result

func _local_box(mesh: MeshInstance3D, offset: Vector3) -> AABB:
	var box := mesh.get_aabb()
	var xf := mesh.transform
	var p := mesh.get_parent()
	while p != null:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	var out := AABB()
	var first := true
	for c in [box.position, box.position + Vector3(box.size.x, 0, 0),
		box.position + Vector3(0, box.size.y, 0), box.position + Vector3(0, 0, box.size.z),
		box.position + Vector3(box.size.x, box.size.y, 0),
		box.position + Vector3(box.size.x, 0, box.size.z),
		box.position + Vector3(0, box.size.y, box.size.z), box.end]:
		var q: Vector3 = xf * c + offset
		if first:
			out = AABB(q, Vector3.ZERO)
			first = false
		else:
			out = out.expand(q)
	return out

func _light_bounds(chunk: Node, lens: MeshInstance3D, cell: Vector2i) -> AABB:
	var bounds := _local_box(lens, Vector3(cell.x * S, 0, cell.y * S))
	var children := chunk.get_children()
	var i := children.find(lens)
	# _troffer emits lens followed immediately by its four trim meshes.
	for j in range(i + 1, mini(i + 5, children.size())):
		if children[j] is MeshInstance3D:
			bounds = bounds.merge(_local_box(children[j], Vector3(cell.x * S, 0, cell.y * S)))
	return bounds


func _fixture_bounds(chunk: Node, fixture: MeshInstance3D,
		cell: Vector2i, kind: String) -> AABB:
	var model_root := fixture.get_parent()
	while model_root != null and not model_root.has_meta("office_model"):
		model_root = model_root.get_parent()
	if model_root == null:
		return _light_bounds(chunk, fixture, cell) if kind == "light" \
			else _local_box(fixture, Vector3(cell.x * S, 0, cell.y * S))
	var offset := Vector3(cell.x * S, 0, cell.y * S)
	var result := AABB()
	var first := true
	for node in model_root.find_children("*", "MeshInstance3D", true, false):
		var part := _local_box(node as MeshInstance3D, offset)
		result = part if first else result.merge(part)
		first = false
	return result

func _on_lattice(v: float) -> bool:
	var n := (v - SEAM_OFFSET) / PITCH
	return absf(n - round(n)) <= EPS / PITCH

func _check_materials(chunk: Node) -> void:
	var ceiling := Mats.office_ceiling() as ShaderMaterial
	check(ceiling != null and ceiling.shader.resource_path ==
		"res://shaders/office_ceiling.gdshader", "office ceiling material changed")
	check(is_equal_approx(ceiling.get_shader_parameter("pitch"), PITCH),
		"office ceiling pitch changed")
	check(ceiling.get_shader_parameter("scenario_ceiling_tex") != null,
		"Scenario ceiling finish is missing")

func _scan(ws: int, cell: Vector2i) -> void:
	var chunk := Chunk.new(ws, cell, 1)
	var actual_style := WorldGen.cell_style(ws, cell, 1)
	var fixtures := _fixture_nodes(chunk)
	var seen_lights := 0
	var seen_vents := 0
	var dead_lights := 0
	var flicker_lenses := 0
	var flicker_material: Material
	var boxes: Array[AABB] = []
	for fixture in fixtures:
		var kind := String(fixture.get_meta("office_ceiling_fixture", ""))
		var panels: Vector2i = fixture.get_meta("office_ceiling_panels", Vector2i.ZERO)
		check(panels.x > 0 and panels.y > 0, "%s has invalid panel metadata" % fixture.name)
		var b := _fixture_bounds(chunk, fixture, cell, kind)
		var want := Vector2(panels) * PITCH
		check(absf(b.size.x - want.x) < 0.012 and absf(b.size.z - want.y) < 0.012,
			"%s size %s does not match panels %s" % [fixture.name, b.size, panels])
		for edge in [b.position.x, b.end.x, b.position.z, b.end.z]:
			check(_on_lattice(edge), "%s edge %.4f misses ceiling lattice" % [fixture.name, edge])
		check(b.position.x >= cell.x * S - EPS and b.end.x <= (cell.x + 1) * S + EPS and
			b.position.z >= cell.y * S - EPS and b.end.z <= (cell.y + 1) * S + EPS,
			"%s crosses chunk boundary" % fixture.name)
		for old in boxes:
			check(not old.intersects(b.grow(-0.01)), "%s overlaps another ceiling fixture" % fixture.name)
		boxes.append(b)
		if actual_style == WorldGen.OFFICE_CORRIDOR:
			var along_x := WorldGen.corridor(ws, cell) != 2
			var perp := (b.get_center().z if along_x else b.get_center().x) - (cell.y * S + S * 0.5 if along_x else cell.x * S + S * 0.5)
			var half_perp := b.size.z * 0.5 if along_x else b.size.x * 0.5
			check(absf(perp) + half_perp <= 1.3 + EPS, "%s leaves corridor lane" % fixture.name)
		if kind == "light":
			seen_lights += 1
			var housing := fixture.get_parent().find_child(
				"Troffer metal housing", true, false) as MeshInstance3D
			check(housing != null, "imported light housing is missing")
			if housing != null:
				var offset := Vector3(cell.x * S, 0, cell.y * S)
				var lens_box := _local_box(fixture, offset)
				var housing_box := _local_box(housing, offset)
				check(lens_box.position.y < housing_box.position.y - 0.002,
					"light diffuser faces the ceiling cavity instead of the room")
			if fixture.material_override == Mats.panel_dead():
				dead_lights += 1
			if fixture.has_meta("office_ceiling_flicker"):
				flicker_lenses += 1
				flicker_material = fixture.material_override
		else:
			seen_vents += 1
		check(kind == "light" or kind == "vent", "unknown fixture kind %s" % kind)
	var expected := 4 if actual_style == WorldGen.OFFICE_CORRIDOR else 8
	check(seen_lights == expected and seen_vents == 2,
		"style %d has %d lights/%d vents, expected %d/2" % [actual_style, seen_lights, seen_vents, expected])
	var expected_dead := WorldGen.r01(ws, cell.x, cell.y, 8) < (0.025 if actual_style == WorldGen.OFFICE_CORRIDOR else 0.02)
	if actual_style != WorldGen.OFFICE_CORRIDOR:
		expected_dead = cell != Vector2i.ZERO and expected_dead
	var expected_flicker := not expected_dead \
		and WorldGen.r01(ws, cell.x, cell.y, 9) \
		< (0.07 if actual_style == WorldGen.OFFICE_CORRIDOR else 0.05)
	if actual_style != WorldGen.OFFICE_CORRIDOR:
		expected_flicker = cell != Vector2i.ZERO and expected_flicker
	check(dead_lights == (1 if expected_dead else 0),
		"cell %s dead lenses=%d expected %d" % [cell, dead_lights, 1 if expected_dead else 0])
	check(flicker_lenses == (1 if expected_flicker else 0),
		"cell %s flicker lenses=%d expected %d" % [
			cell, flicker_lenses, 1 if expected_flicker else 0])
	if expected_dead:
		if actual_style == WorldGen.OFFICE_CORRIDOR:
			dead_corridors += 1
		else:
			dead_rooms += 1
	if expected_flicker:
		if actual_style == WorldGen.OFFICE_CORRIDOR:
			flicker_corridors += 1
		else:
			flicker_rooms += 1
	var room_lights: Array[Node] = []
	for candidate in chunk.find_children("*", "OmniLight3D", true, false):
		if str(candidate.get_meta("visible_source", "")) in [
				"office_troffer_grid", "office_flickering_troffer"]:
			room_lights.append(candidate)
	check(room_lights.size() == (2 if expected_flicker else 1),
		"cell %s has %d actual lights, expected %d" % [
			cell, room_lights.size(), 2 if expected_flicker else 1])
	var flicker_nodes := 0
	for room_light in room_lights:
		if room_light is FlickerLight:
			flicker_nodes += 1
			check((room_light as FlickerLight).mats == [flicker_material],
				"cell %s flicker drives more than its selected lens" % cell)
	check(flicker_nodes == (1 if expected_flicker else 0),
		"cell %s flicker nodes=%d expected %d" % [
			cell, flicker_nodes, 1 if expected_flicker else 0])
	lights += seen_lights
	vents += seen_vents
	if actual_style == WorldGen.OFFICE_CORRIDOR:
		corridors += 1
	chunk.free()

func run() -> void:
	_check_materials(null)
	# Cover the full 7x7 cell sample for each requested deterministic seed.
	var seeds := [1, 240721, 9137]
	for seed in seeds:
		var ws := WorldGen.level_seed(seed, 1)
		for x in range(-3, 4):
			for z in range(-3, 4):
				_scan(ws, Vector2i(x, z))
	check(corridors > 0, "sample did not cover an office corridor")
	check(dead_rooms > 0, "sample did not cover a dead office room")
	check(dead_corridors > 0, "sample did not cover a dead office corridor")
	check(flicker_rooms > 0, "sample did not cover a flickering office room")
	check(flicker_corridors > 0,
		"sample did not cover a flickering office corridor")
	print("OFFICE_CEILING_GRID_AUDIT: cells=147 lights=%d vents=%d corridors=%d failures=%d" % [lights, vents, corridors, failures])
	quit(1 if failures else 0)

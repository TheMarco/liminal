class_name Cabinet
## Sculpted slot machine cabinet shell, built once with SurfaceTool and shared
## by every machine. A 2D side profile — kick, belly, protruding button deck,
## reclined screen face, curved crown — extruded across the cabinet width,
## with triangulated flat side panels.

const HW := 0.29

static var _mesh: ArrayMesh


## Side profile in (z, y): +z is the player-facing front. Counter-clockwise.
static func profile() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.20, 0.00),   # front of kick
		Vector2(0.20, 0.06),
		Vector2(0.25, 0.10),   # kick flares out
		Vector2(0.27, 0.72),   # belly panel
		Vector2(0.36, 0.80),   # button deck juts out
		Vector2(0.33, 0.92),   # deck top tucks back
		Vector2(0.27, 1.48),   # reclined reel glass
		Vector2(0.23, 1.90),   # pay-table face
		Vector2(0.16, 2.02),   # crown curve
		Vector2(0.04, 2.10),
		Vector2(-0.25, 2.10),  # flat top to the back
		Vector2(-0.25, 0.00),  # flat back
	])


static func mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var pts := profile()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var np := pts.size()
	# extruded outer shell, one quad per profile segment
	for i in np:
		var a := pts[i]
		var b := pts[(i + 1) % np]
		var v0 := Vector3(-HW, a.y, a.x)
		var v1 := Vector3(HW, a.y, a.x)
		var v2 := Vector3(HW, b.y, b.x)
		var v3 := Vector3(-HW, b.y, b.x)
		st.add_vertex(v0)
		st.add_vertex(v1)
		st.add_vertex(v2)
		st.add_vertex(v0)
		st.add_vertex(v2)
		st.add_vertex(v3)
	# flat side panels
	var idx := Geometry2D.triangulate_polygon(pts)
	for t in range(0, idx.size(), 3):
		var p0 := pts[idx[t]]
		var p1 := pts[idx[t + 1]]
		var p2 := pts[idx[t + 2]]
		st.add_vertex(Vector3(HW, p0.y, p0.x))
		st.add_vertex(Vector3(HW, p1.y, p1.x))
		st.add_vertex(Vector3(HW, p2.y, p2.x))
		st.add_vertex(Vector3(-HW, p2.y, p2.x))
		st.add_vertex(Vector3(-HW, p1.y, p1.x))
		st.add_vertex(Vector3(-HW, p0.y, p0.x))
	st.generate_normals()
	_mesh = st.commit()
	return _mesh

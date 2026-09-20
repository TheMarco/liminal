extends SceneTree
## Package 3.1 gate: hidden-traversal pure math. Endpoint mapping M, double-H
## detection, graph adapter regions/neighbors, Dijkstra across links, and the
## continuous link-distance metric. No scene boot; topology-backed checks use
## a planned floor directly.
##
## Run:
##   godot --headless --path . --script tools/audit_traversal_math.gd

const EPS_SIDE := 0.05
const EPS_EQ := 0.0001

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition and failures.size() < 80:
		failures.append(message)


func _endpoints(origin_a: Vector3, yaw_a: float, origin_b: Vector3,
		yaw_b: float) -> Array:
	var a := Transform3D(Basis(Vector3.UP, yaw_a), origin_a)
	var b := Transform3D(Basis(Vector3.UP, yaw_b), origin_b)
	return [a, b]


func _run() -> void:
	_audit_endpoint_validation()
	_audit_mapping_identities()
	_audit_double_h_detected()
	_audit_graph_adapter()
	_audit_dijkstra()
	_audit_link_distance()
	for failure in failures:
		print("  FAIL " + failure)
	if failures.is_empty():
		print("  PASS - traversal math holds")
		quit()
	else:
		quit(1)


func _audit_endpoint_validation() -> void:
	var flat := Transform3D(Basis(Vector3.UP, 0.7), Vector3(3, 0, 9))
	_expect(TraversalLink.frames_valid(flat, flat),
		"upright yaw-only frames rejected")
	var pitched := Transform3D(Basis(Vector3.RIGHT, 0.2), Vector3.ZERO)
	_expect(not TraversalLink.frames_valid(pitched, flat),
		"pitched frame accepted")
	var scaled := Transform3D(Basis(Vector3.UP, 0.0).scaled(Vector3(2, 1, 1)),
		Vector3.ZERO)
	_expect(not TraversalLink.frames_valid(scaled, flat),
		"scaled frame accepted")


func _audit_mapping_identities() -> void:
	var yaws := [0.0, PI * 0.25, PI * 0.5, PI * 0.75, PI, PI * 1.25,
		PI * 1.5, PI * 1.75]
	var idx := 0
	for yaw_a in yaws:
		for yaw_b in yaws:
			var ends := _endpoints(
				Vector3(12.0 + idx, 0.0, -30.0 - idx * 2.0), yaw_a,
				Vector3(-400.0 - idx * 3.0, 0.0, 77.0 + idx), yaw_b)
			idx += 1
			var link := TraversalLink.new("t:%d" % idx, "ra", "rb",
				ends[0], ends[1], 3.2)
			_expect(link.verify_mapping(),
				"mapping identity failed yaw_a=%f yaw_b=%f" % [yaw_a, yaw_b])
			# Round trip holds for points, orientation, and velocity.
			var p := Vector3(1.25, 0.5, -2.75)
			var back: Vector3 = link.inverse_mapping() * (link.mapping() * p)
			_expect(back.distance_to(p) < EPS_EQ,
				"point round trip drifted yaw_a=%f yaw_b=%f" % [yaw_a, yaw_b])
			var v := Vector3(0.3, 0.0, -4.5)
			var vb: Vector3 = link.inverse_mapping().basis \
				* (link.mapping().basis * v)
			_expect(vb.distance_to(v) < EPS_EQ,
				"velocity round trip drifted yaw_a=%f yaw_b=%f"
				% [yaw_a, yaw_b])
			var q := Vector3(-0.75, 1.1, 0.4)
			var via_m: Vector3 = link.mapping() * (ends[0] * q)
			var via_h: Vector3 = ends[1] \
				* (TraversalLink.HALF_TURN * q)
			_expect(via_m.distance_to(via_h) < EPS_EQ,
				"geometry identity M*(A*q)==B*H*q failed")


func _audit_double_h_detected() -> void:
	# A double application of the half turn must fail the signed-side and
	# direction assertions even though a pure round trip still cancels out.
	var ends := _endpoints(Vector3.ZERO, 0.3, Vector3(90, 0, -40), 1.9)
	var bad := TraversalLink.new("bad", "ra", "rb", ends[0], ends[1], 3.2,
		true)
	_expect(not bad.verify_mapping(),
		"double-H mapping passed the signed assertions")
	var p := Vector3(0.5, 0.0, -1.5)
	var back: Vector3 = bad.inverse_mapping() * (bad.mapping() * p)
	_expect(back.distance_to(p) < EPS_EQ,
		"double-H round trip unexpectedly broken (test setup wrong)")


func _audit_graph_adapter() -> void:
	var graph := TraversalGraph.new()
	var ends := _endpoints(Vector3.ZERO, 0.0, Vector3(120, 0, 60), PI * 0.5)
	var link := TraversalLink.new("L1", "site:s/approach_a",
		"site:s/approach_b", ends[0], ends[1], 3.2)
	graph.register_link(link, AABB(Vector3(-6, 0, -6), Vector3(12, 3, 12)),
		AABB(Vector3(114, 0, 54), Vector3(12, 3, 12)))
	_expect(graph.locate(Vector3(1, 1, 1)) == "site:s/approach_a",
		"site volume did not win over grid")
	_expect(graph.locate(Vector3(125, 1, 55)) == "site:s/approach_b",
		"destination volume missed")
	_expect(graph.locate(Vector3(500, 1, 500)) == "grid:41:41",
		"grid fallback wrong")
	var steps := graph.neighbors("site:s/approach_a")
	_expect(steps.size() == 1 and steps[0]["link"] == "L1"
		and steps[0].has("waypoints") and steps[0].has("kind")
		and steps[0].has("clearance") and steps[0].has("cost"),
		"link neighbor step malformed")
	# Ordinary grid cardinals come from real topology.
	var ws := WorldGen.level_seed(11, 1)
	var route := DescentRoute.build(ws, 1, 2)
	var topology := DescentTopology.new(ws, 1)
	route.set_topology(topology)
	topology.plan_floor(route)
	var wired := TraversalGraph.new()
	wired.use_topology(topology)
	var at := Vector2i(20, 20)
	for step in wired.neighbors("grid:20:20"):
		var edge: String = step["edge"]
		var dir := -1
		for d in 4:
			if DescentTopology.edge_key(at, d) == edge:
				dir = d
		_expect(dir >= 0 and not topology.is_wall(at, dir),
			"grid neighbor not a real open edge")


func _audit_dijkstra() -> void:
	var graph := TraversalGraph.new()
	var ends := _endpoints(Vector3.ZERO, 0.0, Vector3(1000, 0, 0), 0.0)
	graph.register_link(TraversalLink.new("L", "r_a", "r_b", ends[0],
		ends[1], 3.2), AABB(Vector3(-6, 0, -6), Vector3(12, 3, 12)),
		AABB(Vector3(994, 0, -6), Vector3(12, 3, 12)))
	var path := graph.route("r_a", "r_b", 64)
	_expect(path == ["r_a", "r_b"], "link route wrong: %s" % [path])
	# Partial routes target a valid frontier step, never raw far coordinates.
	var far := graph.route("r_b", "grid:999:999", 2)
	_expect(far.size() > 0 and far[0] == "r_b"
		and far[far.size() - 1] != "grid:999:999",
		"partial route overreached the budget")


func _audit_link_distance() -> void:
	var ends := _endpoints(Vector3.ZERO, 0.0, Vector3(100, 0, 0), 0.0)
	var link := TraversalLink.new("L", "ra", "rb", ends[0], ends[1], 4.0)
	# Walk straight through; the readout must not jump at the plane.
	var prev := -1.0
	var worst := 0.0
	var z := -8.0
	while z <= 8.0:
		var o := Vector3(-6.0, 1.4, z)
		var t := Vector3(106.0, 1.4, -z)
		var d: float = TraversalGraph.link_distance(o, t, link)
		if prev >= 0.0:
			worst = maxf(worst, absf(d - prev))
		prev = d
		z += 0.25
	_expect(worst < 0.6, "link distance jumps at the seam: %f" % worst)
	# The minimum is over the aperture, not snapped to its centre.
	var o2 := Vector3(-6, 1.4, -1.9)
	var t2 := Vector3(106, 1.4, -1.9)
	var off := TraversalGraph.link_distance(o2, t2, link)
	var snapped: float = o2.distance_to(Vector3(0, 1.4, 0)) \
		+ Vector3(100, 1.4, 0).distance_to(t2)
	_expect(off < snapped - 0.1,
		"aperture minimization did not beat centre snapping")
	var rev: float = TraversalGraph.link_distance(Vector3(106, 1.4, 0),
		Vector3(-6, 1.4, 0), link)
	var fwd: float = TraversalGraph.link_distance(Vector3(-6, 1.4, 0),
		Vector3(106, 1.4, 0), link)
	_expect(absf(rev - fwd) < EPS_EQ, "link distance asymmetric")

class_name TraversalGraph
extends RefCounted
## Narrow adapter over grid topology plus nonlocal traversal links (spec 6.2).
##
## Ordinary regions are `grid:x:y` with current cardinal edges. A reserved
## site replaces its footprint navigation with named regions such as
## `site:id/approach_a`. `locate()` tests authoritative site volumes first,
## then falls back to the ordinary grid. `world_cell()` keeps the seeded
## WorldGen coordinate system untouched. Routing is Dijkstra (zero
## heuristic) while nonlocal links exist, with a measured expansion budget;
## partial routes end at a valid expanded step, never at raw far coordinates.

const LINK_COST := 1.0
const GRID_COST := 1.0
const EYE_HEIGHT := 1.4
const DISTANCE_ITERATIONS := 16

var _links := {}
var _volumes: Array = [] # {region, aabb, link}
var _topology: DescentTopology = null
var _ports: Array[Dictionary] = []
var _owned_cells := {}
## Connectivity version: bumped by membership and enable changes.
## Consumers poll it before deciding movement (no signal reentrancy).
var topology_revision := 0
## Approach-transform version. Static links never bump it; the moving
## frames of later packages declare themselves here.
var geometry_revision := 0


func register_link(link: TraversalLink, volume_a: AABB,
		volume_b: AABB) -> void:
	_links[link.id] = link
	_volumes.append({"region": link.region_a, "aabb": volume_a,
		"link": link.id})
	_volumes.append({"region": link.region_b, "aabb": volume_b,
		"link": link.id})
	topology_revision += 1


## Enable or disable a link with a connectivity bump, so polling
## consumers invalidate before their next movement decision.
func set_link_enabled(id: String, enabled: bool) -> void:
	var link: TraversalLink = _links.get(id, null)
	if link == null or link.enabled == enabled:
		return
	link.enabled = enabled
	topology_revision += 1


func use_topology(topology: DescentTopology) -> void:
	_topology = topology


## Explicit physical openings only: never infer an opening from an AABB.
## inside_path runs from the seam approach through the bends to the port.
## Ports remain ordinary walkable exits when the nonlocal edge is disabled.
func register_port(region: String, outside: Vector3, inside_path: Array[Vector3]) -> void:
	assert(not inside_path.is_empty())
	var grid := grid_region(world_cell(outside))
	var inward: Array[Vector3] = [inside_path.back()]
	var outward := inside_path.duplicate()
	outward.append(outside)
	_ports.append({"from": grid, "destination": region, "kind": "port",
		"waypoints": inward, "clearance": HiddenLinkSite.PASSAGE_W,
		"cost": outside.distance_to(inside_path.back())})
	_ports.append({"from": region, "destination": grid, "kind": "port",
		"waypoints": outward, "clearance": HiddenLinkSite.PASSAGE_W,
		"cost": outside.distance_to(inside_path.back())})
	for l in _links.values():
		if region == l.region_a or region == l.region_b:
			var approach := inside_path.duplicate()
			approach.reverse()
			var frame: Transform3D = l.endpoint_a if region == l.region_a else l.endpoint_b
			approach.append(frame * Vector3(0, 0, -0.25))
			l.waypoints[region] = approach
	topology_revision += 1


func reserve_cells(cells: Array[Vector2i]) -> void:
	for cell in cells:
		_owned_cells[cell] = true
	topology_revision += 1


func site_at(position: Vector3) -> String:
	for entry in _volumes:
		if _inside_region(entry, position):
			return str(entry["link"])
	return ""


func link(id: String) -> TraversalLink:
	return _links.get(id, null)


## Enabled links for perception queries. Disabled links are invisible to
## sight, contact, peers, and audio, exactly as to crossing.
func links() -> Array[TraversalLink]:
	var out: Array[TraversalLink] = []
	for id in _links:
		var l: TraversalLink = _links[id]
		if l.enabled:
			out.append(l)
	return out


static func world_cell(position: Vector3) -> Vector2i:
	var c := float(WorldGen.CELL_SIZE)
	return Vector2i(floori(position.x / c), floori(position.z / c))


static func grid_region(cell: Vector2i) -> String:
	return "grid:%d:%d" % [cell.x, cell.y]


func locate(position: Vector3) -> String:
	for entry in _volumes:
		if _inside_region(entry, position):
			return str(entry["region"])
	return grid_region(world_cell(position))


func _inside_region(entry: Dictionary, position: Vector3) -> bool:
	if not (entry["aabb"] as AABB).has_point(position):
		return false
	var l: TraversalLink = _links[entry["link"]]
	var frame := l.endpoint_a if entry["region"] == l.region_a else l.endpoint_b
	return (frame.affine_inverse() * position).z >= -HiddenLinkSite.HYSTERESIS


## Explicit TraversalStep records: destination, link or ordinary edge ID,
## approach/exit waypoints, kind, clearance, and nonnegative cost.
func neighbors(region: String) -> Array:
	var out: Array = []
	for port in _ports:
		if port["from"] == region:
			out.append(port)
	for entry in _volumes:
		if str(entry["region"]) != region:
			continue
		var link: TraversalLink = _links.get(str(entry["link"]), null)
		if link == null or not link.enabled:
			continue
		var dest := link.other_region(region)
		if dest.is_empty():
			continue
		out.append({
			"destination": dest,
			"link": link.id,
			"waypoints": _link_waypoints(link, region),
			"kind": "link",
			"clearance": link.clearance,
			"cost": LINK_COST,
		})
	if region.begins_with("grid:") and _topology != null:
		var parts := region.split(":")
		if parts.size() == 3 and parts[1].is_valid_int() \
				and parts[2].is_valid_int():
			var at := Vector2i(int(parts[1]), int(parts[2]))
			if _owned_cells.has(at):
				return out
			for dir in 4:
				if _topology.is_wall(at, dir):
					continue
				var to: Vector2i = at + WorldGen.DIRV[dir]
				if _owned_cells.has(to):
					continue
				var centre := Vector3(at.x + 0.5, 0, at.y + 0.5) * WorldGen.CELL_SIZE
				var direction := Vector3(WorldGen.DIRV[dir].x, 0, WorldGen.DIRV[dir].y)
				out.append({
					"destination": grid_region(to),
					"edge": DescentTopology.edge_key(at, dir),
					"waypoints": [centre + direction * (WorldGen.CELL_SIZE * 0.5 + 0.5)],
					"kind": "edge",
					"clearance": 12.0,
					"cost": GRID_COST,
				})
	return out


func _link_waypoints(link: TraversalLink, from_region: String) -> Array:
	var fwd := from_region == link.region_a
	var src := link.endpoint_a if fwd else link.endpoint_b
	var dst := link.endpoint_b if fwd else link.endpoint_a
	return [src.origin + src.basis.z * 1.0, dst.origin + dst.basis.z * 1.0]


## Dijkstra route with an expansion budget. Unreached targets return the
## path to the deepest expanded step, a valid frontier region.
func route(from_region: String, to_region: String,
		budget: int) -> Array[String]:
	var dist := {from_region: 0.0}
	var prev := {}
	var open: Array = [from_region]
	var expanded := 0
	var deepest := from_region
	while not open.is_empty() and expanded < budget:
		open.sort_custom(func(a: String, b: String) -> bool:
			return float(dist[a]) < float(dist[b]))
		var current: String = open.pop_front()
		expanded += 1
		deepest = current
		if current == to_region:
			break
		for step in neighbors(current):
			var dest := str(step["destination"])
			var cost := float(dist[current]) + float(step["cost"])
			if cost < float(dist.get(dest, INF)):
				dist[dest] = cost
				prev[dest] = current
				if not open.has(dest):
					open.append(dest)
	var end := to_region if dist.has(to_region) else deepest
	var path: Array[String] = [end]
	while prev.has(path[0]):
		path.push_front(str(prev[path[0]]))
	return path


## Continuous one-link distance between an observer and a target on opposite
## sides: the minimum over the aperture width of the summed straight
## segments through the mapped crossing point (spec 6.2). Both directions
## participate; only the final displayed number is quantized by callers.
static func link_distance(o: Vector3, t: Vector3,
		link: TraversalLink) -> float:
	var m := link.mapping()
	var cross_y := (o.y + t.y) * 0.5
	var half := link.aperture_width * 0.5
	# Both crossing parametrizations keep observer/target roles fixed; the
	# minimum covers observers starting on either side of the link.
	var best := _minimize_leg(o, t, link.endpoint_a, half, cross_y, m)
	var back := _minimize_leg(o, t, link.endpoint_b, half, cross_y,
		m.affine_inverse())
	return minf(best, back)


static func _minimize_leg(o: Vector3, t: Vector3, frame: Transform3D,
		half: float, cross_y: float, m: Transform3D) -> float:
	var lo := -half
	var hi := half
	for i in DISTANCE_ITERATIONS:
		var m1 := lo + (hi - lo) / 3.0
		var m2 := hi - (hi - lo) / 3.0
		if _leg_length(o, t, frame, m1, cross_y, m) \
				< _leg_length(o, t, frame, m2, cross_y, m):
			hi = m2
		else:
			lo = m1
	var mid := _leg_length(o, t, frame, (lo + hi) * 0.5, cross_y, m)
	var edge := minf(_leg_length(o, t, frame, -half, cross_y, m),
		_leg_length(o, t, frame, half, cross_y, m))
	return minf(mid, edge)


static func _leg_length(o: Vector3, t: Vector3, frame: Transform3D, s: float,
		cross_y: float, m: Transform3D) -> float:
	var cross := Vector3(frame.origin.x + frame.basis.x.x * s, cross_y,
		frame.origin.z + frame.basis.x.z * s)
	return o.distance_to(cross) + (m * cross).distance_to(t)

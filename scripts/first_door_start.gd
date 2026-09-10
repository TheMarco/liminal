class_name FirstDoorStart
extends RefCounted
## New-run admission: the first floor must contain a usable early discovery.
## The accepted seed is the run's real seed, so saves, props and later floors
## all reproduce the same building. Continue does not select a new seed.
const MAX_ATTEMPTS := 32
const FALLBACK_SEEDS := [21, 75, 27, 37, 39]
static var _valid := {}
static var last_attempts := 0
static var last_used_fallback := false

static func select_seed(requested: int, excluded := 0) -> int:
	last_attempts = 0
	last_used_fallback = false
	for attempt in MAX_ATTEMPTS:
		var candidate := requested if attempt == 0 else \
			(WorldGen.h(requested, attempt, 0, 1987) | 1)
		last_attempts += 1
		if candidate > 0 and candidate != excluded and accepts(candidate):
			return candidate
	# A bounded search must never quietly admit a floor without its discovery.
	# These are generated seeds, checked through the same geometry contract.
	for candidate in FALLBACK_SEEDS:
		last_attempts += 1
		if candidate != excluded and accepts(candidate):
			last_used_fallback = true
			return candidate
	push_error("FirstDoorStart: no valid introductory doorway; refusing new run")
	return 0

static func accepts(seed: int) -> bool:
	if _valid.has(seed):
		return bool(_valid[seed])
	var route := DescentRoute.build(seed, 0, 0)
	if route.intro_door_hint.is_empty():
		_valid[seed] = false
		return false
	var topology := DescentTopology.new(seed, 0)
	route.set_topology(topology)
	topology._plan_photo_doors(route)
	var record := topology.intro_photo_door()
	var evidence := PhotoDirector.build_plan(route)
	if record.is_empty() or evidence.is_empty() or \
			PhotoDirector.intro_route_evidence_count(route, evidence) < PhotoDirector.required_for(0, 0):
		_valid[seed] = false
		return false
	var cm := ChunkManager.new()
	cm.world_seed = seed
	cm.theme = 0
	cm.descent = true
	cm.descent_base_seed = seed
	cm.descent_route = route
	cm.descent_topology = topology
	var parts: Array[Chunk] = []
	var seen := {}
	var at: Vector2i = record["cell"]
	var other: Vector2i = at + WorldGen.DIRV[DescentTopology.edge_dir(record)]
	for endpoint in [at, other]:
		for member in WorldGen.owning_room_members(seed, endpoint, 0):
			if not seen.has(member):
				seen[member] = true
				parts.append(cm._build(member, false))
	var director := PhotoDirector.new()
	director.world_seed = seed
	director.theme = 0
	var valid := director._photo_door_approach_clear(record, parts)
	for part in parts:
		part.free()
	director.free()
	cm.free()
	_valid[seed] = valid
	return valid

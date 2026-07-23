class_name WorldGen
## Deterministic, stateless world generation queries.
## Every function is a pure function of (world seed, cell coords), so any chunk
## can be built or rebuilt in isolation and both sides of a shared edge agree.

const WALL_P := 0.45
const MAXH := 2147483647.0
const DIRV := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const OPP := [1, 0, 3, 2]

## The live themes, in the order the 1-N keys select them. Deliberately sparse:
## 3 was the derelict theme park, cut because it never held up beside the
## interiors. Ids are NOT renumbered — every other theme keeps the seed salt and
## world it always had, so old seeds still reproduce.
const THEMES: Array[int] = [0, 1, 2, 4, 5, 6]

const STYLE_EMPTY := 0
const STYLE_PILLARS := 1
const STYLE_SLOTS := 2
const STYLE_LOUNGE := 3
const STYLE_GRAND := 4
const STYLE_HALLWAY := 5
const STYLE_BALLROOM := 6

const OFFICE_EMPTY := 10
const OFFICE_CORRIDOR := 11
const OFFICE_CUBICLES := 12
const OFFICE_STORAGE := 13
const OFFICE_BREAK := 14
const OFFICE_BOARDROOM := 15

const SEWER_TUNNEL := 20
const SEWER_BASIN := 21
const SEWER_PUMP := 22
const SEWER_DRY := 23
const SEWER_GALLERY := 24
const SEWER_CISTERN := 25

const AIR_GATE := 40
const AIR_CONCOURSE := 41
const AIR_CHECKIN := 42
const AIR_BAGGAGE := 43
const AIR_ESCALATOR := 44
const AIR_HALL := 45
const AIR_TRANSIT := 46
const AIR_FOODCOURT := 47

const ASY_CELL := 50       # patient room — small, often split again
const ASY_WARD := 51       # rows of metal beds down a shared room
const ASY_DAYROOM := 52    # the rare big common room
const ASY_TREATMENT := 53  # restraint table, ECT cart, tiled walls
const ASY_HYDRO := 54      # hydrotherapy tubs under dripping tile
const ASY_OFFICE := 55     # records and administration
const ASY_CORRIDOR := 56   # narrow ward corridor, gurneys against the walls
const ASY_CHAPEL := 57     # a rare assembly room, pews still facing forward

const SCH_CORRIDOR := 60   # the spine: locker runs, strip lights, no bell
const SCH_CLASSROOM := 61  # desks in rows facing a board nobody wrote on
const SCH_CAFETERIA := 62  # folding tables, serving line, trays stacked
const SCH_BATHROOM := 63   # stalls, sinks, a mirror you have to walk past
const SCH_GYM := 64        # the big one — sprung floor, hoops, bleachers
const SCH_LIBRARY := 65    # stacks and reading tables
const SCH_LAB := 66        # science benches with gas taps and stools
const SCH_ADMIN := 67      # front office, counter, filing
const SCH_AUDITORIUM := 68 # a rare stage and rows of empty folding seats

# Eight-cell (96m) semantic districts. Room styles still vary within a zone,
# but the weights now agree over a meaningful walk: a run of gates gives way
# to baggage handling, patient wards yield to treatment, and so on. The room
# root keeps a merged space in one district even when it crosses a boundary.
const ZONE_SPAN := 8
const ZONE_COUNT := 3


static func h(ws: int, a: int, b: int, salt: int) -> int:
	var x: int = ws + salt * 668265263
	x ^= a * 73856093
	x ^= b * 19349663
	x = (x ^ (x >> 13)) * 1274126177
	x ^= (x >> 16)
	return x & 0x7FFFFFFF


static func r01(ws: int, a: int, b: int, salt: int) -> float:
	return float(h(ws, a, b, salt)) / MAXH


## Secondary random stream derived from an already-computed hash.
static func hr01(hash_val: int, salt: int) -> float:
	return float(h(hash_val, salt, 0, 77)) / MAXH


## Canonical edge id: east/north edges belong to the lower-coordinate cell,
## so both cells adjacent to an edge derive identical parameters for it.
static func _edge(cell: Vector2i, dir: int) -> Array:
	match dir:
		0: return [cell, 0]
		1: return [Vector2i(cell.x - 1, cell.y), 0]
		2: return [cell, 1]
		3: return [Vector2i(cell.x, cell.y - 1), 1]
	return [cell, 0]


static func _edge_hash(ws: int, ec: Vector2i, axis: int) -> int:
	return h(ws, ec.x, ec.y, 101 if axis == 0 else 211)


static func _base_wall(eh: int) -> bool:
	return float(eh) / MAXH < WALL_P


## If a cell would be sealed on all four sides, force open the edge with the
## lowest hash. Both neighbours of that edge can compute this locally.
static func _forced_open(ws: int, cell: Vector2i) -> int:
	var hs := [
		_edge_hash(ws, cell, 0),
		_edge_hash(ws, Vector2i(cell.x - 1, cell.y), 0),
		_edge_hash(ws, cell, 1),
		_edge_hash(ws, Vector2i(cell.x, cell.y - 1), 1),
	]
	for eh in hs:
		if not _base_wall(eh):
			return -1
	var best := 0
	for i in range(1, 4):
		if hs[i] < hs[best]:
			best = i
	return best


## First solid edge scanning from a hashed start — anchors airport gate
## glass, check-in backs and escalator mezzanines. -1 if the cell has no
## walls. Exposed here so spawn logic can know which side a gate's sealed
## apron strip is on.
static func anchor_wall(ws: int, cell: Vector2i, salt: int) -> int:
	var start := int(r01(ws, cell.x, cell.y, salt) * 3.99)
	for i in 4:
		var d := (start + i) % 4
		if is_wall(ws, cell, d):
			return d
	return -1


## Corridor cells sharing an axis punch straight through the edge between
## them — the passage runs on, cell after cell. Symmetric, so both
## neighbours agree.
static func corridor_link(ws: int, cell: Vector2i, dir: int) -> bool:
	var c1 := corridor(ws, cell)
	if c1 == 0 or corridor(ws, cell + DIRV[dir]) != c1:
		return false
	return (c1 == 1 and dir <= 1) or (c1 == 2 and dir >= 2)



# --- rooms --------------------------------------------------------------------
# Cells cluster into rooms, and walls exist ONLY on the boundary between two
# different rooms. Boundaries of a contiguous blob always close on themselves,
# so a wall can never stand alone in the open the way per-edge walls did.
# Rooms come in sizes: a single cell, a two- or three-cell suite, or an
# aligned 2x2 hall. Ceiling height follows room size, so small rooms read as
# small. Single-cell rooms are often split again by a partition, which is
# where the genuinely small rooms come from.

const NO_HALL := Vector2i(-2147483647, -2147483647)
const HALL_P := 0.17


## Aligned 2x2 block promoted to one big hall — or NO_HALL.
static func hall_root(ws: int, cell: Vector2i) -> Vector2i:
	var bx := cell.x - posmod(cell.x, 2)
	var bz := cell.y - posmod(cell.y, 2)
	if r01(ws, bx, bz, 610) >= HALL_P:
		return NO_HALL
	# a hall may not swallow a corridor band
	for dx in 2:
		for dz in 2:
			if corridor(ws, Vector2i(bx + dx, bz + dz)) != 0:
				return NO_HALL
	return Vector2i(bx, bz)


## Raw merge preference, ignoring whether the target can accept it.
static func _merge_raw(ws: int, cell: Vector2i) -> int:
	# The origin is the guaranteed arrival room. Keep it as a root so theme
	# spawn contracts (classroom, ward, gate) cannot silently move their props
	# into a neighbouring anchor cell while the player still arrives at (0, 0).
	if cell == Vector2i.ZERO:
		return -1
	if corridor(ws, cell) != 0 or hall_root(ws, cell) != NO_HALL:
		return -1
	var r := r01(ws, cell.x, cell.y, 611)
	if r < 0.24:
		return 0   # merge into +x neighbour
	if r < 0.44:
		return 2   # merge into +z neighbour
	return -1


## A cell may only merge into a cell that is itself a room root, so chains
## stay one link long and every room stays small enough to reason about.
static func merge_dir(ws: int, cell: Vector2i) -> int:
	var d := _merge_raw(ws, cell)
	if d == -1:
		return -1
	var nb: Vector2i = cell + DIRV[d]
	if corridor(ws, nb) != 0 or hall_root(ws, nb) != NO_HALL:
		return -1
	if _merge_raw(ws, nb) != -1:
		return -1
	return d


## Identity of the room this cell belongs to. Pure function of the cell, so
## both sides of every edge always agree on whether they share a room.
static func room_id(ws: int, cell: Vector2i) -> Vector2i:
	var h := hall_root(ws, cell)
	if h != NO_HALL:
		return h
	var d := merge_dir(ws, cell)
	return cell if d == -1 else cell + DIRV[d]


## How many cells the room occupies (1, 2, 3 or 4).
static func room_size(ws: int, root: Vector2i) -> int:
	if hall_root(ws, root) == root:
		return 4
	var n := 1
	if merge_dir(ws, Vector2i(root.x - 1, root.y)) == 0:
		n += 1
	if merge_dir(ws, Vector2i(root.x, root.y - 1)) == 2:
		n += 1
	return n


## Centre of the room in world metres — where its furniture belongs.
static func room_centre(ws: int, root: Vector2i) -> Vector2:
	if hall_root(ws, root) == root:
		return Vector2(root.x * 12.0 + 12.0, root.y * 12.0 + 12.0)
	var mx := merge_dir(ws, Vector2i(root.x - 1, root.y)) == 0
	var mz := merge_dir(ws, Vector2i(root.x, root.y - 1)) == 2
	var x0 := float(root.x) * 12.0
	var z0 := float(root.y) * 12.0
	# An L-shaped room's bounding-box centre falls in the quadrant the room
	# does NOT own — furniture placed there would push through a wall. Use
	# the root cell, which is always part of the room.
	if mx and mz:
		return Vector2(x0 + 6.0, z0 + 6.0)
	var x1 := x0 + 12.0
	var z1 := z0 + 12.0
	if mx:
		x0 -= 12.0
	if mz:
		z0 -= 12.0
	return Vector2((x0 + x1) * 0.5, (z0 + z1) * 0.5)


## Coarse maintenance era for material palettes. Six-cell districts keep the
## same finish over meaningful stretches, and the room root guarantees every
## member of a merged room agrees even when it crosses a district boundary.
static func finish_variant(ws: int, cell: Vector2i, theme: int) -> int:
	var root := room_id(ws, cell)
	var zone_x := floori(float(root.x + 3) / 6.0)
	var zone_z := floori(float(root.y + 3) / 6.0)
	return h(ws, zone_x, zone_z, 1201 + theme * 37) % 3


## Semantic district for a room: 0..2, interpreted separately by each theme.
## This is intentionally independent of finish_variant — a department can
## cross an old repaint boundary, and a renovation can cut across departments.
static func macro_zone(ws: int, cell: Vector2i, theme: int) -> int:
	var root := room_id(ws, cell)
	var zone_x := floori(float(root.x + ZONE_SPAN / 2) / float(ZONE_SPAN))
	var zone_z := floori(float(root.y + ZONE_SPAN / 2) / float(ZONE_SPAN))
	return h(ws, zone_x, zone_z, 1301 + theme * 53) % ZONE_COUNT


## Human-readable names are used by audits and debug tooling rather than the
## runtime scene, keeping district intent easy to inspect when tuning seeds.
static func macro_zone_name(zone: int, theme: int) -> String:
	var names := {
		0: ["gaming", "hotel", "convention"],
		1: ["operations", "records", "staff"],
		2: ["conveyance", "treatment", "maintenance"],
		4: ["airside", "departures", "arrivals"],
		5: ["patient wing", "treatment", "administration"],
		6: ["academic", "commons", "administration"],
	}
	var labels: Array = names.get(theme, ["zone 0", "zone 1", "zone 2"])
	return labels[clampi(zone, 0, labels.size() - 1)]


## Landmarks only claim true 2x2 halls, never the spawn room or a corridor.
## Roughly one hall in five is promoted: rare in a local view, but dependable
## over a longer walk. Each floor gets a single unmistakable landmark grammar.
static func landmark_style(ws: int, cell: Vector2i, theme: int) -> int:
	var root := room_id(ws, cell)
	if root == Vector2i.ZERO or room_size(ws, root) < 4 or corridor(ws, root) != 0:
		return -1
	if r01(ws, root.x, root.y, 1391 + theme * 61) >= 0.22:
		return -1
	match theme:
		0: return STYLE_BALLROOM
		1: return OFFICE_BOARDROOM
		2: return SEWER_CISTERN
		4: return AIR_FOODCOURT
		5: return ASY_CHAPEL
		6: return SCH_AUDITORIUM
	return -1


## Ceiling height for a room: small rooms are low and close, halls soar.
static func room_height(ws: int, root: Vector2i, theme: int) -> float:
	var n := room_size(ws, root)
	var r := r01(ws, root.x, root.y, 612)
	if theme == 2:
		return 2.7 if n < 4 else 3.4
	if theme == 4:
		if n >= 4: return 6.2
		return 4.4 if n >= 2 else lerpf(3.2, 3.8, r)
	if theme == 1:
		if n >= 4: return 3.6
		return 3.0 if n >= 2 else lerpf(2.65, 2.9, r)
	if theme == 5:
		# institutional: low and close everywhere, only the dayroom breathes
		if n >= 4: return 4.6
		return 3.15 if n >= 2 else lerpf(2.65, 2.95, r)
	if theme == 6:
		# a school is built to one height and then the gym happens
		if n >= 4: return 6.6
		return 3.4 if n >= 2 else lerpf(2.9, 3.15, r)
	if n >= 4:
		return 6.4
	if n >= 2:
		return lerpf(3.3, 3.7, r)
	return lerpf(2.7, 3.05, r)


## Openings in the two walls a partition would run into, as (centre,
## clearance) along the partition's fixed axis.
static func crossing_openings(ws: int, cell: Vector2i, theme: int, along_x: bool) -> Array:
	var out := []
	for d in ([1, 0] if along_x else [3, 2]):
		var info := edge_info(ws, cell, d, theme)
		if info["wall"]:
			continue
		if info["full_open"]:
			out.append(Vector2(6.0, 6.5))
		else:
			out.append(Vector2(info["t"], float(info["w"]) * 0.5 + 0.9))
	return out


## Where a partition can actually stand: the first offset that clears every
## doorway in the walls it meets, or -1 if the room cannot take one. Without
## this a partition can end mid-doorway and split the opening in two.
static func partition_offset(ws: int, cell: Vector2i, theme: int, along_x: bool, want: float) -> float:
	var blocked := crossing_openings(ws, cell, theme, along_x)
	for c in [want, 4.0, 5.5, 7.0, 8.0, 3.2, 8.8]:
		var ok := true
		for b in blocked:
			if absf(c - b.x) < b.y:
				ok = false
				break
		if ok:
			return c
	return -1.0


## Does this single-cell room get an interior partition, and where? Returns
## [along_x, offset_metres] or [] for none. This is where small rooms come
## from — a 12x12 cell split into, say, 4x12 and 8x12.
static func room_split(ws: int, root: Vector2i, theme: int) -> Array:
	# Never drop a partition across a level's arrival room. In the school this
	# could put the fixed spawn capsule inside a wall before the first frame.
	if root == Vector2i.ZERO or theme == 2 or room_size(ws, root) != 1 \
			or corridor(ws, root) != 0:
		return []
	var r := r01(ws, root.x, root.y, 613)
	# the asylum is mostly small rooms: split single cells aggressively
	var split_p := 0.3
	if theme == 1:
		split_p = 0.42
	elif theme == 5:
		split_p = 0.52
	elif theme == 6:
		# split hard: a school is many small rooms off a corridor, not a
		# handful of halls. This is where the offices and cupboards come from.
		split_p = 0.55
	if r > split_p:
		return []
	var along_x := r01(ws, root.x, root.y, 614) < 0.5
	var off: float = [4.0, 5.5, 7.0, 8.0][int(r01(ws, root.x, root.y, 615) * 3.99)]
	return [along_x, off]


## Deterministic "drainage" direction: every cell keeps one edge open that
## steps toward the origin (axis picked by hash when both apply). The chains
## form a spanning tree over the whole grid, so every room provably connects
## to every other — no more sealed multi-cell pockets, which per-cell
## forced-open logic alone cannot prevent.
static func _parent_dir(ws: int, cell: Vector2i) -> int:
	if cell == Vector2i.ZERO:
		return -1
	if cell.x == 0:
		return 3 if cell.y > 0 else 2
	if cell.y == 0:
		return 1 if cell.x > 0 else 0
	if r01(ws, cell.x, cell.y, 601) < 0.5:
		return 1 if cell.x > 0 else 0
	return 3 if cell.y > 0 else 2


## Two cells in the same room have no wall between them. Two cells in
## different rooms always have one — sometimes with a doorway through it
## (see edge_info), never a bare panel standing in the open.
static func is_wall(ws: int, cell: Vector2i, dir: int) -> bool:
	if room_id(ws, cell) == room_id(ws, cell + DIRV[dir]):
		return false
	if corridor_link(ws, cell, dir):
		return false
	return not _doorway(ws, cell, dir)


## The cell of a room that sits closest to the origin — the room hangs its
## guaranteed way out off this one, so a room needs one such door, not one
## per cell.
static func room_link_cell(ws: int, root: Vector2i) -> Vector2i:
	var best := root
	var bd := absi(root.x) + absi(root.y)
	var cells: Array[Vector2i] = []
	if hall_root(ws, root) == root:
		cells = [Vector2i(root.x + 1, root.y), Vector2i(root.x, root.y + 1),
			Vector2i(root.x + 1, root.y + 1)]
	else:
		if merge_dir(ws, Vector2i(root.x - 1, root.y)) == 0:
			cells.append(Vector2i(root.x - 1, root.y))
		if merge_dir(ws, Vector2i(root.x, root.y - 1)) == 2:
			cells.append(Vector2i(root.x, root.y - 1))
	for c in cells:
		var d := absi(c.x) + absi(c.y)
		if d < bd or (d == bd and (c.x < best.x or (c.x == best.x and c.y < best.y))):
			best = c
			bd = d
	return best


## Is the boundary between these two rooms pierced by a doorway here? Each
## room forces exactly one — from its origin-most cell, stepping inward — so
## the whole floor stays connected without perforating every wall.
static func _doorway(ws: int, cell: Vector2i, dir: int) -> bool:
	if room_link_cell(ws, room_id(ws, cell)) == cell and _parent_dir(ws, cell) == dir:
		return true
	var nb: Vector2i = cell + DIRV[dir]
	if room_link_cell(ws, room_id(ws, nb)) == nb and _parent_dir(ws, nb) == OPP[dir]:
		return true
	# rooms open onto corridors, not into each other: a room-to-room door is
	# rare, a door onto a corridor is the normal way in. That makes corridors
	# the circulation spine instead of decoration.
	var a_cor := corridor(ws, cell) != 0
	var b_cor := corridor(ws, cell + DIRV[dir]) != 0
	var p := 0.13
	if a_cor != b_cor:
		p = 0.55
	elif a_cor and b_cor:
		p = 0.4
	var e := _edge(cell, dir)
	return hr01(_edge_hash(ws, e[0], e[1]), 21) < p


## Per-theme probability that an open edge is fully open (vs a doorway).
static func _fo_p(theme: int) -> float:
	match theme:
		1: return 0.28
		2: return 0.34
		3: return 0.5
		4: return 0.55
		5: return 0.26
		6: return 0.08   # a school is rooms off corridors, and doors between
	return 0.45


## Fully open edge (no wall, no doorway stub) — first-order estimate used by
## the door-illusion rule below; deliberately ignores that rule itself so
## there is no recursion.
static func _open_edge(ws: int, cell: Vector2i, dir: int, theme: int) -> bool:
	if is_wall(ws, cell, dir):
		return false
	if corridor_link(ws, cell, dir):
		return true
	var e2 := _edge(cell, dir)
	return hr01(_edge_hash(ws, e2[0], e2[1]), 1) < _fo_p(theme)


static func edge_info(ws: int, cell: Vector2i, dir: int, theme := 0) -> Dictionary:
	var e := _edge(cell, dir)
	var eh := _edge_hash(ws, e[0], e[1])
	var wall := is_wall(ws, cell, dir)
	if corridor_link(ws, cell, dir):
		# nothing interrupts a running corridor — not even a door frame
		return {"wall": false, "full_open": true, "t": 6.0, "w": 4.0, "exit_sign": false}
	# inside one room there is simply nothing there
	if room_id(ws, cell) == room_id(ws, cell + DIRV[dir]):
		return {"wall": false, "full_open": true, "t": 6.0, "w": 4.0, "exit_sign": false}
	var full_open := false
	# A school corridor is enclosed by definition — you get doors off it, never
	# a missing wall. Left to the rule below it never stays enclosed: its own
	# two through-links already count as open edges, so every side edge trips
	# the "already an open hall" test and the passage dissolves into the rooms.
	var ca := corridor(ws, cell)
	var cb := corridor(ws, cell + DIRV[dir])
	var a_cor := ca != 0
	var b_cor := cb != 0
	var is_corr := a_cor or b_cor
	if theme == 6 and is_corr:
		var sw := lerpf(1.6, 2.1, hr01(eh, 2))
		var st := lerpf(2.6, 9.4, hr01(eh, 3))
		# Side classrooms may sit irregularly along the hall. A doorway at the
		# end of its axis cannot: outside the central lane it opens directly into
		# the inaccessible classroom strip behind the narrowed corridor wall.
		var terminal := (ca == 1 and dir <= 1) or (ca == 2 and dir >= 2) \
			or (cb == 1 and dir <= 1) or (cb == 2 and dir >= 2)
		if terminal:
			st = 6.0
			sw = minf(sw, 2.4)
		return {"wall": wall, "full_open": false,
			"t": st, "w": sw,
			"exit_sign": hr01(eh, 4) < 0.2}
	if not wall and not full_open:
		# A cased doorway only sells "a room behind this wall" when both
		# sides feel enclosed. If either side is already a merged open hall
		# (2+ other fully open edges), a lone door-wall standing in open
		# space gives the game away — open the edge completely instead.
		for ci in 2:
			var c2: Vector2i = cell if ci == 0 else cell + DIRV[dir]
			var open_n := 0
			for d2 in 4:
				if _edge(c2, d2) == e:
					continue
				if _open_edge(ws, c2, d2, theme):
					open_n += 1
			if open_n >= 2:
				full_open = true
				break
	var w := lerpf(1.7, 2.8, hr01(eh, 2)) if theme == 1 else lerpf(2.3, 4.4, hr01(eh, 2))
	var margin := w / 2.0 + 0.8
	var t := lerpf(margin, 12.0 - margin, hr01(eh, 3))
	var has_sign := hr01(eh, 4) < (0.10 if theme == 1 else 0.16)
	if theme == 2:
		# sewers: openings are wide centered archways spanning the channel,
		# so the waterway and both walkways pass through together
		w = lerpf(4.8, 6.6, hr01(eh, 2))
		t = 6.0
		has_sign = false
	elif theme == 4:
		# airport: one continuous terminal — most edges fully open, the rest
		# broad tall portals, many crowned with a hanging wayfinding sign
		w = lerpf(3.8, 6.4, hr01(eh, 2))
		var m4 := w / 2.0 + 0.9
		t = lerpf(m4, 12.0 - m4, hr01(eh, 3))
		has_sign = hr01(eh, 4) < 0.34
	elif theme == 5:
		# asylum: narrow institutional doorways, never generous
		w = lerpf(1.5, 2.3, hr01(eh, 2))
		var m5 := w / 2.0 + 0.8
		t = lerpf(m5, 12.0 - m5, hr01(eh, 3))
		has_sign = hr01(eh, 4) < 0.10
	elif theme == 6:
		# school: a single classroom door, or the double doors at the end of
		# a corridor — nothing in between
		w = 2.6 if hr01(eh, 5) < 0.3 else lerpf(1.6, 2.0, hr01(eh, 2))
		var m6 := w / 2.0 + 0.9
		t = lerpf(m6, 12.0 - m6, hr01(eh, 3))
		has_sign = hr01(eh, 4) < 0.22
	# Narrow circulation spines need an architectural boundary wherever an edge
	# is not their straight-through link. Letting it become fully open exposes
	# the service/guest-room
	# strip behind the secondary corridor wall, including the backs of decorative
	# locked doors. Keep it as a cased opening instead. At a terminal or junction,
	# the opening is centred on the lane so it cannot discharge into that hidden
	# strip.  This is symmetric: both sides see the same corridor axis and edge.
	if (theme == 0 or theme == 1 or theme == 4 or theme == 5) and is_corr:
		full_open = false
		var terminal := (ca == 1 and dir <= 1) or (ca == 2 and dir >= 2) \
			or (cb == 1 and dir <= 1) or (cb == 2 and dir >= 2)
		if terminal:
			t = 6.0
			# A transit bank needs its whole cross-section at a genuine exit;
			# the narrower hotel, office and asylum spines use a single doorway.
			w = 10.4 if theme == 4 else minf(w, 2.4)
	return {"wall": wall, "full_open": full_open, "t": t, "w": w, "exit_sign": has_sign}


## Does a water channel cross this edge? Canonical per edge, so both cells
## build matching trough halves. The spawn cell's south edge is kept dry so
## the default spawn point never lands in water.
static func sewer_channel(ws: int, cell: Vector2i, dir: int) -> bool:
	var e := _edge(cell, dir)
	if e[0] == Vector2i(0, -1) and e[1] == 1:
		return false
	return hr01(_edge_hash(ws, e[0], e[1]), 9) < 0.62


## Deterministic flow sign for the channel crossing an edge: +1 flows toward
## +x/+z, -1 the other way. Shared by both cells, so streams never collide
## head-on at a boundary.
static func sewer_flow(ws: int, cell: Vector2i, dir: int) -> float:
	var e := _edge(cell, dir)
	return 1.0 if hr01(_edge_hash(ws, e[0], e[1]), 10) < 0.5 else -1.0


## Corridor bands: certain whole rows/columns of the grid carve into narrow
## passages, so tight corridors run cell after cell instead of the world
## being nothing but wide rooms. 0 = no corridor, 1 = along x, 2 = along z.
static func corridor(ws: int, cell: Vector2i) -> int:
	if cell == Vector2i.ZERO:
		return 0
	if r01(ws, 0, cell.y, 520) < 0.16 and r01(ws, cell.x, cell.y, 521) < 0.62:
		return 1
	if r01(ws, cell.x, 0, 522) < 0.16 and r01(ws, cell.x, cell.y, 523) < 0.62:
		return 2
	return 0


## Swirling portal to another theme. Returns the destination theme, or -1.
## Portals only open in each theme's roomiest style so the set pieces stay
## clear, and never in the spawn cell.
static func portal(ws: int, cell: Vector2i, theme := 0) -> int:
	if cell == Vector2i.ZERO:
		return -1
	var st := cell_style(ws, cell, theme)
	var ok := false
	match theme:
		0: ok = st == STYLE_EMPTY
		1: ok = st == OFFICE_EMPTY
		2: ok = st == SEWER_DRY
		4: ok = st == AIR_HALL
		5: ok = st == ASY_DAYROOM
		6: ok = st == SCH_GYM
	if not ok:
		return -1
	if r01(ws, cell.x, cell.y, 501) > 0.30:
		return -1
	# pick any OTHER live theme; THEMES is sparse (3 was the theme park)
	var others: Array[int] = []
	for t in THEMES:
		if t != theme:
			others.append(t)
	return others[int(r01(ws, cell.x, cell.y, 502) * (float(others.size()) - 0.01))]


## Rare working lift facade in a quiet, unsplit single-cell room. Keeping the
## predicate here makes the set piece deterministic and lets dev tools locate
## one without constructing the whole world.
static func elevator_cell(ws: int, cell: Vector2i, theme: int) -> bool:
	if room_id(ws, cell) != cell or room_size(ws, cell) != 1 \
			or not room_split(ws, cell, theme).is_empty() \
			or portal(ws, cell, theme) >= 0:
		return false
	var st := cell_style(ws, cell, theme)
	var eligible := st == STYLE_EMPTY or st == OFFICE_EMPTY \
		or st == SEWER_DRY or st == AIR_HALL \
		or st == ASY_DAYROOM or st == SCH_ADMIN
	return eligible and r01(ws, cell.x, cell.y, 1700) < 0.28 \
		and anchor_wall(ws, cell, 1701) >= 0


## What kind of room this is. Seeded by the room ROOT so every cell of a
## room agrees, and gated by room SIZE so a set piece only lands where it
## fits: slot banks and ferris wheels want a hall; a small room does not get
## a carousel.
static func cell_style(ws: int, cell: Vector2i, theme := 0) -> int:
	var cdir := corridor(ws, cell)
	if cdir != 0:
		match theme:
			1: return OFFICE_CORRIDOR
			2: return SEWER_GALLERY
			4: return AIR_TRANSIT
			5: return ASY_CORRIDOR
			6: return SCH_CORRIDOR
			_: return STYLE_HALLWAY
	var root := room_id(ws, cell)
	var n := room_size(ws, root)
	var r := r01(ws, root.x, root.y, 7)
	var zone := macro_zone(ws, root, theme)
	var landmark := landmark_style(ws, root, theme)
	if landmark >= 0:
		return landmark
	if theme == 5:
		if root == Vector2i.ZERO:
			return ASY_WARD
		if n >= 4:
			if zone == 0: return ASY_DAYROOM if r < 0.82 else ASY_WARD
			if zone == 1: return ASY_HYDRO if r < 0.62 else ASY_DAYROOM
			return ASY_OFFICE if r < 0.48 else ASY_DAYROOM
		if n >= 2:
			if zone == 0:
				if r < 0.66: return ASY_WARD
				if r < 0.84: return ASY_DAYROOM
				return ASY_OFFICE
			if zone == 1:
				if r < 0.48: return ASY_TREATMENT
				if r < 0.82: return ASY_HYDRO
				return ASY_WARD
			if r < 0.56: return ASY_OFFICE
			if r < 0.80: return ASY_WARD
			return ASY_TREATMENT
		if zone == 0:
			return ASY_CELL if r < 0.78 else ASY_OFFICE
		if zone == 1:
			if r < 0.45: return ASY_TREATMENT
			if r < 0.72: return ASY_CELL
			return ASY_HYDRO
		return ASY_OFFICE if r < 0.58 else ASY_CELL
	if theme == 6:
		# a school is mostly classrooms; everything else is the exception you
		# walk past on the way to another classroom
		if root == Vector2i.ZERO:
			return SCH_CLASSROOM
		if n >= 4:
			if zone == 0: return SCH_LIBRARY if r < 0.48 else SCH_GYM
			if zone == 1: return SCH_CAFETERIA if r < 0.62 else SCH_GYM
			return SCH_CAFETERIA if r < 0.55 else SCH_LIBRARY
		if n >= 2:
			if zone == 0:
				if r < 0.46: return SCH_CLASSROOM
				if r < 0.76: return SCH_LAB
				return SCH_LIBRARY
			if zone == 1:
				if r < 0.48: return SCH_CAFETERIA
				if r < 0.74: return SCH_LIBRARY
				return SCH_CLASSROOM
			if r < 0.52: return SCH_ADMIN
			if r < 0.75: return SCH_LIBRARY
			return SCH_CLASSROOM
		if zone == 0:
			if r < 0.62: return SCH_CLASSROOM
			if r < 0.84: return SCH_LAB
			return SCH_LIBRARY
		if zone == 1:
			if r < 0.38: return SCH_CLASSROOM
			if r < 0.64: return SCH_BATHROOM
			if r < 0.84: return SCH_LIBRARY
			return SCH_CAFETERIA
		if r < 0.54: return SCH_ADMIN
		if r < 0.76: return SCH_CLASSROOM
		if r < 0.90: return SCH_BATHROOM
		return SCH_LIBRARY
	if theme == 4:
		if root == Vector2i.ZERO:
			return AIR_GATE
		if n >= 4:
			if zone == 0: return AIR_GATE if r < 0.76 else AIR_CONCOURSE
			if zone == 1: return AIR_CHECKIN if r < 0.52 else AIR_CONCOURSE
			return AIR_BAGGAGE if r < 0.74 else AIR_HALL
		if n >= 2:
			if zone == 0:
				if r < 0.58: return AIR_GATE
				if r < 0.86: return AIR_CONCOURSE
				return AIR_HALL
			if zone == 1:
				if r < 0.52: return AIR_CHECKIN
				if r < 0.80: return AIR_CONCOURSE
				return AIR_ESCALATOR
			if r < 0.58: return AIR_BAGGAGE
			if r < 0.82: return AIR_HALL
			return AIR_CONCOURSE
		if zone == 0:
			return AIR_CONCOURSE if r < 0.62 else AIR_GATE
		if zone == 1:
			if r < 0.44: return AIR_HALL
			if r < 0.78: return AIR_ESCALATOR
			return AIR_CONCOURSE
		return AIR_HALL if r < 0.58 else AIR_BAGGAGE
	if theme == 2:
		if n >= 4:
			return SEWER_BASIN if zone != 2 or r < 0.55 else SEWER_PUMP
		if n >= 2:
			if zone == 0: return SEWER_TUNNEL if r < 0.78 else SEWER_PUMP
			if zone == 1: return SEWER_BASIN if r < 0.56 else SEWER_PUMP
			return SEWER_PUMP if r < 0.68 else SEWER_DRY
		if zone == 0: return SEWER_TUNNEL if r < 0.78 else SEWER_DRY
		if zone == 1: return SEWER_TUNNEL if r < 0.42 else SEWER_DRY
		return SEWER_DRY if r < 0.70 else SEWER_PUMP
	if theme == 1:
		if root == Vector2i.ZERO:
			return OFFICE_CUBICLES
		if n >= 4:
			if zone == 0: return OFFICE_CUBICLES
			if zone == 1: return OFFICE_STORAGE if r < 0.58 else OFFICE_CUBICLES
			return OFFICE_BREAK if r < 0.48 else OFFICE_CUBICLES
		if n >= 2:
			if zone == 0: return OFFICE_CUBICLES if r < 0.78 else OFFICE_EMPTY
			if zone == 1: return OFFICE_STORAGE if r < 0.72 else OFFICE_CUBICLES
			return OFFICE_BREAK if r < 0.62 else OFFICE_CUBICLES
		if zone == 0: return OFFICE_EMPTY if r < 0.34 else OFFICE_CUBICLES
		if zone == 1: return OFFICE_STORAGE if r < 0.72 else OFFICE_EMPTY
		return OFFICE_BREAK if r < 0.66 else OFFICE_EMPTY
	if root == Vector2i.ZERO:
		return STYLE_LOUNGE
	if n >= 4:
		if zone == 0: return STYLE_GRAND if r < 0.38 else STYLE_SLOTS
		if zone == 1: return STYLE_GRAND if r < 0.48 else STYLE_LOUNGE
		return STYLE_GRAND if r < 0.72 else STYLE_PILLARS
	if n >= 2:
		if zone == 0:
			if r < 0.64: return STYLE_SLOTS
			if r < 0.82: return STYLE_PILLARS
			return STYLE_LOUNGE
		if zone == 1:
			if r < 0.62: return STYLE_LOUNGE
			if r < 0.82: return STYLE_EMPTY
			return STYLE_PILLARS
		if r < 0.54: return STYLE_PILLARS
		if r < 0.82: return STYLE_LOUNGE
		return STYLE_EMPTY
	if zone == 0: return STYLE_EMPTY if r < 0.22 else (STYLE_LOUNGE if r < 0.42 else STYLE_PILLARS)
	if zone == 1: return STYLE_EMPTY if r < 0.38 else (STYLE_LOUNGE if r < 0.82 else STYLE_PILLARS)
	return STYLE_EMPTY if r < 0.46 else (STYLE_PILLARS if r < 0.78 else STYLE_LOUNGE)

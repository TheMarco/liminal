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
const THEMES: Array[int] = [0, 1, 2, 4, 5, 6, 7, 8, 9]

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

const ANNEX_OPEN := 20       # broad, nearly empty rooms
const ANNEX_MAZE := 21       # offset wall slabs turn one room into several views
const ANNEX_LONG := 22       # long uninterrupted sight lines
const ANNEX_QUIET := 23      # mostly empty, with deliberately sparse lighting
const ANNEX_PASSAGE := 24    # the narrow circulation spine
const ANNEX_LOBBY := 25      # rare open landmark with low partitions
## Dedicated Annex circulation grid. A one-cell band every six columns / five
## rows becomes a long corridor; the spaces between are subdivided into mostly
## 12x12 and 12x24 rooms, with only rare 24x24 chambers.
const ANNEX_CORRIDOR_X := 6
const ANNEX_CORRIDOR_Z := 5


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

const MALL_CORRIDOR := 70   # the broad public gallery, shopfronts on both sides
const MALL_STORE := 71      # a small shuttered retail unit
const MALL_ANCHOR := 72     # the remains of a department store
const MALL_FOODCOURT := 73  # bolted tables and dead menu boxes
const MALL_ATRIUM := 74     # planters, fountain and a false upper balcony
const MALL_SERVICE := 75    # concrete back-of-house loading passages
const MALL_KIOSKS := 76     # abandoned islands in the concourse
const MALL_CINEMA := 77     # landmark box office and sealed screens

const PRISON_CORRIDOR := 80 # a barred gallery running the length of a cell block
const PRISON_CELLBLOCK := 81# two tiers of cells around a central floor
const PRISON_CELLS := 82    # close individual cells and bunks
const PRISON_MESS := 83     # fixed tables under harsh lamps
const PRISON_SHOWER := 84   # tiled communal washroom
const PRISON_GUARD := 85    # barred control cage and observation post
const PRISON_INDUSTRY := 86 # prison workshop / laundry
const PRISON_VISITATION := 87 # divided booths and a dead telephone line
const PRISON_ROTUNDA := 88  # landmark radial guard hub

# The Poolrooms. Every cell floods to the same level, so the water is one
# continuous body across the whole floor and is always chest deep — the styles
# differ in what stands in it and what you can climb out onto, never in depth.
const POOL_BASIN := 90      # open water under a grid of tiled piers
const POOL_CHANNEL := 91    # the narrow swimming lane between rooms
const POOL_DECK := 92       # a dry walkway along one or two walls, with ladders
const POOL_SOLARIUM := 93   # window wall, blown-out daylight, god rays
const POOL_ALCOVE := 94     # a small still bay with no windows at all
const POOL_STAIRS := 95     # a wide tiled stair descending into the water
const POOL_GALLERY := 96    # piers and a mezzanine walkway with handrails
const POOL_CISTERN := 97    # landmark: a vast dim hall of piers and skylights

# Eight-cell (96m) semantic districts. Room styles still vary within a zone,
# but the weights now agree over a meaningful walk: a run of gates gives way
# to baggage handling, patient wards yield to treatment, and so on. The room
# root keeps a merged space in one district even when it crosses a boundary.
const ZONE_SPAN := 8
const ZONE_COUNT := 3


## Stable per-floor seed derivation shared by runtime and audits. Existing
## salts are preserved byte-for-byte; new themes only add new streams.
static func level_seed(base: int, theme: int) -> int:
	if theme == 0:
		return base
	var salts := {
		1: 348039917,
		2: 715827883,
		4: 536870923,
		5: 998244353,
		6: 179424673,
		7: 463670041,
		8: 805306457,
		9: 217645177,
	}
	return ((base ^ int(salts.get(theme, 348039917))) & 0x7FFFFFFF) | 1


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
static func anchor_wall(ws: int, cell: Vector2i, salt: int, theme := 0) -> int:
	var start := int(r01(ws, cell.x, cell.y, salt) * 3.99)
	for i in 4:
		var d := (start + i) % 4
		if is_wall(ws, cell, d, theme):
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
	if theme == 2:
		var aroot := annex_room_id(ws, cell)
		# Put the supplied damask in the arrival junction so the level never
		# presents as a plain mint material test. The broader distribution still
		# leaves a clear majority of rooms unpapered.
		if aroot == Vector2i.ZERO:
			return 3
		var ax := floori(float(aroot.x + 1) / 3.0)
		var az := floori(float(aroot.y + 1) / 3.0)
		var roll := h(ws, ax, az, 1275) % 10
		if roll < 7:
			return roll % 3
		return 3 if roll < 9 else 4
	var root := room_id(ws, cell)
	var zone_x := floori(float(root.x + 3) / 6.0)
	var zone_z := floori(float(root.y + 3) / 6.0)
	return h(ws, zone_x, zone_z, 1201 + theme * 37) % 3


## One committed finish for an entire collinear Annex wall line. Shared edges
## are built by both adjacent streamed chunks; choosing from either room made
## two materials occupy the same wall and visibly split or z-fight. A line key
## keeps both faces and every contiguous segment consistent while perpendicular
## walls can still belong to different renovation eras.
static func annex_wall_finish(ws: int, cell: Vector2i, dir: int) -> int:
	var vertical_line := dir <= 1
	var line := 0
	if vertical_line:
		line = cell.x + (1 if dir == 0 else 0)
	else:
		line = cell.y + (1 if dir == 2 else 0)
	var roll := h(ws, line, 0 if vertical_line else 1, 1289) % 10
	if roll < 7:
		return h(ws, line, 0 if vertical_line else 1, 1291) % 3
	return 3 if roll < 9 else 4


## Baseboards belong to the wallpaper treatment itself. Plain painted walls
## meet the carpet directly; both wallpaper finishes receive continuous trim.
## annex_wall_finish() is keyed by the complete physical wall line, so both
## faces and every streamed segment make the same decision.
static func annex_wall_baseboard(ws: int, cell: Vector2i, dir: int) -> bool:
	return annex_wall_finish(ws, cell, dir) >= 3


## Corridor shells and their solid intersection corners are one continuous
## architectural system. A single seed-stable finish prevents a straight run
## from changing between wallpaper and paint where it crosses an intersection.
## Rooms and freestanding wall masses still provide the broader finish variety.
static func annex_corridor_finish(ws: int) -> int:
	var roll := h(ws, 0, 0, 1301) % 10
	if roll < 7:
		return roll % 3
	return 3 if roll < 9 else 4


## Semantic district for a room: 0..2, interpreted separately by each theme.
## This is intentionally independent of finish_variant — a department can
## cross an old repaint boundary, and a renovation can cut across departments.
static func macro_zone(ws: int, cell: Vector2i, theme: int) -> int:
	var root := annex_room_id(ws, cell) if theme == 2 else room_id(ws, cell)
	var zone_x := floori(float(root.x + ZONE_SPAN / 2) / float(ZONE_SPAN))
	var zone_z := floori(float(root.y + ZONE_SPAN / 2) / float(ZONE_SPAN))
	return h(ws, zone_x, zone_z, 1301 + theme * 53) % ZONE_COUNT


## Human-readable names are used by audits and debug tooling rather than the
## runtime scene, keeping district intent easy to inspect when tuning seeds.
static func macro_zone_name(zone: int, theme: int) -> String:
	var names := {
		0: ["gaming", "hotel", "convention"],
		1: ["operations", "records", "staff"],
		2: ["open plan", "service maze", "dead offices"],
		4: ["airside", "departures", "arrivals"],
		5: ["patient wing", "treatment", "administration"],
		6: ["academic", "commons", "administration"],
		7: ["retail galleries", "food and cinema", "service wing"],
		8: ["cell blocks", "institutional", "custody"],
		9: ["bathing halls", "channels", "plant"],
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
		2: return ANNEX_LOBBY
		4: return AIR_FOODCOURT
		5: return ASY_CHAPEL
		6: return SCH_AUDITORIUM
		7: return MALL_CINEMA
		8: return PRISON_ROTUNDA
		9: return POOL_CISTERN
	return -1


## Ceiling height for a room: small rooms are low and close, halls soar.
static func room_height(ws: int, root: Vector2i, theme: int) -> float:
	var n := room_size(ws, root)
	var r := r01(ws, root.x, root.y, 612)
	if theme == 2:
		# The Annex never rewards a large room with height. A low, almost
		# invariant drop ceiling makes every opening feel like the same building.
		return 2.76 if n < 4 else 2.84
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
	if theme == 7:
		if n >= 4: return 7.2
		return 4.8 if n >= 2 else lerpf(3.7, 4.2, r)
	if theme == 8:
		if n >= 4: return 6.8
		return 4.4 if n >= 2 else lerpf(3.25, 3.65, r)
	if theme == 9:
		# Measured from the deck datum, not the basin floor, so every room is
		# another 1.55m taller than this once you are standing in the water.
		if n >= 4: return 7.4
		return 5.2 if n >= 2 else lerpf(4.1, 4.6, r)
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
	# A split is a room-type decision, not a generic overlay. Letting it replace
	# landmark/set-piece styles created context nonsense: bunks in showers,
	# store fascias behind a food-court counter, and classroom filler in gyms.
	# Only styles that plausibly contain a little stockroom/office annex may be
	# subdivided; every other style keeps its authored furnishing contract.
	var st := cell_style(ws, root, theme)
	if theme == 6 and st != SCH_ADMIN:
		return []
	if theme == 7 and st != MALL_STORE and st != MALL_SERVICE:
		return []
	if theme == 8 and st != PRISON_INDUSTRY:
		return []
	# A partition dropped into standing water reads as a mistake, and would cut
	# the one continuous body of water the floor depends on.
	if theme == 9:
		return []
	var r := r01(ws, root.x, root.y, 613)
	# the asylum is mostly small rooms: split single cells aggressively
	var split_p := 0.3
	if theme == 1:
		split_p = 0.42
	elif theme == 5:
		split_p = 0.52
	elif theme == 6:
		# Administrative suites can contain small offices and cupboards.
		split_p = 0.55
	elif theme == 7:
		# Only inline shops and service rooms receive a stockroom.
		split_p = 0.18
	elif theme == 8:
		# A workshop can contain a caged tool or stock room. Actual cells are
		# built by the barred cell-strip system, never by generic partitions.
		split_p = 0.62
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


## 0 room, 1 horizontal corridor, 2 vertical corridor, 3 intersection.
## Keeping the origin as an intersection makes the actual launch demonstrate
## the level's mixed-scale circulation immediately.
static func annex_corridor_axis(_ws: int, cell: Vector2i) -> int:
	var horizontal := posmod(cell.y, ANNEX_CORRIDOR_Z) == 0
	var vertical := posmod(cell.x, ANNEX_CORRIDOR_X) == 0
	if horizontal and vertical:
		return 3
	if horizontal:
		return 1
	if vertical:
		return 2
	return 0


## Physical clear width of an Annex passage. Width is keyed to the whole row
## or column rather than to each cell, so a hallway holds its proportions over
## a long run before opening into a differently scaled crossing or room.
static func annex_horizontal_width(ws: int, row: int) -> float:
	var roll := h(ws, row, 0, 2827) % 100
	if roll < 48:
		return 2.2
	if roll < 78:
		return 3.4
	if roll < 94:
		return 4.8
	return 6.4


static func annex_vertical_width(ws: int, column: int) -> float:
	var roll := h(ws, column, 0, 2831) % 100
	if roll < 48:
		return 2.2
	if roll < 78:
		return 3.4
	if roll < 94:
		return 4.8
	return 6.4


## Theme-local room identity. This graph is intentionally unrelated to the
## generic Vegas/office rooms: most spaces are one cell, some are paired, and
## a controlled minority become 2x2 chambers. That produces a noticeable jump
## from compressed hallways to wider rooms without returning to hangar-sized
## floor plates.
static func annex_room_id(ws: int, cell: Vector2i) -> Vector2i:
	if annex_corridor_axis(ws, cell) != 0:
		return cell
	var bx := cell.x - posmod(cell.x, 2)
	var bz := cell.y - posmod(cell.y, 2)
	var mode := h(ws, bx, bz, 2813) % 100
	if mode < 28:
		for dx in 2:
			for dz in 2:
				if annex_corridor_axis(ws, Vector2i(bx + dx, bz + dz)) != 0:
					return cell
		return Vector2i(bx, bz)
	if mode < 56:
		var hx := Vector2i(bx, cell.y)
		if annex_corridor_axis(ws, hx) == 0 \
				and annex_corridor_axis(ws, hx + Vector2i(1, 0)) == 0:
			return hx
	if mode < 84:
		var vz := Vector2i(cell.x, bz)
		if annex_corridor_axis(ws, vz) == 0 \
				and annex_corridor_axis(ws, vz + Vector2i(0, 1)) == 0:
			return vz
	return cell


static func annex_room_size(ws: int, root: Vector2i) -> int:
	var total := 0
	for dx in 2:
		for dz in 2:
			if annex_room_id(ws, root + Vector2i(dx, dz)) == root:
				total += 1
	return maxi(total, 1)


## A furniture hoard is a rare interruption reserved for true 24x24 rooms.
## At thirteen percent of those rooms it remains roughly a one-percent event
## across the complete Annex rather than becoming another standard prop kit.
static func annex_furniture_pile(ws: int, root: Vector2i) -> bool:
	return annex_room_size(ws, root) >= 4 \
		and r01(ws, root.x, root.y, 2867) < 0.13


## Lighting changes in broad two-cell zones rather than per chunk, so the
## player crosses a deliberate pool of lower illumination instead of a noisy
## checkerboard. Quiet rooms are always dim; a smaller share of corridors and
## other rooms inherit a dim macro-block.
static func annex_dim_zone(ws: int, cell: Vector2i) -> bool:
	if cell == Vector2i.ZERO:
		return false
	if annex_corridor_axis(ws, cell) == 0 \
			and cell_style(ws, cell, 2) == ANNEX_QUIET:
		return true
	var bx := floori(float(cell.x) / 2.0)
	var bz := floori(float(cell.y) / 2.0)
	return r01(ws, bx, bz, 2879) < 0.10


## A minority of dim macro-blocks have no fixture in a given chunk at all.
## This produces genuinely low-light stretches without drawing dark, visibly
## switched-off troffers on an otherwise bright ceiling.
static func annex_light_gap(ws: int, cell: Vector2i) -> bool:
	if not annex_dim_zone(ws, cell):
		return false
	var bx := floori(float(cell.x) / 2.0)
	var bz := floori(float(cell.y) / 2.0)
	return r01(ws, bx, bz, 2881) < 0.28


static func _annex_corridor_supports(axis: int, dir: int) -> bool:
	return axis == 3 or (axis == 1 and dir <= 1) or (axis == 2 and dir >= 2)


static func _annex_forced_open(ws: int, cell: Vector2i, dir: int) -> bool:
	if _parent_dir(ws, cell) == dir:
		return true
	var nb: Vector2i = cell + DIRV[dir]
	return _parent_dir(ws, nb) == OPP[dir]


## Dedicated mixed-scale Annex topology: long narrow corridor bands, human-
## scale rooms, occasional merged chambers, broad doorless openings and a
## guaranteed spanning tree so no room becomes unreachable.
static func _annex_edge_info(ws: int, cell: Vector2i, dir: int) -> Dictionary:
	var nb: Vector2i = cell + DIRV[dir]
	var ca := annex_corridor_axis(ws, cell)
	var cb := annex_corridor_axis(ws, nb)
	if ca != 0 and cb != 0 \
			and _annex_corridor_supports(ca, dir) \
			and _annex_corridor_supports(cb, OPP[dir]):
		return {
			"wall": false, "full_open": true,
			"t": 6.0, "w": 12.0, "exit_sign": false,
		}

	var e := _edge(cell, dir)
	var owner: Vector2i = e[0]
	var axis := int(e[1])
	var eh := _edge_hash(ws, owner, axis)
	var forced := _annex_forced_open(ws, cell, dir)

	# A room opening onto a corridor is a short, cased side passage through the
	# corridor's reserved wall strip. It is never a missing twelve-metre wall.
	if (ca == 0) != (cb == 0):
		if not forced and hr01(eh, 84) >= 0.34:
			return {
				"wall": true, "full_open": false,
				"t": 6.0, "w": 0.0, "exit_sign": false,
			}
		var corridor_w := lerpf(3.2, 5.0, hr01(eh, 85))
		var corridor_margin := corridor_w * 0.5 + 0.65
		return {
			"wall": false, "full_open": false,
			"t": lerpf(corridor_margin, 12.0 - corridor_margin, hr01(eh, 86)),
			"w": corridor_w, "exit_sign": false,
		}

	# Cells belonging to one authored room have no seam between them.
	if ca == 0 and cb == 0 and annex_room_id(ws, cell) == annex_room_id(ws, nb):
		return {
			"wall": false, "full_open": true,
			"t": 6.0, "w": 12.0, "exit_sign": false,
		}

	# Separate rooms remain closed most of the time. Tree edges and occasional
	# secondary cuts become the broad, off-centre openings seen in the refs.
	if not forced and hr01(eh, 87) >= 0.20:
		return {
			"wall": true, "full_open": false,
			"t": 6.0, "w": 0.0, "exit_sign": false,
		}
	var completely_open := hr01(eh, 88) < 0.16
	var width := lerpf(4.2, 7.2, hr01(eh, 89))
	var margin := width * 0.5 + 0.55
	var offset := lerpf(margin, 12.0 - margin, hr01(eh, 90))
	return {
		"wall": false, "full_open": completely_open,
		"t": offset, "w": width, "exit_sign": false,
	}


## Two cells in the same room have no wall between them. Two cells in
## different rooms always have one — sometimes with a doorway through it
## (see edge_info), never a bare panel standing in the open.
static func is_wall(ws: int, cell: Vector2i, dir: int, theme := 0) -> bool:
	if theme == 2:
		return bool(_annex_edge_info(ws, cell, dir)["wall"])
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
		7: return 0.52   # a mall is one public interior interrupted by shopfronts
		8: return 0.06   # a prison boundary is always legible
		9: return 0.12   # compact pool rooms, with occasional broad connections
	return 0.45


## Fully open edge (no wall, no doorway stub) — first-order estimate used by
## the door-illusion rule below; deliberately ignores that rule itself so
## there is no recursion.
static func _open_edge(ws: int, cell: Vector2i, dir: int, theme: int) -> bool:
	if is_wall(ws, cell, dir, theme):
		return false
	if corridor_link(ws, cell, dir):
		return true
	var e2 := _edge(cell, dir)
	return hr01(_edge_hash(ws, e2[0], e2[1]), 1) < _fo_p(theme)


static func edge_info(ws: int, cell: Vector2i, dir: int, theme := 0) -> Dictionary:
	if theme == 2:
		return _annex_edge_info(ws, cell, dir)
	var e := _edge(cell, dir)
	var eh := _edge_hash(ws, e[0], e[1])
	var wall := is_wall(ws, cell, dir, theme)
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
	if (theme == 6 or theme == 8) and is_corr:
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
			"exit_sign": hr01(eh, 4) < (0.10 if theme == 8 else 0.2)}
	if theme == 9 and not wall:
		# Pool Rooms used to inherit the open-hall heuristic below.  Because
		# water already joins visually through every doorway, that heuristic
		# dissolved more than a third of all room boundaries and produced
		# hundreds-of-cells-wide spaces.  Keep a small deterministic minority
		# fully open and leave the rest as broad tiled openings.
		full_open = hr01(eh, 1) < _fo_p(theme)
	elif not wall and not full_open:
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
		# Doorless, broad rectangular cuts. Their off-centre placement makes a
		# sequence of rooms read as an office maze instead of a tiled grid.
		w = lerpf(4.2, 7.4, hr01(eh, 2))
		var m2 := w / 2.0 + 0.7
		t = lerpf(m2, 12.0 - m2, hr01(eh, 3))
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
	elif theme == 7:
		w = lerpf(4.4, 7.2, hr01(eh, 2))
		var m7 := w / 2.0 + 0.8
		t = lerpf(m7, 12.0 - m7, hr01(eh, 3))
		has_sign = hr01(eh, 4) < 0.28
	elif theme == 8:
		w = lerpf(1.25, 1.75, hr01(eh, 2))
		var m8 := w / 2.0 + 0.75
		t = lerpf(m8, 12.0 - m8, hr01(eh, 3))
		has_sign = false
	elif theme == 9:
		# Broad tiled openings: you swim between halls, and a doorway you have
		# to aim at would make the water feel like a corridor system.
		w = lerpf(3.2, 5.4, hr01(eh, 2))
		var m9 := w / 2.0 + 0.9
		t = lerpf(m9, 12.0 - m9, hr01(eh, 3))
		has_sign = false
	# Narrow circulation spines need an architectural boundary wherever an edge
	# is not their straight-through link. Letting it become fully open exposes
	# the service/guest-room
	# strip behind the secondary corridor wall, including the backs of decorative
	# locked doors. Keep it as a cased opening instead. At a terminal or junction,
	# the opening is centred on the lane so it cannot discharge into that hidden
	# strip.  This is symmetric: both sides see the same corridor axis and edge.
	if (theme == 0 or theme == 1 or theme == 2 or theme == 4 or theme == 5 \
			or theme == 7 or theme == 8) and is_corr:
		full_open = false
		var terminal := (ca == 1 and dir <= 1) or (ca == 2 and dir >= 2) \
			or (cb == 1 and dir <= 1) or (cb == 2 and dir >= 2)
		if terminal:
			t = 6.0
			# A transit bank needs its whole cross-section at a genuine exit;
			# the narrower hotel, office and asylum spines use a single doorway.
			if theme == 2:
				w = minf(w, 4.8)
			else:
				w = 10.4 if theme == 4 or theme == 7 else minf(w, 2.4)
	return {"wall": wall, "full_open": full_open, "t": t, "w": w, "exit_sign": has_sign}


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
		2: ok = st == ANNEX_QUIET
		4: ok = st == AIR_HALL
		5: ok = st == ASY_DAYROOM
		6: ok = st == SCH_GYM
		7: ok = st == MALL_ATRIUM
		8: ok = st == PRISON_GUARD
		9: ok = st == POOL_DECK
	if not ok:
		return -1
	# Preserve Wander's cross-floor portal contract while keeping the minimalist
	# Annex genuinely sparse: about one percent of its cells qualify, versus the
	# denser set-piece floors' established rate.
	var portal_p := 0.04 if theme == 2 else 0.30
	if r01(ws, cell.x, cell.y, 501) > portal_p:
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
	var local_root := annex_room_id(ws, cell) if theme == 2 else room_id(ws, cell)
	var local_size := annex_room_size(ws, local_root) if theme == 2 \
		else room_size(ws, local_root)
	if local_root != cell or local_size != 1 \
			or not room_split(ws, cell, theme).is_empty() \
			or portal(ws, cell, theme) >= 0:
		return false
	var st := cell_style(ws, cell, theme)
	var eligible := st == STYLE_EMPTY or st == OFFICE_EMPTY \
		or st == ANNEX_QUIET or st == AIR_HALL \
		or st == ASY_DAYROOM or st == SCH_ADMIN \
		or st == MALL_ATRIUM or st == PRISON_GUARD \
		or st == POOL_DECK
	if st == POOL_DECK and eligible:
		# The facade stands on the dry deck at 1.42, which lifts its header
		# display to 4.37 — only decks with headroom to spare may carry one.
		eligible = room_height(ws, cell, theme) >= 4.45
	return eligible and r01(ws, cell.x, cell.y, 1700) < 0.28 \
		and anchor_wall(ws, cell, 1701, theme) >= 0


## What kind of room this is. Seeded by the room ROOT so every cell of a
## room agrees, and gated by room SIZE so a set piece only lands where it
## fits: slot banks and ferris wheels want a hall; a small room does not get
## a carousel.
static func cell_style(ws: int, cell: Vector2i, theme := 0) -> int:
	if theme == 2:
		if annex_corridor_axis(ws, cell) != 0:
			return ANNEX_PASSAGE
		var aroot := annex_room_id(ws, cell)
		var asize := annex_room_size(ws, aroot)
		var ar := r01(ws, aroot.x, aroot.y, 2941)
		# Wide rooms should actually exploit their footprint: they favour open
		# plans and the column/half-wall lobby grammar. Single cells stay more
		# restrained and are where quiet rooms and compressed mazes concentrate.
		if asize >= 4:
			if ar < 0.45: return ANNEX_OPEN
			if ar < 0.70: return ANNEX_LOBBY
			if ar < 0.85: return ANNEX_LONG
			if ar < 0.95: return ANNEX_MAZE
			return ANNEX_QUIET
		if asize >= 2:
			if ar < 0.40: return ANNEX_OPEN
			if ar < 0.52: return ANNEX_LOBBY
			if ar < 0.70: return ANNEX_LONG
			if ar < 0.85: return ANNEX_MAZE
			return ANNEX_QUIET
		if ar < 0.35: return ANNEX_OPEN
		if ar < 0.67: return ANNEX_QUIET
		if ar < 0.82: return ANNEX_LONG
		if ar < 0.96: return ANNEX_MAZE
		return ANNEX_LOBBY
	var cdir := corridor(ws, cell)
	if cdir != 0:
		match theme:
			1: return OFFICE_CORRIDOR
			2: return ANNEX_PASSAGE
			4: return AIR_TRANSIT
			5: return ASY_CORRIDOR
			6: return SCH_CORRIDOR
			7: return MALL_CORRIDOR
			8: return PRISON_CORRIDOR
			9: return POOL_CHANNEL
			_: return STYLE_HALLWAY
	var root := room_id(ws, cell)
	var n := room_size(ws, root)
	var r := r01(ws, root.x, root.y, 7)
	var zone := macro_zone(ws, root, theme)
	var landmark := landmark_style(ws, root, theme)
	if landmark >= 0:
		return landmark
	if theme == 9:
		# The floor is water first and rooms second, so the open basin is the
		# default everywhere and the named grammars are what interrupts it.
		if root == Vector2i.ZERO:
			return POOL_DECK
		if n >= 4:
			if r < 0.40: return POOL_GALLERY
			if r < 0.72: return POOL_BASIN
			return POOL_SOLARIUM
		if n >= 2:
			if zone == 0:
				if r < 0.44: return POOL_BASIN
				if r < 0.68: return POOL_SOLARIUM
				return POOL_GALLERY
			if zone == 1:
				if r < 0.52: return POOL_BASIN
				if r < 0.76: return POOL_DECK
				return POOL_STAIRS
			if r < 0.50: return POOL_BASIN
			if r < 0.74: return POOL_GALLERY
			return POOL_DECK
		if zone == 0:
			if r < 0.38: return POOL_BASIN
			if r < 0.60: return POOL_SOLARIUM
			if r < 0.80: return POOL_DECK
			return POOL_ALCOVE
		if zone == 1:
			if r < 0.44: return POOL_BASIN
			if r < 0.64: return POOL_STAIRS
			if r < 0.84: return POOL_DECK
			return POOL_ALCOVE
		if r < 0.36: return POOL_BASIN
		if r < 0.58: return POOL_ALCOVE
		if r < 0.80: return POOL_DECK
		return POOL_STAIRS
	if theme == 8:
		if root == Vector2i.ZERO:
			return PRISON_CELLBLOCK
		if n >= 4:
			if zone == 0: return PRISON_CELLBLOCK if r < 0.78 else PRISON_GUARD
			if zone == 1: return PRISON_MESS if r < 0.52 else PRISON_INDUSTRY
			return PRISON_GUARD if r < 0.58 else PRISON_VISITATION
		if n >= 2:
			if zone == 0: return PRISON_CELLBLOCK if r < 0.60 else PRISON_CELLS
			if zone == 1:
				if r < 0.38: return PRISON_MESS
				if r < 0.70: return PRISON_SHOWER
				return PRISON_INDUSTRY
			return PRISON_GUARD if r < 0.48 else PRISON_VISITATION
		if zone == 0: return PRISON_CELLS if r < 0.82 else PRISON_GUARD
		if zone == 1: return PRISON_SHOWER if r < 0.46 else PRISON_INDUSTRY
		return PRISON_GUARD if r < 0.56 else PRISON_VISITATION
	if theme == 7:
		if root == Vector2i.ZERO:
			return MALL_ATRIUM
		if n >= 4:
			if zone == 0: return MALL_ATRIUM if r < 0.62 else MALL_ANCHOR
			if zone == 1: return MALL_FOODCOURT if r < 0.58 else MALL_ATRIUM
			return MALL_ANCHOR if r < 0.54 else MALL_SERVICE
		if n >= 2:
			if zone == 0:
				if r < 0.50: return MALL_STORE
				if r < 0.78: return MALL_KIOSKS
				return MALL_ATRIUM
			if zone == 1: return MALL_FOODCOURT if r < 0.54 else MALL_STORE
			return MALL_SERVICE if r < 0.58 else MALL_ANCHOR
		if zone == 0: return MALL_STORE if r < 0.66 else MALL_KIOSKS
		if zone == 1: return MALL_STORE if r < 0.52 else MALL_FOODCOURT
		return MALL_SERVICE if r < 0.66 else MALL_STORE
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
		if root == Vector2i.ZERO:
			return ANNEX_OPEN
		if n >= 4:
			return ANNEX_OPEN if r < 0.70 else ANNEX_LOBBY
		if n >= 2:
			if zone == 0:
				return ANNEX_OPEN if r < 0.58 else ANNEX_LONG
			if zone == 1:
				return ANNEX_MAZE if r < 0.64 else ANNEX_OPEN
			return ANNEX_QUIET if r < 0.38 else ANNEX_MAZE
		if zone == 0:
			return ANNEX_OPEN if r < 0.58 else ANNEX_LONG
		if zone == 1:
			return ANNEX_MAZE if r < 0.64 else ANNEX_QUIET
		return ANNEX_QUIET if r < 0.62 else ANNEX_MAZE
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


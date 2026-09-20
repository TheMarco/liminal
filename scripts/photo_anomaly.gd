class_name PhotoAnomaly
extends Node3D
## One wrong thing, standing in a cell, waiting to be photographed.
##
## Several shapes share this node. PLACEMENT wedges the floor's own signature
## furniture upright into the ceiling, then lets it crash down only after its
## developed photograph leaves the screen;
## DUPLICATE stands two identical copies of it shoulder to shoulder where one
## is furniture and two are a mistake; WRITING paints a phrase on a wall that
## only the camera can see (photo-only render layer); TURNED swaps the prop
## between an ordinary eye-visible stance and a lens-only copy that tracks
## the camera; BLEED wraps a bleed prop the dressing already placed. Props are ALWAYS the floor's own — the
## owner ruled (2026-08-19) that foreign objects appear only as the bleed
## near the elevator, never scattered as anomalies. The wrongness is the
## impossible placement, the duplication, never the object's origin.
##
## The node is spawned by PhotoDirector on `chunk_built` and parented to the
## chunk, so streaming and blackout rebuilds retire and recreate it for free.
## All positions here are chunk-local (cells are 12m, chunks sit at
## cell * CELL_SIZE with y = 0). Documented state does NOT live here — the
## director owns it, so a rebuilt cell cannot resurrect a spent photograph.

enum Type { PLACEMENT, DUPLICATE, WRITING, BLEED, GIANT, RING, MISSING,
	PRINT, PORTAL, TURNED, NUMBERED_DOOR, DOORWAY, OBSTRUCTION, BOUNTY }

## Render layer bit reserved for photo-only geometry. Player cameras clear
## this bit; the raised viewfinder and snapshot camera both set it.
const PHOTO_LAYER_BIT := 19
const PHOTO_LAYER := 1 << PHOTO_LAYER_BIT
## Eye-only geometry: visible to the bare eye, cleared by the RAISED camera.
## MISSING props live here — through the lens the spot is empty.
const EYE_ONLY_LAYER_BIT := 17
const EYE_ONLY_LAYER := 1 << EYE_ONLY_LAYER_BIT
## Print-only geometry: invisible to eye AND raised viewfinder; only the
## snapshot camera includes it, so it exists solely in the developed photo.
const PRINT_LAYER_BIT := 16
const PRINT_LAYER := 1 << PRINT_LAYER_BIT

## Ordinary evidence has no invisible metre cutoff: if it is rendered,
## framed and unobstructed, the photograph can document it.
const CAPTURE_DISTANCE := INF
const CAPTURE_DISTANCE_WRITING := INF

const WRITING_FONT := preload("res://fonts/RazorKeen-Regular.otf")
const WRITING_MAX_WIDTH := 2.78 # fits every reserved 3m wall run
const WRITING_MAX_HEIGHT := 2.35
const WRITING_FLOOR_MARGIN := 0.38
const WRITING_CEILING_MARGIN := 0.25
const PORTAL_SHADER := preload("res://shaders/portal_glimpse.gdshader")
const PORTAL_GLOW_SHADER := preload("res://shaders/portal_glow.gdshader")
## CC0 Poly Haven panoramas the tear looks out into (SOURCE.md alongside).
const PORTAL_PANOS := [
	"res://textures/portals/abandoned_parking_2k.hdr",
	"res://textures/portals/hilly_terrain_01_2k.hdr",
	"res://textures/portals/quarry_04_2k.hdr",
	"res://textures/portals/construction_yard_2k.hdr",
	"res://textures/portals/outdoor_umbrellas_2k.hdr",
]

## Themes whose BLEED_PROPS row is a portable, self-contained prop and can
## therefore carry PLACEMENT/DUPLICATE. Airport luggage is a scatter set with
## per-piece centres and no footprint; prop-less themes plan WRITING only.
const PROP_THEMES := [0, 1, 2, 5, 6, 7, 9]
## PLACEMENT: enough of the furniture pierces the ceiling to read as physically
## stuck, while most of its body remains visible and photographable below it.
const CEILING_EMBED_MIN := 0.14
const CEILING_EMBED_MAX := 0.38
## GIANT: the prop at wrong scale, capped so it still fits under the cell's
## ceiling with a hand's width to spare.
const GIANT_SCALE_MAX := 2.6
## RING: lens-only circle of the room's own prop, all facing the centre.
const RING_COUNT := 5
const RING_RADIUS := 2.2

## Pre-authored, deliberately unreliable. No hints, no truths, no names.
## Camera-only writing. The voice is the building addressing the intruder:
## second person, present tense, hint-less, nameless. Distinct from the
## asylum's eye-visible ASY_SCRAWLS (patient voices, marker on plaster) —
## the two pools must not blur.
const PHRASES := [
	"STAY",
	"DON'T LEAVE",
	"IT SEES YOU",
	"KEEP WALKING",
	"NOT ALONE",
	"YOU SHOULDN'T BE HERE",
	"IT'S CLOSER",
	"LET ME IN",
	"DON'T TURN AROUND",
	"WE CAN HEAR YOU",
	"THERE IS NO EXIT",
	"STOP TAKING PICTURES",
	"YOU'RE STILL HERE",
	"WE COUNTED YOU",
	"YOU WERE FASTER YESTERDAY",
	"THE LIGHTS ARE FOR YOU",
	"IT LEARNED YOUR NAME",
	"PUT THE CAMERA DOWN",
	"THIS ONE IS OF YOU",
	"SMILE",
	"WE DEVELOP AT NIGHT",
	"THE FILM REMEMBERS",
	"YOU BLINKED",
	"BEHIND THE WALLPAPER",
	"UNDER THE CARPET TOO",
	"THE FLOOR BELOW IS AWAKE",
	"IT RIDES THE LIFT WITH YOU",
	"THE LIFT GOES ONE WAY",
	"DEEPER",
	"ALMOST DOWN",
	"YOU LIVE HERE NOW",
	"THE DOORS MOVE WHEN IT'S DARK",
	"HOLD STILL LONGER",
	"IT PRACTISES STANDING STILL",
	"DON'T FEED THE METER",
	"THE TAPES LIE",
	"WATCH THE CORNERS",
	"IT WEARS THE ROOMS",
	"NOT THAT DOOR",
	"WRONG WAY",
	"TURN BACK",
	"TOO LATE FOR THAT",
	"WHO TOLD YOU TO LOOK",
	"YOU FOUND THE WRONG ONES",
	"THERE ARE MORE OF US",
	"ONE OF THESE ROOMS IS YOURS",
	"IT SAVED YOU A SEAT",
	"THE EXIT MOVED",
	"ASK THE STATIC",
	"IT HEARD THE SHUTTER",
]

var type := Type.PLACEMENT
var id := ""
var cell := Vector2i.ZERO
var world_seed := 0
var theme := 0
## Dev (--photo-debug): writing renders on the normal camera too.
var debug_visible := false
## PLACEMENT's furniture pivot. It stays completely still while lodged in the
## slab; motion begins only when the developed print has left the screen.
var _placement_pivot: Node3D
var _placement_rest_y := 0.0
var _points: Array[Vector3] = []   # chunk-local sample points
var _evidence_roots: Array[Node3D] = []
var _evidence_corners: Array[Vector3] = []
var _writing_label: Label3D
## Colliders the anomaly itself carries (GIANT's walk-blocker). The camera's
## occlusion rays must ignore them — sample points sit inside the prop, so
## its own body otherwise occludes it from every stance (found 2026-08-19:
## a required GIANT was uncapturable from 16/16 stances).
var _body_rids: Array[RID] = []
## Anomaly visual roots remain present after documentation.
var _resolvables: Array[Node] = []
var _glow: OmniLight3D
var _glow_source: MeshInstance3D
var _floor_y := 0.0
## PORTAL only: the theme whose air the tear looks out into (-1 = the
## outside, a dead grey). Set by the director from the descent order.
var next_theme := -1
## TURNED only: the eye-visible copy at its ordinary yaw, and the lens-only
## copy that tracks the camera. The eye pivot survives resolve() — turned.
var _turned_eye: Node3D
var _turned_lens: Node3D
var _number_plate: Label3D
var _number_print: Node3D
var _doorway_resolve := Callable()
## Observational name supplied by an experimental cross-realm doorway.
var realm_destination := ""
var _realm_centre := Vector3.ZERO
var _realm_width := 0.0
var _realm_height := 0.0


func configure(p_id: String, p_type: int, p_cell: Vector2i, p_world_seed: int,
		p_theme: int, wall_dir: int, wall_along: float) -> void:
	id = p_id
	type = p_type as Type
	cell = p_cell
	world_seed = p_world_seed
	theme = p_theme
	var floor_h := Chunk.cell_floor_h(world_seed, cell, theme)
	_floor_y = floor_h
	set_process(false)   # only TURNED tracks the camera per frame
	# configure() is called before add_child, so debug_visible is already set.
	match type:
		Type.TURNED:
			_build_turned(floor_h)
		Type.WRITING, Type.PRINT:
			# Keep the legacy PRINT type/id for deterministic plans and saves.
			# All writing must be discoverable before spending a photograph.
			_build_writing(floor_h, wall_dir, wall_along)
		Type.DUPLICATE:
			_build_props(floor_h, 2)
		Type.GIANT:
			_build_giant(floor_h)
		Type.RING:
			_build_ring(floor_h)
		Type.MISSING:
			_build_missing(floor_h)
		Type.PORTAL:
			_build_portal(floor_h, wall_dir, wall_along)
		_:
			_build_props(floor_h, 1)
	if debug_visible:
		print("photo anomaly %s built, points %s" % [id, str(photo_points())])


## Global sample points the camera tests for framing. All must pass the
## frustum-and-sight checks for the shot to count.
func photo_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	if is_instance_valid(_writing_label):
		# Test the whole phrase, not just its centre. Label3D's bounds include
		# wrapping and the actual font, so long/tall writing stays photographable.
		var box := _writing_label.get_aabb()
		if box.size.length_squared() > 0.00001:
			for i in 8:
				out.append(_writing_label.to_global(box.get_endpoint(i)))
			return out
	for p in _points:
		out.append(to_global(p))
	return out


## Geometry for the evidence mark is intentionally separate from the sparse
## visibility probes. Use every visible mesh/text bound, including both copies
## of a duplicate, all ring members, and the footprint of an absent prop.
func evidence_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	if not _evidence_corners.is_empty():
		for point in _evidence_corners:
			out.append(to_global(point))
	elif not _evidence_roots.is_empty():
		for visual in _evidence_roots:
			if is_instance_valid(visual):
				_append_evidence_geometry(visual, out, true)
	else:
		_append_evidence_geometry(self, out, type == Type.MISSING)
	return photo_points() if out.is_empty() else out


func _append_evidence_geometry(node: Node, out: Array[Vector3], include_eye: bool) -> void:
	if node is Node3D and not (node as Node3D).visible:
		return
	if node is MeshInstance3D or node is Label3D:
		var visual := node as VisualInstance3D
		var mask := 1 | PHOTO_LAYER | PRINT_LAYER | (EYE_ONLY_LAYER if include_eye else 0)
		if visual.layers & mask:
			var box: AABB = visual.get_aabb()
			for i in 8:
				var point := visual.to_global(box.get_endpoint(i))
				# The buried top of ceiling furniture is not part of the evidence.
				if type == Type.PLACEMENT and is_instance_valid(_placement_pivot):
					point.y = minf(point.y, global_position.y + Chunk.cell_ceil_h(world_seed, cell, theme))
				out.append(point)
	for child in node.get_children():
		_append_evidence_geometry(child, out, include_eye)


func configure_realm_destination(destination: String, seal: PhotoDoorSeal) -> void:
	realm_destination = destination
	_realm_centre = to_local(seal.to_global(seal.centre))
	_realm_width = seal.width
	_realm_height = seal.height


## A live realm window can fill the entire viewfinder at close range. Its
## frame corners need not fit: a clear aim into its aperture is sufficient.
## Other anomalies retain their existing whole-subject framing requirement.
func framing_points(cam: Camera3D) -> Array[Vector3]:
	if _realm_width <= 0.0:
		return photo_points()
	var points: Array[Vector3] = []
	var normal := global_basis * _facing
	var centre := to_global(_realm_centre + _facing * 0.20)
	var forward := -cam.global_basis.z
	var denominator := forward.dot(normal)
	if denominator >= -0.001:
		return points
	var distance := (centre - cam.global_position).dot(normal) / denominator
	if distance <= 0.0 or distance > capture_distance():
		return points
	var hit := cam.global_position + forward * distance
	var local_hit := to_local(hit) - _realm_centre
	var across := Vector3.FORWARD if absf(_facing.x) > 0.5 else Vector3.RIGHT
	if absf(local_hit.dot(across)) > _realm_width * 0.5 - 0.06 \
			or local_hit.y < 0.08 or local_hit.y > _realm_height - 0.08:
		return points
	points.append(hit)
	return points


## A bleed prop the dressing already placed becomes photographable evidence:
## no visuals of its own, just sample points over the existing prop. One
## documentation credit per floor is enforced by the director, not here.
func configure_bleed(p_id: String, p_cell: Vector2i,
		points: Array[Vector3], visuals: Array[Node3D] = []) -> void:
	id = p_id
	type = Type.BLEED
	cell = p_cell
	_points = points
	_evidence_roots = visuals


func configure_doorway(seal: PhotoDoorSeal, at: Vector2i,
		when_resolved: Callable) -> void:
	id = seal.photo_id
	type = Type.OBSTRUCTION if seal.obstruction else Type.DOORWAY
	theme = seal.theme
	cell = at
	_doorway_resolve = when_resolved
	var direction: Vector2i = WorldGen.DIRV[seal.dir]
	_facing = -Vector3(direction.x, 0.0, direction.y)
	# Points sit just in front of the still-solid wall. Other walls/furniture
	# continue to occlude the shot; never exclude an entire chunk's physics.
	var surface_depth := seal.obstruction_depth + 0.08 if seal.obstruction else 0.4
	var centre := seal.centre + _facing * surface_depth
	var across := Vector3.FORWARD if seal.dir < 2 else Vector3.RIGHT
	if seal.obstruction and is_instance_valid(seal.fill):
		_evidence_roots = [seal.fill]
	else:
		for side in [-1.0, 1.0]:
			for y in [0.0, seal.height]:
				_evidence_corners.append(centre + across * seal.width * 0.5 * side + Vector3.UP * float(y))
	for side in [-1.0, 1.0]:
		for y in [0.4, seal.height - 0.25]:
			_points.append(centre + across * seal.width * 0.38 * side \
				+ Vector3.UP * float(y))


## Room-side normal for WRITING (the label faces back into its room), zero
## for the free-standing types. The camera uses it to reject detections from
## the far side of the wall: the occlusion ray tolerance cannot tell "in
## front of the writing" from "behind its wall" on its own, because the
## label floats less than the tolerance proud of the surface.
var _facing := Vector3.ZERO


func facing_normal() -> Vector3:
	return _facing


## One terse line for the counted-photo caption: the circle on the print
## says where, this says what. Ambiguity-safe — names the wrongness, never
## the cause.
func count_caption() -> String:
	if not realm_destination.is_empty():
		return "THAT ROOM DOES NOT BELONG HERE"
	match type:
		Type.OBSTRUCTION:
			return PhotoObstruction.caption(theme)
		Type.DOORWAY:
			return "THERE WAS NO DOOR HERE"
		Type.NUMBERED_DOOR:
			return "THE FILM SAYS 106"
		Type.MISSING:
			return "THE CAMERA SAYS IT IS NOT THERE"
		Type.PORTAL:
			return "THAT IS NOT WHAT'S BEHIND THIS WALL"
		Type.PRINT:
			return "\"%s\" — ONLY THE CAMERA SEES IT" % phrase_for(
				world_seed, cell)
		Type.PLACEMENT:
			return "THE CEILING IS HOLDING IT"
		Type.DUPLICATE:
			# Name the impossibility, never the arrangement — "THERE ARE
			# TWO" read as a shrug (owner, 2026-08-20).
			return "TWO, WHEN YOU AREN'T LOOKING"
		Type.GIANT:
			return "IT SHOULD NOT FIT IN HERE"
		Type.TURNED:
			return "IT TURNED FOR THE PICTURE"
		Type.RING:
			return "THEY MEET WHEN THE ROOM IS EMPTY"
		Type.WRITING:
			return "\"%s\"" % phrase_for(world_seed, cell)
		Type.BLEED:
			return "IT BELONGS TO THE FLOOR BELOW"
	return ""


## Observational album notes, frozen at shutter time rather than regenerated
## from a room that may later change. These do not grant evidence credit.
func album_description(documented := false) -> String:
	if not realm_destination.is_empty():
		return "A doorway into %s, inside another floor." % realm_destination
	match type:
		Type.OBSTRUCTION:
			return PhotoObstruction.description(theme, documented)
		Type.WRITING, Type.PRINT:
			return 'Writing visible only through the camera: "%s".' % phrase_for(world_seed, cell)
		Type.NUMBERED_DOOR:
			return "Door 106. It read 104 before the first photograph." if documented \
				else "The camera shows 106; the door reads 104."
		Type.DOORWAY:
			return "A passage opened by an earlier photograph." if documented \
				else "A doorway visible only through the camera."
		Type.PLACEMENT:
			return "An object lodged in the ceiling, still visible through the camera."
		Type.DUPLICATE:
			return "Two identical objects in a space that looks empty without the camera."
		Type.TURNED:
			return "An object that turns to face the camera."
		Type.GIANT:
			return "A piece of furniture far larger than it should be."
		Type.RING:
			return "A circle of objects visible only through the camera."
		Type.MISSING:
			return "An object visible to the eye is missing from this photograph."
		Type.PORTAL:
			return "A view through the wall into another place."
		Type.BLEED:
			return "An object from the floor below, out of place here."
	return "An unusual detail in the building."


func occlusion_excludes() -> Array[RID]:
	return _body_rids


func capture_distance() -> float:
	return CAPTURE_DISTANCE


static func phrase_for(ws: int, at: Vector2i) -> String:
	return PHRASES[WorldGen.h(ws, at.x, at.y, 9241) % PHRASES.size()]


## Somewhere on this cell's walls with enough clear surface to write on.
## Every wall edge carries a doorway (t = centre along the edge, w = width),
## so the phrase goes on the wider stretch beside the opening. Returns
## {dir, along} or {} when no wall offers MIN_WRITING_RUN metres. Pure over
## route data, so the planner and the audit can prove placement sceneless.
const MIN_WRITING_RUN := 3.0

static func writing_spot_for(route: DescentRoute, at: Vector2i) -> Dictionary:
	# Corridor cells line their walls with interior surfaces inset from the
	# canonical edge; writing on the edge plane would hide behind the lining.
	if WorldGen.corridor(route.world_seed, at) != 0:
		return {}
	# Annex passage cells build a second, variable-width corridor shell inside
	# their canonical perimeter. The outer wall can therefore pass every route
	# test while remaining completely buried behind an authored corner mass.
	if route.theme == 2 \
			and WorldGen.cell_style(route.world_seed, at, route.theme) \
			== WorldGen.ANNEX_PASSAGE:
		return {}
	var furnished_walls := _theme_furnished_walls(route, at)
	var start := WorldGen.h(route.world_seed, at.x, at.y, 9257) % 4
	for i in 4:
		var dir := (start + i) % 4
		if furnished_walls.has(dir):
			continue
		var info := route.edge_info(at, dir)
		if not bool(info.get("wall", false)) \
				or bool(info.get("full_open", false)):
			continue
		var t := float(info.get("t", WorldGen.CELL_SIZE * 0.5))
		var w := float(info.get("w", 0.0))
		var left_run := (t - w * 0.5) - 0.8
		var right_run := 11.2 - (t + w * 0.5)
		var run := maxf(left_run, right_run)
		if run < MIN_WRITING_RUN:
			continue
		var along := (0.8 + left_run * 0.5) if left_run >= right_run \
			else (t + w * 0.5 + right_run * 0.5)
		return {"dir": dir, "along": along}
	return {}


## Scene-aware counterpart used when the chunk has finished its authored
## furniture. A wall is acceptable only when a real player capsule can stand
## in front of it and the whole approach between wall and stance is clear.
## Alternate along-wall positions rescue dense rooms where the topology's
## preferred midpoint happens to be occupied by a lounge or workstation.
static func writing_spot_for_chunk(route: DescentRoute, at: Vector2i,
		chunk: Chunk) -> Dictionary:
	if chunk == null:
		return writing_spot_for(route, at)
	for spot in _writing_spot_candidates(route, at):
		var dir := int(spot["dir"])
		if chunk._edge_info(at, dir).has("photo_door_id"):
			continue # writing must not float across the lens-only aperture
		var along := float(spot["along"])
		if _writing_approach_clear(chunk, dir, along) \
				and _writing_sightline_clear(chunk, dir, along):
			return spot
	return {}


static func _writing_spot_candidates(route: DescentRoute,
		at: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if WorldGen.corridor(route.world_seed, at) != 0:
		return out
	if route.theme == 2 \
			and WorldGen.cell_style(route.world_seed, at, route.theme) \
			== WorldGen.ANNEX_PASSAGE:
		return out
	var furnished_walls := _theme_furnished_walls(route, at)
	var start := WorldGen.h(route.world_seed, at.x, at.y, 9257) % 4
	for i in 4:
		var dir := (start + i) % 4
		if furnished_walls.has(dir):
			continue
		var info := route.edge_info(at, dir)
		if not bool(info.get("wall", false)) \
				or bool(info.get("full_open", false)):
			continue
		var t := float(info.get("t", WorldGen.CELL_SIZE * 0.5))
		var w := float(info.get("w", 0.0))
		var spans := [Vector2(0.8, t - w * 0.5),
			Vector2(t + w * 0.5, 11.2)]
		for span in spans:
			var run: float = span.y - span.x
			if run < MIN_WRITING_RUN:
				continue
			var lo: float = span.x + 1.45
			var hi: float = span.y - 1.45
			var alongs := [(lo + hi) * 0.5]
			if hi - lo > 1.2:
				alongs.append(lerpf(lo, hi, 0.20))
				alongs.append(lerpf(lo, hi, 0.80))
			for along in alongs:
				out.append({"dir": dir, "along": along})
	return out


static func _writing_approach_clear(chunk: Chunk, dir: int,
		along: float) -> bool:
	var floor_h := Chunk.cell_floor_h(chunk.wseed, chunk.cell, chunk.theme)
	var wall := Vector3(11.55, floor_h, along)
	var inward := Vector3(-1, 0, 0)
	match dir:
		1:
			wall = Vector3(0.45, floor_h, along)
			inward = Vector3(1, 0, 0)
		2:
			wall = Vector3(along, floor_h, 11.55)
			inward = Vector3(0, 0, -1)
		3:
			wall = Vector3(along, floor_h, 0.45)
			inward = Vector3(0, 0, 1)
	for distance in [1.0, 1.8, 2.6, 3.4, 4.2]:
		if not chunk._floor_spot_clear(wall + inward * float(distance),
				0.38, 1.8):
			return false
	return true


## Prove at least one real eye-height view of the writing's maximum fitted
## rectangle. Capsule clearance alone is insufficient: cubicle partitions and
## other side furniture can leave a walkable lane while hiding one of the label
## corners, and PhotoCamera correctly requires every corner to be visible.
static func _writing_sightline_clear(chunk: Chunk, dir: int,
		along: float) -> bool:
	var floor_h := Chunk.cell_floor_h(chunk.wseed, chunk.cell, chunk.theme)
	var dirv3 := Vector3(WorldGen.DIRV[dir].x, 0.0, WorldGen.DIRV[dir].y)
	var inward := -dirv3
	var across := Vector3.FORWARD if absf(dirv3.x) > 0.5 else Vector3.RIGHT
	var half := WorldGen.CELL_SIZE * 0.5
	var plane := half + signf(dirv3.x + dirv3.z) * (half - 0.45)
	var centre := Vector3(plane, floor_h + 1.52, along) \
		if dirv3.x != 0.0 else Vector3(along, floor_h + 1.52, plane)
	var bottom := floor_h + WRITING_FLOOR_MARGIN
	var top := Chunk.cell_ceil_h(chunk.wseed, chunk.cell, chunk.theme) \
		- WRITING_CEILING_MARGIN
	var height := minf(WRITING_MAX_HEIGHT, top - bottom)
	centre.y = clampf(centre.y, bottom + height * 0.5, top - height * 0.5)
	var targets: Array[Vector3] = [centre]
	for side in [-1.0, 1.0]:
		for vertical in [-1.0, 1.0]:
			targets.append(centre + across * WRITING_MAX_WIDTH * 0.5 * side \
				+ Vector3.UP * height * 0.5 * vertical)
	# At 3.5m the maximum fitted phrase clears the raised camera's 58-degree
	# framing. Later stances rescue a view whose near point is beside furniture.
	for distance in [3.5, 4.2]:
		var stance := centre + inward * float(distance)
		stance.y = floor_h
		# Mirrors Player's 0.38m x 1.8m capsule and 1.377m eye without a
		# PhotoAnomaly <-> Player script dependency cycle.
		if not chunk._floor_spot_clear(stance, 0.38, 1.8):
			continue
		var eye := stance + Vector3.UP * 1.377
		var all_clear := true
		for target in targets:
			if not chunk._segment_clear(eye, target):
				all_clear = false
				break
		if all_clear:
			return true
	return false


## Theme builders can place an entire authored structure in front of an
## otherwise valid canonical wall. Those walls are not evidence surfaces: a
## phrase behind prison bars or a serving line exists mathematically but has
## no legal view from the room. Keep this pure and mirror the builder's exact
## deterministic wall choices so planning and runtime rebuilds agree.
static func _theme_furnished_walls(route: DescentRoute,
		at: Vector2i) -> Array[int]:
	var blocked: Array[int] = []
	if route.theme != 8:
		return blocked
	var style := WorldGen.cell_style(route.world_seed, at, route.theme)
	if style == WorldGen.PRISON_CELLBLOCK:
		var root := WorldGen.room_id(route.world_seed, at)
		var along_x := WorldGen.r01(route.world_seed, root.x, root.y,
			1840) < 0.5
		blocked = [2, 3]
		if not along_x:
			blocked = [0, 1]
		return blocked
	if style in [WorldGen.PRISON_CELLS, WorldGen.PRISON_MESS,
			WorldGen.PRISON_SHOWER]:
		# Each of these builders claims the first solid wall: respectively a
		# barred cell strip, serving line, or bank of shower fixtures.
		for dir in 4:
			var info := route.edge_info(at, dir)
			if bool(info.get("wall", false)) \
					and not bool(info.get("full_open", false)):
				blocked.append(dir)
				break
	return blocked


## The room noticed being photographed: a counted shot resolves its
## anomaly. Ceiling furniture drops, lens-only and eye-only things are simply
## gone afterwards, writings leave the wall, the giant's glow dies — and the
## TURNED prop alone escalates: the real one now faces the player. Chunk
## rebuilds skip documented anomalies entirely, so the resolution holds.
func resolve(restoring := false) -> void:
	match type:
		Type.DOORWAY, Type.OBSTRUCTION:
			if _doorway_resolve.is_valid():
				_doorway_resolve.call()
				_doorway_resolve = Callable()
		Type.NUMBERED_DOOR:
			if is_instance_valid(_number_plate):
				_number_plate.text = "106"
		Type.PLACEMENT:
			_release_ceiling_furniture(restoring)
		Type.TURNED:
			_turn_real_prop()
		_:
			pass # Documentation awards proof; it does not erase the anomaly.


## PLACEMENT and TURNED are the anomalies whose resolution is a visible
## payoff. The camera holds them until the paper-photo review closes:
## PLACEMENT's fall would otherwise complete behind an opaque black review
## card, and TURNED's point is that the prop has moved WHILE the paper was
## up — the player lowers the print and it is facing them.
func resolves_after_review() -> bool:
	return type in [Type.PLACEMENT, Type.TURNED, Type.NUMBERED_DOOR, Type.DOORWAY, Type.OBSTRUCTION]


## The real prop turns after review; the lens copy keeps following the viewer.
func _turn_real_prop() -> void:
	if _turned_eye == null or not is_instance_valid(_turned_eye):
		return
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var to_cam := cam.global_position - _turned_eye.global_position
		if Vector2(to_cam.x, to_cam.z).length_squared() > 0.04:
			_turned_eye.rotation.y = atan2(to_cam.x, to_cam.z)
	_set_layer(_turned_eye, EYE_ONLY_LAYER)


func _release_ceiling_furniture(restoring := false) -> void:
	if _placement_pivot == null or not is_instance_valid(_placement_pivot):
		return
	var pivot := _placement_pivot
	_placement_pivot = null
	# Keep the impossible ceiling pose in the lens while the physical prop falls.
	var lens_pose := pivot.duplicate() as Node3D
	lens_pose.name = "DocumentedCeilingPose"
	add_child(lens_pose)
	_set_photo_only(lens_pose)
	_set_layer(pivot, EYE_ONLY_LAYER)
	if is_instance_valid(_glow):
		_glow.light_cull_mask = PHOTO_LAYER
	if is_instance_valid(_glow_source):
		_set_layer(_glow_source, PHOTO_LAYER)
	if restoring:
		pivot.position.y = _placement_rest_y
		var sign_value := -1.0 \
			if WorldGen.h(world_seed, cell.x, cell.y, 9383) % 2 == 0 else 1.0
		pivot.rotation.x = sign_value * 0.06
		pivot.rotation.z = -sign_value * 0.04
		return
	var distance := maxf(0.1, pivot.position.y - _placement_rest_y)
	var duration := clampf(sqrt(2.0 * distance / 9.8), 0.32, 0.62)
	var tilt_sign := -1.0 \
		if WorldGen.h(world_seed, cell.x, cell.y, 9383) % 2 == 0 else 1.0
	var drop := create_tween()
	drop.set_parallel(true)
	drop.tween_property(pivot, "position:y", _placement_rest_y, duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	# Gentle: the rest height is now the true mesh bottom on the carpet, so a
	# hard tilt would visibly bury one edge and hang the other (the old 0.16
	# was tuned when the whole prop floated and never met the floor).
	drop.tween_property(pivot, "rotation:x", tilt_sign * 0.06, duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	drop.tween_property(pivot, "rotation:z", -tilt_sign * 0.04, duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	drop.chain().tween_callback(_ceiling_furniture_impact.bind(pivot))
	# A short, heavy rebound keeps the landing from reading as another smooth
	# scripted translation.
	drop.chain().tween_property(pivot, "position:y",
		_placement_rest_y + 0.055, 0.055).set_trans(Tween.TRANS_QUAD)
	drop.chain().tween_property(pivot, "position:y",
		_placement_rest_y, 0.085).set_ease(Tween.EASE_IN) \
		.set_trans(Tween.TRANS_QUAD)


func _ceiling_furniture_impact(pivot: Node3D) -> void:
	if not is_instance_valid(pivot):
		return
	var thud := AudioStreamPlayer3D.new()
	thud.stream = SoundBank.thud()
	thud.volume_db = -1.0
	thud.max_distance = 24.0
	thud.position = pivot.position
	add_child(thud)
	thud.play()
	thud.finished.connect(thud.queue_free)


## A doorway-shaped tear in the wall, camera-only, looking out onto
## somewhere that cannot be there: parallax murk tinted toward the next
## floor's air, or a dead grey "outside" on the last floors. The image is
## the camera's claim, never a confirmed place — the mystery contract holds.
func _build_portal(floor_h: float, wall_dir: int, wall_along: float) -> void:
	var dir := maxi(wall_dir, 0)
	var half := WorldGen.CELL_SIZE * 0.5
	var dirv3 := Vector3(WorldGen.DIRV[dir].x, 0.0, WorldGen.DIRV[dir].y)
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.5, 2.5)
	quad.mesh = mesh
	var mat := ShaderMaterial.new()
	mat.shader = PORTAL_SHADER
	var pano_path: String = PORTAL_PANOS[WorldGen.h(world_seed, cell.x,
		cell.y, 9337) % PORTAL_PANOS.size()]
	mat.set_shader_parameter("pano", load(pano_path))
	mat.set_shader_parameter("yaw_offset",
		WorldGen.r01(world_seed, cell.x, cell.y, 9341))
	mat.set_shader_parameter("seed_phase",
		float(WorldGen.h(world_seed, cell.x, cell.y, 9331) % 977))
	quad.material_override = mat
	quad.layers = (1 | PHOTO_LAYER) if debug_visible else PHOTO_LAYER
	quad.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plane := half + signf(dirv3.x + dirv3.z) * (half - 0.42)
	quad.position = Vector3(plane, floor_h + 1.45, wall_along) \
		if dirv3.x != 0.0 else Vector3(wall_along, floor_h + 1.45, plane)
	quad.rotation.y = atan2(dirv3.x, dirv3.z) + PI
	add_child(quad)
	_resolvables.append(quad)
	# The outer energy bleed: a second, slightly larger additive quad a
	# hair proud of the crack so the glow feathers onto the wall.
	var glow_quad := MeshInstance3D.new()
	var glow_mesh := QuadMesh.new()
	glow_mesh.size = mesh.size * 1.35
	glow_quad.mesh = glow_mesh
	var glow_mat := ShaderMaterial.new()
	glow_mat.shader = PORTAL_GLOW_SHADER
	glow_mat.set_shader_parameter("seed_phase",
		float(WorldGen.h(world_seed, cell.x, cell.y, 9331) % 977))
	glow_quad.material_override = glow_mat
	glow_quad.layers = quad.layers
	glow_quad.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	glow_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow_quad.position = quad.position + dirv3 * -0.02
	glow_quad.rotation.y = quad.rotation.y
	add_child(glow_quad)
	_resolvables.append(glow_quad)
	_points = [quad.position, quad.position + Vector3(0, 0.9, 0)]
	_facing = -dirv3


## TURNED: to the bare eye the room's own furniture stands at an ordinary
## hash yaw; through the raised lens the same object has rotated to face the
## camera, and keeps facing it as the player strafes — the anomaly passes the
## player's own test. The developed print catches it looking dead into the
## shot. The one anomaly that resolves by getting WORSE: when the review
## closes, the real prop is turned toward the player too. The eye copy
## carries a real collider (ordinary furniture must block), so like RING the
## build demands a proven clear floor spot and degrades to the compact
## ceiling form in dense rooms — a collider may never claim a doorway lane.
func _build_turned(floor_h: float) -> void:
	var row: Array = Chunk.BLEED_PROPS.get(theme, [])
	if row.is_empty():
		_build_universal_photo(floor_h)
		return
	var scene := load(row[0]) as PackedScene
	if scene == null:
		return
	var scl := float(row[1])
	var centre_off: Vector3 = row[2]
	var extents: Vector3 = row[3]
	var footprint := maxf(1.0, maxf(extents.x, extents.z) * 0.5 + 0.10)
	var spot := _find_spot(floor_h, footprint, maxf(extents.y, 2.1), false)
	if spot == Vector3.INF:
		type = Type.PLACEMENT
		_build_props(floor_h, 1)
		return
	var yaw := float(WorldGen.h(world_seed, cell.x, cell.y, 9283) % 8) \
		* PI * 0.25
	_turned_eye = Node3D.new()
	_turned_eye.position = spot
	_turned_eye.rotation.y = yaw
	add_child(_turned_eye)
	var eye_inst := scene.instantiate() as Node3D
	eye_inst.scale = Vector3.ONE * scl
	eye_inst.position = -centre_off * scl
	_turned_eye.add_child(eye_inst)
	_set_layer(eye_inst, EYE_ONLY_LAYER)
	if extents != Vector3.ZERO:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = extents
		shape.shape = box
		shape.position = Vector3(0, extents.y * 0.5, 0)
		body.add_child(shape)
		_turned_eye.add_child(body)
		_body_rids.append(body.get_rid())
	_turned_lens = Node3D.new()
	_turned_lens.position = spot
	_turned_lens.rotation.y = yaw
	add_child(_turned_lens)
	var lens_inst := scene.instantiate() as Node3D
	lens_inst.scale = Vector3.ONE * scl
	lens_inst.position = -centre_off * scl
	_turned_lens.add_child(lens_inst)
	_set_photo_only(lens_inst)
	_resolvables.append(_turned_lens)
	var h := maxf(extents.y, 1.6)
	_points = [spot + Vector3(0, h * 0.45, 0), spot + Vector3(0, h * 0.8, 0)]
	set_process(true)


## The lens copy tracks the camera with a slight lag — instant tracking
## reads as a mechanism, the lag reads as something moving. Runs whether the
## camera is raised or not (the copy is photo-layer-only, so the tracking is
## invisible to the bare eye and costs one atan2).
func _process(delta: float) -> void:
	if _turned_lens == null or not is_instance_valid(_turned_lens):
		set_process(false)
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var to_cam := cam.global_position - _turned_lens.global_position
	if Vector2(to_cam.x, to_cam.z).length_squared() < 0.04:
		return
	_turned_lens.rotation.y = lerp_angle(_turned_lens.rotation.y,
		atan2(to_cam.x, to_cam.z), minf(1.0, delta * 5.0))


func _build_missing(floor_h: float) -> void:
	var row: Array = Chunk.BLEED_PROPS.get(theme, [])
	if row.is_empty():
		return
	var scene := load(row[0]) as PackedScene
	if scene == null:
		return
	var scl := float(row[1])
	var centre_off: Vector3 = row[2]
	var extents: Vector3 = row[3]
	var spot := _find_spot(floor_h, 1.0, maxf(extents.y, 1.0))
	var yaw := float(WorldGen.h(world_seed, cell.x, cell.y, 9283) % 8) \
		* PI * 0.25
	var pivot := Node3D.new()
	pivot.position = spot
	pivot.rotation.y = yaw
	add_child(pivot)
	var inst := scene.instantiate() as Node3D
	inst.scale = Vector3.ONE * scl
	inst.position = -centre_off * scl
	pivot.add_child(inst)
	_set_layer(inst, EYE_ONLY_LAYER)
	if extents != Vector3.ZERO:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = extents
		shape.shape = box
		shape.position = Vector3(0, extents.y * 0.5, 0)
		body.add_child(shape)
		pivot.add_child(body)
		_body_rids.append(body.get_rid())
	_resolvables.append(pivot)
	_points = [spot + Vector3(0, maxf(extents.y, 1.0) * 0.5, 0),
		spot + Vector3(0, maxf(extents.y, 1.0) * 0.85, 0)]


func _build_writing(floor_h: float, wall_dir: int, wall_along: float) -> void:
	var dir := maxi(wall_dir, 0)
	var half := WorldGen.CELL_SIZE * 0.5
	var dirv3 := Vector3(WorldGen.DIRV[dir].x, 0.0, WorldGen.DIRV[dir].y)
	var label := Label3D.new()
	_writing_label = label
	label.text = phrase_for(world_seed, cell)
	label.font = WRITING_FONT
	label.font_size = 220
	label.pixel_size = 0.0034
	label.width = 820.0
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = Color(0.88, 0.84, 0.76, 0.95)
	label.outline_size = 0
	label.layers = (1 | PHOTO_LAYER) if debug_visible else PHOTO_LAYER
	label.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# Walls carry their thickness inward from the canonical edge, so the
	# writing floats a hand's width proud of the paper, never inside it.
	var plane := half + signf(dirv3.x + dirv3.z) * (half - 0.45)
	label.position = Vector3(plane, floor_h + 1.52, wall_along) \
		if dirv3.x != 0.0 else Vector3(wall_along, floor_h + 1.52, plane)
	# Face back into the room.
	label.rotation.y = atan2(dirv3.x, dirv3.z) + PI
	add_child(label)
	# Label3D shapes/wraps its glyphs on the deferred queue. Wait for those
	# actual bounds before fitting, and never display the oversized first pose.
	label.hide()
	_fit_writing_to_wall.call_deferred()
	_resolvables.append(label)
	_points = [label.position]
	_facing = -dirv3


func _fit_writing_to_wall() -> void:
	if not is_instance_valid(_writing_label):
		return
	var label := _writing_label
	var bounds := label.get_aabb()
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	var floor_y := _floor_y + WRITING_FLOOR_MARGIN
	var ceiling_y := Chunk.cell_ceil_h(world_seed, cell, theme) \
		- WRITING_CEILING_MARGIN
	var available_height := minf(WRITING_MAX_HEIGHT, ceiling_y - floor_y)
	var fit := minf(1.0, minf(WRITING_MAX_WIDTH / bounds.size.x,
		available_height / bounds.size.y))
	# Scale the shaped geometry, not pixel_size: bounds/framing are correct
	# immediately, without needing another deferred glyph rebuild.
	label.scale = Vector3.ONE * fit
	var bottom := bounds.position.y * fit
	var top := bounds.end.y * fit
	label.position.y = clampf(_floor_y + 1.52, floor_y - bottom, ceiling_y - top)
	_points = [label.position]
	label.show()


func _build_props(floor_h: float, count: int) -> void:
	var row: Array = Chunk.BLEED_PROPS.get(theme, [])
	if row.is_empty():
		_build_universal_photo(floor_h)
		return
	var scene := load(row[0]) as PackedScene
	if scene == null:
		return
	var scl := float(row[1])
	var centre_off: Vector3 = row[2]
	var extents: Vector3 = row[3]
	# Search the built room, not just six lucky random points. The exhaustive
	# lattice and doorway-lane fallback share the same collision bookkeeping as
	# authored furniture, so a planned prop cannot exist inside the set dressing.
	var spacing := maxf(0.72, extents.x + 0.10)
	var footprint := maxf(1.0, maxf(extents.x, extents.z) * 0.5
		+ (spacing * 0.5 if count > 1 else 0.10))
	var spot := _find_spot(floor_h, footprint, maxf(extents.y, 2.1))
	var yaw := float(WorldGen.h(world_seed, cell.x, cell.y, 9283) % 8) \
		* PI * 0.25
	if count == 1:
		# PLACEMENT: ordinary furniture in its ordinary upright orientation,
		# except its top has been driven through the ceiling. It remains rigidly
		# still until the photograph has developed and gameplay returns.
		#
		# Both poses come from the MEASURED mesh bounds, never the BLEED_PROPS
		# extents: those are collision boxes for foot-origined models, and
		# reading them as a centred AABB parked every dropped prop half its
		# own box height in the air (reported 2026-08-20 — fallen furniture
		# floated 0.4-0.95m off the carpet).
		var inst := scene.instantiate() as Node3D
		inst.scale = Vector3.ONE * scl
		inst.position = -centre_off * scl
		var span := [INF, -INF]
		_visual_span(inst, inst.transform, span)
		var bottom := 0.0 if is_inf(float(span[0])) else float(span[0])
		var top := maxf(extents.y, 0.6) \
			if is_inf(float(span[1])) else float(span[1])
		var height := maxf(top - bottom, 0.3)
		var ceil_h := Chunk.cell_ceil_h(world_seed, cell, theme)
		var embed := clampf(height * 0.22,
			CEILING_EMBED_MIN, CEILING_EMBED_MAX)
		var pivot_y := ceil_h - top + embed
		_placement_rest_y = floor_h - bottom + 0.004
		_placement_pivot = Node3D.new()
		_placement_pivot.position = Vector3(spot.x, pivot_y, spot.z)
		_placement_pivot.rotation.y = yaw
		add_child(_placement_pivot)
		_placement_pivot.add_child(inst)
		_glow = OmniLight3D.new()
		_glow.light_color = Color(0.72, 0.82, 1.0)
		_glow.light_energy = 0.48
		_glow.omni_range = 4.2
		_glow.omni_attenuation = 1.4
		_glow.shadow_enabled = false
		_glow.position = Vector3(spot.x, pivot_y + bottom - 0.25, spot.z)
		_glow.set_meta("visible_source", "anomaly_cold_mote")
		add_child(_glow)
		_glow_source = _visible_anomaly_source(_glow.position)
		# Sample only the portion below the slab; a point embedded in the ceiling
		# would make an otherwise obvious anomaly fail the line-of-sight test.
		_points = [
			Vector3(spot.x, pivot_y + bottom + height * 0.2, spot.z),
			Vector3(spot.x, pivot_y + bottom + height * 0.5, spot.z)]
	else:
		# DUPLICATE: two identical copies, identical yaw, near-touching —
		# and lens-only. To the eye the floor is empty; through the raised
		# viewfinder two of the room's own furniture stand where nothing is.
		# Eye-visible duplicates read as furniture in prop-rich themes (a
		# playtest raged at two slot machines inside a casino, 2026-08-19),
		# so like the writing, the wrongness exists only on the photo layer.
		var side := Vector3(cos(yaw), 0.0, -sin(yaw))
		for i in count:
			var pivot := Node3D.new()
			pivot.position = spot + side * (float(i) - 0.5) * spacing
			pivot.rotation.y = yaw
			add_child(pivot)
			var inst := scene.instantiate() as Node3D
			inst.scale = Vector3.ONE * scl
			inst.position = -centre_off * scl
			pivot.add_child(inst)
			_set_photo_only(inst)
			_resolvables.append(pivot)
			_points.append(pivot.position + Vector3(0, 0.8, 0))


## Prop-less themes still need a guaranteed non-wall fallback when authored
## geometry claims every validated writing surface. A small impossible paper
## photograph is theme-neutral, compact enough for a doorway lane, has no
## collider, and uses the ordinary delayed PLACEMENT drop resolution.
func _build_universal_photo(floor_h: float) -> void:
	var spot := _find_spot(floor_h, 0.75, 1.8)
	var ceil_h := Chunk.cell_ceil_h(world_seed, cell, theme)
	var pivot_y := clampf(floor_h + 2.05,
		floor_h + 1.45, ceil_h - 0.45)
	_placement_rest_y = floor_h + 0.42
	_placement_pivot = Node3D.new()
	_placement_pivot.position = Vector3(spot.x, pivot_y, spot.z)
	_placement_pivot.rotation.y = float(WorldGen.h(world_seed, cell.x, cell.y, 9283) % 8) \
		* PI * 0.25
	add_child(_placement_pivot)

	var paper_mat := StandardMaterial3D.new()
	paper_mat.albedo_color = Color(0.92, 0.89, 0.80)
	paper_mat.roughness = 0.94
	var paper_mesh := BoxMesh.new()
	paper_mesh.size = Vector3(0.96, 0.78, 0.045)
	var paper := MeshInstance3D.new()
	paper.mesh = paper_mesh
	paper.material_override = paper_mat
	_placement_pivot.add_child(paper)

	var exposure_mat := StandardMaterial3D.new()
	exposure_mat.albedo_color = Color(0.055, 0.065, 0.06)
	exposure_mat.roughness = 0.82
	exposure_mat.emission_enabled = true
	exposure_mat.emission = Color(0.28, 0.42, 0.72)
	exposure_mat.emission_energy_multiplier = 1.35
	var exposure_mesh := BoxMesh.new()
	exposure_mesh.size = Vector3(0.76, 0.52, 0.052)
	var exposure := MeshInstance3D.new()
	exposure.mesh = exposure_mesh
	exposure.material_override = exposure_mat
	exposure.position = Vector3(0.0, 0.065, -0.028)
	_placement_pivot.add_child(exposure)

	var glow := OmniLight3D.new()
	glow.light_color = Color(0.72, 0.82, 1.0)
	glow.light_energy = 0.42
	glow.omni_range = 3.6
	glow.shadow_enabled = false
	glow.position = _placement_pivot.position
	glow.set_meta("visible_source", "impossible_photo_exposure")
	add_child(glow)
	_glow = glow
	_points = [_placement_pivot.position,
		_placement_pivot.position - Vector3(0, 0.28, 0)]


## GIANT: the room's own furniture at a scale it has no business being,
## standing in the open under the placement glow. Eye-visible, so it carries
## a real collider — nothing invisible may block, nothing visible may be
## walked through.
func _build_giant(floor_h: float) -> void:
	var row: Array = Chunk.BLEED_PROPS.get(theme, [])
	if row.is_empty():
		return
	var scene := load(row[0]) as PackedScene
	if scene == null:
		return
	var scl := float(row[1])
	var centre_off: Vector3 = row[2]
	var extents: Vector3 = row[3]
	var ceil_h := Chunk.cell_ceil_h(world_seed, cell, theme)
	var base_h := maxf(extents.y, 0.6)
	# The ceiling cap wins even when a full-size replacement cabinet leaves
	# less than the preferred 1.5x enlargement. Never bury its top in the slab.
	var factor := minf((ceil_h - floor_h - 0.25) / base_h, GIANT_SCALE_MAX)
	var spot := _find_spot(floor_h, 1.5, base_h * factor)
	var yaw := float(WorldGen.h(world_seed, cell.x, cell.y, 9283) % 8) \
		* PI * 0.25
	var pivot := Node3D.new()
	pivot.position = spot
	pivot.rotation.y = yaw
	add_child(pivot)
	var inst := scene.instantiate() as Node3D
	inst.scale = Vector3.ONE * scl * factor
	inst.position = -centre_off * scl * factor
	pivot.add_child(inst)
	if extents != Vector3.ZERO:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = extents * factor
		shape.shape = box
		shape.position = Vector3(0, extents.y * factor * 0.5, 0)
		body.add_child(shape)
		pivot.add_child(body)
		_body_rids.append(body.get_rid())
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.72, 0.82, 1.0)
	glow.light_energy = 0.5
	glow.omni_range = 5.0
	glow.omni_attenuation = 1.4
	glow.shadow_enabled = false
	glow.position = spot + Vector3(0, base_h * factor + 0.3, 0)
	glow.set_meta("visible_source", "anomaly_cold_mote")
	add_child(glow)
	_glow = glow
	_glow_source = _visible_anomaly_source(glow.position)
	_points = [spot + Vector3(0, base_h * factor * 0.5, 0),
		spot + Vector3(0, base_h * factor * 0.9, 0)]


## Supernatural highlights still need a visible origin. This small cold mote is
## deliberately readable before its modest local light reaches nearby walls;
## it replaces the former unexplained point-source glow around anomalies.
func _visible_anomaly_source(at: Vector3) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.20, 0.42)
	material.emission_enabled = true
	material.emission = Color(0.42, 0.62, 1.0)
	material.emission_energy_multiplier = 2.2
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mesh := SphereMesh.new()
	mesh.radius = 0.055
	mesh.height = 0.11
	var mote := MeshInstance3D.new()
	mote.name = "AnomalyLightSource"
	mote.mesh = mesh
	mote.material_override = material
	mote.position = at
	mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mote)
	return mote


## RING: the prop repeated in a circle, every copy facing the centre —
## lens-only, so the eye sees clear floor and the viewfinder sees a rite.
func _build_ring(floor_h: float) -> void:
	var row: Array = Chunk.BLEED_PROPS.get(theme, [])
	if row.is_empty():
		return
	var scene := load(row[0]) as PackedScene
	if scene == null:
		return
	var scl := float(row[1])
	var centre_off: Vector3 = row[2]
	var centre := _find_spot(floor_h, RING_RADIUS + 0.6, 2.0, false)
	if centre == Vector3.INF:
		# A ring is optional variety, never a placement gamble. Dense rooms keep
		# the same evidence id but receive the compact, non-blocking ceiling form.
		type = Type.PLACEMENT
		_build_props(floor_h, 1)
		return
	for i in RING_COUNT:
		var ang := TAU * float(i) / float(RING_COUNT)
		var offset := Vector3(cos(ang), 0.0, sin(ang)) * RING_RADIUS
		var pivot := Node3D.new()
		pivot.position = centre + offset
		pivot.rotation.y = atan2(-offset.x, -offset.z)
		add_child(pivot)
		var inst := scene.instantiate() as Node3D
		inst.scale = Vector3.ONE * scl
		inst.position = -centre_off * scl
		pivot.add_child(inst)
		_set_photo_only(inst)
		_resolvables.append(pivot)
	_points = [centre + Vector3(0, 1.0, 0),
		centre + Vector3(RING_RADIUS, 0.8, 0)]


## Lowest and highest visual mesh y under `node`, accumulated into
## `span` = [low, high], in the space `xf` maps into. Walks local
## transforms rather than global ones so tree-less audit builds measure
## the same numbers the live game does.
func _visual_span(node: Node, xf: Transform3D, span: Array) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var aabb: AABB = (node as MeshInstance3D).mesh.get_aabb()
		for i in 8:
			var corner := xf * aabb.get_endpoint(i)
			span[0] = minf(float(span[0]), corner.y)
			span[1] = maxf(float(span[1]), corner.y)
	for child in node.get_children():
		if child is Node3D:
			_visual_span(child, xf * (child as Node3D).transform, span)


## Deterministic clear-floor search shared by the standing builders. Random
## points give each cell a distinct composition; a dense lattice then proves
## the rest of the room before the guaranteed clear approach lane through a
## real doorway is used as the final fallback.
func _find_spot(floor_h: float, radius: float, height: float,
		allow_doorway_fallback := true) -> Vector3:
	var half := WorldGen.CELL_SIZE * 0.5
	var chunk := get_parent() as Chunk
	var spot := Vector3(half, floor_h, half)
	for attempt in 8:
		var candidate := Vector3(
			half + (WorldGen.r01(world_seed, cell.x, cell.y,
				9271 + attempt * 7) - 0.5) * 5.0,
			floor_h,
			half + (WorldGen.r01(world_seed, cell.x, cell.y,
				9277 + attempt * 7) - 0.5) * 5.0)
		spot = candidate
		if chunk == null or (chunk._floor_spot_clear(candidate, radius, height)
				and _photo_approach_clear(chunk, candidate, radius)):
			return spot
	if chunk == null:
		return spot
	var lattice := [1.25, 2.5, 3.75, 5.0, 6.25, 7.5, 8.75, 10.0, 10.75]
	var count := lattice.size() * lattice.size()
	var start := posmod(WorldGen.h(world_seed, cell.x, cell.y, 9291), count)
	for offset in count:
		var index := (start + offset) % count
		var candidate := Vector3(
			float(lattice[index % lattice.size()]), floor_h,
			float(lattice[int(index / lattice.size())]))
		if chunk._floor_spot_clear(candidate, radius, height) \
				and _photo_approach_clear(chunk, candidate, radius):
			return candidate
	if not allow_doorway_fallback:
		return Vector3.INF
	# Every traversable cased opening owns a 3.6m furniture-free approach lane.
	# Its centre is the only honest fallback when a room's entire interior is
	# authored set dressing.
	for dir in 4:
		var info: Dictionary = chunk._edge_info(cell, dir)
		if bool(info.get("wall", false)) or bool(info.get("full_open", false)):
			continue
		var along := float(info.get("t", half))
		match dir:
			0: return Vector3(10.6, floor_h, along)
			1: return Vector3(1.4, floor_h, along)
			2: return Vector3(along, floor_h, 10.6)
			_: return Vector3(along, floor_h, 1.4)
	return spot


## At least one player-sized stance and the sight lane back to the prop must
## be clear. Merely finding an empty square for the anomaly stranded props in
## auditorium seating and dense lounges where the camera could never frame it.
func _photo_approach_clear(chunk: Chunk, target: Vector3,
		target_radius: float) -> bool:
	for distance in [1.8, 3.5, 5.5]:
		for ang in 8:
			var direction := Vector3(cos(TAU * float(ang) / 8.0), 0.0,
				sin(TAU * float(ang) / 8.0))
			var stand := target + direction * float(distance)
			if stand.x < 0.5 or stand.x > 11.5 \
					or stand.z < 0.5 or stand.z > 11.5 \
					or not chunk._floor_spot_clear(stand, 0.38, 1.8):
				continue
			var clear := true
			var first := maxf(target_radius + 0.35, 0.75)
			var travel := first
			while travel < float(distance) - 0.35:
				if not chunk._floor_spot_clear(
						target + direction * travel, 0.20, 1.8):
					clear = false
					break
				travel += 0.55
			if clear:
				return true
	return false


## Move every visual under `node` to the photo-only render layer (plus the
## normal layer under --photo-debug), and drop any collision it carries —
## nothing invisible may block the player.
func _set_photo_only(node: Node) -> void:
	_set_layer(node, PHOTO_LAYER, true)


## Put every visual under `node` on exactly `layer` (adding the normal layer
## under --photo-debug); with strip_collision, remove bodies as well.
func _set_layer(node: Node, layer: int, strip_collision := false) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = \
			(1 | layer) if debug_visible else layer
	# Camera-only geometry must not feed global illumination either, or
	# glossy floors mirror things the eye cannot see (SDFGI ignores render
	# layers; owner report, 2026-08-20).
	if node is GeometryInstance3D and (layer & (PHOTO_LAYER | PRINT_LAYER)):
		(node as GeometryInstance3D).gi_mode = \
			GeometryInstance3D.GI_MODE_DISABLED
	if strip_collision and node is CollisionObject3D:
		node.queue_free()
		return
	for child in node.get_children():
		_set_layer(child, layer, strip_collision)


## The eye reads 104; the viewfinder and developed photograph reveal 106.
## Photographing the discrepancy makes 106 real after review.
func configure_numbered_door(p_id: String, p_cell: Vector2i, plate: Label3D) -> void:
	id = p_id
	cell = p_cell
	theme = 0
	type = Type.NUMBERED_DOOR
	_number_plate = plate
	plate.text = "104"
	plate.layers = EYE_ONLY_LAYER
	set_process(false)
	_facing = plate.global_basis.z.normalized()
	for offset in [Vector3(-0.11, -0.055, 0.025), Vector3(0.11, 0.055, 0.025)]:
		_points.append(to_local(plate.to_global(offset)))
	_number_print = Node3D.new()
	add_child(_number_print)
	_number_print.global_transform = plate.global_transform
	var backing := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.432, 0.202, 0.003)
	backing.mesh = box
	backing.material_override = Mats.darkwood()
	backing.layers = PHOTO_LAYER
	backing.position.z = 0.006
	backing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_number_print.add_child(backing)
	var printed := plate.duplicate() as Label3D
	printed.remove_meta("casino_number_plate")
	printed.text = "106"
	printed.position = Vector3(0, 0, 0.011)
	printed.rotation = Vector3.ZERO
	printed.layers = PHOTO_LAYER
	_number_print.add_child(printed)

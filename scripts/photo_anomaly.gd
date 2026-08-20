class_name PhotoAnomaly
extends Node3D
## One wrong thing, standing in a cell, waiting to be photographed.
##
## Four shapes share this node. PLACEMENT hangs the floor's own signature
## prop inverted at head height, slowly turning under its own faint light;
## DUPLICATE stands two identical copies of it shoulder to shoulder where one
## is furniture and two are a mistake; WRITING paints a phrase on a wall that
## only the camera can see (photo-only render layer); BLEED wraps a bleed
## prop the dressing already placed. Props are ALWAYS the floor's own — the
## owner ruled (2026-08-19) that foreign objects appear only as the bleed
## near the elevator, never scattered as anomalies. The wrongness is the
## inversion, the hover, the duplication, never the object's origin.
##
## The node is spawned by PhotoDirector on `chunk_built` and parented to the
## chunk, so streaming and blackout rebuilds retire and recreate it for free.
## All positions here are chunk-local (cells are 12m, chunks sit at
## cell * CELL_SIZE with y = 0). Documented state does NOT live here — the
## director owns it, so a rebuilt cell cannot resurrect a spent photograph.

enum Type { PLACEMENT, DUPLICATE, WRITING, BLEED, GIANT, RING, MISSING, PRINT }

## Render layer bit reserved for photo-only geometry. Player cameras clear
## this bit; the snapshot camera sets it.
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

## How far a photograph carries. Writing must be read, not glimpsed.
const CAPTURE_DISTANCE := 15.0
const CAPTURE_DISTANCE_WRITING := 9.5

const WRITING_FONT := preload("res://fonts/RazorKeen-Regular.otf")

## Themes whose BLEED_PROPS row is a portable, self-contained prop and can
## therefore carry PLACEMENT/DUPLICATE. Airport luggage is a scatter set with
## per-piece centres and no footprint; prop-less themes plan WRITING only.
const PROP_THEMES := [0, 1, 2, 5, 6, 7, 9]
## The hanging prop hovers with its lowest point at least this high, and its
## highest point at least this far under the ceiling.
const HANG_CLEARANCE_HEAD := 1.9
const HANG_CLEARANCE_CEIL := 0.35
const HANG_MIN_ABOVE_FLOOR := 1.15
const HANG_SPIN := 0.32
## GIANT: the prop at wrong scale, capped so it still fits under the cell's
## ceiling with a hand's width to spare.
const GIANT_SCALE_MAX := 2.6
const GIANT_SCALE_MIN := 1.5
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
## Slow drift for the hanging prop; a perfectly still floating object reads
## as a physics bug, a turning one reads as held.
var _spin: Node3D
var _points: Array[Vector3] = []   # chunk-local sample points
## Colliders the anomaly itself carries (GIANT's walk-blocker). The camera's
## occlusion rays must ignore them — sample points sit inside the prop, so
## its own body otherwise occludes it from every stance (found 2026-08-19:
## a required GIANT was uncapturable from 16/16 stances).
var _body_rids: Array[RID] = []
## Nodes a resolve() removes, plus the giant's glow and the floor height for
## the placement drop.
var _resolvables: Array[Node] = []
var _glow: OmniLight3D
var _floor_y := 0.0


func configure(p_id: String, p_type: int, p_cell: Vector2i, p_world_seed: int,
		p_theme: int, wall_dir: int, wall_along: float) -> void:
	id = p_id
	type = p_type as Type
	cell = p_cell
	world_seed = p_world_seed
	theme = p_theme
	var floor_h := Chunk.cell_floor_h(world_seed, cell, theme)
	_floor_y = floor_h
	# configure() is called before add_child, so debug_visible is already set.
	match type:
		Type.WRITING:
			_build_writing(floor_h, wall_dir, wall_along, false)
		Type.PRINT:
			_build_writing(floor_h, wall_dir, wall_along, true)
		Type.DUPLICATE:
			_build_props(floor_h, 2)
		Type.GIANT:
			_build_giant(floor_h)
		Type.RING:
			_build_ring(floor_h)
		Type.MISSING:
			_build_missing(floor_h)
		_:
			_build_props(floor_h, 1)
	if debug_visible:
		print("photo anomaly %s built, points %s" % [id, str(photo_points())])


func _process(dt: float) -> void:
	if _spin != null:
		_spin.rotate_y(dt * HANG_SPIN)


## Global sample points the camera tests for framing. All must pass the
## frustum-and-sight checks for the shot to count.
func photo_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p in _points:
		out.append(to_global(p))
	return out


## A bleed prop the dressing already placed becomes photographable evidence:
## no visuals of its own, just sample points over the existing prop. One
## documentation credit per floor is enforced by the director, not here.
func configure_bleed(p_id: String, p_cell: Vector2i,
		points: Array[Vector3]) -> void:
	id = p_id
	type = Type.BLEED
	cell = p_cell
	_points = points


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
	match type:
		Type.MISSING:
			return "THE CAMERA SAYS IT IS NOT THERE"
		Type.PRINT:
			return "\"%s\" — ONLY THE FILM SEES IT" % phrase_for(
				world_seed, cell)
		Type.PLACEMENT:
			return "NOTHING HOLDS IT"
		Type.DUPLICATE:
			# Name the impossibility, never the arrangement — "THERE ARE
			# TWO" read as a shrug (owner, 2026-08-20).
			return "TWO, WHEN YOU AREN'T LOOKING"
		Type.GIANT:
			return "IT SHOULD NOT FIT IN HERE"
		Type.RING:
			return "THEY MEET WHEN THE ROOM IS EMPTY"
		Type.WRITING:
			return "\"%s\"" % phrase_for(world_seed, cell)
		Type.BLEED:
			return "IT BELONGS TO THE FLOOR BELOW"
	return ""


func occlusion_excludes() -> Array[RID]:
	return _body_rids


func capture_distance() -> float:
	return CAPTURE_DISTANCE_WRITING if type == Type.WRITING \
		else CAPTURE_DISTANCE


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
	var start := WorldGen.h(route.world_seed, at.x, at.y, 9257) % 4
	for i in 4:
		var dir := (start + i) % 4
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


## The room noticed being photographed: a counted shot resolves its
## anomaly. Hanging props drop, lens-only and eye-only things are simply
## gone afterwards, writings leave the wall, the giant's glow dies. Chunk
## rebuilds skip documented anomalies entirely, so the resolution holds.
func resolve() -> void:
	match type:
		Type.PLACEMENT:
			if _spin != null and is_instance_valid(_spin):
				var pivot := _spin
				_spin = null
				var drop := create_tween()
				drop.tween_property(pivot, "position:y",
					_floor_y + 0.45, 0.5) \
					.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
				drop.tween_callback(func():
					var thud := AudioStreamPlayer3D.new()
					thud.stream = SoundBank.thud()
					thud.volume_db = -4.0
					thud.position = pivot.position
					add_child(thud)
					thud.play()
					thud.finished.connect(thud.queue_free))
		Type.GIANT:
			if _glow != null and is_instance_valid(_glow):
				_glow.queue_free()
				_glow = null
		_:
			for node in _resolvables:
				if is_instance_valid(node):
					node.queue_free()
			_resolvables.clear()


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


func _build_writing(floor_h: float, wall_dir: int, wall_along: float,
		print_only := false) -> void:
	var dir := maxi(wall_dir, 0)
	var half := WorldGen.CELL_SIZE * 0.5
	var dirv3 := Vector3(WorldGen.DIRV[dir].x, 0.0, WorldGen.DIRV[dir].y)
	var label := Label3D.new()
	label.text = phrase_for(world_seed, cell)
	label.font = WRITING_FONT
	label.font_size = 220
	label.pixel_size = 0.0034
	label.width = 820.0
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = Color(0.88, 0.84, 0.76, 0.95)
	label.outline_size = 0
	var layer := PRINT_LAYER if print_only else PHOTO_LAYER
	label.layers = (1 | layer) if debug_visible else layer
	label.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# Walls carry their thickness inward from the canonical edge, so the
	# writing floats a hand's width proud of the paper, never inside it.
	var plane := half + signf(dirv3.x + dirv3.z) * (half - 0.45)
	label.position = Vector3(plane, floor_h + 1.52, wall_along) \
		if dirv3.x != 0.0 else Vector3(wall_along, floor_h + 1.52, plane)
	# Face back into the room.
	label.rotation.y = atan2(dirv3.x, dirv3.z) + PI
	add_child(label)
	_resolvables.append(label)
	_points = [label.position]
	_facing = -dirv3


func _build_props(floor_h: float, count: int) -> void:
	var row: Array = Chunk.BLEED_PROPS.get(theme, [])
	if row.is_empty():
		return
	var scene := load(row[0]) as PackedScene
	if scene == null:
		return
	var scl := float(row[1])
	var centre_off: Vector3 = row[2]
	var extents: Vector3 = row[3]
	var half := WorldGen.CELL_SIZE * 0.5
	# Deterministic spot search: the first candidate the chunk's collision
	# bookkeeping calls clear, so the wrong thing never stands inside the
	# right furniture. The last candidate is taken clearance or not — an
	# overlapping anomaly beats a missing one.
	var chunk := get_parent() as Chunk
	var spot := Vector3(half, floor_h, half)
	for attempt in 6:
		var candidate := Vector3(
			half + (WorldGen.r01(world_seed, cell.x, cell.y,
				9271 + attempt * 7) - 0.5) * 5.0,
			floor_h,
			half + (WorldGen.r01(world_seed, cell.x, cell.y,
				9277 + attempt * 7) - 0.5) * 5.0)
		spot = candidate
		if chunk == null or chunk._floor_spot_clear(candidate, 1.1, 2.1):
			break
	var yaw := float(WorldGen.h(world_seed, cell.x, cell.y, 9283) % 8) \
		* PI * 0.25
	if count == 1:
		# PLACEMENT: the prop hangs inverted overhead, slowly turning, lit
		# faintly from beneath so it catches the eye from a doorway. Height
		# is fitted between head clearance and the ceiling; a low ceiling
		# with a tall prop drops it to chest height rather than into the
		# slab, which reads as wrong all the same.
		var ceil_h := Chunk.cell_ceil_h(world_seed, cell, theme)
		var half_h := maxf(extents.y * 0.5, 0.3)
		var pivot_y := minf(ceil_h - HANG_CLEARANCE_CEIL - half_h,
			floor_h + HANG_CLEARANCE_HEAD + half_h)
		pivot_y = maxf(pivot_y, floor_h + HANG_MIN_ABOVE_FLOOR + half_h)
		_spin = Node3D.new()
		_spin.position = Vector3(spot.x, pivot_y, spot.z)
		_spin.rotation = Vector3(PI, yaw, 0.0)
		add_child(_spin)
		var inst := scene.instantiate() as Node3D
		inst.scale = Vector3.ONE * scl
		inst.position = -centre_off * scl
		_spin.add_child(inst)
		var glow := OmniLight3D.new()
		glow.light_color = Color(0.72, 0.82, 1.0)
		glow.light_energy = 0.55
		glow.omni_range = 4.2
		glow.omni_attenuation = 1.4
		glow.shadow_enabled = false
		glow.position = Vector3(spot.x, pivot_y - half_h - 0.25, spot.z)
		add_child(glow)
		_points = [_spin.position, _spin.position - Vector3(0, half_h * 0.7, 0)]
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
			pivot.position = spot + side * (float(i) - 0.5) * 0.72
			pivot.rotation.y = yaw
			add_child(pivot)
			var inst := scene.instantiate() as Node3D
			inst.scale = Vector3.ONE * scl
			inst.position = -centre_off * scl
			pivot.add_child(inst)
			_set_photo_only(inst)
			_resolvables.append(pivot)
			_points.append(pivot.position + Vector3(0, 0.8, 0))


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
	var factor := clampf((ceil_h - floor_h - 0.25) / base_h,
		GIANT_SCALE_MIN, GIANT_SCALE_MAX)
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
	add_child(glow)
	_glow = glow
	_points = [spot + Vector3(0, base_h * factor * 0.5, 0),
		spot + Vector3(0, base_h * factor * 0.9, 0)]


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
	var centre := _find_spot(floor_h, RING_RADIUS + 0.6, 2.0)
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


## Deterministic clear-floor search shared by the standing builders: first
## candidate the chunk's collision bookkeeping calls clear, last candidate
## taken clearance or not.
func _find_spot(floor_h: float, radius: float, height: float) -> Vector3:
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
		if chunk == null or chunk._floor_spot_clear(candidate, radius, height):
			break
	return spot


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

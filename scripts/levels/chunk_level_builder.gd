class_name ChunkLevelBuilder
extends RefCounted
## Base for the per-theme chunk builders. Chunk picks one from its
## LEVEL_BUILDERS registry during _init and calls into it from the four
## construction dispatchers: _build_floor_ceiling, _build_walls, _build_lighting
## and _build_props.
##
## Builders receive only immutable generation facts and a typed construction
## façade. They cannot read or mutate the live Chunk node directly. Chunk still
## hosts the proven geometry kernel behind ChunkSceneWriter, but that is an
## implementation detail that can move without changing every theme.
##
## Builders are duck-typed beyond this. They implement whatever their own
## dispatch arms need; there is no abstract method set to satisfy.

var ctx: ChunkBuildContext
var scene: ChunkSceneWriter


func _init(context: ChunkBuildContext,
		writer: ChunkSceneWriter) -> void:
	ctx = context
	scene = writer


## Is position `t` along a corridor wall far enough from every door and from the
## seating bay to place something against it?
##
## Five floors run the same corridor algorithm with different trim, and this test
## was four byte-identical copies whose only difference was the door half-width:
## 0.62 in the casino and the asylum, 0.66 in the office, 0.63 in the school. Each
## floor still calls it through its own named wrapper, so the difference is a
## visible argument rather than a constant buried in a duplicate.
static func corridor_clear_at(t: float, doors: Array, bay: Array,
		clearance: float, door_half_width: float) -> bool:
	if not bay.is_empty() and absf(t - float(bay[0])) < float(bay[1]) * 0.5 + clearance:
		return false
	for dt in doors:
		if absf(t - float(dt)) < door_half_width + clearance:
			return false
	return true

class_name OfficeCeilingGrid
extends RefCounted
## The source texture has one central T-bar cross per repeat, at UV (0.5, 0.5).
## Texture edges meet inside a tile, so its two half-tiles form one 0.75m bay.
const PITCH := 0.75
const SEAM_OFFSET := PITCH * 0.5
const TROFFER_TRIM_ALLOWANCE := 0.18
# The 6m by 2.6m fixture grid covers even the tallest 3.6m Office rooms with
# this reach. Larger radii mostly add overlapping light/shadow work next door.
const LIGHT_REACH := 6.5
# Render layer 2: the slab stays visible to ordinary/photo cameras and remains
# a shadow caster. Only downward Office troffers exclude it as a receiver.
const CEILING_RENDER_LAYER := 1 << 1


static func center(desired_world: Vector2, panels: Vector2i) -> Vector2:
	var offset := Vector2(
		SEAM_OFFSET if panels.x % 2 == 0 else 0.0,
		SEAM_OFFSET if panels.y % 2 == 0 else 0.0)
	return (desired_world - offset).snapped(Vector2.ONE * PITCH) + offset


static func outer_size(panels: Vector2i) -> Vector2:
	return Vector2(panels) * PITCH


static func lens_size(panels: Vector2i) -> Vector2:
	# Chunk._troffer adds 9cm of trim on either side of its lens.
	return outer_size(panels) - Vector2.ONE * TROFFER_TRIM_ALLOWANCE

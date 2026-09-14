class_name AirportCeilingGrid
extends RefCounted
## Same authored acoustic panel maps as Office, at a 60cm terminal bay pitch.
## The texture's central T-bar cross places seams half a repeat from zero.
const PITCH := 0.6
const SEAM_OFFSET := PITCH * 0.5
const FRAME := 0.03


static func center(world: Vector2, panels: Vector2i) -> Vector2:
	var phase := Vector2(SEAM_OFFSET if panels.x % 2 == 0 else 0.0,
		SEAM_OFFSET if panels.y % 2 == 0 else 0.0)
	return (world - phase).snapped(Vector2.ONE * PITCH) + phase


static func outer_size(panels: Vector2i) -> Vector2:
	return Vector2(panels) * PITCH

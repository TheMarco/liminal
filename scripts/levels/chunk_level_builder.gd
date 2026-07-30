class_name ChunkLevelBuilder
extends RefCounted
## Base for the per-theme chunk builders. Chunk picks one from its
## LEVEL_BUILDERS registry during _init and calls into it from the four
## construction dispatchers: _build_floor_ceiling, _build_walls, _build_lighting
## and _build_props.
##
## The host is typed rather than left as an untyped `var chunk`. Naming Chunk in
## an annotation does not create the preload cycle the untyped version was
## avoiding -- chunk.gd preloads the builders, the builders only refer to the
## class -- and it gets static checking and completion back on the roughly three
## thousand chunk.* accesses across the nine builders.
##
## What a builder may use on its host, all of it public API for this purpose:
##
##   geometry kernel   _box _mbox _cyl _mcyl _quad _mquad _sphere _msphere
##                     _rbox _mrbox _mcone _mellipsoid _mbeam
##   colliders         _collider_box _collider_cyl _collider_yaw_box
##                     _collider_rot_box
##   furnishing groups _furnishing_pivot _bind_furnishing_colliders _adopt_local
##   authored props    _cc0_prop _attributed_floor_prop _attributed_prop_local
##                     _asy_model _prop_scene
##   determinism       _r(salt) -- a pure hash of (seed, cell, salt), so it is
##                     call-order independent and safe to move between files
##   cell facts        wseed cell theme style ceil_h room_root room_n
##                     is_room_anchor body, plus the shared constants
##
## Anything a second theme starts calling belongs on Chunk under a neutral name,
## not on one builder: reaching a method through the active builder that only one
## builder defines is what broke the school admin terminal and the prison guard
## desk.
##
## Builders are duck-typed beyond this. They implement whatever their own
## dispatch arms need; there is no abstract method set to satisfy.

var chunk: Chunk


func _init(host: Chunk) -> void:
	chunk = host

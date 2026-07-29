extends RefCounted

## Shared host reference for per-level chunk builders.
##
## Builders deliberately use an untyped host so the builder modules can be
## preloaded without creating a circular dependency on Chunk.
var chunk


func _init(host) -> void:
	chunk = host

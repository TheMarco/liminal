extends "res://tools/lib/audit_base.gd"
## A rejected decorative site must not leave an off-tree mesh owning GPU assets.

class BlockedAnnex extends "res://scripts/levels/annex_level_builder.gd":
	func _annex_blocks_doorway(_p: Vector3, _yaw: float,
			_width: float, _depth: float, _photo_only := false) -> bool:
		return true


func run() -> void:
	var chunk := Chunk.new(21, Vector2i.ZERO, 2, null, true)
	var builder := BlockedAnnex.new(chunk._build_context, chunk._scene_writer)
	var before := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	for i in 8:
		builder._annex_carpet_damage()
	expect(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == before,
		"rejected carpet overlays leaked orphan nodes")
	chunk.free()
	builder = null
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	finish("rejected Annex overlays release their nodes and resources")

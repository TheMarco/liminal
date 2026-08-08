extends SceneTree
## Prints the real furniture-mutation capability of one representative cell
## for every generated style. This keeps DescentTopology's pure capability
## table grounded without putting Chunk construction back in production plans.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var base_seed := 405195947
	for theme in WorldGen.THEMES:
		var ws := WorldGen.level_seed(base_seed, theme)
		var found := {}
		for radius in range(0, 31):
			for y in range(-radius, radius + 1):
				for x in range(-radius, radius + 1):
					if radius > 0 and absi(x) != radius and absi(y) != radius:
						continue
					var at := Vector2i(x, y)
					var style := WorldGen.cell_style(ws, at, theme)
					if found.has(style):
						continue
					var root := WorldGen.annex_room_id(ws, at) if theme == 2 \
						else WorldGen.room_id(ws, at)
					if root != at:
						continue
					var chunk := Chunk.new(ws, at, theme, {
						"furniture_variant_override": 1,
					})
					print("MUTATION_STYLE theme=%d style=%d changed=%d safe=%d" % [
						theme, style, chunk.mutation_furniture_changed_groups,
						chunk.mutation_furniture_clearance_violations()])
					chunk.free()
					found[style] = true
		Chunk.clear_runtime_caches()
		Mats.clear_runtime_caches()
		VhsRitual.clear_runtime_cache()
	quit()

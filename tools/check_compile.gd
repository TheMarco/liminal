extends SceneTree
## Fast preflight: build one Chunk of every live theme and confirm it produced
## real geometry.
##
## chunk.gd preloads all nine level builders, so a syntax or missing-method error
## in any one of them fails the whole Chunk class. GDScript reports that as a
## parse error and then carries on, which makes every downstream audit fail with
## a confusing secondary error (`get_children` on a null value) instead of the
## real cause. Running this first turns that into one clear message.
##
## Run:
##   godot --headless --path . --script tools/check_compile.gd

const MIN_NODES := 6


func _init() -> void:
	var bad := 0
	for theme in WorldGen.THEMES:
		var ws := WorldGen.level_seed(1, theme)
		var chunk := Chunk.new(ws, Vector2i.ZERO, theme)
		var n := _count(chunk)
		if n <= MIN_NODES:
			printerr("theme %d built only %d nodes — Chunk did not construct" % [
				theme, n])
			bad += 1
		else:
			print("theme %d ok (%d nodes, style %d)" % [theme, n, chunk.style])
		chunk.free()
	Chunk.finish_prop_preloads()
	if bad > 0:
		printerr("COMPILE CHECK FAILED: %d theme(s) built nothing" % bad)
		quit(1)
		return
	print("compile check pass")
	quit()


func _count(node: Node) -> int:
	var n := 1
	for child in node.get_children():
		n += _count(child)
	return n

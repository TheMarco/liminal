extends "res://tools/audit_world_hash.gd"
## Construction may yield between fixtures, but its completed geometry,
## material/light state, labels, colliders and child order must stay identical.
## Reuse the established world digest rather than a separate scene serializer.

func _init() -> void:
	call_deferred("_audit_slices")


func _audit_slices() -> void:
	var failures: Array[String] = []
	if "--busways-only" in OS.get_cmdline_user_args():
		_audit_busway_templates(failures)
		for failure in failures: printerr(failure)
		if failures.is_empty(): print("busway templates: PASS")
		await preload("res://tools/lib/audit_cleanup.gd").release(self)
		quit(0 if failures.is_empty() else 1)
		return
	# A prison partition must not prepare casino wallpaper that it discards.
	var partition := Chunk.new(WorldGen.level_seed(1315734997, 8), Vector2i(4, 2), 8, null, true)
	var split := partition._resolved_room_split()
	if split.is_empty():
		failures.append("fixture lost its prison partition")
	else:
		partition._partition(split[0], split[1])
		for key in Mats._c:
			if str(key).begins_with("wallpaper"):
				failures.append("prison partition loaded unused casino wallpaper")
	partition.free()
	_audit_busway_templates(failures)
	var checked := 0
	var themes := [8, 10]
	if "--all-themes" in OS.get_cmdline_user_args():
		themes = WorldGen.THEMES
	for theme in themes:
		var ws := WorldGen.level_seed(1315734997, theme)
		var cells := _cells_for(ws, theme)
		# Include furnished anchors for every style, not just a member whose
		# style is present but whose furniture belongs to a different chunk.
		var anchor_styles := {}
		for z in range(-12, 13):
			for x in range(-12, 13):
				var cell := Vector2i(x, z)
				if WorldGen.room_id(ws, cell) != cell: continue
				var style := WorldGen.cell_style(ws, cell, theme)
				if not anchor_styles.has(style):
					anchor_styles[style] = true
					cells.append([cell, "furnished", {}])
		for entry in cells:
			var direct := Chunk.new(ws, entry[0], theme, entry[2])
			var sliced := Chunk.new(ws, entry[0], theme, entry[2], true)
			var slices := 0
			while not sliced.build_next_slice() and slices < 10000:
				slices += 1
			var expected: PackedStringArray = []
			var actual: PackedStringArray = []
			_walk(direct, "", expected)
			_walk(sliced, "", actual)
			var label := "theme %d cell %s %s" % [theme, entry[0], entry[1]]
			if expected.size() <= MIN_NODES or expected != actual:
				failures.append("scene changed: " + label)
				_write("res://build/streaming-slices/expected.txt", expected)
				_write("res://build/streaming-slices/actual.txt", actual)
			if sliced._build_stage != 8 or not sliced._build_jobs.is_empty():
				failures.append("unfinished jobs: " + label)
			if sliced.portal_dest != direct.portal_dest:
				failures.append("portal destination changed: " + label)
			direct.free()
			sliced.free()
			checked += 1
			if not failures.is_empty(): break
		if not failures.is_empty(): break
	if failures.is_empty():
		print("sliced streaming: %d rooms match synchronous construction" % checked)
	else:
		for failure in failures: printerr(failure)
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit(0 if failures.is_empty() else 1)


func _audit_busway_templates(failures: Array[String]) -> void:
	Chunk.BRUTALIST_LEVEL_BUILDER.prewarm_busways()
	var prepared := ProceduralDetails._floor_templates.size()
	for span in [5.6, 12.0, 24.0]:
		for drop in [0.12, 1.01, 4.37, 9.91]:
			var root := Node3D.new()
			Chunk.BRUTALIST_LEVEL_BUILDER._busway_hardware(root, span - 1.2, drop)
			if root.get_child_count() != 4:
				failures.append("busway hardware lost its four material batches")
			for node in root.get_children():
				if node.get_meta("procedural_detail") != "busway_rod_unit": continue
				var multi: MultiMesh = node.multimesh
				if multi.instance_count != 4:
					failures.append("busway lost a suspension rod")
				# DummyRenderer returns identity for every MultiMesh transform.
				# Verify placement with a native --busways-only run instead.
				if DisplayServer.get_name() == "headless": continue
				for i in multi.instance_count:
					var bounds: AABB = multi.get_instance_transform(i) * multi.mesh.get_aabb()
					if absf(bounds.position.y + 0.08) > 0.0001 or absf(bounds.end.y - drop) > 0.0001:
						failures.append("busway rod no longer meets its tray and ceiling")
			root.free()
	if ProceduralDetails._floor_templates.size() != prepared:
		failures.append("continuous room heights created additional busway templates")

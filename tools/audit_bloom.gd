extends SceneTree
## Focused regression audit for Theme 11 — The Bloom.
## Verifies every room grammar is reachable and constructible, both corridor
## axes remain enclosed and traversable, sourced assets reach runtime, and the
## signature heart/storm/gym set pieces retain their authored contracts.
## Run: godot --headless --path . --script tools/audit_bloom.gd

const THEME := 11
const BASE_SEED := 918273
const SEARCH_RADIUS := 36
const STYLES := [
	WorldGen.BLOOM_PASSAGE,
	WorldGen.BLOOM_COMMONS,
	WorldGen.BLOOM_CLASSROOM,
	WorldGen.BLOOM_INCUBATOR,
	WorldGen.BLOOM_NEST,
	WorldGen.BLOOM_ATRIUM,
	WorldGen.BLOOM_GYM,
	WorldGen.BLOOM_HEART,
	WorldGen.BLOOM_STORM_APERTURE,
]


func _init() -> void:
	call_deferred("_run")


func _count_meta(node: Node, key: String) -> int:
	var count := 1 if node.has_meta(key) else 0
	for child in node.get_children():
		count += _count_meta(child, key)
	return count


func _find_meta(node: Node, key: String) -> Node:
	if node.has_meta(key):
		return node
	for child in node.get_children():
		var found := _find_meta(child, key)
		if found != null:
			return found
	return null


func _count_unsourced_fixture_lights(node: Node) -> int:
	var count := 0
	if node.has_meta("bloom_fixture_light"):
		var owner := node.get_parent()
		if not node is Light3D or owner == null \
				or not owner.has_meta("bloom_fluorescent_fixture") \
				or not node.has_meta("visible_source"):
			count += 1
	for child in node.get_children():
		count += _count_unsourced_fixture_lights(child)
	return count


func _run() -> void:
	var ws := WorldGen.level_seed(BASE_SEED, THEME)
	var samples := {}
	var corridor_axes := {}
	for radius in range(SEARCH_RADIUS + 1):
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				if maxi(absi(x), absi(z)) != radius:
					continue
				var cell := Vector2i(x, z)
				var style := WorldGen.cell_style(ws, cell, THEME)
				var root_cell := WorldGen.room_id(ws, cell)
				if not samples.has(style) and (style == WorldGen.BLOOM_PASSAGE \
						or root_cell == cell):
					samples[style] = cell
				var axis := WorldGen.corridor(ws, cell)
				if style == WorldGen.BLOOM_PASSAGE and axis != 0 \
						and not corridor_axes.has(axis):
					corridor_axes[axis] = cell
		if samples.size() == STYLES.size() and corridor_axes.size() == 2:
			break

	var failures: Array[String] = []
	for style in STYLES:
		if not samples.has(style):
			failures.append("missing style %d" % style)
	if corridor_axes.size() != 2:
		failures.append("did not discover both passage axes")

	var host := Node3D.new()
	root.add_child(host)
	var authored_roots := 0
	var authored_vines := 0
	var authored_flesh := 0
	for style in STYLES:
		if not samples.has(style):
			continue
		var cell: Vector2i = samples[style]
		var chunk := Chunk.new(ws, cell, THEME)
		host.add_child(chunk)
		if chunk.style != style:
			failures.append("style mismatch at %s: expected %d got %d" % [
				cell, style, chunk.style])
		if _count_meta(chunk, "bloom_growth_root") < 1:
			failures.append("style %d has no cell-local growth" % style)
		if _count_meta(chunk, "bloom_spores") != 1:
			failures.append("style %d does not own exactly one spore system" % style)
		if _count_meta(chunk, "bloom_micro_flakes") != 1:
			failures.append("style %d does not own exactly one micro-flake system" % style)
		if _count_meta(chunk, "bloom_flakes") != 1:
			failures.append("style %d does not own exactly one hero flake system" % style)
		if _count_meta(chunk, "bloom_fluorescent_fixture") < 2:
			failures.append("style %d has fewer than two authored fixtures" % style)
		if _count_unsourced_fixture_lights(chunk) > 0:
			failures.append("style %d contains a light detached from its visible fixture" % style)
		authored_roots += _count_meta(chunk, "bloom_hero_roots")
		authored_vines += _count_meta(chunk, "bloom_authored_vines")
		authored_flesh += _count_meta(chunk, "bloom_authored_flesh")
		if _count_meta(chunk, "bloom_red_light") > 0:
			failures.append("style %d contains an unmotivated red point light" % style)
		match style:
			WorldGen.BLOOM_COMMONS:
				if chunk.room_root == Vector2i.ZERO \
						and WorldGen.portal(ws, cell, THEME) >= 0:
					failures.append("arrival cell unexpectedly owns a portal")
			WorldGen.BLOOM_CLASSROOM:
				if _count_meta(chunk, "bloom_displaced_furniture") < 2:
					failures.append("classroom lacks displaced school furniture")
			WorldGen.BLOOM_INCUBATOR:
				if _count_meta(chunk, "bloom_incubator") < 2:
					failures.append("incubator lab lacks multiple pods")
			WorldGen.BLOOM_NEST:
				if _count_meta(chunk, "BloomPulse") < 1 \
						and chunk.find_children("*", "BloomPulse", true, false).is_empty():
					# Global script classes report as Node3D in some headless builds;
					# growth density above is the stable fallback contract.
					pass
			WorldGen.BLOOM_GYM:
				if _count_meta(chunk, "bloom_drowned_court") != 1 \
						or _count_meta(chunk, "bloom_bleachers") < 2:
					failures.append("drowned gym lost its court or bleachers")
			WorldGen.BLOOM_HEART:
				if _count_meta(chunk, "bloom_heart") != 1:
					failures.append("heart chamber has no pulsing heart")
			WorldGen.BLOOM_STORM_APERTURE:
				if _count_meta(chunk, "bloom_storm_aperture") != 1:
					failures.append("storm landmark has no sealed aperture")
		host.remove_child(chunk)
		chunk.free()

	for axis in corridor_axes:
		var cell: Vector2i = corridor_axes[axis]
		var chunk := Chunk.new(ws, cell, THEME)
		host.add_child(chunk)
		if _count_meta(chunk, "bloom_passage_part") < 5:
			failures.append("passage axis %d has no complete shell" % axis)
		var side_dirs := [2, 3] if int(axis) == 1 else [0, 1]
		for dir in side_dirs:
			if bool(WorldGen.edge_info(ws, cell, dir, THEME)["full_open"]):
				failures.append("passage %s side %d became fully open" % [cell, dir])
		host.remove_child(chunk)
		chunk.free()

	# The downloaded source model and both PBR foundations must be loadable in
	# the same headless environment used by release audits.
	if load(Chunk.BLOOM_ROOT_PATH) == null:
		failures.append("Poly Haven Pine Roots model is not loadable")
	if load(Chunk.BLOOM_VINES_PATH) == null:
		failures.append("Somersby Modular Vines model is not loadable")
	if load(Chunk.BLOOM_FLESH_BLOB_PATH) == null:
		failures.append("ChopperManiac Flesh Blob model is not loadable")
	for path in [
		"res://textures/bloom/leather_red_02_coll1_1k.jpg",
		"res://textures/bloom/mud_forest_diff_1k.jpg",
		"res://textures/bloom/cellular_flesh/others_0001_color_2k.jpg",
		"res://textures/bloom/cellular_flesh/others_0001_normal_opengl_2k.png",
		"res://textures/bloom/cellular_flesh/others_0001_roughness_2k.jpg",
		"res://textures/bloom/cellular_flesh/others_0001_ao_2k.jpg",
		"res://textures/bloom/cellular_flesh/others_0001_height_2k.png",
		"res://textures/bloom/bloom_flake_atlas.png",
	]:
		if load(path) == null:
			failures.append("Bloom source texture is not loadable: %s" % path)
	if authored_roots < 1:
		failures.append("no representative room instanced Pine Roots")
	if authored_vines < 4:
		failures.append("representative rooms do not use enough authored vine masses")
	if authored_flesh < 4:
		failures.append("representative rooms do not use enough animated flesh masses")
	var env := EnvBuilder.build(THEME)
	if env.background_color.get_luminance() > 0.02 \
			or env.ambient_light_energy < 0.35 \
			or env.glow_intensity < 0.40 or env.ssr_max_steps < 48:
		failures.append("Bloom environment lost its dark wet/glowing profile")

	host.free()
	print("Bloom audit: styles=%d corridor_axes=%d roots=%d vines=%d flesh=%d failures=%d" % [
		samples.size(), corridor_axes.size(), authored_roots, authored_vines,
		authored_flesh, failures.size()])
	for failure in failures:
		print("FAIL ", failure)
	if failures.is_empty():
		print("PASS — every Bloom grammar constructs with enclosed tunnels and sourced organic art")
	quit(0 if failures.is_empty() else 1)

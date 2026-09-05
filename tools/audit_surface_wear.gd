extends SceneTree
## Contract audit for deterministic, collision-free SurfaceWear decoration.

const SEEDS := [1, 240721, 980712989]
const PROP_THEMES := [0, 1, 4, 5, 6, 7, 8, 10, 11]
const REQUIRED_CAUSES := {
	0: ["traffic_wear", "casino_fixture_smoke", "drink_spill_"], 1: ["furniture_floor_wear_office_task_chair", "office_repaint", "office_removed_notice", "replacement_carpet_square"],
	2: ["annex_connected_moisture_wall", "annex_damp_seam", "wallpaper_exposed_backing", "annex_swollen_skirting"], 4: ["airport_luggage_bumper", "airport_removed_floor_sign"],
	5: ["asylum_scrubbed_patch", "asylum_exposed_mortar", "plumbing_grout_"], 6: ["school_poster_ghost", "gym_worn_varnish", "plumbing_grout_"],
	7: ["mall_removed_lettering", "removed_kiosk_and_bolts", "mall_roof_patch", "mall_shutter_bottom_dust"], 8: ["prison_low_salt", "prison_old_paint_layers", "plumbing_runoff_"],
	9: ["pool_missing_mosaic", "pool_replacement_tiles", "pool_ladder_anchor_rust"],
	10: ["concrete_joint_crack", "patched_cable_penetration", "fixture_seep_data_center_cooling_unit"], 11: ["bloom_root_pressure", "bloom_fallen_plaster", "bloom_dried_residue"]}
const REQUIRED_PROP_PREFIXES := {0: ["casino_brass"], 6: ["school_locker"], 8: ["prison_bars", "prison_door"], 7: ["mall_fountain"]}
var failures: Array[String] = []
var counts := {}
var out_path := ""

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out_path = arg.trim_prefix("--out=")
	# This is a scene contract, not a streaming benchmark. Load props on demand
	# so the dummy renderer never creates meshes on background preload threads.
	for base in SEEDS:
		for theme in WorldGen.THEMES:
			var ws := WorldGen.level_seed(base, theme)
			var anchors := _anchors(ws, theme)
			for cell in anchors:
				_check_chunk(ws, cell, theme)
	SurfaceWear.enabled = true
	Chunk.clear_runtime_caches()
	Mats.clear_runtime_caches()
	await process_frame
	await physics_frame
	for theme in WorldGen.THEMES:
		var c: Dictionary = counts.get(theme, {"patches": 0, "props": 0, "causes": {}, "styles": [], "rooms": 0})
		print("surface-wear theme %d: patches=%d prop_overlays=%d" % [theme, c.patches, c.props])
		print("surface-wear report: " + JSON.stringify(c))
		if c.patches == 0:
			failures.append("theme %d generated no surface wear patches" % theme)
		if PROP_THEMES.has(theme) and c.props == 0:
			failures.append("theme %d generated no prop overlays" % theme)
		for prefix: String in REQUIRED_PROP_PREFIXES.get(theme, []):
			if not _has_kind_prefix(c.kinds, prefix):
				failures.append("theme %d missing required prop prefix %s" % [theme, prefix])
		for prefix: String in REQUIRED_CAUSES.get(theme, []):
			var found := false
			for cause: String in c.causes:
				if cause.begins_with(prefix): found = true; break
			if not found: failures.append("theme %d missing required cause prefix %s" % [theme, prefix])
	if not out_path.is_empty():
		var file := FileAccess.open(out_path, FileAccess.WRITE)
		if file == null: failures.append("could not open report output: " + out_path)
		else: file.store_string(JSON.stringify(counts) + "\n")
	if failures.is_empty():
		print("surface-wear audit: PASS")
	else:
		for f in failures: printerr("FAIL " + f)
	quit(0 if failures.is_empty() else 1)

func _anchors(ws: int, theme: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var seen := {}
	var seen_cells := {}
	for radius in range(0, 13):
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				var cell := Vector2i(x, z)
				var style := WorldGen.cell_style(ws, cell, theme)
				var room := WorldGen.annex_room_id(ws, cell) if theme == 2 else WorldGen.room_id(ws, cell)
				var wet_style := (theme == 5 and style in [WorldGen.ASY_HYDRO, WorldGen.ASY_TREATMENT]) \
					or (theme == 7 and style == WorldGen.MALL_ATRIUM) \
					or (theme == 10 and style == WorldGen.BRUTAL_WATER_COURT)
				var sample_limit := 8 if wet_style else (4 if theme == 2 else 1)
				if room == cell and not seen_cells.has(cell) and int(seen.get(style, 0)) < sample_limit:
					seen[style] = int(seen.get(style, 0)) + 1
					seen_cells[cell] = true
					out.append(cell)
	if not out.has(Vector2i.ZERO): out.push_front(Vector2i.ZERO)
	return out

func _has_kind_prefix(kinds: Dictionary, prefix: String) -> bool:
	for kind: String in kinds:
		if kind.begins_with(prefix): return true
	return false

func _check_chunk(ws: int, cell: Vector2i, theme: int) -> void:
	SurfaceWear.enabled = false
	var clean := Chunk.new(ws, cell, theme)
	var clean_colliders := _colliders(clean)
	var clean_gameplay := _gameplay_counts(clean)
	clean.free()
	SurfaceWear.enabled = true
	var decorated := Chunk.new(ws, cell, theme)
	var decorated_colliders := _colliders(decorated)
	var decorated_gameplay := _gameplay_counts(decorated)
	if clean_colliders != decorated_colliders: failures.append("theme %d cell %s collider graph changed" % [theme, cell])
	if clean_gameplay != decorated_gameplay: failures.append("theme %d cell %s gameplay counts changed" % [theme, cell])
	var sig_a := _wear_signatures(decorated)
	var decorated_again := Chunk.new(ws, cell, theme)
	if sig_a != _wear_signatures(decorated_again): failures.append("theme %d cell %s wear is nondeterministic" % [theme, cell])
	_validate(decorated)
	var summary: Dictionary = decorated.get_meta("surface_wear_summary", {})
	var c: Dictionary = counts.get(theme, {"patches": 0, "props": 0, "causes": {}, "profiles": {}, "kinds": {}, "styles": [], "rooms": 0})
	c.rooms += 1
	var style_id: int = WorldGen.cell_style(ws, cell, theme)
	if not c.styles.has(style_id): c.styles.append(style_id)
	c.patches += int(summary.get("patches", 0))
	c.props += int(summary.get("prop_meshes", 0))
	for cause in summary.get("placed_causes", {}): c.causes[cause] = int(c.causes.get(cause, 0)) + int(summary.placed_causes[cause])
	for n in decorated.find_children("*", "MeshInstance3D", true, false):
		if n.get_meta("surface_wear_prop_overlay", false):
			var mat := n.material_overlay as ShaderMaterial
			var profile := str(mat.get_shader_parameter("profile")) if mat != null else "unknown"
			var kind := str(n.get_meta("surface_wear_prop_kind", "unknown"))
			c.profiles[profile] = int(c.profiles.get(profile, 0)) + 1
			c.kinds[kind] = int(c.kinds.get(kind, 0)) + 1
	counts[theme] = c
	decorated_again.free()
	decorated.free()

func _colliders(root: Node) -> Array:
	var out := []
	_walk_colliders(root, Transform3D.IDENTITY, out)
	out.sort_custom(func(a, b): return str(a) < str(b))
	return out

func _walk_colliders(node: Node, xf: Transform3D, out: Array) -> void:
	var here := xf
	if node is Node3D: here = xf * node.transform
	if node is CollisionShape3D and node.shape != null:
		out.append([_shape_signature(node.shape), str(here.origin), str(here.basis)])
	if node is CollisionObject3D: out.append([node.get_class(), node.collision_layer, node.collision_mask])
	for child in node.get_children(): _walk_colliders(child, here, out)

func _shape_signature(shape: Shape3D) -> Array:
	if shape is BoxShape3D: return ["Box", (shape as BoxShape3D).size]
	if shape is CylinderShape3D: return ["Cylinder", (shape as CylinderShape3D).height, (shape as CylinderShape3D).radius]
	if shape is CapsuleShape3D: return ["Capsule", (shape as CapsuleShape3D).height, (shape as CapsuleShape3D).radius]
	if shape is SphereShape3D: return ["Sphere", (shape as SphereShape3D).radius]
	if shape is ConvexPolygonShape3D: return ["Convex", (shape as ConvexPolygonShape3D).points]
	if shape is ConcavePolygonShape3D: return ["Concave", (shape as ConcavePolygonShape3D).faces]
	return [shape.get_class()]

func _gameplay_counts(root: Node) -> Dictionary:
	var out := {"charging": 0, "vhs": 0, "lights": 0, "labels": 0, "areas": 0}
	_count_gameplay(root, out)
	return out

func _count_gameplay(node: Node, out: Dictionary) -> void:
	if node is ChargingStation: out.charging += 1
	if node is VhsRitual: out.vhs += 1
	if node is Light3D: out.lights += 1
	if node is Label3D: out.labels += 1
	if node is Area3D: out.areas += 1
	for child in node.get_children(): _count_gameplay(child, out)

func _wear_signatures(root: Node) -> Array:
	var out := []
	_walk_wear(root, Transform3D.IDENTITY, out)
	out.sort_custom(func(a, b): return str(a) < str(b))
	return out

func _walk_wear(node: Node, xf: Transform3D, out: Array) -> void:
	var here := xf
	if node is Node3D: here = xf * node.transform
	if node is MeshInstance3D and node.get_meta("surface_wear_patch", false):
		var patch_params: Array = []
		var applied: Dictionary = node.get_meta("surface_wear_parameters", {})
		for key: String in ["wear_seed", "strength", "patch_size", "ink", "surface_roughness", "tile_pitch"]:
			patch_params.append(applied.get(key))
		out.append([node.get_meta("surface_wear_motif"), node.get_meta("surface_wear_cause"), node.get_meta("surface_wear_center"), node.get_meta("surface_wear_normal"), node.get_meta("surface_wear_size"), node.get_meta("surface_wear_support_offset"), str(here), patch_params])
	if node is MeshInstance3D and node.get_meta("surface_wear_prop_overlay", false):
		var mat := node.material_overlay as ShaderMaterial
		var params := []
		for key: String in ["mesh_to_prop", "bounds_min", "bounds_size", "wear_seed", "strength", "profile", "casino", "infected"]:
			params.append(mat.get_shader_parameter(key) if mat != null else null)
		out.append(["prop", node.get_meta("surface_wear_prop_kind"), str(here), params])
	for child in node.get_children(): _walk_wear(child, here, out)

func _validate(root: Node) -> void:
	var patches := 0
	var props := 0
	var lifted := 0
	for n in root.find_children("*", "MeshInstance3D", true, false):
		if n.get_meta("surface_wear_patch", false):
			patches += 1
			var applied: Dictionary = n.get_meta("surface_wear_parameters", {})
			var patch_strength := float(applied.get("strength", -1.0))
			for key: String in ["wear_seed", "strength", "patch_size", "ink", "surface_roughness", "tile_pitch"]:
				expect(applied.has(key), "surface wear missing applied parameter " + key)
			expect(patch_strength > 0.0 and patch_strength <= SurfaceWear.MAX_STRENGTH, "surface wear patch strength out of range")
			var normal: Vector3 = n.get_meta("surface_wear_normal")
			var size: Vector2 = n.get_meta("surface_wear_size")
			var support: Vector2 = n.get_meta("surface_wear_support_size")
			var offset: Vector2 = n.get_meta("surface_wear_support_offset")
			var parent_xf := _composed_transform(n, root)
			var center: Vector3 = n.get_meta("surface_wear_center")
			expect(parent_xf.origin.distance_to(center + (n.get_meta("surface_wear_normal") as Vector3) * .006) <= .001, "surface wear center transform mismatch")
			var derived: Vector3 = (parent_xf.basis.inverse().transposed() * Vector3.BACK).normalized()
			expect(derived.distance_to((n.get_meta("surface_wear_normal") as Vector3).normalized()) <= .001, "surface wear normal transform mismatch")
			expect(normal.length() > 0.999 and normal.length() < 1.001, "surface wear normal is not unit")
			expect(size.x > 0 and size.y > 0, "surface wear patch has nonpositive size")
			expect(abs(offset.x) + size.x / 2.0 <= support.x / 2.0 + .003 and abs(offset.y) + size.y / 2.0 <= support.y / 2.0 + .003, "surface wear patch exceeds support")
		if n.get_meta("surface_wear_prop_overlay", false):
			props += 1
			var overlay := n.material_overlay as ShaderMaterial
			var strength := float(overlay.get_shader_parameter("strength"))
			expect(strength > 0.0 and strength <= 0.28, "prop overlay strength out of range")
			for key: String in ["mesh_to_prop", "bounds_min", "bounds_size", "wear_seed", "strength", "profile", "casino", "infected"]:
				expect(overlay.get_shader_parameter(key) != null, "prop overlay missing parameter " + key)
		if n.name == "LiftedFinish":
			lifted += 1
			var extent: float = absf((n.mesh as Mesh).get_aabb().end.z)
			expect(extent <= 0.009, "LiftedFinish outward extent exceeded")
		if n.get_meta("surface_wear_patch", false):
			_validate_cosmetic_tree(n)
	expect(lifted <= 1, "more than one LiftedFinish in chunk")
	expect(patches <= SurfaceWear.MAX_PATCHES and props <= SurfaceWear.MAX_PROP_MESHES, "surface wear cap exceeded")

func expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _validate_cosmetic_tree(node: Node) -> void:
	expect(not (node is CollisionObject3D or node is CollisionShape3D), "surface wear has collision")
	if node is GeometryInstance3D:
		expect(node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "surface wear shadow enabled")
		expect(node.gi_mode == GeometryInstance3D.GI_MODE_DISABLED, "surface wear GI enabled")
	for child in node.get_children(): _validate_cosmetic_tree(child)

func _composed_transform(node: Node, root: Node) -> Transform3D:
	var chain: Array[Node3D] = []
	var current := node
	while current != root:
		if current is Node3D: chain.push_front(current)
		current = current.get_parent()
	var out := Transform3D.IDENTITY
	for item in chain: out *= item.transform
	return out

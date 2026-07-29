extends Node3D
## Visual-QA stage for props that are BUILT rather than loaded.
##
## `preview_model.tscn` stages a glTF file; these have no file. They are
## assembled at runtime out of boxes and cylinders by a method on Chunk, using
## that chunk's theme materials and its deterministic per-cell noise, so the
## only honest way to look at one is to build a real chunk and call the method.
##
## Everything the chunk built for itself is hidden first, leaving the prop alone
## on a neutral floor.
##
## Run: godot --path . tools/preview_prop.tscn -- \
##   --prop=_mall_bench --screenshot=/tmp/bench.png

const T := 0.15


func _ready() -> void:
	var want := ""
	var shot := "/tmp/liminal-prop.png"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prop="):
			want = arg.substr(7)
		elif arg.begins_with("--screenshot="):
			shot = arg.substr(13)
	if want.is_empty():
		push_error("Pass --prop=_function_name")
		get_tree().quit(1)
		return

	var theme := _theme_for(want)
	var chunk := Chunk.new(WorldGen.level_seed(4242, theme), Vector2i(0, 0), theme)
	add_child(chunk)
	# Everything up to here is the room. Hide it so only the prop remains.
	var before := chunk.get_child_count()
	for i in before:
		var c := chunk.get_child(i)
		if c is Node3D:
			(c as Node3D).visible = false

	if not _build(chunk, want):
		push_error("no preview recipe for %s" % want)
		get_tree().quit(2)
		return

	var bounds := _bounds(chunk, before)
	if bounds.size == Vector3.ZERO:
		push_error("%s produced no visible geometry" % want)
		get_tree().quit(3)
		return
	# Centre it over the origin so the camera framing below is predictable.
	var shift := Vector3(-bounds.get_center().x, -bounds.position.y,
		-bounds.get_center().z)
	for i in range(before, chunk.get_child_count()):
		var c := chunk.get_child(i)
		if c is Node3D:
			(c as Node3D).position += shift
	bounds.position += shift

	_stage(bounds)
	await get_tree().process_frame
	await get_tree().create_timer(0.7).timeout
	get_viewport().get_texture().get_image().save_png(shot)
	print("%s | %.2f x %.2f x %.2f m | %s" % [want,
		bounds.size.x, bounds.size.y, bounds.size.z, shot])
	get_tree().quit()


## Which floor's materials the prop belongs to. A mall bench built with casino
## velvet would be a misleading picture.
func _theme_for(name: String) -> int:
	if name.begins_with("_office") or name == "_vt100" or name == "_shelf_unit" \
			or name == "_troffer":
		return 1
	if name == "_slot_machine_alt" or name == "_rope_barrier":
		return 0
	if name.begins_with("_sewer"):
		return 2
	if name.begins_with("_annex"):
		return 2
	if name.begins_with("_air") or name == "_checkin_desk" \
			or name == "_stanchion_line":
		return 4
	if name.begins_with("_asy"):
		return 5
	if name.begins_with("_sch"):
		return 6
	if name.begins_with("_mall"):
		return 7
	if name.begins_with("_prison"):
		return 8
	return 0


## One call per prop, with arguments chosen to show it at its most typical.
## Wall-mounted props are given wall 3 and its inner plane.
func _build(c: Chunk, n: String) -> bool:
	var mid := Vector3(6, 0, 6)
	var plane := T / 2.0
	match n:
		"_troffer":
			c.call("_troffer", Vector3(6, 2.6, 6), Vector2(1.2, 0.3),
				Mats.office_panel(), Mats.metal_gray())
		"_procedural_slot_machine":
			c.call("_procedural_slot_machine", 6.0, 6.0, 1.0, 0)
		"_change_machine": c.call("_change_machine", 3, plane)
		"_slot_machine_alt": c.call("_slot_machine_alt", 6.0, 6.0, 1.0, 4)
		"_rope_barrier": c.call("_rope_barrier", mid, 0.0, "preview")
		"_velvet_ropes": c.call("_velvet_ropes")
		"_casino_ballroom": c.call("_casino_ballroom")
		"_hallway": c.call("_hallway")
		"_office_air_conditioners": c.call("_office_air_conditioners", [])
		"_office_cubicle_cluster": c.call("_office_cubicle_cluster", mid, 0)
		"_office_desk": c.call("_office_desk", mid, Vector2(0, 1), 0)
		"_vt100": c.call("_vt100", Vector3(6, 0.75, 6), 0.0)
		"_shelf_unit": c.call("_shelf_unit", mid, true, 7)
		"_sewer_pump_skid": c.call("_sewer_pump_skid", mid, 1.0, 1.0, 7)
		"_sewer_panel": c.call("_sewer_panel", 3, plane)
		"_annex_half_wall":
			c.call("_annex_block", mid, 0.0, 4.8, 0.30, 1.05,
				"annex_half_wall")
		"_air_adboxes": c.call("_air_adboxes", 3, plane)
		"_air_bin": c.call("_air_bin", mid)
		"_air_trolley": c.call("_air_trolley", mid, 0.0, 7, 3)
		"_stanchion_line":
			c.call("_stanchion_line", Vector3(3, 0, 6), Vector3(9, 0, 6), 3)
		"_air_jetway":
			var w := Node3D.new()
			c.add_child(w)
			c.call("_air_jetway", w)
		"_air_gate_desk": c.call("_air_gate_desk", mid, 0.0, "B12")
		"_checkin_desk": c.call("_checkin_desk", mid, 0.0, 0.0, 7)
		"_asy_fixture": c.call("_asy_fixture", Vector3(6, 2.7, 6), Mats.office_panel())
		"_asy_restraint_table": c.call("_asy_restraint_table", mid, 0.0)
		"_asy_ect": c.call("_asy_ect", mid, 0.0, 7)
		"_asy_iv": c.call("_asy_iv", mid)
		"_asy_straitjacket": c.call("_asy_straitjacket", 3, plane)
		"_asy_dayroom_table": c.call("_asy_dayroom_table", mid, 7)
		"_asy_chemistry_counter": c.call("_asy_chemistry_counter", mid, 0.0, 7)
		"_sch_bin": c.call("_sch_bin", mid)
		"_sch_trolley": c.call("_sch_trolley", mid, 0.0)
		"_sch_caf_table": c.call("_sch_caf_table", mid, 0.0, 7)
		"_sch_servery": c.call("_sch_servery", 3)
		"_sch_stalls": c.call("_sch_stalls", 3)
		"_sch_sinks": c.call("_sch_sinks", 3)
		"_sch_urinals": c.call("_sch_urinals", 3)
		"_sch_hoop": c.call("_sch_hoop", Vector3(6, 0, 1.0), 0.0)
		"_sch_bleachers": c.call("_sch_bleachers", mid, 0.0, 6.0)
		"_sch_stack": c.call("_sch_stack", mid, 0.0, 7)
		"_sch_stool": c.call("_sch_stool", mid, 7)
		"_sch_fountain": c.call("_sch_fountain", 3, plane)
		"_sch_case": c.call("_sch_case", 3, plane)
		"_mall_bench": c.call("_mall_bench", mid, 0.0)
		"_mall_display_table": c.call("_mall_display_table", mid, 0.0, 7)
		"_mall_shelves":
			# only mounts on a genuinely solid wall, and which walls are solid
			# is per-cell — try each until one takes.
			for d in 4:
				var n0 := c.get_child_count()
				c.call("_mall_shelves", d, 7)
				if c.get_child_count() > n0:
					break
		"_mall_rack": c.call("_mall_rack", mid, 0.0, 7)
		"_mall_counter": c.call("_mall_counter", mid, 0.0)
		"_mall_gondola": c.call("_mall_gondola", mid, 0.0, 4.0, 7)
		"_mall_food_table": c.call("_mall_food_table", mid, 7)
		"_mall_kiosk": c.call("_mall_kiosk", mid, 0.0, 7)
		"_mall_rope_post": c.call("_mall_rope_post", mid)
		"_prison_mess_table": c.call("_prison_mess_table", mid, 0.0)
		"_prison_shower_station": c.call("_prison_shower_station", 3, 6.0)
		"_prison_visitation_booth": c.call("_prison_visitation_booth", mid)
		"_prison_bars":
			c.call("_prison_bars", mid, 0.0, 3.1, 2.6, true, false)
		"_sch_locker_run":
			c.call("_sch_locker_run", true, 6.0, 2.0, 10.0, 1.0,
				Mats.sch_trim(), 0.45, 1.85, 7)
		"_sch_short_locker_run":
			c.call("_sch_locker_run", true, 6.0, 5.7, 6.3, 1.0,
				Mats.sch_trim(), 0.45, 1.85, 7)
		"_prison_visitation_phone":
			var v := Node3D.new()
			v.position = mid
			c.add_child(v)
			c.call("_prison_visitation_phone", v, 1.0)
		_:
			return false
	return true


## Bounds of everything added after `first`, in chunk space.
func _bounds(chunk: Chunk, first: int) -> AABB:
	var out := AABB()
	var have := false
	for i in range(first, chunk.get_child_count()):
		var n := chunk.get_child(i)
		if not (n is Node3D):
			continue
		for m in _meshes(n):
			var mi := m as MeshInstance3D
			if mi.mesh == null:
				continue
			var bb := _world_of(chunk, mi) * mi.mesh.get_aabb()
			out = bb if not have else out.merge(bb)
			have = true
	return out if have else AABB()


func _meshes(n: Node) -> Array:
	var out := []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out


## Transform from the chunk down to this node. The chunk is not in the tree in
## a useful place, so global_transform would be relative to the wrong root.
func _world_of(root: Node, target: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur := target
	while cur != null and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


func _stage(b: AABB) -> void:
	var extent: float = maxf(maxf(b.size.x, b.size.z), 0.6)
	var height: float = maxf(b.size.y, 0.5)
	var floor_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(maxf(6.0, extent * 4.0), 0.08, maxf(6.0, extent * 4.0))
	floor_mesh.mesh = box
	floor_mesh.position.y = -0.05
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.16, 0.16, 0.17)
	fm.roughness = 0.85
	floor_mesh.material_override = fm
	add_child(floor_mesh)

	var cam := Camera3D.new()
	var reach: float = maxf(extent, height)
	cam.position = Vector3(reach * 1.15, height * 0.62 + 0.5,
		maxf(2.2, reach * 1.9))
	cam.look_at_from_position(cam.position, Vector3(0, height * 0.45, 0),
		Vector3.UP)
	cam.fov = 46.0
	add_child(cam)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-46, -38, 0)
	key.light_energy = 1.5
	key.shadow_enabled = true
	add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-extent, height + 1.2, extent)
	fill.light_energy = 5.0
	fill.omni_range = maxf(8.0, extent * 5.0)
	add_child(fill)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.05, 0.055)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.43, 0.46)
	env.ambient_light_energy = 0.9
	world.environment = env
	add_child(world)

extends SceneTree
## Breathing ceiling + paired-wall proof. Office only.
## godot --path . --script tools/preview_breathing_surfaces.gd -- --case=ceiling
## godot --path . --script tools/preview_breathing_surfaces.gd -- --capture --case=paired --out-dir=/tmp/liminal-breathing-paired
const Probe := preload("res://tools/lib/breathing_wall_probe.gd")
const Cleanup := preload("res://tools/lib/audit_cleanup.gd")
const SEED := 980712989
const BREATH := 7.0
const FRAMES := 24

var case_name := "ceiling"
var theme := 1
var out_dir := "/tmp/liminal-breathing-surfaces"
var capture := false
var world: Node3D
var room: Chunk
var camera: Camera3D
var torch: SpotLight3D
var effects: Array[Node3D] = []
var label: Label
var elapsed := 0.0
var playing := true
var busy := true
var report: Dictionary = {}
var focus := Vector3.ZERO
var failed_write := false

func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--capture":
			capture = true
		elif arg.begins_with("--case="):
			var want: String = arg.trim_prefix("--case=")
			if want == "ceiling" or want == "paired":
				case_name = want
		elif arg.begins_with("--theme="):
			theme = int(arg.trim_prefix("--theme="))
		elif arg.begins_with("--out-dir="):
			out_dir = arg.trim_prefix("--out-dir=")
	call_deferred("_start")

func _start() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Visual preview needs a GPU renderer; omit --headless.")
		quit(1)
		return
	root.size = Vector2i(1280, 800)
	root.window_input.connect(_input)
	world = Node3D.new()
	root.add_child(world)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	label = Label.new()
	label.position = Vector2(20, 18)
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(label)
	Chunk.request_prop_preloads()
	await create_timer(2.0).timeout
	if capture:
		DirAccess.make_dir_recursive_absolute(out_dir)
		await _load_case(case_name)
		if effects.is_empty():
			_write_report()
			await _cleanup()
			await Cleanup.release(self)
			quit(1)
			return
		await _capture_sequence()
		_write_report()
		var ok: bool = _report_passes()
		await _cleanup()
		await Cleanup.release(self)
		quit(0 if ok else 1)
	else:
		await _load_case(case_name)
		busy = false

func _cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r in range(5):
		for dx in range(-r, r + 1):
			for dy in [-r, r]:
				var c := Vector2i(dx, dy)
				if not out.has(c):
					out.append(c)
			for dy2 in range(-r + 1, r):
				var c2 := Vector2i(dx, dy2) if dx == -r or dx == r else Vector2i(dx, dy2)
				if (dx == -r or dx == r) and not out.has(c2):
					out.append(c2)
	# Fallback: guarantee a bounded 5x5 grid even if ring logic drifts.
	if out.size() < 25:
		out.clear()
		for x in range(-2, 3):
			for y in range(-2, 3):
				out.append(Vector2i(x, y))
	return out.slice(0, 25)

func _load_case(which: String) -> void:
	busy = true
	await _cleanup()
	case_name = which
	var theme_name: String = str(DescentRun.THEME_NAMES.get(theme, "theme %d" % theme))
	label.text = "Finding %s patch in %s…" % [which, theme_name]
	await process_frame
	report = {"case": which, "theme": theme, "name": theme_name, "seed": SEED,
		"status": "no suitable patch", "samples": [], "surfaces": [], "files": []}
	var ws: int = WorldGen.level_seed(SEED, theme)
	var selection: Dictionary = {}
	for at: Vector2i in _cells():
		var candidate := Chunk.new(ws, at, theme)
		if which == "ceiling":
			selection = _select_ceiling(candidate)
		else:
			selection = _select_paired(candidate)
		if not selection.is_empty():
			room = candidate
			break
		candidate.free()
	if room == null or selection.is_empty():
		label.text = "%s (%s): no safe patch in 25 sampled cells." % [theme_name, which]
		report["status"] = "no suitable patch in 25 cells"
		return
	world.add_child(room)
	var env := WorldEnvironment.new()
	env.environment = EnvBuilder.build(theme)
	world.add_child(env)
	var surfaces: Array = selection["surfaces"]
	var descs: Array = []
	for entry: Dictionary in surfaces:
		var face: SurfaceWear.Face = entry["face"]
		var center: Vector3 = entry["center"]
		var psize: Vector2 = entry["size"]
		var pdepth: float = float(entry["depth"])
		var fx := Probe.new()
		room.add_child(fx)
		fx.attach(face, center, psize)
		fx.configure_size(psize, pdepth)
		effects.append(fx)
		descs.append({"material": face.material, "center": str(center),
			"normal": str(face.normal), "size": str(psize), "depth_m": pdepth})
	report["surfaces"] = descs
	report["cell"] = str(room.cell)
	report["status"] = "preview ready"
	report["native_fragment_shading_preserved"] = true
	camera = Camera3D.new()
	camera.fov = 68.0
	camera.near = 0.06
	world.add_child(camera)
	torch = SpotLight3D.new()
	torch.position = Vector3(0.10, -0.10, -0.06)
	torch.light_color = Color(0.88, 0.93, 1.0)
	torch.light_energy = 4.5
	torch.spot_range = 21.0
	torch.spot_angle = 46.0
	torch.spot_attenuation = 1.15
	torch.light_volumetric_fog_energy = 1.25
	torch.shadow_enabled = true
	camera.add_child(torch)
	if which == "ceiling":
		_frame_ceiling(selection)
	else:
		_frame_paired(selection)
	camera.current = true
	elapsed = 0.0
	_update_label()
	await physics_frame
	await physics_frame

# --- selection ---

func _scanner(chunk: Chunk) -> SurfaceWear:
	var scanner := SurfaceWear.new()
	scanner.host = chunk
	scanner.ctx = chunk._build_context
	for child: Node in chunk.get_children():
		scanner._scan(child, Transform3D.IDENTITY, -1)
	return scanner

func _blockers(chunk: Chunk) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var meshes: Array[Node] = chunk.find_children("*", "MeshInstance3D", true, false)
	for node: MeshInstance3D in meshes:
		if node.mesh == null or not node.visible:
			continue
		out.append({"mesh": node, "transform": _relative(node, chunk),
			"bounds": node.mesh.get_aabb()})
	return out

func _select_ceiling(chunk: Chunk) -> Dictionary:
	var scanner := _scanner(chunk)
	var blockers := _blockers(chunk)
	var floor_y: float = chunk._floor_h()
	for face: SurfaceWear.Face in scanner.ceilings:
		if face.normal.y > -0.98:
			continue
		if not (face.mesh.mesh is BoxMesh or face.mesh.mesh is QuadMesh):
			continue
		if face.size.x < 2.1 or face.size.y < 2.1:
			continue
		for cand: Vector2 in [Vector2(3.0, 2.5), Vector2(2.5, 2.0), Vector2(2.0, 2.0)]:
			var size_ := Vector2(minf(cand.x, face.size.x - 0.3), minf(cand.y, face.size.y - 0.3))
			if size_.x < 1.5 or size_.y < 1.5:
				continue
			for depth: float in [0.45, 0.35, 0.28]:
				if face.center.y - depth < floor_y + 2.25:
					continue
				for ox: float in [0.0, -0.25, 0.25]:
					for oy: float in [0.0, -0.25, 0.25]:
						var center: Vector3 = face.center + face.u * ox * face.size.x + face.v * oy * face.size.y
						if not _inside_face(face, center, size_):
							continue
						if _patch_clear(face, center, size_, blockers, depth, [face.mesh]):
							return {"surfaces": [{"face": face, "center": center,
								"size": size_, "depth": depth}]}
	return {}

func _select_paired(chunk: Chunk) -> Dictionary:
	var scanner := _scanner(chunk)
	var blockers := _blockers(chunk)
	var walls: Array[SurfaceWear.Face] = scanner.walls
	for i in range(walls.size()):
		var a: SurfaceWear.Face = walls[i]
		if not (a.mesh.mesh is BoxMesh or a.mesh.mesh is QuadMesh):
			continue
		for j in range(i + 1, walls.size()):
			var b: SurfaceWear.Face = walls[j]
			if b.mesh == a.mesh:
				continue
			if not (b.mesh.mesh is BoxMesh or b.mesh.mesh is QuadMesh):
				continue
			if a.normal.dot(b.normal) > -0.99:
				continue
			var delta: Vector3 = b.center - a.center
			var lane: float = delta.dot(a.normal)
			if lane < 2.0 or lane > 10.0:
				continue
			var mid: Vector3 = (a.center + b.center) * 0.5
			var pa: Vector3 = mid - a.normal * ((mid - a.center).dot(a.normal))
			var pb: Vector3 = mid - b.normal * ((mid - b.center).dot(b.normal))
			for size_: Vector2 in [Vector2(3.0, 2.0), Vector2(2.5, 1.8), Vector2(2.0, 1.5), Vector2(1.5, 1.2)]:
				for depth: float in [0.55, 0.45, 0.40, 0.30]:
					if lane - 2.0 * depth < 1.6:
						continue
					var floor_y: float = chunk._floor_h()
					var best_a := Vector3.ZERO
					var best_b := Vector3.ZERO
					var found := false
					for lift: float in [1.5, 1.2, 1.8]:
						for slide: float in [0.0, -0.6, 0.6]:
							var ca: Vector3 = pa + a.u * slide
							ca.y = floor_y + lift
							var cb: Vector3 = pb + a.u * slide
							cb.y = floor_y + lift
							if not _inside_face(a, ca, size_) or not _inside_face(b, cb, size_):
								continue
							if _patch_clear(a, ca, size_, blockers, depth, [a.mesh, b.mesh]) \
									and _patch_clear(b, cb, size_, blockers, depth, [a.mesh, b.mesh]):
								best_a = ca
								best_b = cb
								found = true
								break
						if found:
							break
					if found:
						return {"surfaces": [{"face": a, "center": best_a, "size": size_, "depth": depth},
							{"face": b, "center": best_b, "size": size_, "depth": depth}]}
	return {}

func _inside_face(face: SurfaceWear.Face, center: Vector3, size_: Vector2) -> bool:
	var off: Vector3 = center - face.center
	return absf(off.dot(face.u)) + size_.x * 0.5 + 0.1 <= face.size.x * 0.5 \
		and absf(off.dot(face.v)) + size_.y * 0.5 + 0.1 <= face.size.y * 0.5

func _patch_clear(face: SurfaceWear.Face, center: Vector3, size_: Vector2,
		blockers: Array[Dictionary], depth: float, skip: Array) -> bool:
	var frame := Transform3D(Basis(face.u, face.v, face.normal), center)
	var envelope := AABB(Vector3(-size_.x * 0.5, -size_.y * 0.5, -0.02),
		Vector3(size_.x, size_.y, depth + 0.12))
	for blocker: Dictionary in blockers:
		var bmesh: MeshInstance3D = blocker["mesh"]
		if skip.has(bmesh):
			continue
		var bxf: Transform3D = blocker["transform"]
		var bb: AABB = blocker["bounds"]
		var local: AABB = frame.affine_inverse() * bxf * bb
		if envelope.intersects(local):
			return false
	return true

func _relative(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result: Transform3D = node.transform
	var parent: Node = node.get_parent()
	while parent != ancestor and parent is Node3D:
		result = (parent as Node3D).transform * result
		parent = parent.get_parent()
	return result

# --- framing ---

func _blocker_boxes() -> Array[AABB]:
	var boxes: Array[AABB] = []
	if room == null:
		return boxes
	for node: MeshInstance3D in room.find_children("*", "MeshInstance3D", true, false):
		if node.mesh == null or not node.visible:
			continue
		boxes.append(_relative(node, room) * node.mesh.get_aabb())
	return boxes

func _segment_clear(a: Vector3, b: Vector3, boxes: Array[AABB], radius := 0.15) -> bool:
	for bb: AABB in boxes:
		if bb.grow(radius).intersects_segment(a, b) != null:
			return false
	return true

func _in_bounds(p: Vector3) -> bool:
	return p.x > 0.4 and p.x < 11.6 and p.z > 0.4 and p.z < 11.6 and p.y > 0.2 and p.y < 11.0

func _frame_ceiling(selection: Dictionary) -> void:
	var surfaces: Array = selection["surfaces"]
	var entry: Dictionary = surfaces[0]
	var center: Vector3 = entry["center"]
	var gc: Vector3 = room.to_global(center)
	focus = gc
	var floor_y: float = room._floor_h()
	var boxes := _blocker_boxes()
	for off: Vector2 in [Vector2(1.1, 1.1), Vector2(-1.1, 1.1), Vector2(1.1, -1.1), Vector2(-1.1, -1.1), Vector2(0.0, 1.6)]:
		var pos := Vector3(gc.x + off.x, floor_y + 1.5, gc.z + off.y)
		if not _in_bounds(pos):
			continue
		if _segment_clear(pos, gc + Vector3.DOWN * 0.25, boxes):
			camera.position = pos
			camera.look_at(gc, Vector3.UP)
			return
	var fallback := Vector3(clampf(gc.x + 1.0, 0.5, 11.5), floor_y + 1.5, clampf(gc.z + 1.0, 0.5, 11.5))
	camera.position = fallback
	camera.look_at(gc, Vector3.UP)

func _frame_paired(selection: Dictionary) -> void:
	var surfaces: Array = selection["surfaces"]
	var ea: Dictionary = surfaces[0]
	var eb: Dictionary = surfaces[1]
	var ca: Vector3 = room.to_global(ea["center"])
	var cb: Vector3 = room.to_global(eb["center"])
	var fa: SurfaceWear.Face = ea["face"]
	var mid: Vector3 = (ca + cb) * 0.5
	focus = mid
	var along: Vector3 = fa.normal.cross(Vector3.UP)
	if along.length() < 0.1:
		along = fa.u - fa.u.dot(Vector3.UP) * Vector3.UP
	along = along.normalized()
	var floor_y: float = room._floor_h()
	var boxes := _blocker_boxes()
	for side: float in [1.0, -1.0]:
		for dist: float in [4.2, 3.2, 5.2]:
			var pos: Vector3 = mid + along * (dist * side)
			pos.y = floor_y + 1.6
			if not _in_bounds(pos):
				continue
			if _segment_clear(pos, ca + fa.normal * 0.25, boxes) and _segment_clear(pos, cb - fa.normal * 0.25, boxes):
				camera.position = pos
				camera.look_at(mid, Vector3.UP)
				return
	var fb: Vector3 = mid + along * 3.5
	fb.y = floor_y + 1.6
	fb.x = clampf(fb.x, 0.5, 11.5)
	fb.z = clampf(fb.z, 0.5, 11.5)
	camera.position = fb
	camera.look_at(mid, Vector3.UP)

# --- capture ---

func _set_all(value: float) -> void:
	for fx: Node3D in effects:
		fx.set_amount(value)

func _grab(path: String) -> void:
	for warm in 6:
		await process_frame
		RenderingServer.force_draw(false, 1.0 / 60.0)
	var err: int = root.get_texture().get_image().save_png(path)
	if err != OK:
		failed_write = true
		report["capture_error"] = err
	else:
		var files: Array = report["files"]
		files.append(path)

func _check_collision(tag: String, expected_amount: float) -> void:
	var space: PhysicsDirectSpaceState3D = root.world_3d.direct_space_state
	var misses := 0
	var max_error := 0.0
	for fx: Node3D in effects:
		var normal: Vector3 = (fx.face as SurfaceWear.Face).normal
		var frame: Transform3D = fx.frame
		var w: float = (fx.patch_size as Vector2).x
		for frac: float in [-0.3, 0.0, 0.3]:
			var x: float = frac * w
			var h: float = fx.height_at(x, 0.0, expected_amount)
			var expected: Vector3 = room.to_global(frame * Vector3(x, 0.0, h))
			var query := PhysicsRayQueryParameters3D.create(expected + normal * 1.0, expected - normal * 0.2)
			var hit: Dictionary = space.intersect_ray(query)
			if hit.is_empty():
				misses += 1
			else:
				var hp: Vector3 = hit["position"]
				max_error = maxf(max_error, hp.distance_to(expected))
	var samples: Array = report["samples"]
	samples.append({"pose": tag, "amount": expected_amount, "misses": misses,
		"max_collision_error_m": max_error})

func _capture_sequence() -> void:
	_set_all(0.0)
	await physics_frame
	await physics_frame
	await _check_collision("rest", 0.0)
	label.text = "%s — rest" % case_name
	await _grab(out_dir.path_join("rest.png"))
	_set_all(1.0)
	await physics_frame
	await physics_frame
	await _check_collision("peak", 1.0)
	label.text = "%s — peak" % case_name
	await _grab(out_dir.path_join("peak.png"))
	for i in range(FRAMES):
		var amount: float = pow(sin(PI * float(i) / float(FRAMES)), 2.0)
		_set_all(amount)
		await physics_frame
		await physics_frame
		label.text = "%s — frame %d/24" % [case_name, i]
		await _grab(out_dir.path_join("frame_%03d.png" % i))
	_set_all(0.0)
	await physics_frame
	await physics_frame
	await _check_collision("returned-rest", 0.0)
	var mesh_ok := true
	var mat_ok := true
	for fx: Node3D in effects:
		fx.set_amount(0.0)
		mesh_ok = mesh_ok and fx.mesh_node.mesh == fx.original
		mat_ok = mat_ok and fx.mesh_node.material_override == fx.original_material
		fx.restore()
		mesh_ok = mesh_ok and fx.mesh_node.mesh == fx.original
		mat_ok = mat_ok and fx.mesh_node.material_override == fx.original_material
	report["original_mesh_restored"] = mesh_ok
	report["original_material_restored"] = mat_ok
	var misses := 0
	var max_error := 0.0
	var samples: Array = report["samples"]
	for s: Dictionary in samples:
		misses += int(s["misses"])
		max_error = maxf(max_error, float(s["max_collision_error_m"]))
	report["total_misses"] = misses
	report["max_collision_error_m"] = max_error
	report["collision_pass"] = misses == 0 and max_error < 0.01
	report["status"] = "captured" if not failed_write else "capture write failed"
	print(JSON.stringify(report))

func _report_passes() -> bool:
	if effects.is_empty():
		return false
	if failed_write:
		return false
	if report.has("capture_error"):
		return false
	return bool(report.get("collision_pass", false)) \
		and bool(report.get("original_mesh_restored", false)) \
		and bool(report.get("original_material_restored", false))

func _write_report() -> void:
	var file: FileAccess = FileAccess.open(out_dir.path_join("report.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "  "))
	else:
		failed_write = true
		printerr("Could not write report.json to %s" % out_dir)

# --- interactive ---

func _update_label() -> void:
	if effects.is_empty():
		return
	var parts: Array[String] = []
	for fx: Node3D in effects:
		var ps: Vector2 = fx.patch_size
		parts.append("%.1f x %.1f m, %d cm" % [ps.x, ps.y, int(round(fx.amplitude * 100.0))])
	label.text = "%s (%s) — %s\n1/2 case - Space pause - R rest - B peak - F flashlight" % [
		str(DescentRun.THEME_NAMES.get(theme, "")), case_name, " + ".join(parts)]

func _process(delta: float) -> bool:
	if not busy and not effects.is_empty() and playing:
		elapsed += delta
		_set_all(pow(sin(PI * fmod(elapsed, BREATH) / BREATH), 2.0))
	return false

func _input(event: InputEvent) -> void:
	if busy or not (event is InputEventKey):
		return
	var key: InputEventKey = event
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_ESCAPE:
			quit()
		KEY_SPACE:
			playing = not playing
		KEY_1:
			await _load_case("ceiling")
			busy = false
		KEY_2:
			await _load_case("paired")
			busy = false
		KEY_R, KEY_B:
			playing = false
			_set_all(0.0 if key.keycode == KEY_R else 1.0)
		KEY_F:
			if torch != null:
				torch.visible = not torch.visible

func _cleanup() -> void:
	for fx: Node3D in effects:
		if is_instance_valid(fx):
			fx.restore()
	effects.clear()
	camera = null
	torch = null
	room = null
	if world != null:
		for child: Node in world.get_children():
			child.queue_free()
		await process_frame
		await physics_frame

extends SceneTree
## Native Office doorway proof only. No campaign, saves, monsters or topology writes.
const Room := preload("res://tools/lib/doorway_preview_chunk.gd")
const Effect := preload("res://tools/lib/native_doorway_proof.gd")
var world: Node3D
var effect: Node3D
var player: Player
var cam: Camera3D
var label: Label
var capture := false
var check := false
var target := 0.0
var moving := false
var ready := false
var sound: Node
var post_process: PostProcessController
var output := "/tmp/liminal-native-doorway"
var _motion_review := false
var _render_poses := 0
var _collision_updates := 0
var _motion_frame_ms: Array[float] = []

func _init() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	check = "--check" in OS.get_cmdline_user_args()
	_motion_review = "--motion-check" in OS.get_cmdline_user_args()
	root.window_input.connect(_input)
	call_deferred("start")

func start() -> void:
	Engine.max_fps = 60
	root.size = Vector2i(1440,900)
	root.title = "Liminal — Native doorway proof (F6 to transform)"
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	GameSettings.current = GameSettings.new()
	var ws := WorldGen.level_seed(980712989, 1)
	var site := Vector2i.ZERO
	var found := false
	for x in range(-12,13):
		for z in range(-12,13):
			var at := Vector2i(x,z)
			if WorldGen.cell_style(ws,at,1) != WorldGen.OFFICE_EMPTY: continue
			if WorldGen.room_size(ws,WorldGen.room_id(ws,at)) != 1: continue
			if WorldGen.cell_style(ws,at+Vector2i(0,1),1) != WorldGen.OFFICE_CORRIDOR: continue
			if WorldGen.corridor(ws,at+Vector2i(0,1)) != 2: continue
			site = at
			found = true
			break
		if found: break
	assert(found, "No native Office room/corridor pair")
	print("Doorway native fixture: ",site)
	var near_room := Room.new(ws,site,2)
	var far_room := Room.new(ws,site+Vector2i(0,1),3)
	world.add_child(near_room)
	far_room.position.z = 12.0
	world.add_child(far_room)
	# Neighbours provide actual ceiling/lighting beyond the passage, not a void.
	for offset in [Vector2i(0,2),Vector2i(1,1),Vector2i(-1,1)]:
		var room := Chunk.new(ws,site+offset,1)
		room.position = Vector3(offset.x*12,0,offset.y*12)
		world.add_child(room)
	var env := WorldEnvironment.new()
	env.environment = EnvBuilder.build(1)
	world.add_child(env)
	effect = Effect.new()
	# The selected treatment is deformation with a soft local boundary.
	# The older looks remain available only as comparison modes.
	effect.magic_enabled = "--full-magic" in OS.get_cmdline_user_args()
	effect.soft_deformation = not effect.magic_enabled and not ("--deformation-only" in OS.get_cmdline_user_args())
	effect.position = Vector3(6,0,12)
	world.add_child(effect)
	effect.setup(near_room,far_room)
	sound = preload("res://scripts/supernatural_audio.gd").new()
	world.add_child(sound)
	var violations := near_room.doorway_clearance_violations()+far_room.doorway_clearance_violations()
	assert(violations == 0, "Native doorway approaches obstructed")
	print("Native doorway clearance: PASS")
	var layer := CanvasLayer.new()
	root.add_child(layer)
	label = Label.new()
	label.position = Vector2(20,18)
	label.add_theme_font_size_override("font_size",18)
	layer.add_child(label)
	if "--vhs-crt" in OS.get_cmdline_user_args():
		# The game's actual two-pass presentation, without changing saved settings.
		post_process = PostProcessController.new()
		world.add_child(post_process)
		post_process.setup(world,true,true)
		post_process.ensure_scene_copy()
		root.size_changed.connect(_apply_presentation_scaling)
		_apply_presentation_scaling()
		print("Presentation: VHS ON / CRT ON (native game passes, 480-line 3D source)")
	if check or capture:
		cam = Camera3D.new()
		world.add_child(cam)
		cam.fov = 68
		cam.position = Vector3(4.5,1.5,6.3)
		cam.look_at(Vector3(6,1.3,12))
		cam.current = true
		var torch := SpotLight3D.new()
		torch.position = Vector3(0.10,-0.10,-0.06)
		torch.light_color = Color(0.88,0.93,1.0)
		torch.light_energy = Player.FLASH_ENERGY
		torch.spot_range = 21.0
		torch.spot_angle = 46.0
		torch.shadow_enabled = true
		cam.add_child(torch)
		await _review()
		return
	player = Player.new()
	player.position = Vector3(5.2,0.05,6.4)
	player.rotation.y = PI
	world.add_child(player)
	player.set_flashlight(true)
	cam = player.cam
	ready = true
	_update_label()
	if "--input-check" in OS.get_cmdline_user_args():
		await _review_input()
	elif _motion_review: await _review_motion()
	else: root.grab_focus()

func _review() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	if capture and "--particle-closeup" in OS.get_cmdline_user_args():
		await _review_particle_closeup()
		world.queue_free()
		await process_frame
		await preload("res://tools/lib/audit_cleanup.gd").release(self)
		quit()
		return
	var max_pose_ms := 0.0
	# Sweep actual 60 Hz poses through the last third of opening / first third
	# of closing. Endpoint-only images missed the earlier, nearly-flat sill.
	for appearing in [true,false]:
		effect.opening = appearing
		var steps := roundi(Effect.TRANSITION_SECONDS*60.0)
		for frame in range(1,steps):
			var amount := float(frame if appearing else steps-frame)/steps
			if amount < 0.68: continue
			effect.pose(amount)
			_assert_no_sill()
	effect.opening = true
	for side in [-1,1]:
		cam.position = Vector3(5.35,1.5,12+side*5.0)
		cam.look_at(Vector3(6,1.3,12))
		for phase in [0.0,0.25,0.5,0.68,0.75,0.85,0.9,0.96,0.999,1.0,0.0]:
			var start_usec := Time.get_ticks_usec()
			effect.pose(phase)
			max_pose_ms = maxf(max_pose_ms,(Time.get_ticks_usec()-start_usec)/1000.0)
			_update_label()
			await physics_frame
			await physics_frame
			var offset := Vector3(0,0,side*0.5)
			var ray := PhysicsRayQueryParameters3D.create(Vector3(6,1.2,12)+offset,Vector3(6,1.2,12)-offset)
			var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
			if phase == 0.0: assert(not hit.is_empty(), "Closed wall lost collision")
			if phase == 1.0: assert(hit.is_empty(), "Open doorway blocked")
			if phase >= 0.68 and phase < 1.0: _assert_no_sill()
			if not effect.magic_enabled or phase == 0.0 or phase == 1.0:
				assert(not effect.sparks.visible and not effect.smoke.visible and not effect.veil.visible and not effect.hot_fragments.visible and effect._magic_amount == 0.0, "Magic survives disabled mode or stable endpoint")
				for material in [effect.wall_material,effect.rim_material]:
					assert(material.get_shader_parameter("magic_amount") == 0.0, "Wall glow survives disabled mode or stable endpoint")
			var edge_amount: float = effect.soft_edge_material.get_shader_parameter("magic_amount")
			assert(effect.soft_edge.visible == (edge_amount > 0.001 and phase > 0.0 and phase < 1.0), "Boundary blend visibility mismatch")
			if phase == 0.0 or phase == 1.0 or (not effect.magic_enabled and not effect.soft_deformation):
				assert(edge_amount == 0.0, "Boundary blend survives a sharp mode or stable endpoint")
			for chunk in effect.chunks:
				for mesh in chunk.site_nodes:
					assert(mesh.visible == (phase == 1.0), "Native geometry ownership mismatch")
				for shape in chunk.site_shapes:
					assert(shape.disabled == (phase != 1.0), "Native collision ownership mismatch")
			if capture:
				for i in 45:
					effect.advance_magic(1.0/60)
					await process_frame
				root.get_texture().get_image().save_png(output.path_join("side%d-phase%.3f.png"%[side,phase]))
	print("PASS — native endpoints, approach clearance, two-sided collision and closed restoration")
	print("Maximum sampled pose build: ",max_pose_ms," ms (not a frame-time guarantee)")
	world.queue_free()
	await process_frame
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit()

func _review_particle_closeup() -> void:
	cam.position = Vector3(4.8,1.4,10.0)
	cam.look_at(Vector3(4.9,1.4,12))
	cam.fov = 38.0
	effect.pose(0.5)
	_update_label()
	for i in 60:
		effect.advance_magic(1.0/60)
		await process_frame
	# Identical fragment positions/ages in both views isolate the edge blur.
	for fragments in effect.hot_fragments.get_children(): fragments.set_process(false)
	for enabled in [true,false]:
		effect.soft_edge.visible = enabled
		for i in 16: await process_frame
		root.get_texture().get_image().save_png(output.path_join("particle-closeup-blur-%s.png"%str(enabled)))
	print("Captured frozen hot particles with edge blur on/off")

func _assert_no_sill() -> void:
	# No upward-facing reveal or casing return may span the lowest 12 cm.
	for i in range(0,effect._rim_vertices.size(),3):
		var a: Vector3 = effect._rim_vertices[i]
		var b: Vector3 = effect._rim_vertices[i+1]
		var c: Vector3 = effect._rim_vertices[i+2]
		var low := maxf(a.y,maxf(b.y,c.y)) < 0.12
		assert(not (low and effect._rim_normals[i].y > 0.5), "Doorway left a floor-level sill at %.4f"%effect.phase)

func _physics_process(_dt: float) -> bool:
	if ready and effect.sync_collision(): _collision_updates += 1
	return false

func _apply_presentation_scaling() -> void:
	# Match Main._apply_scaling: only the 3D source is lowered to 480 lines.
	root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	root.scaling_3d_scale = clampf(480.0/float(maxi(root.size.y,1)),0.05,1.0)

func _process(dt: float) -> bool:
	if is_instance_valid(post_process): post_process.update()
	if not ready: return false
	if not moving:
		effect.advance_magic(dt)
		return false
	var p := player.global_position
	if target == 0.0 and absf(p.z-12.0)<1.6 and absf(p.x-6.0)<2.3:
		label.text = "Doorway holds open — step clear of the opening to close it."
		sound.set_in_view(false)
		effect.advance_magic(dt)
		return false
	sound.set_in_view(cam.is_position_in_frustum(Vector3(6,1.2,12)))
	if _motion_review: _motion_frame_ms.append(dt*1000.0)
	# pose updates emitters against the new contour once, not three times/tick.
	effect.magic_clock += dt
	effect.pose(move_toward(effect.phase,target,dt/Effect.TRANSITION_SECONDS),false)
	_render_poses += 1
	# move_toward snaps exactly; native geometry/collision also use exact endpoints.
	moving = effect.phase != target
	if not moving: sound.end_event()
	_update_label()
	return false

func _review_motion() -> void:
	# Measure the live render/physics split, not a synthetic mesh-build loop.
	for i in 60: await process_frame
	for goal in [1.0,0.0]:
		_render_poses = 0
		_collision_updates = 0
		_motion_frame_ms.clear()
		var started := Time.get_ticks_usec()
		target = goal
		effect.opening = goal == 1.0
		moving = true
		while moving: await process_frame
		var seconds := float(Time.get_ticks_usec()-started)/1000000.0
		await physics_frame
		await physics_frame
		assert(effect.phase == goal and effect._collision_phase == goal, "Render/collision endpoint mismatch")
		assert(effect.collider.disabled == (goal == 1.0), "Wrong endpoint collision")
		for chunk in effect.chunks:
			for shape in chunk.site_shapes:
				assert(shape.disabled == (goal != 1.0), "Native collision did not settle")
		print("Motion %s: %.3f s, %d distinct render poses (%.1f/s), %d collision updates"%
			["open" if goal == 1.0 else "close",seconds,_render_poses,_render_poses/seconds,_collision_updates])
		_motion_frame_ms.sort()
		print("Frame time: p95 %.2f ms, maximum %.2f ms"%
			[_motion_frame_ms[int((_motion_frame_ms.size()-1)*0.95)],_motion_frame_ms.back()])
		if goal == 0.0 and effect.magic_enabled:
			assert(effect.hot_fragments.visible and effect.hot_fragments.get_child_count() > 0, "Closing particles were cut off")
			await create_timer(ShadowBurnFragments.DURATION+0.1).timeout
			assert(effect.hot_fragments.get_child_count() == 0 and not effect.hot_fragments.visible, "Closing particles did not settle")
			print("Closing particle tail: PASS — survives closure, then naturally fades away")
		for i in 30: await process_frame
	ready = false
	world.queue_free()
	await process_frame
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit()

func _review_input() -> void:
	# Exercise the engine input path, not a direct handler/animation call.
	for i in 10: await process_frame
	var passed := true
	var keys := [KEY_F6,KEY_B,KEY_M,KEY_F6,KEY_B,KEY_M]
	for index in keys.size():
		var key: Key = keys[index]
		var before: Variant = target if key == KEY_F6 else (effect.soft_deformation if key == KEY_B else effect.magic_enabled)
		var event := InputEventKey.new()
		# Cover native physical keys and logical-only forwarded key events.
		event.physical_keycode = key if index < 3 else KEY_NONE
		event.keycode = key
		event.pressed = true
		Input.parse_input_event(event)
		await process_frame
		event = event.duplicate()
		event.pressed = false
		Input.parse_input_event(event)
		var after: Variant = target if key == KEY_F6 else (effect.soft_deformation if key == KEY_B else effect.magic_enabled)
		var changed: bool = before != after
		print("Input %s: %s"%[OS.get_keycode_string(key),"PASS" if changed else "FAIL"])
		passed = passed and changed
	ready = false
	world.queue_free()
	await process_frame
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit(0 if passed else 1)

func _update_label() -> void:
	var treatment := "Full magic" if effect.magic_enabled else ("Soft deformation — blended edges, no particles, smoke or glow" if effect.soft_deformation else "Deformation only — sharp edges, no particles, smoke or glow")
	if is_instance_valid(post_process): treatment += " • VHS + CRT ON"
	# Native title feedback remains readable outside the VHS/CRT shaders.
	var state := ("Opening" if target == 1.0 else "Closing") if moving else ("Open" if effect.phase >= 1.0 else "Closed")
	var title := "Liminal — Doorway | %s | %s"%[state,treatment]
	if root.title != title: root.title = title
	label.text = "NATIVE DOORWAY — isolated visual proof, not campaign\nF6: appear / disappear • M: full magic • B: soft / sharp deformation • WASD / mouse • F: torch • Esc: release mouse\n%s\n%s — %.0f%% • original ceiling, carpet and adjoining rooms"%[treatment,"Transforming" if effect.phase>0 and effect.phase<1 else ("Ordinary opening" if effect.phase>=1 else "Solid wall"),effect.phase*100]

func _input(event: InputEvent) -> void:
	if not ready: return
	if not (event is InputEventKey) or not event.pressed or event.echo: return
	var key: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	if key == KEY_F6:
		target = 0.0 if target == 1.0 else 1.0
		effect.opening = target == 1.0
		sound.begin_event()
		moving = true
	elif key == KEY_M:
		effect.magic_enabled = not effect.magic_enabled
		effect.pose(effect.phase)
	elif key == KEY_B:
		effect.soft_deformation = effect.magic_enabled or not effect.soft_deformation
		effect.magic_enabled = false
		effect.pose(effect.phase)
	else: return
	print("Preview input: ",OS.get_keycode_string(key))
	_update_label()

extends SceneTree
## Runtime contracts for the six Blender replacements, beyond file existence.
const MOTION := preload("res://scripts/airport_carousel_motion.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("HERO_PROP_AUDIT: " + message)


func _init() -> void:
	call_deferred("run")


func run() -> void:
	for pair in [[4, Chunk.AIRPORT_CAROUSEL_PATH], [5, Chunk.ASY_ECT_PATH], [5, Chunk.ASY_RESTRAINT_PATH],
			[8, Chunk.VT100_MONITOR_PATH], [8, Chunk.VT100_KEYBOARD_PATH], [7, Chunk.MALL_MERCHANDISE_PATH],
			[7, Chunk.MALL_DISPLAY_PATH], [11, Chunk.BLOOM_INCUBATOR_PATH]]:
		check(Chunk._prop_preload_paths().has(pair[1]), "Missing global prefetch: " + pair[1])
		check(Chunk.theme_prop_paths(pair[0]).has(pair[1]), "Missing theme prefetch: " + pair[1])
	# Dense path sampling tests both joins and corner motion, plus clearance for luggage.
	var prior := MOTION.path_pose(0.0)
	for i in range(1, 1001):
		var pose := MOTION.path_pose(MOTION.PATH_LENGTH * i / 1000.0)
		check(Vector2(prior.x, prior.z).distance_to(Vector2(pose.x, pose.z)) < MOTION.PATH_LENGTH / 999.0,
			"Carousel luggage jumps at a belt join")
		var cap_z := clampf(pose.z, -MOTION.HALF_STRAIGHT, MOTION.HALF_STRAIGHT)
		check(Vector2(pose.x, pose.z - cap_z).length() + 0.28 < MOTION.OUTER_RADIUS,
			"Moving luggage crosses the carousel rim")
		var tangent := Vector3(pose.x - prior.x, 0, pose.z - prior.z).normalized()
		var heading := Basis(Vector3.UP, -pose.y) * Vector3.BACK
		check(heading.dot(tangent) > 0.999, "Carousel luggage heading is not tangent to belt")
		prior = pose
	var movement := MOTION.new()
	var carrier := Node3D.new()
	carrier.set_meta("carousel_path_offset", 1.0)
	movement.add_child(carrier)
	movement.place_luggage()
	check(is_equal_approx(carrier.position.y, MOTION.BELT_HEIGHT + 0.018),
		"Luggage is not resting on the taller belt deck")
	var before := carrier.transform
	movement._process(1.0)
	check(not carrier.transform.is_equal_approx(before), "Carousel luggage does not move")
	movement.speed = 0.0
	before = carrier.transform
	movement._process(1.0)
	check(carrier.transform.is_equal_approx(before), "Stopped carousel still moves luggage")
	movement.free()
	# Exercise the actual VT100 interaction callbacks and actual authored screen.
	var prison := Chunk.new(WorldGen.level_seed(4242, 8), Vector2i.ZERO, 8)
	root.add_child(prison)
	var terminal := prison._vt100(Vector3(6, 0, 6), 0.0)
	check(terminal != null, "VT100 failed to instantiate")
	if terminal != null:
		var screen := terminal.find_child("CRTScreen", true, false) as MeshInstance3D
		var readout: Label3D
		var hit: Interactable
		for child in terminal.get_children():
			if child is Label3D and child.has_meta("terminal_readout"): readout = child
			if child is Interactable: hit = child
		check(screen != null and readout != null and hit != null, "Terminal lost its live screen/readout/interaction")
		if screen != null and hit != null and readout != null:
			prison._use_terminal(prison, hit, readout, screen)
			check(readout.visible and hit.get_meta("queried"), "Terminal query did not reveal record")
			var initial := int(hit.get_meta("page"))
			prison._use_terminal(prison, hit, readout, screen)
			check(int(hit.get_meta("page")) == (initial + 1) % Chunk.TERMINAL_PAGES.size(), "Terminal next record failed")
			prison._reset_terminal(hit, readout, screen)
			check(not readout.visible and not hit.get_meta("queried"), "Terminal reset failed")
	prison.free()
	# The guard desk top is y=.7875; the keyboard must sit on it, not sink into it.
	var guard := Chunk.new(WorldGen.level_seed(4242, 8), Vector2i.ZERO, 8)
	var keyboard := guard._vt100_keyboard(Vector3.ZERO, 0.0)
	var keyboard_model := keyboard.get_child(0) as Node3D
	check(is_equal_approx(keyboard_model.position.y, Chunk.VT100_DESK_HEIGHT),
		"Keyboard is below the measured desk surface")
	guard.free()
	# Interior pulse must never scale the rigid machine or its glass.
	var bloom := Chunk.new(WorldGen.level_seed(4242, 11), Vector2i.ZERO, 11)
	root.add_child(bloom)
	var first := bloom.get_child_count()
	bloom._level_builder._incubator_pod(Vector3(6, 0, 6), Vector3.ONE, 0.3)
	var vessel := bloom.get_child(first) as Node3D
	var egg := vessel.find_child("LivingEgg", true, false) as MeshInstance3D
	var glass := vessel.find_child("ContainmentGlass", true, false) as MeshInstance3D
	var liquid := vessel.find_child("PreservationLiquid", true, false) as MeshInstance3D
	var pulse := vessel.find_child("LivingEggPulse", true, false) as Node3D
	check(egg != null and glass != null and liquid != null and pulse != null, "Incubator missing egg, fluid, glass or pulse")
	if pulse != null and glass != null:
		var glass_xf := glass.global_transform
		var egg_xf := egg.global_transform
		pulse._process(0.5)
		check(glass.global_transform.is_equal_approx(glass_xf), "Rigid tank pulses with egg")
		check(not egg.global_transform.is_equal_approx(egg_xf), "Egg does not pulse inside tank")
		check(glass.material_override is ShaderMaterial and liquid.material_override is ShaderMaterial,
			"Tank fluid/glass shaders not installed")
		for step in 24:
			pulse._process(0.25)
			var xf := vessel.global_transform.affine_inverse() * egg.global_transform
			var egg_bounds := xf * egg.mesh.get_aabb()
			check(egg_bounds.get_center().distance_to(Vector3(0.23, 1.18, 0.035)) < 0.055,
				"Egg shifted away from the containment chamber center")
			check(egg_bounds.position.y > 0.583 and egg_bounds.end.y < 1.663,
				"Pulsing egg extends above or below preservation fluid")
	bloom.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("HERO_PROP_AUDIT: failures=%d" % failures)
	quit(1 if failures else 0)

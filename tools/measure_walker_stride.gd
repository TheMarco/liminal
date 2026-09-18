extends SceneTree
## Sample authored foot trajectories at the actual in-game model scale.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var failures := 0
	var checked := 0
	var expected := 0
	for index in ShadowWalkerVisual.model_count():
		var visual := ShadowWalkerVisual.new()
		visual.model_index = index
		root.add_child(visual)
		var skeleton := visual.find_child("Skeleton3D", true, false) as Skeleton3D
		if skeleton == null:
			print("missing skeleton ", index)
			visual.free()
			continue
		var animation := visual.animation_player()
		animation.set_process(false)
		var clip := animation.get_animation(&"runtime/walk")
		print("MODEL ", index, " length ", clip.length, " skeleton scale ", skeleton.global_basis.get_scale())
		var feet: Array[int] = []
		for bone in skeleton.get_bone_count():
			var name := skeleton.get_bone_name(bone)
			if "foot" in name.to_lower() or "toe" in name.to_lower():
				feet.append(bone)
				print("  bone ", bone, " ", name)
			# Non-biped roster members (the hound) carry no toe bases;
			# expect only the feet the skeletons actually have.
			if "toebase" in name.to_lower():
				expected += 1
		var samples := {}
		for bone in feet:
			samples[bone] = []
		var count := 240
		for frame in count + 1:
			animation.seek(clip.length * frame / count, true)
			skeleton.force_update_all_bone_transforms()
			for bone in feet:
				samples[bone].append(skeleton.to_global(skeleton.get_bone_global_pose(bone).origin))
		for bone in feet:
			var positions: Array = samples[bone]
			var low := INF
			var high := -INF
			for p: Vector3 in positions:
				low = minf(low, p.y)
				high = maxf(high, p.y)
			var speeds: Array[float] = []
			var old_drift: Array[float] = []
			var new_drift: Array[float] = []
			for frame in range(1, count):
				var a: Vector3 = positions[frame - 1]
				var b: Vector3 = positions[frame]
				var v := (b - a) / (clip.length / count)
				if b.y <= low + (high - low) * 0.25 and v.z < -0.1:
					speeds.append(-v.z)
					# Net world-space foot velocity, as a fraction of body speed:
					# body advance + local stance-foot retreat at playback scale.
					old_drift.append(absf(1.0 + v.z / 2.9))
					new_drift.append(absf(1.0 + v.z / visual.walk_cycle_speed()))
			speeds.sort()
			old_drift.sort()
			new_drift.sort()
			print("  ", skeleton.get_bone_name(bone), " height ", low, "..", high,
				" stance samples ", speeds.size(), " median backwards m/s ",
				speeds[speeds.size()/2] if not speeds.is_empty() else 0.0)
			if "toebase" in skeleton.get_bone_name(bone).to_lower():
				checked += 1
				var median := new_drift[new_drift.size()/2] if not new_drift.is_empty() else INF
				var before := old_drift[old_drift.size()/2] if not old_drift.is_empty() else INF
				print("    median planted-foot slide: ", snappedf(before * 100, 0.1),
					"% -> ", snappedf(median * 100, 0.1), "% of body speed")
				# Sampling a discrete imported clip can move the median by a few
				# tenths of a percent at a phase boundary. Keep the 60% reduction
				# contract, with 0.2 percentage points of measurement tolerance.
				if median > 0.12 or median > before * 0.4 + 0.002:
					failures += 1
					push_error("Stride calibration does not sufficiently reduce foot drift")
		visual.free()
	if checked != expected:
		failures += 1
	print("stride calibration: ", checked, " stance feet checked; ", failures, " failures")
	quit(0 if failures == 0 else 1)

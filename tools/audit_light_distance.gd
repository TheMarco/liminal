extends "res://tools/lib/audit_base.gd"
## Installation preserves practical fixtures' paired light/shadow fade budget.
## Legacy stream lights may extend their reach; prop glows stay authored.

func run() -> void:
	var rooms := 0
	var lamps := 0
	var practicals := 0
	var accents := 0
	for theme in WorldGen.THEMES:
		var manager := ChunkManager.new()
		manager.world_seed = WorldGen.level_seed(240721, theme)
		manager.theme = theme
		root.add_child(manager)
		manager.set_process(false)
		for cell in [Vector2i.ZERO, Vector2i(3, 3), Vector2i(-4, 2)]:
			var chunk := manager._build(cell, false)
			var before := {}
			for node in chunk.find_children("*", "Light3D", true, false):
				var light := node as Light3D
				before[light] = [light.distance_fade_enabled, light.distance_fade_begin,
					light.distance_fade_length, light.distance_fade_shadow,
					light.light_energy, light.visible, light.shadow_enabled]
			chunk.prepare_runtime_rendering(ChunkManager.ROOM_LIGHT_FADE_BEGIN)
			for light: Light3D in before:
				var state: Array = before[light]
				expect(light.light_energy == state[4] and light.visible == state[5] \
					and light.shadow_enabled == state[6], "distance preparation changed fixture state")
				if light.get_meta("stream_room_light", false) and state[0]:
					lamps += 1
					expect(light.distance_fade_begin >= ChunkManager.ROOM_LIGHT_FADE_BEGIN,
						"theme %d architectural lamp fades inside visible core" % theme)
					expect(light.distance_fade_length == state[2], "shadow fade length increased")
					expect(minf(light.distance_fade_begin, light.distance_fade_shadow) <= minf(state[1], state[3]),
						"effective shadow budget increased")
				else:
					accents += 1
					expect([light.distance_fade_enabled, light.distance_fade_begin,
						light.distance_fade_length, light.distance_fade_shadow] == state.slice(0, 4),
						"distance preparation changed a prop light or an unfaded light")
				if light.has_meta("practical_shadow_tier"):
					practicals += 1
					_check_practical(light)
			manager._install_chunk(cell, chunk)
			rooms += 1
		stop_audio(manager)
		manager.queue_free()
		await process_frame
	# Prove the actual installer applies this even without explicit preparation.
	var airport := ChunkManager.new()
	airport.world_seed = 99173
	airport.theme = 4
	root.add_child(airport)
	airport.set_process(false)
	var working := airport._build(Vector2i.ZERO)
	var checked := 0
	for node in working.find_children("*", "Light3D", true, false):
		if node.has_meta("practical_shadow_tier"):
			checked += 1
			_check_practical(node)
		elif node.get_meta("stream_room_light", false):
			checked += 1
			expect(node.distance_fade_begin >= ChunkManager.ROOM_LIGHT_FADE_BEGIN,
				"ordinary streaming did not apply room-light policy")
	expect(checked > 0 and practicals > 20 and accents > practicals,
		"audit failed to exercise practical fixtures and prop lights")
	working.set_blackout(true)
	working.set_blackout(false)
	for node in working.find_children("*", "Light3D", true, false):
		if node.has_meta("practical_shadow_tier"):
			_check_practical(node)
		elif node.get_meta("stream_room_light", false):
			expect(node.distance_fade_begin >= ChunkManager.ROOM_LIGHT_FADE_BEGIN,
				"blackout restored the obsolete lighting distance")
	stop_audio(airport)
	airport.queue_free()
	await process_frame
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("LIGHT_DISTANCE rooms=%d legacy_extended=%d practicals=%d unchanged=%d" % [
		rooms, lamps, practicals, accents])
	finish("streamed lighting distance")


func _check_practical(light: Light3D) -> void:
	expect(light.distance_fade_enabled and light.distance_fade_begin == 24.0
		and light.distance_fade_length == 8.0, "installation changed practical fade budget")
	expect(light.shadow_enabled and light.shadow_opacity == 1.0
		and light.distance_fade_shadow >= light.distance_fade_begin,
		"fixture occlusion fades before its light")

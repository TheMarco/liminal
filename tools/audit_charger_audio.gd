extends "res://tools/lib/audit_base.gd"
## Real Descent station, listener, supplied loop and game-bus routing.
## Run with --test-mode --nologo. Captures samples; not an ear-verified mix.

func find_station(node: Node) -> ChargingStation:
	for child in node.get_children():
		if child is ChargingStation and not child.broken:
			return child
		var result := find_station(child)
		if result != null:
			return result
	return null


func measure(capture: AudioEffectCapture, seconds: float) -> Vector2:
	capture.clear_buffer()
	await create_timer(seconds).timeout
	var samples := capture.get_buffer(capture.get_frames_available())
	var energy := 0.0
	var peak := 0.0
	for sample in samples:
		energy += sample.length_squared()
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	return Vector2(linear_to_db(sqrt(energy / maxf(1.0, samples.size() * 2.0))),
		linear_to_db(peak))


func run() -> void:
	Engine.max_fps = 60
	var game := await boot_game(1175477015)
	await create_timer(2.0).timeout
	var station := find_station(game.level_root)
	expect(station != null, "No healthy generated station")
	if station == null:
		await teardown_game(game)
		finish()
		return
	game.cm.set_process(false)
	game.player.set_physics_process(false)
	game.player.teleport(station.global_position + station.global_basis.z * 1.5 + Vector3.UP * 0.05)
	game.player.cam.look_at(station._hit.global_position)
	game.player._flash_charge = 5.0
	game.player._scan_interaction()
	expect(game.player._focused == station._hit, "Real interaction ray missed charger")
	expect(station._hum.stream == SoundBank.buzz(), "Charger stopped using the supplied recording")
	expect(station._hum.bus == SoundBank.HALL_BUS, "Charger bypasses world reverb/mute")
	expect(not AudioServer.is_bus_mute(AudioServer.get_bus_index(SoundBank.GAME_BUS)),
		"Game audio muted during charging")
	# Isolate this emitter for measurement, still feeding the real Hall -> Game chain.
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, "ChargerAudit")
	AudioServer.set_bus_send(idx, SoundBank.HALL_BUS)
	station._hum.bus = "ChargerAudit"
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 12.0
	AudioServer.add_bus_effect(idx, capture)
	await create_timer(0.2).timeout
	var idle := await measure(capture, 0.8)
	station._hit.activated.emit(game.player)
	await create_timer(0.1).timeout
	expect(game.player.is_charging_at(station), "E activation did not charge")
	expect(station._hum.volume_db == ChargingStation.CHARGING_HUM_DB, "Active gain not applied")
	var active := await measure(capture, 8.5)
	expect(station._hum.playing, "Charging loop ended after one recording")
	expect(active.x > -32.0 and active.x < -16.0, "Charging level not audible/balanced: %s" % active)
	expect(active.y < -8.0, "Charging sound lacks peak headroom: %s" % active)
	expect(active.x - idle.x > 12.0, "Charging not distinct from idle")
	station._hum.stop()
	await create_timer(0.2).timeout
	expect(station._hum.playing, "Stopped active emitter did not recover")
	station._hum.stream_paused = true
	await create_timer(0.2).timeout
	expect(station._hum.stream_paused, "Recovery bypassed realm/audio hold")
	station._hum.stream_paused = false
	var resumed := await measure(capture, 0.6)
	expect(resumed.x > -38.0, "No signal after audio hold")
	station._hit.activated.emit(game.player)
	await create_timer(0.1).timeout
	expect(not game.player.is_charging() and station._hum.volume_db == ChargingStation.IDLE_HUM_DB,
		"Disconnect did not restore quiet idle")
	var dead := ChargingStation.new()
	dead.broken = true
	dead.broken_tried = true
	game.add_child(dead)
	await create_timer(0.2).timeout
	expect(not dead._hum.playing and dead._hit.prompt_text == "OUT OF ORDER",
		"A restored dead station restarted its hum")
	print("CHARGER AUDIO: idle %.1f, charging %.1f dBFS; active peak %.1f dBFS" % [idle.x, active.x, active.y])
	await teardown_game(game)
	AudioServer.remove_bus(idx)
	finish("charging signal, loop duration, restart, pause/resume, disconnect and dead-station silence")

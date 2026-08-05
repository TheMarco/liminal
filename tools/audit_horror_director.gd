extends SceneTree
## Deterministic pacing contract for the shared horror director.
## Run: godot --headless --path . --script tools/audit_horror_director.gd

var failures: Array[String] = []


func _init() -> void:
	var director := HorrorDirector.new()
	director.enabled = true

	# A visual sighting receives the frame to itself and a short recovery tail.
	_expect(director.try_start_visual(3.4),
		"an idle director rejected a visual sighting")
	_expect(not director.can_start_hostile(),
		"hostile encounter overlapped a visual sighting")
	_expect(not director.try_start_blackout(),
		"blackout overlapped a visual sighting")
	_expect(not director.try_start_whisper(2.0),
		"whisper overlapped a visual sighting")
	director.advance(3.5)
	_expect(not director.can_start_hostile(),
		"visual sighting had no recovery silence")
	director.advance(HorrorDirector.VISUAL_RECOVERY + 0.1)
	_expect(director.can_start_hostile(),
		"visual recovery never released the hostile channel")

	# Several figures may comprise one encounter, but no other beat joins it.
	director.set_hostile_count(1)
	_expect(director.can_start_hostile(),
		"director blocked reinforcement within one hostile encounter")
	director.set_hostile_count(3)
	_expect(not director.try_start_blackout(),
		"blackout started while hostile figures were active")
	_expect(not director.try_start_ambient(2.0),
		"ambient knock competed with a hostile encounter")
	director.set_pressure(0.0)
	director.set_hostile_count(0)
	_expect(not director.try_start_visual(2.0),
		"hostile encounter ended without recovery silence")
	director.advance(HorrorDirector.HOSTILE_RECOVERY_EARLY + 0.1)
	_expect(director.try_start_blackout(),
		"hostile recovery never released the blackout channel")

	# A blackout is exclusive and leaves a shorter recovery late in the run.
	_expect(not director.try_start_whisper(2.0),
		"whisper started during a blackout")
	_expect(not director.can_start_hostile(),
		"hostile encounter started during a blackout")
	director.set_pressure(1.0)
	director.end_blackout()
	_expect(not director.try_start_visual(2.0),
		"blackout ended without recovery silence")
	director.advance(HorrorDirector.BLACKOUT_RECOVERY_LATE + 0.1)
	_expect(director.try_start_whisper(2.0),
		"late-run blackout recovery did not release quiet beats")

	# Scripted video/card presentation is always authoritative.
	director.set_scripted_hold(true)
	_expect(not director.can_start_hostile(),
		"hostile encounter ignored a scripted presentation")
	_expect(not director.try_start_ambient(1.0),
		"ambient sound ignored a scripted presentation")
	director.set_scripted_hold(false)
	director.advance(10.0)
	_expect(director.can_start_hostile(),
		"scripted presentation permanently held the director")

	# Wander bypasses Descent pacing rather than becoming unnaturally silent.
	director.enabled = false
	director.set_scripted_hold(false)
	director.set_hostile_count(3, false)
	_expect(director.try_start_ambient(1.0),
		"disabled director changed Wander ambience")
	director.free()

	for failure in failures:
		print("  FAIL " + failure)
	if failures.is_empty():
		print("horror director audit: PASS — exclusive beats, recovery and presentation holds")
		quit()
	else:
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

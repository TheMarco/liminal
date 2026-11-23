extends SceneTree
## Regenerate the lossless media formerly synthesized when a room first appeared.
## godot --headless --path . --script tools/bake_ambient_resources.gd -- --test-mode

func _init() -> void:
	call_deferred("bake")

func bake() -> void:
	seed(985078973)
	var chime_error := pa_chime().save_to_wav("res://sounds/airport/pa_chime.wav")
	var jet_error := jet_far().save_to_wav("res://sounds/airport/jet_far.wav")
	var detail_error := await write_noise(false, "res://textures/shared/surface_detail.png")
	var ripple_error := await write_noise(true, "res://textures/pool/ripple_normal.png")
	if [chime_error, jet_error, detail_error, ripple_error] != [OK, OK, OK, OK]:
		push_error("Failed to save generated audio or textures.")
		quit(1)
		return
	quit()

func write_noise(ripple: bool, path: String) -> Error:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.014 if ripple else 0.02
	noise.fractal_octaves = 4
	if ripple:
		noise.fractal_gain = 0.42
	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.width = 1024 if ripple else 512
	texture.height = texture.width
	texture.seamless = true
	texture.generate_mipmaps = true
	if ripple:
		texture.as_normal_map = true
		texture.bump_strength = 1.6
	if texture.get_image() == null:
		await texture.changed
	return texture.get_image().save_png(path)


func pa_chime() -> AudioStreamWAV:
	var n := int(SoundBank.RATE * 1.7)
	var s := PackedFloat32Array()
	s.resize(n)
	var tones := [830.6, 659.3, 554.4]
	for ti in 3:
		var t0 := 0.42 * float(ti)
		var f: float = tones[ti]
		for i in n:
			var t := float(i) / SoundBank.RATE - t0
			if t < 0.0:
				continue
			var v := 0.30 * sin(TAU * f * t) * exp(-3.2 * t)
			v += 0.10 * sin(TAU * f * 2.0 * t + 0.6) * exp(-6.0 * t)
			s[i] += v * minf(1.0, t * 120.0)
	return SoundBank._wav(s)

func jet_far() -> AudioStreamWAV:
	var dur := 9.0
	var n := int(SoundBank.RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp1 := 0.0
	var lp2 := 0.0
	var lp3 := 0.0
	for i in n:
		var t := float(i) / SoundBank.RATE
		lp1 = lerpf(lp1, randf() * 2.0 - 1.0, 0.06)
		lp2 = lerpf(lp2, lp1, 0.09)
		lp3 = lerpf(lp3, lp2, 0.12)
		# slow attack, long release
		var env := pow(sin(PI * clampf(t / dur, 0.0, 1.0)), 1.6)
		var v := lp3 * 1.6 * env
		v += 0.10 * sin(TAU * 32.0 * t + 3.0 * lp3) * env
		# faint turbine whine riding on top, drifting down in pitch
		v += 0.03 * sin(TAU * (860.0 - 120.0 * t / dur) * t) * env * env
		s[i] = v * 0.6
	return SoundBank._wav(s)

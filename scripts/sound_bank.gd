class_name SoundBank
## Procedurally synthesized audio, generated once at first use and cached.
## Everything is math — sines, noise, envelopes — rendered into AudioStreamWAV
## buffers, so the project still ships zero binary assets.

const RATE := 22050.0

static var _c := {}


static func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(RATE)
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


## Crossfade the tail into the head so loops are clickless.
static func _loop_blend(s: PackedFloat32Array, n: int) -> PackedFloat32Array:
	for i in n:
		var w := float(i) / float(n)
		s[s.size() - n + i] = lerpf(s[s.size() - n + i], s[i], w)
	return s


## Wrap a sample so each play gets random pitch/volume variation.
static func randomized(wav: AudioStreamWAV, pitch := 1.15, vol_db := 2.0) -> AudioStreamRandomizer:
	var r := AudioStreamRandomizer.new()
	r.add_stream(0, wav)
	r.random_pitch = pitch
	r.random_volume_offset_db = vol_db
	return r


## Bright slot machine chime.
static func ding() -> AudioStreamWAV:
	if _c.has("ding"):
		return _c["ding"]
	var n := int(RATE * 0.55)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.5 * sin(TAU * 1318.5 * t) * exp(-7.0 * t)
		v += 0.22 * sin(TAU * 2637.0 * t) * exp(-12.0 * t)
		v += 0.1 * sin(TAU * 3951.0 * t) * exp(-18.0 * t)
		s[i] = v * minf(1.0, t * 300.0)
	_c["ding"] = _wav(s)
	return _c["ding"]


## Looping fluorescent ballast buzz.
static func buzz() -> AudioStreamWAV:
	if _c.has("buzz"):
		return _c["buzz"]
	var n := int(RATE * 0.5)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var v := 0.16 * sin(TAU * 120.0 * t)
		v += 0.08 * sin(TAU * 240.0 * t + 0.7)
		v += 0.05 * sin(TAU * 360.0 * t + 1.9)
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.2)
		v += 0.06 * lp
		s[i] = v
	_c["buzz"] = _wav(_loop_blend(s, 1100), true)
	return _c["buzz"]


## 12-second loop of muffled hotel-PA organ muzak: four soft minor-seventh
## chords with detune, tremolo and vibrato. Played quietly through walls.
static func muzak() -> AudioStreamWAV:
	if _c.has("muzak"):
		return _c["muzak"]
	var chords := [
		[130.81, 155.56, 196.00, 233.08],  # Cm7
		[103.83, 130.81, 155.56, 196.00],  # Abmaj7
		[87.31, 103.83, 130.81, 155.56],   # Fm7
		[98.00, 123.47, 146.83, 174.61],   # G7
	]
	var chord_len := 3.0
	var seg := int(RATE * chord_len)
	var s := PackedFloat32Array()
	s.resize(seg * 4)
	for ci in 4:
		for f in chords[ci]:
			for detune in [-0.15, 0.15]:
				var ff: float = f * (1.0 + detune / 100.0)
				for i in seg:
					var t := float(i) / RATE
					var tg := float(ci) * chord_len + t
					var env := minf(1.0, t / 0.5) * minf(1.0, (chord_len - t) / 0.7)
					var trem := 1.0 - 0.18 * (0.5 + 0.5 * sin(TAU * 3.1 * tg + float(ci)))
					var v := sin(TAU * ff * tg + 0.6 * sin(TAU * 5.3 * tg))
					s[ci * seg + i] += 0.042 * env * trem * v
	_c["muzak"] = _wav(_loop_blend(s, 2200), true)
	return _c["muzak"]


## Soft thump of a shoe on carpet.
static func step_carpet() -> AudioStreamWAV:
	if _c.has("step_carpet"):
		return _c["step_carpet"]
	var n := int(RATE * 0.16)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.16)
		var env := exp(-26.0 * t) * minf(1.0, t * 400.0)
		s[i] = (lp * 1.5 + 0.18 * sin(TAU * 72.0 * t)) * env * 0.85
	_c["step_carpet"] = _wav(s)
	return _c["step_carpet"]


## Hard click of a shoe on marble.
static func step_marble() -> AudioStreamWAV:
	if _c.has("step_marble"):
		return _c["step_marble"]
	var n := int(RATE * 0.12)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var raw := randf() * 2.0 - 1.0
		lp = lerpf(lp, raw, 0.5)
		var hp := raw - lp
		var env := exp(-45.0 * t) * minf(1.0, t * 600.0)
		var v := hp * 0.9 * env
		v += 0.25 * sin(TAU * 950.0 * t) * exp(-40.0 * t)
		v += 0.12 * sin(TAU * 2100.0 * t) * exp(-55.0 * t)
		s[i] = v * 0.6
	_c["step_marble"] = _wav(s)
	return _c["step_marble"]


## Distant structural thud — something heavy, somewhere else in the hotel.
static func thud() -> AudioStreamWAV:
	if _c.has("thud"):
		return _c["thud"]
	var n := int(RATE * 0.6)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var v := 0.55 * sin(TAU * 52.0 * t + 6.0 * exp(-8.0 * t)) * exp(-5.0 * t)
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.06)
		v += lp * 0.3 * exp(-9.0 * t)
		s[i] = v * minf(1.0, t * 200.0)
	_c["thud"] = _wav(s)
	return _c["thud"]


## Single keyboard key press — short, high-passed click.
static func key_click() -> AudioStreamWAV:
	if _c.has("key_click"):
		return _c["key_click"]
	var n := int(RATE * 0.045)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var raw := randf() * 2.0 - 1.0
		lp = lerpf(lp, raw, 0.55)
		var hp := raw - lp
		var env := exp(-120.0 * t) * minf(1.0, t * 2000.0)
		s[i] = (hp * 0.9 + 0.2 * sin(TAU * 1900.0 * t)) * env * 0.55
	_c["key_click"] = _wav(s)
	return _c["key_click"]


## Endless rushing channel water: cascaded low-passed noise with a slow
## gurgling swell, blended into a seamless loop.
static func water_rush() -> AudioStreamWAV:
	if _c.has("water_rush"):
		return _c["water_rush"]
	var n := int(RATE * 1.8)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp1 := 0.0
	var lp2 := 0.0
	var swell := 0.0
	for i in n:
		var t := float(i) / RATE
		var raw := randf() * 2.0 - 1.0
		lp1 = lerpf(lp1, raw, 0.22)
		lp2 = lerpf(lp2, lp1, 0.3)
		swell = lerpf(swell, randf(), 0.0012)
		# body of the flow plus a thin bright splash layer on top
		var v := lp2 * (0.5 + 0.35 * swell)
		v += (lp1 - lp2) * 0.22
		s[i] = v * (0.85 + 0.15 * sin(TAU * 0.55 * t))
	_c["water_rush"] = _wav(_loop_blend(s, 3600), true)
	return _c["water_rush"]


## Single drip: a wet pitch-falling plink.
static func drip() -> AudioStreamWAV:
	if _c.has("drip"):
		return _c["drip"]
	var n := int(RATE * 0.28)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var f := 640.0 + 900.0 * exp(-34.0 * t)
		var v := 0.5 * sin(TAU * f * t) * exp(-22.0 * t)
		v += 0.12 * (randf() * 2.0 - 1.0) * exp(-260.0 * t)
		s[i] = v * minf(1.0, t * 900.0)
	_c["drip"] = _wav(s)
	return _c["drip"]


## Slow metal groan — old steel remembering the wind.
static func creak() -> AudioStreamWAV:
	if _c.has("creak"):
		return _c["creak"]
	var n := int(RATE * 1.6)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var f := 118.0 - 26.0 * t + 7.0 * sin(TAU * 2.3 * t)
		var env := pow(sin(PI * t / 1.6), 2.0)
		var v := 0.28 * sin(TAU * f * t + 2.5 * sin(TAU * 5.1 * t)) * env
		v += 0.1 * sin(TAU * f * 2.7 * t) * env
		v += 0.05 * sin(TAU * 640.0 * t + 8.0 * sin(TAU * 3.0 * t)) * env * env
		s[i] = v
	_c["creak"] = _wav(s)
	return _c["creak"]


## Struck iron somewhere down the ward — inharmonic partials ringing out.
static func clang() -> AudioStreamWAV:
	if _c.has("clang"):
		return _c["clang"]
	var n := int(RATE * 1.1)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.4 * sin(TAU * 312.0 * t) * exp(-4.5 * t)
		v += 0.26 * sin(TAU * 841.0 * t + 0.7) * exp(-6.5 * t)
		v += 0.16 * sin(TAU * 1487.0 * t + 1.9) * exp(-9.0 * t)
		v += 0.08 * sin(TAU * 2333.0 * t + 0.3) * exp(-13.0 * t)
		v += 0.3 * (randf() * 2.0 - 1.0) * exp(-90.0 * t)
		s[i] = v * minf(1.0, t * 700.0)
	_c["clang"] = _wav(s)
	return _c["clang"]


## A low human moan from rooms away — worn to almost nothing by the walls.
static func moan() -> AudioStreamWAV:
	if _c.has("moan"):
		return _c["moan"]
	var n := int(RATE * 2.4)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 168.0 - 42.0 * (t / 2.4) + 5.0 * sin(TAU * 4.7 * t)
		var env := pow(sin(PI * t / 2.4), 1.6)
		var v := 0.3 * sin(TAU * f * t)
		v += 0.14 * sin(TAU * f * 2.0 * t + 0.9)
		v += 0.07 * sin(TAU * f * 3.1 * t + 2.2)
		# breath: slow noise, low-passed until it is only air
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.045)
		v += 0.12 * lp
		s[i] = v * env
	_c["moan"] = _wav(s)
	return _c["moan"]


## Three-tone descending airport PA chime — the sound before every departure
## nobody is here to catch.
static func pa_chime() -> AudioStreamWAV:
	if _c.has("pa_chime"):
		return _c["pa_chime"]
	var n := int(RATE * 1.7)
	var s := PackedFloat32Array()
	s.resize(n)
	var tones := [830.6, 659.3, 554.4]
	for ti in 3:
		var t0 := 0.42 * float(ti)
		var f: float = tones[ti]
		for i in n:
			var t := float(i) / RATE - t0
			if t < 0.0:
				continue
			var v := 0.30 * sin(TAU * f * t) * exp(-3.2 * t)
			v += 0.10 * sin(TAU * f * 2.0 * t + 0.6) * exp(-6.0 * t)
			s[i] += v * minf(1.0, t * 120.0)
	_c["pa_chime"] = _wav(s)
	return _c["pa_chime"]


## Muffled PA announcement: syllabic band-limited babble shaped like speech,
## smeared past intelligibility by distance and hall reverb.
static func pa_voice() -> AudioStreamWAV:
	if _c.has("pa_voice"):
		return _c["pa_voice"]
	var dur := 4.6
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp1 := 0.0
	var lp2 := 0.0
	var syl := 0.0        # current syllable amplitude
	var syl_t := 0.0      # time left in current syllable/pause
	var f0 := 118.0
	var i := 0
	while i < n:
		if syl_t <= 0.0:
			# next syllable, or a word gap
			if randf() < 0.24:
				syl = 0.0
				syl_t = randf_range(0.10, 0.30)
			else:
				syl = randf_range(0.45, 1.0)
				syl_t = randf_range(0.08, 0.20)
				f0 = clampf(f0 + randf_range(-14.0, 14.0), 95.0, 150.0)
		var t := float(i) / RATE
		# glottal buzz: low harmonics only — a voice through too many walls
		var v := 0.5 * sin(TAU * f0 * t) + 0.28 * sin(TAU * f0 * 2.0 * t + 0.8)
		v += 0.14 * sin(TAU * f0 * 3.0 * t + 1.9)
		# consonant hiss
		lp1 = lerpf(lp1, randf() * 2.0 - 1.0, 0.3)
		lp2 = lerpf(lp2, lp1, 0.35)
		v = v * 0.16 + (lp1 - lp2) * 0.35
		# syllable envelope with soft edges
		var k := clampf(syl_t * 30.0, 0.0, 1.0)
		v *= syl * k
		# phrase fade in/out
		v *= minf(1.0, t / 0.3) * minf(1.0, (dur - t) / 0.8)
		s[i] = v * 0.75
		syl_t -= 1.0 / RATE
		i += 1
	_c["pa_voice"] = _wav(s)
	return _c["pa_voice"]


## Distant heavy jet spooling somewhere out on the field: a long low swell
## of filtered thunder that arrives, leans on the glass, and leaves.
static func jet_far() -> AudioStreamWAV:
	if _c.has("jet_far"):
		return _c["jet_far"]
	var dur := 9.0
	var n := int(RATE * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp1 := 0.0
	var lp2 := 0.0
	var lp3 := 0.0
	for i in n:
		var t := float(i) / RATE
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
	_c["jet_far"] = _wav(s)
	return _c["jet_far"]


## Looping portal drone: close detuned partials beating against each other
## with a slow shimmer on top — the sound of held-open space.
static func portal_hum() -> AudioStreamWAV:
	if _c.has("portal_hum"):
		return _c["portal_hum"]
	var n := int(RATE * 2.4)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var v := 0.16 * sin(TAU * 92.0 * t)
		v += 0.14 * sin(TAU * 93.5 * t + 1.0)
		v += 0.09 * sin(TAU * 138.0 * t + 0.4)
		v += 0.05 * sin(TAU * 276.5 * t + 2.0)
		# glassy shimmer drifting overhead
		v += 0.03 * sin(TAU * 1110.0 * t + 3.0 * sin(TAU * 0.7 * t))
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.1)
		v += 0.03 * lp
		s[i] = v
	_c["portal_hum"] = _wav(_loop_blend(s, 2600), true)
	return _c["portal_hum"]


## Portal transit: a rising sweep that swallows itself.
static func warp() -> AudioStreamWAV:
	if _c.has("warp"):
		return _c["warp"]
	var n := int(RATE * 1.1)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := t / 1.1
		# pitch climbing out of hearing
		var f := 110.0 * pow(9.0, k)
		var env := pow(sin(PI * minf(k * 1.25, 1.0)), 1.4)
		var v := 0.34 * sin(TAU * f * t / (1.0 + 2.2 * k)) * env
		# whoosh body
		lp = lerpf(lp, randf() * 2.0 - 1.0, 0.10 + 0.35 * k)
		v += lp * 0.4 * env
		s[i] = v
	_c["warp"] = _wav(s)
	return _c["warp"]


## A cold exhale right at the edge of hearing — the sound of being noticed
## by something that was pretending to be a shadow.
static func shiver() -> AudioStreamWAV:
	if _c.has("shiver"):
		return _c["shiver"]
	var n := int(RATE * 0.8)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp1 := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := t / 0.8
		# breath that darkens as it fades
		lp1 = lerpf(lp1, randf() * 2.0 - 1.0, 0.45 - 0.35 * k)
		lp2 = lerpf(lp2, lp1, 0.3)
		var env := pow(sin(PI * minf(k * 1.15, 1.0)), 1.6)
		var v := (lp1 - lp2) * 0.9 * env
		v += 0.06 * sin(TAU * 52.0 * t) * env
		s[i] = v * 0.5
	_c["shiver"] = _wav(s)
	return _c["shiver"]


## Two-tone elevator chime from an unseen lobby.
static func elev() -> AudioStreamWAV:
	if _c.has("elev"):
		return _c["elev"]
	var n := int(RATE * 1.3)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.3 * sin(TAU * 659.3 * t) * exp(-3.5 * t) * minf(1.0, t * 200.0)
		if t > 0.28:
			var t2 := t - 0.28
			v += 0.3 * sin(TAU * 523.3 * t2) * exp(-3.0 * t2) * minf(1.0, t2 * 200.0)
		s[i] = v
	_c["elev"] = _wav(s)
	return _c["elev"]

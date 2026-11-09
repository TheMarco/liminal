class_name NtscrtReceiver
extends RefCounted
## Original Godot receiver model informed by NTSCRT's Receiver.swift.
## Only timing/control data reaches the CPU. Image samples stay on the GPU.
## Each texture row describes one scan line: timing/RF, colour reference, hum.

const FIELD_RATE := 60000.0 / 1001.0
const LINE_US := 63.556
const ACTIVE_US := 52.656
const ACTIVE_START := 9.4
var field_index := 0
var clock := 0.0
var horizontal_phase := 0.0
var vertical_phase := 0.0
var color_on := true
var color_confidence := 1.0
var color_phase := 0.0
var color_gain := 1.0
var texture: ImageTexture
var last_cpu_usec := 0
var _accumulator := 0.0
var _gate_phase := 0.0
var _height := 0
var _data := PackedFloat32Array()
var _random := RandomNumberGenerator.new()
var _next_fault := 7.0
var _fault_end := 0.0
var _fault_start := 0.0
var _fault_kind := 0
var _fault_amplitude := 0.0
var _fault_major := false
var _next_major := 35.0
var fault_amount := 0.0
var fault_kind := 0

func reset(seed_value := 19471031) -> void:
	_random.seed = seed_value
	field_index = 0
	clock = 0.0
	_accumulator = 0.0
	horizontal_phase = 0.0
	vertical_phase = 0.0
	_gate_phase = 0.0
	color_on = true
	color_confidence = 1.0
	color_phase = 0.0
	color_gain = 1.0
	_next_fault = 7.0
	_next_major = 35.0
	_fault_end = 0.0
	fault_amount = 0.0
	_height = 0
	texture = null

func _init() -> void:
	reset()

func advance(delta: float, height: int, knobs: Dictionary, stress := 0.0,
		reduced := false, strength := 1.0) -> bool:
	var started := Time.get_ticks_usec()
	_accumulator += clampf(delta, 0.0, 0.1)
	var changed := height != _height or texture == null
	if height != _height:
		_height = maxi(8, height)
		_data.resize(_height * 12)
	# Cap catch-up after a suspended window. No history replay on the game thread.
	var fields := mini(6, int(_accumulator * FIELD_RATE))
	_accumulator -= fields / FIELD_RATE
	for f in fields:
		clock += 1.0 / FIELD_RATE
		field_index += 1
		_update_faults(knobs, reduced)
		_simulate(knobs, stress, reduced, strength, f == fields - 1)
		changed = true
	if changed:
		if fields == 0: _simulate(knobs, stress, reduced, strength, true, false)
		var img := Image.create_from_data(3, _height, false, Image.FORMAT_RGBAF, _data.to_byte_array())
		if texture == null or texture.get_height() != _height:
			texture = ImageTexture.create_from_image(img)
		else:
			texture.update(img)
	last_cpu_usec = Time.get_ticks_usec() - started
	return changed

func _update_faults(knobs: Dictionary, reduced: bool) -> void:
	fault_amount = 0.0
	if reduced or not bool(knobs.get("ntsc_auto_faults", true)):
		return
	if clock >= _next_fault and clock >= _fault_end:
		_fault_major = clock >= _next_major
		_fault_start = clock
		_fault_end = clock + (_random.randf_range(0.3, 0.65) if _fault_major else _random.randf_range(0.1, 0.25))
		_fault_kind = _random.randi_range(0, 4)
		_fault_amplitude = _random.randf_range(0.5, 0.8) if _fault_major else _random.randf_range(0.12, 0.3)
		_next_fault = clock + _random.randf_range(6.0, 12.0)
		if _fault_major: _next_major = clock + _random.randf_range(35.0, 55.0)
	if clock < _fault_end:
		var phase := (clock - _fault_start) / (_fault_end - _fault_start)
		fault_amount = smoothstep(0.0, 0.12, phase) * (1.0 - smoothstep(0.25, 1.0, phase)) * _fault_amplitude
		fault_kind = _fault_kind

func _simulate(k: Dictionary, stress: float, reduced: bool, amount: float,
		write: bool, evolve := true) -> void:
	var wear := 0.0 if reduced else amount
	var power := clampf(lerpf(1.0,float(k.get("ntsc_signal_strength", 1.0)),minf(wear,1.0)) - stress * 0.22 * wear
		- (fault_amount * 0.55 * wear if fault_kind == 3 else 0.0), 0.0, 1.0)
	if reduced: power = 1.0
	var sigma := maxf(0.0, 100.0 * pow(10.0, -1.9 * power) - 1.26 * pow(power, 4.0)) / 92.5
	var hknob := float(k.get("ntsc_horizontal_hold", 0.0)) * wear
	var vknob := float(k.get("ntsc_vertical_hold", 0.0)) * wear
	var kp := 0.04 * pow(10.0, float(k.get("ntsc_afc", 0.5)))
	var edge := 0.04 * pow(10.0, 0.5) / TAU
	var hfree := signf(hknob) * (edge * pow(absf(hknob) / 0.35, 2.0) if absf(hknob) <= 0.35
		else edge + 0.0265 * (absf(hknob) - 0.35) / 0.65)
	var head_switch := float(k.get("ntsc_head_switch", 0.15)) * wear * 3.0
	var jitter := (float(k.get("ntsc_timebase_jitter", 0.12)) + stress * 0.2) * wear
	var tracking := clampf((float(k.get("ntsc_tracking", 0.0))
		+ (fault_amount if fault_kind == 0 else 0.0)) * wear, 0.0, 1.0)
	var crinkle := (float(k.get("ntsc_crinkle", 0.05)) + (fault_amount if fault_kind == 1 else 0.0)) * wear
	var clog := (float(k.get("ntsc_head_clog", 0.0)) + (fault_amount if fault_kind == 2 else 0.0)) * wear
	var search := lerpf(1.0, float(k.get("ntsc_search_speed", 1.0)), minf(wear, 1.0))
	var hum := float(k.get("ntsc_hum", 0.0)) * wear
	var vbi := maxi(12, int(_height * 20.0 / 242.5))
	var total := _height + vbi
	var line_scale := 262.5 / float(total)
	var gate_alpha := 1.0 - exp(-line_scale / 6.0)
	var color_alpha := 1.0 - exp(-line_scale / 15.0)
	var head_sign := 1.0 if field_index % 2 == 0 else -1.0
	var clogged := clog * (0.95 if _hash(field_index, 47) < clog * 0.65 else clog * 0.3)
	var crease_at := 0.5 + sin(clock * 1.37) * 0.38
	var crease_env := pow(maxf(0.0, sin(clock * 2.9 + 0.4)), 18.0) * crinkle
	if evolve:
		var detune := 0.002 + signf(vknob) * 0.1 * pow(absf(vknob), 1.37)
		var lock := clampf((power - 0.08) / 0.35, 0.0, 1.0) * (1.0 - clogged)
		vertical_phase = fposmod(vertical_phase + detune - 0.015 * lock * sin(TAU * vertical_phase + asin(0.002 / 0.015)), 1.0)
		if reduced or amount == 0.0:
			horizontal_phase = 0.0
			vertical_phase = 0.0
			_gate_phase = 0.0
			color_confidence = 1.0
			color_on = true
			color_phase = 0.0
			color_gain = 1.0
	for row in range(-vbi, _height):
		var y := float(row) / _height
		var rnd := _hash(row + field_index * total, 13) - 0.5
		var track_center := 1.06 - tracking * 0.95 + sin(clock * 0.6) * tracking * 0.05
		var track_loss := (1.0 - smoothstep(0.018, 0.035 + tracking * 0.1, absf(y - track_center))) * tracking
		var crease := (1.0 - smoothstep(0.003, 0.025, absf(y - crease_at))) * crease_env
		var search_loss := 0.0
		if search > 1.05:
			search_loss = (1.0 - smoothstep(0.05, 0.16, absf(sin((y * (search - 1.0) + clock * 0.7) * PI)))) * 0.8
		var loss := clampf(maxf(clogged, maxf(track_loss, maxf(crease, search_loss))) + stress * wear * 0.06, 0.0, 1.0)
		var line_hum := sin(TAU * (y + clock * 0.1)) * hum * 0.25
		# The head hands over at the bottom; the loop carries the timing jump
		# through vertical blanking into the next field's top-of-picture bend.
		var tape_time := head_sign * head_switch * (1.0 if row < _height - 3 else -1.0) * 0.5
		tape_time += jitter * (sin(row * 0.15 + clock * 7.2) * 0.5 + rnd * 0.3)
		tape_time += crease * sin(row * 2.7) * 6.0 + search_loss * sin(row * 0.3) * 2.0
		var sigma_row := maxf(sigma, loss * 0.5)
		if evolve:
			var error := wrapf(tape_time - horizontal_phase, -LINE_US * 0.5, LINE_US * 0.5)
			var detected := power > 0.16 + _hash(row + field_index * total, 37) * 0.16 and loss < 0.8
			horizontal_phase += LINE_US * hfree * line_scale
			if detected:
				horizontal_phase += kp * line_scale * LINE_US / TAU * sin(TAU * (error + rnd * sigma_row * 2.0 + line_hum) / LINE_US)
				_gate_phase += gate_alpha * wrapf(error - _gate_phase, -LINE_US * 0.5, LINE_US * 0.5)
			else:
				horizontal_phase += rnd * sigma_row * 0.3 + 0.004 * wear
			horizontal_phase = wrapf(horizontal_phase, -LINE_US * 8.0, LINE_US * 8.0)
		var shift := wrapf(horizontal_phase - tape_time, -LINE_US * 0.5, LINE_US * 0.5)
		var gate_error := wrapf(shift + _gate_phase, -LINE_US * 0.5, LINE_US * 0.5)
		var burst := maxf(0.0, 1.0 - absf(gate_error) / 2.5) * (1.0 - loss) * clampf(power / 0.45, 0.0, 1.0)
		burst = clampf(burst + rnd * sigma_row, 0.0, 1.0)
		if evolve:
			color_confidence = lerpf(color_confidence, burst, color_alpha)
			if color_on and color_confidence < 0.3: color_on = false
			elif not color_on and color_confidence > 0.5: color_on = true
			color_phase = lerpf(color_phase, gate_error * 0.23 + rnd * sigma_row * 0.8, gate_alpha)
			color_gain = lerpf(color_gain, clampf(1.0 / maxf(burst, 0.3), 0.3, 2.0), color_alpha * 0.5)
		if row < 0 or not write: continue
		var mapped := fposmod(row + vbi + vertical_phase * total, total) - vbi
		var i := row * 12
		_data[i] = shift
		_data[i + 1] = (mapped + 0.5) / _height
		_data[i + 2] = sigma_row
		_data[i + 3] = loss
		_data[i + 4] = cos(color_phase)
		_data[i + 5] = sin(color_phase)
		_data[i + 6] = color_gain if color_on else 0.0
		_data[i + 7] = color_confidence
		_data[i + 8] = line_hum
		_data[i + 9] = clampf(power / 0.45, 0.0, 1.0)
		_data[i + 10] = mapped
		_data[i + 11] = float(field_index)

static func _hash(a: int, b: int) -> float:
	var h := (a * 374761393 + b * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h ^ (h >> 16)) / 2147483647.0

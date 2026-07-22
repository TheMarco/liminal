class_name Ambience
extends AudioStreamPlayer
## Procedural room tone, synthesized into an AudioStreamGenerator.
## Theme 0 (casino): warm 60Hz hum with air noise and a slow swell.
## Theme 1 (office): harsher fluorescent 120Hz ballast tone with bright hiss
## and almost no movement — sterile and constant.
## Theme 2 (sewers): cavernous low water rumble, slowly breathing.
## Theme 4 (airport): vast HVAC air mass — deep, wide, never off.
## Theme 5 (asylum): dead-building air — a hollow draught through broken
## windows over a faint mains hum, breathing far too slowly.

const RATE := 22050.0

var theme := 0

var _pb: AudioStreamGeneratorPlayback
var _t := 0.0
var _lp := 0.0
var _lp2 := 0.0


func _init(p_theme := 0) -> void:
	theme = p_theme
	# A recorded room tone exists for every floor but the school, which keeps
	# the synthesized one. Levels are set in Sfx, measured per file.
	if Sfx.has_bed(theme):
		var b := Sfx.bed(theme)
		stream = b[0]
		volume_db = b[1]
		return
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.2
	stream = gen
	volume_db = -6.0


func _ready() -> void:
	play()
	if Sfx.has_bed(theme):
		return          # a plain looping stream; nothing to synthesize into
	_pb = get_stream_playback()


func _process(_dt: float) -> void:
	if _pb == null:
		return
	var n := _pb.get_frames_available()
	while n > 0:
		n -= 1
		_t += 1.0 / RATE
		# all periodic components have an integer number of cycles per 1000s,
		# so wrapping keeps the waveform continuous and floats precise
		if _t > 1000.0:
			_t -= 1000.0
		var v := 0.0
		if theme == 5:
			# hollow draught, a trace of 50Hz mains, and a very slow breath
			_lp = lerpf(_lp, randf() * 2.0 - 1.0, 0.04)
			_lp2 = lerpf(_lp2, _lp, 0.28)
			v = 0.13 * _lp2
			v += 0.018 * sin(TAU * 50.0 * _t)
			v += 0.007 * sin(TAU * 100.0 * _t + 0.7)
			v *= 0.7 + 0.3 * sin(TAU * 0.03 * _t + 2.0)
		elif theme == 4:
			# terminal air handling: deep broadband mass with a faint duct
			# resonance and the slowest possible breathing
			_lp = lerpf(_lp, randf() * 2.0 - 1.0, 0.05)
			_lp2 = lerpf(_lp2, _lp, 0.22)
			v = 0.14 * _lp2
			v += 0.014 * sin(TAU * 90.0 * _t)
			v += 0.008 * sin(TAU * 180.0 * _t + 1.1)
			v += 0.012 * (randf() * 2.0 - 1.0)
			v *= 0.88 + 0.12 * sin(TAU * 0.025 * _t)
		elif theme == 2:
			_lp = lerpf(_lp, randf() * 2.0 - 1.0, 0.055)
			_lp2 = lerpf(_lp2, _lp, 0.4)
			v = 0.15 * _lp2
			v += 0.018 * sin(TAU * 46.0 * _t)
			v *= 0.76 + 0.24 * sin(TAU * 0.04 * _t + 1.0)
		elif theme == 1:
			v = 0.055 * sin(TAU * 120.0 * _t)
			v += 0.03 * sin(TAU * 240.0 * _t + 0.9)
			v += 0.018 * sin(TAU * 360.0 * _t + 2.1)
			_lp = lerpf(_lp, randf() * 2.0 - 1.0, 0.22)
			v += 0.05 * _lp
			v *= 0.92 + 0.08 * sin(TAU * 0.05 * _t)
		else:
			v = 0.05 * sin(TAU * 60.0 * _t) + 0.03 * sin(TAU * 120.0 * _t + 1.3)
			_lp = lerpf(_lp, randf() * 2.0 - 1.0, 0.035)
			v += 0.09 * _lp
			v *= 0.8 + 0.2 * sin(TAU * 0.05 * _t)
		_pb.push_frame(Vector2(v, v))

extends SceneTree
const Receiver = preload("res://scripts/ntscrt_receiver_gpu.gd")
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _texture(rd: RenderingDevice, size: Vector2i, pixels: PackedByteArray) -> RID:
	var f = RDTextureFormat.new()
	f.width = size.x; f.height = size.y
	f.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	f.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	return rd.texture_create(f,RDTextureView.new(),[pixels])
func _run() -> void:
	var rd = RenderingServer.create_local_rendering_device()
	if rd==null:
		push_error("Receiver GPU audit needs native RenderingDevice")
		quit(1); return
	var size = Vector2i(64,48)
	var pixels = PackedByteArray()
	pixels.resize(size.x*size.y*4)
	for y in size.y:
		for x in size.x:
			var i = (y*size.x+x)*4
			pixels[i] = (x*3+y*7)%256; pixels[i+1] = (x*11)%256; pixels[i+2] = (y*5)%256; pixels[i+3] = 255
	var input = _texture(rd,size,pixels)
	var stage = Receiver.new()
	if not stage.setup(rd,size):
		push_error(stage.error); rd.free_rid(input); stage.dispose(); rd.free(); quit(1); return
	# Golden timing metadata produced by unmodified Swift ReceiverSimulator
	# at the schema's source revision, 64x48 raster, time zero.
	var fixture = {"signal_strength":0.2,"head_switch":4.0,"tracking":0.6,"dropouts":0.8,"horizontal_hold":0.5,"vertical_hold":0.4,"crinkle":0.3,"timebase_jitter":0.5,"head_clog":0.1,"search_speed":3.0,"hum":0.1}
	stage._knobs(fixture)
	stage._advance(0.0)
	var reference_plan = stage._plan()
	_check(stage.nominal==1,"vertical calibration matches original Swift")
	_check(reference_plan[1].decode_u32(36)==6365,"field selection matches original Swift")
	_check(reference_plan[1].decode_u32(32)==96540,"caption parity/data match original Swift")
	var expected = [[0,14.098489,28,63.7067,63.85478,63.23312,41.68492,-0.8065116,0.9965,0.0035,-7.8254995], [24,43.432068,55,63.268414,63.968994,63.83603,41.68492,3.1311524,0.9965,0.0035,26.681639], [47,13.572692,21,63.62275,63.234005,63.446,41.68492,1.446554,0.9965,0.0035,-7.9107366]]
	for row in expected:
		var y = int(row[0])
		for c in 10:
			var value = reference_plan[0].decode_s32(y*48+c*4) if c==1 else reference_plan[0].decode_float(y*48+c*4)
			_check(absf(value-float(row[c+1]))<0.001,"Swift timing row %d component %d: %s expected %s"%[y,c,value,row[c+1]])
	_check(absf(stage._uni(11,123)-0.8659633589809804)<1e-15,"SplitMix64 sequence is identical to Swift")
	stage._reset()
	var out = stage.render(input,0,{})
	rd.submit(); rd.sync()
	var actual = rd.texture_get_data(out,0)
	_check(actual==pixels,"healthy receiver is byte-exact identity")
	stage.render(input,1,{})
	rd.submit(); rd.sync()
	_check(rd.texture_get_data(out,0)==pixels,"healthy receiver remains stable across fields")
	# Directly mistime the burst gate into picture while retaining original
	# shader routines; compare red versus blue gate integrals on the GPU.
	var rows = rd.buffer_get_data(stage._buffers[0])
	for y in size.y:
		rows.encode_float(y*48,10.0)
		rows.encode_float(y*48+36,0.0)
	rd.buffer_update(stage._buffers[0],0,rows.size(),rows)
	var gates: Array[PackedByteArray] = []
	for channel in [0,2,-1]:
		var solid = PackedByteArray()
		solid.resize(pixels.size())
		for i in size.x*size.y:
			if channel>=0: solid[i*4+channel] = 255
			solid[i*4+3] = 255
		rd.texture_update(input,0,solid)
		var list = rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(list,stage._pipelines[0])
		rd.compute_list_bind_uniform_set(list,stage._sets[input.get_id()][0],0)
		rd.compute_list_dispatch(list,ceili(size.y/8.0),1,1)
		rd.compute_list_end()
		rd.submit(); rd.sync()
		gates.append(rd.buffer_get_data(stage._buffers[2]))
		if channel == -1:
			var chroma_list = rd.compute_list_begin()
			rd.compute_list_bind_compute_pipeline(chroma_list,stage._pipelines[1])
			rd.compute_list_bind_uniform_set(chroma_list,stage._sets[input.get_id()][1],0)
			rd.compute_list_dispatch(chroma_list,1,1,1)
			rd.compute_list_end()
			rd.submit(); rd.sync()
			var color = rd.buffer_get_data(stage._buffers[3])
			_check(color.decode_float((size.y-1)*16+8)==0.0,"color killer removes chroma after sustained absent burst")
	_check(gates[0]!=gates[1],"mistimed gate responds to picture chroma")
	_check(absf(gates[0].decode_float(0)-0.596*1.6)<0.0001,"red gate integrates original sixteen taps")
	_check(absf(gates[1].decode_float(4)-0.312*1.6)<0.0001,"blue gate integrates original sixteen taps")
	rd.texture_update(input,0,pixels)
	stage.render(input,2,{"signal_strength":0.2,"head_switch":4.0,"tracking":0.6,"dropouts":0.8,"dropout_compensation":true})
	rd.submit(); rd.sync()
	_check(rd.texture_get_data(out,0)!=pixels,"tape and receiver controls alter the signal")
	# Reset through setup must reproduce deterministic pristine initialization.
	stage.setup(rd,size)
	stage.render(input,0,{})
	rd.submit(); rd.sync()
	_check(rd.texture_get_data(stage.output,0)==pixels,"setup clears timing and color state")
	stage.render(input,1,{"signal_strength":2.0,"head_switch":-4.0})
	rd.submit(); rd.sync()
	_check(rd.texture_get_data(stage.output,0)==pixels,"out-of-range knobs clamp to upstream bounds")
	var before_repeat = stage.r
	stage.render(input,1,{})
	rd.submit(); rd.sync()
	_check(stage.r==before_repeat,"repeated field does not advance receiver timing")
	var timing_before = [stage.r,stage.theta,stage.integ,stage.vp,stage.vi,stage.va,stage.gate_err]
	var theta_before = stage.theta_log.duplicate()
	var gate_before = stage.gate_log.duplicate()
	stage.render(input,1,{"signal_strength":0.2,"tracking":0.12,"horizontal_hold":0.1})
	rd.submit(); rd.sync()
	_check([stage.r,stage.theta,stage.integ,stage.vp,stage.vi,stage.va,stage.gate_err]==timing_before,
		"live knob changes on a repeated field preserve the receiver clock and lock")
	_check(stage.theta_log==theta_before and stage.gate_log==gate_before,
		"live knob changes on a repeated field preserve scanline history")
	_check(rd.texture_get_data(stage.output,0)!=pixels,"repeated-field knob changes still affect the picture")
	stage.render(input,2,{"signal_strength":0.2,"tracking":0.12,"horizontal_hold":0.1})
	rd.submit(); rd.sync()
	_check(stage.r>before_repeat and stage.r-before_repeat<2*stage.L,
		"receiver timing continues for the next field after a live knob change")
	stage.render(input,0,{})
	rd.submit(); rd.sync()
	_check(rd.texture_get_data(stage.output,0)==pixels,"backward seek still resets receiver state")
	stage.render(input,100000,{})
	rd.submit(); rd.sync()
	_check(stage.r-100000*stage.L<121*stage.L,"large seek uses bounded two-second settling")
	stage.dispose(); rd.free_rid(input)
	_check(stage.setup(rd,Vector2i(17,9)),"resize rebuilds row buffers and shaders")
	stage.dispose(); rd.free()
	for failure in failures: push_error(failure)
	print("RECEIVER_GPU_AUDIT ","PASS" if failures.is_empty() else "FAIL", " failures=",failures)
	quit(0 if failures.is_empty() else 1)

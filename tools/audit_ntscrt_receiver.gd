extends SceneTree
const RECEIVER=preload("res://scripts/ntscrt_receiver.gd")
var failures: Array[String]=[]
const CLEAN={"ntsc_auto_faults":false,"ntsc_head_switch":0.0,"ntsc_timebase_jitter":0.0,
	"ntsc_crinkle":0.0,"ntsc_dropouts":0.0,"ntsc_ghost":0.0}
func expect(value: bool,message: String):
	if not value: failures.append(message)
func run_fields(receiver,knobs:Dictionary,fields:int,reduced:=false,wear:=1.0):
	for i in fields: receiver.advance(1.0/RECEIVER.FIELD_RATE,240,knobs,0.0,reduced,wear)
func _init():
	var clean=RECEIVER.new()
	run_fields(clean,CLEAN,60)
	expect(absf(clean.horizontal_phase)<0.00001 and minf(clean.vertical_phase,1.0-clean.vertical_phase)<0.00001,"healthy receiver failed to lock")
	expect(clean.color_on and clean.color_confidence>0.999,"healthy burst lost colour")
	var rows:PackedFloat32Array=clean._data
	for y in 240:
		expect(absf(rows[y*12])<0.00001 and absf(rows[y*12+1]-(y+0.5)/240.0)<0.00001,"healthy raster moved row %d"%y)
	var weak=CLEAN.duplicate()
	weak["ntsc_signal_strength"]=0.0
	run_fields(clean,weak,90)
	expect(clean._data[2]>0.5 and not clean.color_on,"lost signal did not add RF noise and kill colour")
	run_fields(clean,CLEAN,180)
	expect(clean.color_on and clean.color_confidence>0.99,"colour did not recover when reception returned")
	for hold in [-0.8,0.8]:
		var knobs=CLEAN.duplicate()
		knobs["ntsc_horizontal_hold"]=hold
		knobs["ntsc_vertical_hold"]=hold
		var rolling=RECEIVER.new()
		run_fields(rolling,knobs,90)
		expect(minf(rolling.vertical_phase,1.0-rolling.vertical_phase)>0.02,"vertical hold did not roll")
		expect(absf(rolling.horizontal_phase)>0.1,"horizontal hold did not slip")
		for v in rolling._data: expect(is_finite(v),"receiver generated non-finite row data")
	var bad=CLEAN.duplicate()
	bad.merge({"ntsc_signal_strength":0.0,"ntsc_horizontal_hold":1.0,"ntsc_vertical_hold":1.0,
		"ntsc_tracking":1.0,"ntsc_head_clog":1.0,"ntsc_hum":1.0},true)
	var comfortable=RECEIVER.new()
	run_fields(comfortable,bad,10,true)
	expect(comfortable.color_on and comfortable._data[2]==0.0 and comfortable._data[3]==0.0,"reduced flashing retained signal loss")
	expect(absf(comfortable.horizontal_phase)<0.0001 and comfortable.vertical_phase==0.0,"reduced flashing retained rolling")
	run_fields(comfortable,bad,10,false,0.0)
	expect(comfortable._data[2]==0.0 and comfortable._data[3]==0.0,"zero distortion retained RF failure")
	var a=RECEIVER.new()
	var b=RECEIVER.new()
	for i in 60: a.advance(1.0/RECEIVER.FIELD_RATE,240,bad)
	for i in 30: b.advance(2.0/RECEIVER.FIELD_RATE,240,bad)
	expect(a.field_index==b.field_index and a._data==b._data,"receiver depends on display frame batching")
	var started=Time.get_ticks_usec()
	run_fields(a,CLEAN,120)
	print("NTSCRT receiver 240-line mean CPU: %.3f ms"%((Time.get_ticks_usec()-started)/120000.0))
	if failures.is_empty(): print("audit_ntscrt_receiver: PASS")
	else:
		for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)

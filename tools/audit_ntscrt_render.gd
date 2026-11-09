extends SceneTree
## Native GPU contract + cost fixture. No game saves, no frame readback in the
## implementation: get_image is used only here for verification/capture.
## godot --path . --script tools/audit_ntscrt_render.gd
const POST=preload("res://scripts/post_process_controller.gd")
const OUTPUT="res://build/ntscrt-review"
const CLEAN={"ntsc_auto_faults":false,"ntsc_head_switch":0.0,"ntsc_timebase_jitter":0.0,
	"ntsc_crinkle":0.0,"ntsc_dropouts":0.0,"ntsc_ghost":0.0,"ntsc_chroma_noise":0.0,
	"ntsc_rf_noise":0.0,"ntsc_auto_exposure":0.0,"ntsc_brightness":1.0,"ntsc_saturation":1.0,
	"ntsc_chroma_delay":0.0,"ntsc_chroma_bleed":0.0,"ntsc_sharpness":0.0,"ntsc_interlaced":false,
	"vhs_distortion":0.0,"ntsc_quality":1}
var failures:Array[String]=[]
var controller:Node
var source:ColorRect
var label:Label
var metrics:Array=[]
func expect(value:bool,message:String):
	if not value: failures.append(message)
func _init():call_deferred("run")
func settle(count:=8):
	for i in count:await process_frame
	await RenderingServer.frame_post_draw
func capture(name:String)->Image:
	var img=root.get_texture().get_image()
	var display=img.duplicate()
	display.convert(Image.FORMAT_RGB8)
	if root.use_hdr_2d:display.linear_to_srgb()
	display.save_png(OUTPUT.path_join(name+".png"))
	return img
func difference(a:Image,b:Image)->float:
	var total:=0.0
	var count:=0
	for y in range(10,a.get_height()-10,13):
		for x in range(10,a.get_width()-10,13):
			var ca=a.get_pixel(x,y)
			var cb=b.get_pixel(x,y)
			total+=Vector3(ca.r-cb.r,ca.g-cb.g,ca.b-cb.b).length()
			count+=1
	return total/maxi(count,1)
func timing(name:String,count:=90):
	await settle(20)
	var cpu:=0.0
	var gpu:=0.0
	var simulation:=0.0
	var wall:=Time.get_ticks_usec()
	for i in count:
		await RenderingServer.frame_post_draw
		cpu+=RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
		gpu+=RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
		if controller._experimental!=null and controller._experimental.visible:
			simulation+=controller._experimental.last_cpu_usec/1000.0
		await process_frame
	var row={"case":name,"resolution":str(root.size),"render_cpu_ms":cpu/count,
		"render_gpu_ms":gpu/count if gpu>0.0 else null,"simulation_ms":simulation/count,
		"wall_frame_ms":(Time.get_ticks_usec()-wall)/float(count)/1000.0}
	metrics.append(row)
	print("NTSCRT_TIMING ",JSON.stringify(row))
func run():
	if DisplayServer.get_name()=="headless":
		printerr("NTSCRT render audit requires a GPU renderer")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size=Vector2i(1280,720)
	root.use_hdr_2d=true
	root.title="Liminal — NTSCRT validation"
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	source=ColorRect.new()
	source.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat=ShaderMaterial.new()
	mat.shader=Shader.new()
	mat.shader.code="""shader_type canvas_item; render_mode unshaded,blend_disabled;
uniform bool linear_output=true;
uniform float bar_gain=1.0;
void fragment(){
vec3 colors[8]=vec3[8](vec3(0.8),vec3(0.8,0.8,0),vec3(0,0.8,0.8),vec3(0,0.8,0),vec3(0.8,0,0.8),vec3(0.8,0,0),vec3(0,0,0.8),vec3(0.03));
vec3 c=colors[int(clamp(floor(UV.x*8.0),0.0,7.0))]*bar_gain;
if(UV.y>0.5)c=vec3(UV.x);
if(UV.y>0.72)c=vec3(step(0.5,fract(UV.x*80.0)));
if(UV.y>0.91)c=vec3(0.02+UV.x*0.06);
COLOR=vec4(linear_output?pow(c,vec3(2.2)):c,1);
}"""
	source.material=mat
	root.add_child(source)
	label=Label.new()
	label.text="REC  •  NTSCRT SIGNAL TEST   00:00:01"
	label.position=Vector2(40,380)
	label.add_theme_font_size_override("font_size",26)
	root.add_child(label)
	controller=POST.new()
	root.add_child(controller)
	controller.setup(root,false,false)
	controller.ensure_scene_copy()
	await settle()
	var reference=capture("fixture-clean")
	await timing("clean-720p")
	controller.set_effects(true,false)
	for decoder in [2,1,0]:
		var knobs=CLEAN.duplicate()
		knobs["ntsc_decoder"]=decoder
		controller.set_video_pipeline(1,knobs)
		await settle()
		var decoded=capture("decoder-%d"%decoder)
		var worst:=0.0
		for bar in 8:
			var x=int((bar+0.5)*root.size.x/8.0)
			var ca=reference.get_pixel(x,180)
			var cb=decoded.get_pixel(x,180)
			worst=maxf(worst,Vector3(ca.r-cb.r,ca.g-cb.g,ca.b-cb.b).length())
		expect(worst<0.04,"decoder %d corrupts constant colours: %f"%[decoder,worst])
		print("NTSCRT_DECODER %d palette_error=%.6f"%[decoder,worst])
	controller.set_effects(true,true)
	controller.set_video_pipeline(0,{})
	await timing("classic-vhs-crt-720p")
	await settle()
	capture("fixture-classic")
	controller.set_video_pipeline(1,{"ntsc_auto_faults":false})
	await timing("ntscrt-full-720p")
	await settle()
	var healthy=capture("fixture-ntscrt")
	var bad={"ntsc_auto_faults":false,"ntsc_signal_strength":0.25,"ntsc_tracking":0.5,
		"ntsc_horizontal_hold":0.6,"ntsc_vertical_hold":0.7,"ntsc_dropouts":0.8,"ntsc_hum":0.3}
	controller.set_video_pipeline(1,bad)
	await settle(90)
	var damaged=capture("fixture-damaged")
	expect(difference(healthy,damaged)>0.08,"damaged preset did not change rendered pixels")
	controller.set_video_pipeline(1,{"ntsc_quality":0,"ntsc_auto_faults":false})
	await timing("ntscrt-efficient-720p")
	await settle()
	capture("fixture-efficient")
	# Resize must fit every intermediate rectangle, and the final quad must
	# cover the whole viewport. No atlas tiles may leak at the edges.
	for extent in [Vector2i(640,360),Vector2i(1920,1080),Vector2i(3840,2160)]:
		root.size=extent
		controller.set_video_pipeline(1,{"ntsc_auto_faults":false})
		await settle()
		var p=controller._experimental
		# macOS may constrain a requested window to the attached display.
		var actual=root.get_visible_rect().size
		expect(p.buffer_size.y+p.bloom_size.y<=actual.y and p.buffer_size.x<=actual.x,"atlas exceeds viewport at "+str(actual))
		expect(p.get_node("Display").size==actual,"final display does not cover viewport")
		if actual.x>=1920:await timing("ntscrt-full-%dp"%actual.y,60)
		capture("resize-%dx%d"%[actual.x,actual.y])
	root.size=Vector2i(1280,720)
	controller.set_effects(false,false)
	await settle()
	var disabled=capture("fixture-disabled")
	expect(difference(reference,disabled)<0.001,"disabled effects changed the source")
	# Verify the non-HDR backbuffer too: it cannot carry negative values or
	# colour payloads above 1.0, even when the final RGB colour would be valid.
	root.use_hdr_2d=false
	mat.set_shader_parameter("linear_output",false)
	mat.set_shader_parameter("bar_gain",1.25)
	await settle()
	var ldr_reference=capture("fixture-ldr-source")
	var ldr_knobs=CLEAN.duplicate()
	ldr_knobs["ntsc_decoder"]=2
	controller.set_video_pipeline(1,ldr_knobs)
	controller.set_effects(true,false)
	await settle()
	var ldr=capture("fixture-ldr-decoded")
	for bar in 8:
		var x=int((bar+0.5)*root.size.x/8.0)
		var a=ldr_reference.get_pixel(x,180)
		var b=ldr.get_pixel(x,180)
		expect(Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length()<0.04,"LDR backbuffer corrupts bar %d"%bar)
	var rolling=CLEAN.duplicate()
	rolling["vhs_distortion"]=0.5
	rolling["ntsc_decoder"]=2
	controller.set_video_pipeline(1,rolling)
	var pipeline=controller._experimental
	pipeline.set_process(false)
	pipeline.receiver.reset()
	pipeline.receiver.vertical_phase=0.5
	pipeline._process(0.0)
	await settle()
	var blanked=capture("fixture-rolled")
	rolling["ntsc_black_level"]=0.3
	controller.set_video_pipeline(1,rolling)
	await settle()
	var raised=capture("fixture-blanking")
	expect(difference(blanked,raised)>0.02,"black level did not reveal blanking")
	rolling["ntsc_caption_data"]=false
	controller.set_video_pipeline(1,rolling)
	await settle()
	var no_captions=capture("fixture-no-caption-data")
	var caption_delta:=0.0
	for y in root.size.y:
		var a=raised.get_pixel(230,y)
		var b=no_captions.get_pixel(230,y)
		caption_delta=maxf(caption_delta,absf(a.r-b.r))
	expect(caption_delta>0.03,"rolled picture does not contain optional line-21 data")
	var file=FileAccess.open(OUTPUT.path_join("fixture-timings.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"\t"))
	if failures.is_empty():print("audit_ntscrt_render: PASS")
	else:
		for failure in failures:printerr(failure)
	quit(0 if failures.is_empty() else 1)

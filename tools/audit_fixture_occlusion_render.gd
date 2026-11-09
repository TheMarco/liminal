extends "res://tools/lib/audit_base.gd"
## A glossy floor must reflect its own fitting, not one behind an opaque wall.
## Native GPU check; the shadowless control proves the view exposes the bug.
const FITTING := preload("res://scripts/fixture_lighting.gd")
const OUT := "res://build/fixture-occlusion"
var view: SubViewport
var office_diffuser := OS.get_cmdline_user_args().has("--office-diffuser")

func box(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material
	mesh.position = at
	view.add_child(mesh)
	FITTING.prepare_shadow_mesh(mesh)
	return mesh

func fixture(at: Vector3) -> AreaLight3D:
	var lens_mat := StandardMaterial3D.new()
	lens_mat.emission_enabled = true
	lens_mat.emission = Color.WHITE
	lens_mat.emission_energy_multiplier = 2.0
	var fixture_root := Node3D.new()
	fixture_root.position = at
	view.add_child(fixture_root)
	var size := Vector3(1.5,0.05,0.75) if office_diffuser else Vector3(1.2,0.05,0.35)
	var lens := box(size,Vector3.ZERO,lens_mat)
	lens.reparent(fixture_root,false)
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var reach := OfficeCeilingGrid.LIGHT_REACH if office_diffuser else 10.0
	var light := FITTING.lower_face(fixture_root,lens,Color.WHITE,2.0,reach,4,"audit_diffuser")
	if office_diffuser:
		light.light_size = sqrt(light.area_size.x*light.area_size.y/PI)
		light.light_cull_mask &= ~OfficeCeilingGrid.CEILING_RENDER_LAYER
	return light

func capture(label: String) -> Image:
	for i in 8:
		await process_frame
		RenderingServer.force_draw(false,0.0)
	var result := view.get_texture().get_image()
	expect(result.save_png(OUT.path_join(label+".png"))==OK,"capture failed")
	return result

func positive_difference(a: Image, b: Image) -> float:
	var total := 0.0
	# Lower half contains the glossy floor, excluding the luminous fittings.
	for y in range(a.get_height()/2,a.get_height()):
		for x in a.get_width():
			total += maxf(b.get_pixel(x,y).get_luminance()-a.get_pixel(x,y).get_luminance(),0.0)
	return total/(a.get_width()*a.get_height()/2.0)

func run() -> void:
	if DisplayServer.get_name()=="headless":
		fail("fixture occlusion pixels require a native GPU renderer")
		finish("fixture occlusion")
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	view = SubViewport.new()
	view.size = Vector2i(800,600)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.025,0.025,0.025)
	view.add_child(world)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.3,0.3,0.3)
	floor_mat.roughness = 0.18
	box(Vector3(12,0.2,16),Vector3(0,-0.1,-2),floor_mat)
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.3,0.3,0.3)
	box(Vector3(0.4,6,16),Vector3(0,3,-2),wall_mat)
	var camera := Camera3D.new()
	view.add_child(camera)
	camera.look_at_from_position(Vector3(-4,2,4),Vector3(-2,0,-1))
	var local_light := fixture(Vector3(-3,3.5,-1))
	var hidden_light := fixture(Vector3(2,3.5,-1))
	var quality := GameSettings.new("/tmp/liminal-fixture-quality-%d.cfg"%OS.get_process_id())
	for tier in [0,2,3]:
		quality.apply_quality_preset(tier)
		GraphicsQuality.apply_viewport_features(view,quality)
		GraphicsQuality.apply_global(quality)
		for quadrant in 4: view.set_positional_shadow_atlas_quadrant_subdiv(quadrant,Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_16)
		GraphicsQuality.apply_practical_light(local_light,{"shadow_quality":tier})
		GraphicsQuality.apply_practical_light(hidden_light,{"shadow_quality":tier})
		hidden_light.visible = false
		var own_only := await capture("tier-%d-own"%tier)
		hidden_light.visible = true
		var blocked := await capture("tier-%d-blocked"%tier)
		hidden_light.shadow_enabled = false
		var leaking := await capture("tier-%d-shadowless-control"%tier)
		var corrected := positive_difference(own_only,blocked)
		var control := positive_difference(own_only,leaking)
		expect(control>0.005,"control failed to expose through-wall floor reflection")
		expect(corrected<0.001 and corrected<control*0.05,"fixture reflects through wall at tier %d"%tier)
		print("FIXTURE_OCCLUSION tier=%d corrected=%.6f shadowless=%.6f"%[tier,corrected,control])
	if office_diffuser:
		# The ceiling receiver exclusion must still allow the player's torch to
		# illuminate the slab during a blackout. A ceiling-only beam isolates it.
		local_light.visible = false
		hidden_light.visible = false
		var ceiling := box(Vector3(6,0.2,12),Vector3(-3,4.5,-2),wall_mat)
		ceiling.layers = OfficeCeilingGrid.CEILING_RENDER_LAYER
		camera.look_at_from_position(Vector3(-4,2,4),Vector3(-3,4.4,-2))
		var dark := await capture("office-ceiling-dark")
		var torch := SpotLight3D.new()
		torch.light_energy = 8.0
		torch.spot_range = 12.0
		torch.spot_angle = 45.0
		torch.light_cull_mask = OfficeCeilingGrid.CEILING_RENDER_LAYER
		camera.add_child(torch)
		var lit := await capture("office-ceiling-torch")
		var response := positive_difference(dark,lit)
		expect(response>0.005,"Office ceiling disappeared or lost flashlight illumination")
		print("OFFICE_CEILING_TORCH response=",response)
	DirAccess.remove_absolute(quality._path)
	view.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	finish("fixture occlusion pixels")

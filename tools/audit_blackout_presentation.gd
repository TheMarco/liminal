extends "res://tools/lib/audit_base.gd"
const ENV_POWER := preload("res://scripts/blackout_environment.gd")
const SURFACE_POWER := preload("res://scripts/blackout_surfaces.gd")
var chunks_checked := 0
var meshes_checked := 0
var probes_checked := 0

func _environments() -> void:
	var power := ENV_POWER.new()
	for theme in WorldGen.THEMES:
		var env := EnvBuilder.build(theme)
		var before := {}
		for key in ENV_POWER.OFF:
			before[key] = env.get(key)
		var exposure := env.tonemap_exposure
		power.apply(env)
		power.apply(env)
		for key in ENV_POWER.OFF:
			var actual = env.get(key)
			var wanted = ENV_POWER.OFF[key]
			expect(is_equal_approx(actual, wanted) if actual is float else actual == wanted,
				"floor %d left %s powered" % [theme, key])
		expect(env.tonemap_exposure == exposure, "blackout reduced torch exposure")
		power.restore()
		power.restore()
		for key in before:
			expect(env.get(key) == before[key], "floor %d did not restore %s" % [theme, key])
	var airport := EnvBuilder.build(4)
	var office := EnvBuilder.build(1)
	var airport_energy := airport.sdfgi_energy
	var office_energy := office.sdfgi_energy
	power.apply(airport)
	power.apply(office)
	expect(airport.sdfgi_energy == airport_energy and office.sdfgi_energy == 0.0,
		"changing floors restored blackout state into the wrong environment")
	power.restore()
	expect(office.sdfgi_energy == office_energy, "new floor environment did not restore")

func _check_dark(material: Material) -> void:
	if material is BaseMaterial3D:
		expect(not material.emission_enabled, "standard/imported surface still emits during blackout")
		expect(material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED,
			"unshaded powered surface still bypasses room lighting")
	elif material is ShaderMaterial and SURFACE_POWER._has_power(material.shader):
		expect(is_zero_approx(float(material.get_shader_parameter("mains_power"))),
			"powered shader still emits during blackout")

func _annex_ceiling(chunk: Chunk) -> MeshInstance3D:
	for node in chunk.get_children():
		if node is not MeshInstance3D or node.mesh == null:
			continue
		var bounds: AABB = node.transform * node.mesh.get_aabb()
		# Match the actual structural slab, including its instance scale. The
		# blackout material is a local clone, so material identity is not stable.
		if bounds.size.is_equal_approx(Vector3(12.0, 0.3, 12.0)) \
				and bounds.position.is_equal_approx(Vector3(0.0, 2.78, 0.0)):
			return node
	return null

func _chunk(theme: int, cell: Vector2i) -> void:
	var ws := WorldGen.level_seed(240721, theme)
	var chunk := Chunk.new(ws, cell, theme)
	var meshes := {}
	var materials := {}
	var labels := {}
	var probes := {}
	for node in chunk.find_children("*", "MeshInstance3D", true, false):
		var overrides: Array = []
		if node.mesh == null:
			continue
		for i in node.mesh.get_surface_count():
			overrides.append(node.get_surface_override_material(i))
			var mat: Material = node.get_active_material(i)
			if mat is BaseMaterial3D:
				materials[mat] = [mat.emission_enabled, mat.shading_mode]
		meshes[node] = [node.visible, node.material_override, node.material_overlay, overrides]
	for label in chunk.find_children("*", "Label3D", true, false):
		labels[label] = label.shaded
	for probe in chunk.find_children("*", "ReflectionProbe", true, false):
		probes[probe] = [probe.intensity, probe.visible]
	chunk.set_blackout(true)
	chunk.set_blackout(true)
	for mesh in meshes:
		expect(mesh.visible == meshes[mesh][0], "blackout removed geometry in floor %d cell %s" % [theme, cell])
		for i in mesh.mesh.get_surface_count():
			_check_dark(mesh.get_active_material(i))
		meshes_checked += 1
	for mat in materials:
		expect([mat.emission_enabled, mat.shading_mode] == materials[mat], "blackout mutated a shared source material")
	for light in chunk.find_children("*", "Light3D", true, false):
		expect(not light.visible, "blackout left a powered light visible")
	for label in labels:
		expect(label.shaded, "world sign still glows without light")
	for probe in probes:
		probes_checked += 1
		expect(probe.intensity == 0.0, "bright cached room remained in reflections")
		if probe != chunk._pool_reflection:
			expect(not probe.visible, "cached probe still supplies diffuse lighting")
	chunk.set_blackout(false)
	chunk.set_blackout(false)
	for mesh in meshes:
		var before: Array = meshes[mesh]
		expect(mesh.visible == before[0] and mesh.material_override == before[1] \
			and mesh.material_overlay == before[2], "blackout did not restore material/visibility identity")
		for i in before[3].size():
			expect(mesh.get_surface_override_material(i) == before[3][i], "surface override did not restore")
	for label in labels:
		expect(label.shaded == labels[label], "sign shading did not restore")
	for probe in probes:
		expect([probe.intensity, probe.visible] == probes[probe], "probe state did not restore")
	var annex := _annex_ceiling(chunk) if theme == 2 else null
	if annex != null:
		expect(annex.visible, "Annex ceiling slab was hidden after blackout restore")
	# Streaming/staged replacement constructor must also start fully unpowered.
	var dark := Chunk.new(ws, cell, theme, {"blackout": true})
	var normal_meshes := chunk.find_children("*", "MeshInstance3D", true, false)
	var dark_meshes := dark.find_children("*", "MeshInstance3D", true, false)
	expect(dark_meshes.size() == normal_meshes.size(), "initial blackout changed mesh population")
	for i in mini(normal_meshes.size(), dark_meshes.size()):
		var normal_mesh: MeshInstance3D = normal_meshes[i]
		var dark_mesh: MeshInstance3D = dark_meshes[i]
		expect(dark_mesh.visible == normal_mesh.visible,
			"initial blackout changed baseline geometry visibility")
		if dark_mesh.mesh == null:
			continue
		for surface in dark_mesh.mesh.get_surface_count():
			_check_dark(dark_mesh.get_active_material(surface))
	var dark_annex := _annex_ceiling(dark) if theme == 2 else null
	if theme == 2 and cell == Vector2i.ZERO:
		expect(dark_annex != null, "initial blackout fixture lost Annex ceiling slab")
	if dark_annex != null:
		expect(dark_annex.visible, "initial blackout hid Annex ceiling slab")
	for probe in dark.find_children("*", "ReflectionProbe", true, false):
		expect(probe.intensity == 0.0, "probe was created powered after initial blackout overlay")
		expect(not probe.visible, "newly streamed probe could capture the unpowered room")
	dark.set_blackout(false)
	if dark_annex != null:
		expect(dark_annex.visible, "restored initial-blackout Annex ceiling slab is hidden")
	chunk.free()
	dark.free()
	chunks_checked += 1

func _surface_cases() -> void:
	var holder := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mesh.mesh.material = mat
	holder.add_child(mesh)
	var power := SURFACE_POWER.new()
	power.apply(holder)
	expect(mesh.visible and not mesh.get_active_material(0).emission_enabled and mat.emission_enabled,
		"imported mesh material was hidden/mutated instead of locally de-powered")
	mesh.free()
	power.restore() # streaming/mutation may remove objects while power is out
	holder.free()
	for name in ["adbox", "casino_slot_lights", "slot_artwork", "slot_reels", "slot_ticker", "slot_paytable", "slot_wheel"]:
		var original := ShaderMaterial.new()
		original.shader = load("res://shaders/%s.gdshader" % name)
		var off := power.off_material(original) as ShaderMaterial
		expect(off != original and is_zero_approx(float(off.get_shader_parameter("mains_power"))),
			"shader %s has no reversible mains-power contract" % name)

func run() -> void:
	_environments()
	_surface_cases()
	for theme in WorldGen.THEMES:
		for cell in [Vector2i.ZERO, Vector2i(3, 3), Vector2i(-4, 2)]:
			_chunk(theme, cell)
			await process_frame
	# An actual tall Airport ceiling exercises the formerly hidden wood/coffers.
	var found := false
	var ws := WorldGen.level_seed(240721, 4)
	for x in range(-8, 9):
		for z in range(-8, 9):
			var cell := Vector2i(x, z)
			if not found and AirportGrandCeiling.applies(Chunk.cell_ceil_h(ws, cell, 4), WorldGen.cell_style(ws, cell, 4)):
				_chunk(4, cell)
				found = true
	expect(found and probes_checked > 0, "audit missed grand ceiling/probe fixtures")
	var annex_fixture := Chunk.new(WorldGen.level_seed(240721, 2), Vector2i.ZERO, 2)
	var annex_slab := _annex_ceiling(annex_fixture)
	expect(annex_slab != null, "audit missed actual Annex ceiling slab fixture")
	if annex_slab != null:
		var annex_bounds := annex_slab.transform * annex_slab.mesh.get_aabb()
		expect(is_equal_approx(annex_bounds.position.y, 2.78) and is_equal_approx(annex_bounds.end.y, 3.08),
			"Annex ceiling slab bounds changed")
		expect(annex_slab.visible, "normal Annex ceiling slab is hidden")
	annex_fixture.set_blackout(true)
	if annex_slab != null:
		expect(annex_slab.visible, "blackout hid actual Annex ceiling slab")
	annex_fixture.set_blackout(false)
	if annex_slab != null:
		expect(annex_slab.visible, "restored blackout hid actual Annex ceiling slab")
	annex_fixture.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("BLACKOUT_PRESENTATION chunks=%d preserved_meshes=%d probes=%d environments=%d" % [
		chunks_checked, meshes_checked, probes_checked, WorldGen.THEMES.size()])
	finish("blackout presentation")

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
		expect(not material.emission_enabled or is_zero_approx(material.emission_energy_multiplier),
			"standard/imported surface still emits during blackout")
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
	chunk.prepare_runtime_rendering()
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
				materials[mat] = [mat.emission_enabled, mat.shading_mode, mat.emission_energy_multiplier]
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
		expect([mat.emission_enabled, mat.shading_mode, mat.emission_energy_multiplier] == materials[mat], "blackout mutated a shared source material")
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
	var sign := ShaderMaterial.new()
	sign.shader = preload("res://shaders/office_ceiling.gdshader")
	mesh.material_overlay = sign
	power.prepare_mesh(mesh, {})
	# An in-place change, a newly attached surface and an override replaced
	# after room installation must all use their current appearance.
	mat.albedo_color = Color.CORAL
	sign.set_shader_parameter("pitch", 1.25)
	var late := MeshInstance3D.new()
	late.mesh = BoxMesh.new()
	late.material_override = mat
	holder.add_child(late)
	var label := Label3D.new()
	holder.add_child(label)
	power.apply(holder)
	expect(mesh.visible and is_zero_approx(mesh.get_active_material(0).emission_energy_multiplier) and mat.emission_enabled,
		"imported mesh material was hidden/mutated instead of locally de-powered")
	var first_dark := mesh.get_active_material(0) as StandardMaterial3D
	expect(first_dark.albedo_color == mat.albedo_color and late.material_override == first_dark,
		"late fixture or changed colour did not use the current dark material")
	expect(mesh.material_overlay != sign and mesh.material_overlay.get_shader_parameter("pitch") == 1.25
		and is_zero_approx(mesh.material_overlay.get_shader_parameter("mains_power")) and label.shaded,
		"prepared overlay or late label had the wrong blackout state")
	mesh.free()
	power.restore() # streaming/mutation may remove objects while power is out
	expect(late.material_override == mat and not label.shaded, "late fixture or label failed to restore")
	var replacement := mat.duplicate() as StandardMaterial3D
	replacement.albedo_color = Color.GREEN
	late.material_override = replacement
	power.apply(holder)
	expect(late.material_override != replacement and late.material_override.albedo_color == Color.GREEN
		and first_dark.albedo_color == Color.CORAL, "second blackout used or modified an earlier snapshot")
	power.restore()
	expect(late.material_override == replacement, "second blackout restored a stale override")
	holder.free()
	for name in ["adbox", "casino_slot_lights", "slot_artwork", "slot_reels", "slot_ticker", "slot_paytable", "slot_wheel"]:
		var original := ShaderMaterial.new()
		original.shader = load("res://shaders/%s.gdshader" % name)
		var off := power.off_material(original) as ShaderMaterial
		expect(off != original and is_zero_approx(float(off.get_shader_parameter("mains_power"))),
			"shader %s has no reversible mains-power contract" % name)

func _indexed_room() -> void:
	var room := Chunk.new(WorldGen.level_seed(240721, 0), Vector2i.ZERO, 0)
	var holder := Node3D.new()
	room.add_child(holder)
	var original := StandardMaterial3D.new()
	var replaced := MeshInstance3D.new()
	replaced.mesh = BoxMesh.new()
	replaced.material_override = original
	holder.add_child(replaced)
	var changed := MeshInstance3D.new()
	changed.mesh = replaced.mesh
	changed.material_override = original
	holder.add_child(changed)
	var fixed_root := Node3D.new()
	fixed_root.set_meta(&"fixed_power_bindings", true)
	holder.add_child(fixed_root)
	var fixed := MeshInstance3D.new()
	fixed.mesh = BoxMesh.new()
	fixed.mesh.material = original
	fixed_root.add_child(fixed)
	fixed.owner = fixed_root
	var fixture := preload("res://scripts/fixture_lighting.gd").lower_face(holder, replaced,
		Color.WHITE, 2.75, 8.0, 2, "audit fixture")
	fixture.layers = 5
	fixture.light_indirect_energy = 0.625
	fixture.light_volumetric_fog_energy = 0.375
	root.add_child(room)
	var current := original.duplicate() as StandardMaterial3D
	current.emission_enabled = true
	current.albedo_color = Color.CORAL
	replaced.material_override = current
	original.emission_enabled = true
	room.set_blackout(true)
	expect(fixture.visible and fixture.layers == 0 and fixture.light_energy == 0.0
		and fixture.light_indirect_energy == 0.0 and fixture.light_volumetric_fog_energy == 0.0,
		"installed fixture still contributes direct, indirect or volumetric light")
	fixture.light_energy = 1.5 # A running ballast writes energy during an outage.
	room.set_blackout(true)
	expect(fixture.layers == 0, "ballast repowered a fixture during an outage")
	expect(fixed.get_active_material(0) != original, "A fixed imported surface stayed lit")
	expect(replaced.material_override != current and replaced.material_override.albedo_color == Color.CORAL
		and changed.material_override != original, "indexed bindings missed a replacement or newly powered material")
	room.set_blackout(false)
	expect(fixture.visible and fixture.layers == 5 and fixture.light_energy == 2.75
		and fixture.light_indirect_energy == 0.625 and fixture.light_volumetric_fog_energy == 0.375,
		"installed fixture did not recover its original light channels")
	expect(fixed.get_surface_override_material(0) == null and fixed.get_active_material(0) == original,
		"Restoring a fixed imported surface left a stale override")
	expect(replaced.material_override == current and changed.material_override == original, "indexed bindings restored stale materials")
	var late := OmniLight3D.new()
	holder.add_child(late)
	var removed := changed
	holder.remove_child(removed)
	removed.free()
	room.set_blackout(true)
	expect(not late.visible, "late nested light stayed powered")
	fixed.free()
	fixture.free()
	replaced.free()
	room.set_blackout(false)
	expect(late.visible, "late light failed to recover after removing an indexed mesh")
	root.remove_child(room)
	var label := Label3D.new()
	holder.add_child(label)
	root.add_child(room)
	room.set_blackout(true)
	expect(label.shaded, "room reentry retained its old index")
	room.set_blackout(false)
	room.free()


func _room_diffusers() -> void:
	var first := SURFACE_POWER.new()
	var adjacent := SURFACE_POWER.new()
	var source := StandardMaterial3D.new()
	source.emission_enabled = true
	var first_lens := MeshInstance3D.new()
	first_lens.mesh = first.emitter_box(source)
	var second_lens := MeshInstance3D.new()
	second_lens.mesh = first.emitter_box(source)
	var adjacent_box := adjacent.emitter_box(source)
	expect(first_lens.mesh == second_lens.mesh and first_lens.mesh != adjacent_box,
		"strip diffusers must share geometry only within their room")
	first.index_visuals([first_lens, second_lens])
	var alternate := source.duplicate() as StandardMaterial3D
	alternate.albedo_color = Color.CORAL
	second_lens.set_surface_override_material(0, alternate)
	first.apply_indexed({})
	var switched := first_lens.get_active_material(0) as StandardMaterial3D
	expect(switched != source and is_zero_approx(switched.emission_energy_multiplier)
		and first_lens.get_surface_override_material(0) == null, "room diffuser missed the shared power switch")
	var overridden := second_lens.get_active_material(0) as StandardMaterial3D
	expect(overridden.albedo_color == Color.CORAL and is_zero_approx(overridden.emission_energy_multiplier),
		"room power skipped a replacement diffuser surface")
	expect(adjacent_box.material == source and source.emission_energy_multiplier > 0,
		"cutting one room dimmed a separately powered room")
	first.restore()
	expect(first_lens.get_active_material(0) == source and second_lens.get_surface_override_material(0) == alternate,
		"restoration lost the original diffuser bindings")
	first_lens.free()
	second_lens.free()

func run() -> void:
	_environments()
	_surface_cases()
	_indexed_room()
	_room_diffusers()
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

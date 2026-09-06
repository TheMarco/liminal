extends SceneTree
## Focused Poolrooms water, reflection-probe, and blackout contract audit.

const THEME := 9
const BASE := 240721
const RADIUS := 4
const WATER_LAYER := preload("res://scripts/pool_reflection_probe.gd").WATER_LAYER

var failures: Array[String] = []
var chunks: Array[Chunk] = []

class FakeManager extends Node3D:
	signal chunk_built(chunk: Node3D)
	var chunks: Dictionary = {}

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var ws := WorldGen.level_seed(BASE, THEME)
	var wet_anchor := Vector2i.ZERO
	var member_cell := Vector2i.ZERO
	var jacuzzi_anchor := Vector2i.ZERO
	var have_wet := false
	var have_member := false
	var have_jacuzzi := false
	for x in range(-RADIUS, RADIUS + 1):
		for z in range(-RADIUS, RADIUS + 1):
			var cell := Vector2i(x, z)
			var style := WorldGen.cell_style(ws, cell, THEME)
			var root := WorldGen.room_id(ws, cell)
			if not Chunk.pool_style_dry(style) and root == cell and not have_wet:
				wet_anchor = cell; have_wet = true
			if root != cell and not have_member:
				member_cell = cell; have_member = true
			var probe_chunk := Chunk.new(ws, cell, THEME)
			var has_jacuzzi := false
			for mesh in probe_chunk.find_children("*", "MeshInstance3D", true, false):
				if mesh.has_meta("pool_jacuzzi_water"): has_jacuzzi = true
			probe_chunk.free()
			if has_jacuzzi and root == cell and not have_jacuzzi:
				jacuzzi_anchor = cell; have_jacuzzi = true
			if have_wet and have_member and have_jacuzzi: break
		if have_wet and have_member and have_jacuzzi: break
	check(have_wet, "no wet room anchor found")
	check(have_member, "no room member found")
	check(have_jacuzzi, "no jacuzzi-containing dry anchor found")
	var seen: Dictionary = {}
	for x in range(-RADIUS, RADIUS + 1):
		for z in range(-RADIUS, RADIUS + 1):
			var cell := Vector2i(x, z)
			var chunk := Chunk.new(ws, cell, THEME)
			chunks.append(chunk)
			seen[cell] = chunk
			var waters := chunk.find_children("*", "MeshInstance3D", true, false)
			var contains_jacuzzi := false
			for node in waters:
				if not node.has_meta("pool_water_surface") and not node.has_meta("pool_jacuzzi_water"): continue
				if node.has_meta("pool_jacuzzi_water"): contains_jacuzzi = true
				check(node.layers == WATER_LAYER, "water layers mismatch at %s" % cell)
				check(node.material_override == Mats.pool_water(), "water material mismatch at %s" % cell)
			var probes := chunk.find_children("*", "ReflectionProbe", true, false)
			var wanted := chunk.is_room_anchor and (not Chunk.pool_style_dry(WorldGen.cell_style(ws, cell, THEME)) or contains_jacuzzi)
			var marked: Array = []
			for probe in probes:
				if probe.has_meta("pool_water_reflection"): marked.append(probe)
			check(marked.size() == (1 if wanted else 0), "probe count at %s expected %d got %d" % [cell, 1 if wanted else 0, marked.size()])
			if marked.size() == 1:
				var probe: ReflectionProbe = marked[0]
				check(probe.update_mode == ReflectionProbe.UPDATE_ONCE, "probe update mode at %s" % cell)
				check(probe.box_projection, "probe box projection at %s" % cell)
				check(probe.reflection_mask == WATER_LAYER, "probe reflection mask at %s" % cell)
				check((probe.cull_mask & WATER_LAYER) == 0, "probe cull includes water at %s" % cell)
				check((probe.cull_mask & (PhotoAnomaly.PHOTO_LAYER | PhotoAnomaly.PRINT_LAYER)) == 0, "probe cull includes photo/print at %s" % cell)
	# Blackout is checked on representative wet geometry and an off-tree initial state.
	var target: Chunk = seen[wet_anchor] if seen.has(wet_anchor) else Chunk.new(ws, wet_anchor, THEME)
	if not chunks.has(target): chunks.append(target)
	var water_visible := false
	for node in target.find_children("*", "MeshInstance3D", true, false):
		if node.has_meta("pool_water_surface") or node.has_meta("pool_jacuzzi_water"): water_visible = node.visible
	target.set_blackout(true)
	check(water_visible, "water not visible before blackout")
	var water_after_blackout := false
	for node in target.find_children("*", "MeshInstance3D", true, false):
		if node.has_meta("pool_water_surface") or node.has_meta("pool_jacuzzi_water"): water_after_blackout = node.visible
	check(water_after_blackout, "water not visible during blackout")
	for probe in target.find_children("*", "ReflectionProbe", true, false):
		if probe.has_meta("pool_water_reflection"): check(is_zero_approx(probe.intensity), "blackout probe intensity not zero")
	target.set_blackout(false)
	for probe in target.find_children("*", "ReflectionProbe", true, false):
		if probe.has_meta("pool_water_reflection"): check(is_equal_approx(probe.intensity, 1.0), "restored probe intensity not one")
	var initial := Chunk.new(ws, wet_anchor, THEME, {"blackout": true})
	root.add_child(initial)
	await process_frame
	await process_frame
	var initial_probe: ReflectionProbe = null
	for probe in initial.find_children("*", "ReflectionProbe", true, false):
		if probe.has_meta("pool_water_reflection"): initial_probe = probe; break
	check(initial_probe != null and not initial_probe.visible and is_zero_approx(initial_probe.intensity), "initial blackout probe state invalid")
	initial.set_blackout(false)
	for i in 16: await process_frame
	check(initial_probe != null and initial_probe.visible and is_equal_approx(initial_probe.intensity, 1.0), "initial blackout probe did not restore")
	initial.free()
	var fountain := Mats.mall_fountain_water()
	check(fountain.shader.resource_path.ends_with("fountain_water.gdshader"), "fountain water shader mismatch")
	check(fountain != Mats.pool_water(), "fountain water material is not distinct")
	# The probe must wait for every streamed neighbour before capturing.
	var manager := FakeManager.new()
	root.add_child(manager)
	var gated_chunk := Chunk.new(ws, wet_anchor, THEME)
	manager.add_child(gated_chunk)
	var gated_probe: ReflectionProbe = null
	var placeholders: Array[Node3D] = []
	for probe in gated_chunk.find_children("*", "ReflectionProbe", true, false):
		if probe.has_meta("pool_water_reflection"): gated_probe = probe; break
	if gated_probe != null:
		var required: Array = gated_probe.required_cells
		for required_cell in required:
			var placeholder := Node3D.new()
			placeholders.append(placeholder)
			manager.chunks[required_cell] = placeholder
		var missing: Vector2i = required[0] if not required.is_empty() else wet_anchor
		manager.chunks.erase(missing)
		for i in 16: await process_frame
		check(not gated_probe.visible and not gated_probe.is_processing(), "probe captured with missing neighbour")
		var arrived := Node3D.new()
		placeholders.append(arrived)
		arrived.position = Vector3(missing.x * Chunk.S, 0, missing.y * Chunk.S)
		manager.chunks[missing] = arrived
		manager.chunk_built.emit(arrived)
		for i in 16: await process_frame
		check(gated_probe.visible and not gated_probe.is_processing(), "probe did not capture after neighbourhood completed")
	else:
		failures.append("streaming gate test could not find wet probe")
	for placeholder in placeholders:
		placeholder.free()
	gated_chunk.free()
	manager.free()
	for chunk in chunks: chunk.free()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	for failure in failures: print("FAIL " + failure)
	if failures.is_empty(): print("PASS pool water audit")
	else: quit(1); return
	quit()

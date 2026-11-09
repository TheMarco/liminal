extends SceneTree
## Pool lighting pairing contract: every direct light has a visible emitter
## with matching pair id/type. Dim chunks are explicitly allowed to have none.

const THEME := 9
const SCAN_R := 8

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_count := clampi(int(args[0]) if not args.is_empty() else 8, 1, 24)
	var failures: Array[String] = []
	var direct_count := 0
	var emit_count := 0
	var dim_count := 0
	var wet_chunk_count := 0
	var lit_chunk_count := 0
	var two_plus_light_chunk_count := 0
	var disc_count := 0
	var orb_count := 0
	for si in seed_count:
		var base := WorldGen.h(9811, si * 37, si * 61, 503) | 1
		var ws := WorldGen.level_seed(base, THEME)
		for x in range(-SCAN_R, SCAN_R + 1):
			for z in range(-SCAN_R, SCAN_R + 1):
				var cell := Vector2i(x, z)
				var style := WorldGen.cell_style(ws, cell, THEME)
				if Chunk.pool_style_dry(style):
					continue
				wet_chunk_count += 1
				var chunk := Chunk.new(ws, cell, THEME)
				var emitters := {}
				var emitting_nodes := {}
				var chunk_direct_count := 0
				for n in chunk.find_children("*", "Node", true, false):
					if n.has_meta("pool_light_emitter"):
						emit_count += 1
						var id := str(n.get_meta("pool_light_pair_id", ""))
						emitters[id] = str(n.get_meta("pool_light_type", ""))
						emitting_nodes[id] = n
						if n.get_meta("pool_light_type", "") == "ceiling_disc": disc_count += 1
						if n.get_meta("pool_light_type", "") == "porcelain_orb":
							orb_count += 1
							if n.position.y < chunk.ceil_h - 1.05:
								failures.append(
									"seed %d cell %s: porcelain orb hangs too low at %.2fm under %.2fm ceiling" % [
										si, cell, n.position.y, chunk.ceil_h])
				for n in chunk.find_children("*", "Light3D", true, false):
					if not n.has_meta("pool_direct_light"):
						continue
					direct_count += 1
					chunk_direct_count += 1
					var id := str(n.get_meta("pool_light_pair_id", ""))
					var typ := str(n.get_meta("pool_light_type", ""))
					if not emitters.has(id) or str(emitters[id]) != typ:
						failures.append("seed %d cell %s: direct light pair %s lacks matching visible %s emitter" % [si, cell, id, typ])
					elif typ == "ceiling_disc":
						var emitter: MeshInstance3D = emitting_nodes[id]
						var material: StandardMaterial3D = emitter.material_override
						var face_y: float = (emitter.transform*emitter.get_aabb()).position.y
						if not n is SpotLight3D or (-n.basis.z).dot(Vector3.DOWN)<0.999:
							failures.append("pool ceiling light must emit downward: "+id)
						if absf(n.position.y-(face_y-0.03))>0.004 or Vector2(n.position.x,n.position.z).distance_to(Vector2(emitter.position.x,emitter.position.z))>0.001:
							failures.append("pool light is not at its diffuser face: "+id)
						if not material.emission_enabled or material.emission_energy_multiplier<3.0 or material.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL:
							failures.append("pool diffuser does not visibly emit HDR light: "+id)
						GraphicsQuality.apply_practical_light(n,{"shadow_quality":0})
						if not n.shadow_enabled or n.light_energy<=0.0: failures.append("Low lost direct light or wall occlusion")
						if n.shadow_opacity != 1.0 or n.distance_fade_shadow < n.distance_fade_begin: failures.append("Low fades fixture occlusion before its light")
						GraphicsQuality.apply_practical_light(n,{"shadow_quality":3})
						if not n.shadow_enabled: failures.append("Ultra failed to restore fixture shadows")
				if bool(chunk.get_meta("pool_intentionally_dim", false)):
					dim_count += 1
				if chunk_direct_count > 0:
					lit_chunk_count += 1
				if chunk_direct_count >= 2:
					two_plus_light_chunk_count += 1
				chunk.free()
	print("pool lighting audit: %d seeds | %d wet chunks | %d lit chunks (>=1 direct) | %d chunks with >=2 direct | %d direct lights | %d emitters | %d dim chunks | %d ceiling discs | %d porcelain orbs" % [seed_count, wet_chunk_count, lit_chunk_count, two_plus_light_chunk_count, direct_count, emit_count, dim_count, disc_count, orb_count])
	if direct_count == 0 or emit_count == 0 or dim_count == 0:
		failures.append("lighting audit is inert: expected direct, emitter, and intentionally dim samples")
	if wet_chunk_count == 0 or lit_chunk_count * 100 < wet_chunk_count * 80:
		failures.append("visible-fixture lighting coverage is too low: %d/%d wet chunks lit (need >=80%%)" % [lit_chunk_count, wet_chunk_count])
	if wet_chunk_count >= 10 and two_plus_light_chunk_count * 100 < wet_chunk_count * 10:
		failures.append("denser lighting coverage is too low: only %d/%d wet chunks have >=2 direct fixtures (need >=10%%)" % [two_plus_light_chunk_count, wet_chunk_count])
	if disc_count == 0 or orb_count == 0:
		failures.append("lighting audit did not observe both ceiling discs and porcelain orbs")
	for failure in failures:
		print("  FAIL " + failure)
	if not failures.is_empty():
		quit(1)
		return
	print("  PASS — Pool direct lights are paired with visible fixtures")
	quit()

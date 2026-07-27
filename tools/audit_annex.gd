extends SceneTree
## Deterministic contract audit for the Annex (theme 2).
##
## Run:
##   godot --headless --path . --script tools/audit_annex.gd -- [seeds] [radius]
##
## The floor must stay low, yellow and mixed-scale: long narrow corridors,
## mostly human-sized rooms, rare larger chambers, selective wallpaper, sparse
## furniture hoards only in 24x24 spaces, no sewer effects, and occasional CCTV.

const DIRV := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const OPP := [1, 0, 3, 2]
const VALID_STYLES := [
	WorldGen.ANNEX_OPEN, WorldGen.ANNEX_MAZE, WorldGen.ANNEX_LONG,
	WorldGen.ANNEX_QUIET, WorldGen.ANNEX_PASSAGE, WorldGen.ANNEX_LOBBY,
]


func _walk(node: Node, report: Dictionary) -> void:
	if node is SewerSounds:
		report["legacy"] += 1
	if node is GPUParticles3D:
		report["particles"] += 1
	if node.has_meta("security_camera_mount"):
		report["cameras"] += 1
	if node.has_meta("annex_corridor_shell"):
		report["corridor_shells"] += 1
	if node.has_meta("annex_cross_corner"):
		report["cross_corners"] += 1
		if not bool(node.get_meta("annex_single_finish", false)):
			report["bad_cross_corners"] += 1
	if node.has_meta("wall_utility_kind"):
		report["wall_utilities"] += 1
		var utility_kind := str(node.get_meta("wall_utility_kind"))
		var utility_height := float(node.get_meta("wall_utility_height", -1.0))
		if utility_kind == "outlet":
			report["outlets"] += 1
			if absf(utility_height - 0.31) > 0.001:
				report["bad_utilities"] += 1
		elif utility_kind == "light_switch":
			report["switches"] += 1
			if absf(utility_height - 1.12) > 0.001:
				report["bad_utilities"] += 1
		else:
			report["bad_utilities"] += 1
		if int(node.get_meta("wall_utility_theme", -1)) != 2:
			report["bad_utilities"] += 1
	if node.has_meta("annex_ceiling_light_size"):
		report["ceiling_lights"] += 1
		if not is_equal_approx(
				float(node.get_meta("annex_ceiling_light_size")), 1.20):
			report["bad_ceiling_lights"] += 1
		if not bool(node.get_meta("annex_ceiling_light_on", false)):
			report["unlit_ceiling_fixtures"] += 1
		if float(node.get_meta("annex_ceiling_light_grid_error", INF)) > 0.001:
			report["misaligned_ceiling_lights"] += 1
	if node.has_meta("annex_wall_thickness"):
		report["wall_segments"] += 1
		if float(node.get_meta("annex_wall_thickness", 0.0)) < 0.299:
			report["thin_walls"] += 1
		if bool(node.get_meta("annex_wall_seam_safe", false)):
			report["seam_safe_wall_segments"] += 1
		if not node is MeshInstance3D \
				or not (node as MeshInstance3D).mesh is BoxMesh \
				or not bool(node.get_meta("annex_native_box", false)):
			report["unstable_wall_meshes"] += 1
	if node.has_meta("annex_partition_thickness"):
		report["partitions"] += 1
		if float(node.get_meta("annex_partition_thickness", 0.0)) < 0.299:
			report["thin_walls"] += 1
	if node.has_meta("annex_dim_zone"):
		if bool(node.get_meta("annex_dim_zone")):
			report["dim_zones"] += 1
		if bool(node.get_meta("annex_light_gap", false)):
			report["light_gaps"] += 1
			if int(node.get_meta("annex_ceiling_fixture_count", -1)) != 0:
				report["bad_light_zones"] += 1
		elif int(node.get_meta("annex_ceiling_fixture_count", 0)) <= 0:
			report["bad_light_zones"] += 1
	if node.has_meta("annex_furniture_pile"):
		report["furniture_piles"] += 1
		if int(node.get_meta("annex_room_cells", 0)) < 4:
			report["small_room_piles"] += 1
	if node.has_meta("annex_architecture"):
		report["architecture_assemblies"] += 1
	if str(node.get_meta("authored_model", "")) == "annex_dining_chair":
		report["authored_chairs"] += 1
	elif str(node.get_meta("authored_model", "")) == "annex_school_chair":
		report["authored_school_chairs"] += 1
		if bool(node.get_meta("annex_school_chair_tipped", false)):
			report["tipped_school_chairs"] += 1
	var attributed_kind := str(node.get_meta("attributed_furnishing", ""))
	if attributed_kind == "annex_shelving":
		report["authored_shelving"] += 1
	elif attributed_kind == "annex_air_conditioner":
		report["authored_ac"] += 1
	elif attributed_kind == "annex_loose_box" \
			or attributed_kind == "annex_shelf_box":
		report["authored_boxes"] += 1
		if attributed_kind == "annex_shelf_box" and node is Node3D:
			var box_y := (node as Node3D).position.y
			var contact_error := INF
			for deck_y in [0.09375, 0.69375, 1.14375]:
				contact_error = minf(contact_error, absf(box_y - deck_y))
			if contact_error > 0.002:
				report["floating_shelf_boxes"] += 1
	if node.has_meta("atomic_furnishing"):
		var kind := str(node.get_meta("atomic_furnishing"))
		report["assemblies"] += 1
		report["kinds"][kind] = int(report["kinds"].get(kind, 0)) + 1
		if not kind.begins_with("annex_"):
			report["foreign"] += 1
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mat := mi.material_override as ShaderMaterial
		if mat != null and mat.shader != null \
				and "sewer" in mat.shader.resource_path.to_lower():
			report["legacy"] += 1
	for child in node.get_children():
		_walk(child, report)


func _utility_backing_violations(chunk: Chunk) -> int:
	var walls: Array[MeshInstance3D] = []
	for candidate in chunk.find_children("*", "MeshInstance3D", true, false):
		if candidate.has_meta("annex_wall_thickness"):
			walls.append(candidate as MeshInstance3D)
	var bad := 0
	for candidate in chunk.find_children("*", "Node3D", true, false):
		if not candidate.has_meta("wall_utility_kind"):
			continue
		var mount := candidate as Node3D
		var backed := false
		for wall in walls:
			var half := wall.scale.abs() * 0.5
			var delta := (mount.position - wall.position).abs()
			if delta.x <= half.x + 0.035 \
					and delta.y <= half.y + 0.035 \
					and delta.z <= half.z + 0.035:
				backed = true
				break
		if not backed:
			bad += 1
	return bad


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_count := clampi(int(args[0]) if args.size() > 0 else 18, 1, 32)
	var radius := clampi(int(args[1]) if args.size() > 1 else 12, 4, 18)
	var failures: Array[String] = []
	var style_counts := {}
	var finish_counts := {}
	var wall_finish_counts := {}
	var corridor_cells := 0
	var room_cells := 0
	var large_rooms := 0
	var furniture_pile_roots := 0
	var dim_cells := 0
	var light_gap_cells := 0
	var room_roots := 0
	var room_sizes := {1: 0, 2: 0, 3: 0, 4: 0}
	var open_edges := 0
	var corridor_widths := {34: 0, 48: 0, 64: 0}
	for style in VALID_STYLES:
		style_counts[style] = 0
	for finish in 5:
		finish_counts[finish] = 0
		wall_finish_counts[finish] = 0
	var checked := 0

	for si in seed_count:
		var base_seed := 4243 + si * 7919
		var ws := WorldGen.level_seed(base_seed, 2)
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				var cell := Vector2i(x, z)
				var style := WorldGen.cell_style(ws, cell, 2)
				if WorldGen.annex_dim_zone(ws, cell):
					dim_cells += 1
					if WorldGen.annex_light_gap(ws, cell):
						light_gap_cells += 1
				checked += 1
				style_counts[style] = int(style_counts.get(style, 0)) + 1
				var finish := WorldGen.finish_variant(ws, cell, 2)
				finish_counts[finish] = int(finish_counts.get(finish, 0)) + 1
				if not VALID_STYLES.has(style):
					failures.append("foreign style seed=%d cell=%s style=%d" % [
						base_seed, cell, style])
				var root := WorldGen.annex_room_id(ws, cell)
				var axis := WorldGen.annex_corridor_axis(ws, cell)
				if axis != 0:
					corridor_cells += 1
					if axis == 1 or axis == 3:
						var hw := int(roundf(
							WorldGen.annex_horizontal_width(ws, cell.y) * 10.0))
						corridor_widths[hw] = int(corridor_widths.get(hw, 0)) + 1
					if axis == 2 or axis == 3:
						var vw := int(roundf(
							WorldGen.annex_vertical_width(ws, cell.x) * 10.0))
						corridor_widths[vw] = int(corridor_widths.get(vw, 0)) + 1
					if style != WorldGen.ANNEX_PASSAGE:
						failures.append("corridor cell has room style seed=%d cell=%s style=%d" % [
							base_seed, cell, style])
				else:
					room_cells += 1
					if root == cell:
						room_roots += 1
						var room_size := WorldGen.annex_room_size(ws, root)
						room_sizes[room_size] = int(room_sizes.get(room_size, 0)) + 1
						if room_size > 4:
							failures.append("oversized Annex room seed=%d root=%s size=%d" % [
								base_seed, root, room_size])
						if room_size >= 4:
							large_rooms += 1
							if WorldGen.annex_furniture_pile(ws, root):
								furniture_pile_roots += 1
				var h := WorldGen.room_height(ws, root, 2)
				if h < 2.70 or h > 2.90:
					failures.append("ceiling outside Annex band seed=%d cell=%s h=%.2f" % [
						base_seed, cell, h])
				for dir in 4:
					var nb: Vector2i = cell + DIRV[dir]
					var edge := WorldGen.edge_info(ws, cell, dir, 2)
					var reverse := WorldGen.edge_info(ws, nb, OPP[dir], 2)
					var wall_finish := WorldGen.annex_wall_finish(ws, cell, dir)
					var reverse_finish := WorldGen.annex_wall_finish(
						ws, nb, OPP[dir])
					wall_finish_counts[wall_finish] = int(
						wall_finish_counts.get(wall_finish, 0)) + 1
					if wall_finish != reverse_finish:
						failures.append(
							"shared Annex wall changes finish seed=%d cell=%s dir=%d %d!=%d" % [
								base_seed, cell, dir, wall_finish, reverse_finish])
					if edge["wall"] != reverse["wall"] \
							or edge["full_open"] != reverse["full_open"]:
						failures.append("asymmetric Annex edge seed=%d cell=%s dir=%d" % [
							base_seed, cell, dir])
					if not edge["wall"]:
						open_edges += 1
				if axis == 1 or axis == 3:
					for dir in [0, 1]:
						if WorldGen.edge_info(ws, cell, dir, 2)["wall"]:
							failures.append("horizontal Annex corridor interrupted seed=%d cell=%s dir=%d" % [
								base_seed, cell, dir])
				if axis == 2 or axis == 3:
					for dir in [2, 3]:
						if WorldGen.edge_info(ws, cell, dir, 2)["wall"]:
							failures.append("vertical Annex corridor interrupted seed=%d cell=%s dir=%d" % [
								base_seed, cell, dir])
				if failures.size() >= 20:
					break
			if failures.size() >= 20:
				break
		if failures.size() >= 20:
			break

	for style in VALID_STYLES:
		if int(style_counts.get(style, 0)) == 0:
			failures.append("Annex style never generated: %d" % style)
	for wallpaper in [3, 4]:
		if int(finish_counts.get(wallpaper, 0)) == 0:
			failures.append("wallpaper finish never generated: %d" % wallpaper)
		if int(wall_finish_counts.get(wallpaper, 0)) == 0:
			failures.append("wall-line wallpaper finish never generated: %d" % wallpaper)
	var plain_ratio := float(int(finish_counts[0]) + int(finish_counts[1]) \
		+ int(finish_counts[2])) / float(maxi(checked, 1))
	if plain_ratio < 0.60 or plain_ratio > 0.72:
		failures.append("plain-wall ratio outside intended majority: %.3f" % plain_ratio)
	if WorldGen.finish_variant(WorldGen.level_seed(4242, 2), Vector2i.ZERO, 2) < 3:
		failures.append("arrival junction does not visibly demonstrate supplied wallpaper")
	var corridor_ratio := float(corridor_cells) / float(maxi(checked, 1))
	if corridor_ratio < 0.26 or corridor_ratio > 0.40:
		failures.append("corridor share outside mixed-scale contract: %.3f" % corridor_ratio)
	var large_room_ratio := float(large_rooms) / float(maxi(room_roots, 1))
	if large_room_ratio < 0.04:
		failures.append("large rooms too rare for width contrast: %.3f" % large_room_ratio)
	if large_room_ratio > 0.18:
		failures.append("large rooms too common: %.3f" % large_room_ratio)
	var furniture_pile_ratio := float(furniture_pile_roots) / float(
		maxi(large_rooms, 1))
	if furniture_pile_ratio < 0.06:
		failures.append("large-room furniture piles too rare: %.3f" % [
			furniture_pile_ratio])
	if furniture_pile_ratio > 0.20:
		failures.append("large-room furniture piles too common: %.3f" % [
			furniture_pile_ratio])
	var dim_ratio := float(dim_cells) / float(maxi(checked, 1))
	var light_gap_ratio := float(light_gap_cells) / float(maxi(checked, 1))
	if dim_ratio < 0.12 or dim_ratio > 0.30:
		failures.append("dim-zone ratio outside intended range: %.3f" % dim_ratio)
	if light_gap_ratio < 0.02 or light_gap_ratio > 0.10:
		failures.append("fixture-free gap ratio outside intended range: %.3f" % [
			light_gap_ratio])
	for width_key in [34, 48, 64]:
		if int(corridor_widths.get(width_key, 0)) == 0:
			failures.append("Annex passage width never generated: %.1fm" % [
				float(width_key) / 10.0])
	if not ResourceLoader.exists("res://sounds/ambient-annex.mp3"):
		failures.append("Annex ambient loop is missing")
	elif not Sfx.has_bed(2):
		failures.append("Annex ambient loop is not registered as its room bed")
	else:
		var annex_bed := Sfx.bed(2)
		if annex_bed.is_empty() or not (annex_bed[0] is AudioStreamMP3) \
				or not (annex_bed[0] as AudioStreamMP3).loop:
			failures.append("Annex ambient recording is not configured to loop")
	var main_script := load("res://scripts/main.gd")
	var main_node: Node = main_script.new()
	main_node.set("descent", true)
	if main_node.call("_music_track_for", 2) != "":
		failures.append("Annex still selects a music track")
	main_node.free()

	# Runtime construction is more expensive than pure topology, so exercise a
	# compact but multi-seed window. It still builds hundreds of complete rooms.
	var runtime := {
		"legacy": 0, "particles": 0, "cameras": 0,
		"assemblies": 0, "architecture_assemblies": 0,
		"foreign": 0, "corridor_shells": 0,
		"cross_corners": 0, "bad_cross_corners": 0,
		"wall_utilities": 0, "outlets": 0, "switches": 0,
		"bad_utilities": 0, "floating_utilities": 0,
		"authored_chairs": 0, "authored_shelving": 0,
		"authored_school_chairs": 0, "tipped_school_chairs": 0,
		"authored_boxes": 0, "floating_shelf_boxes": 0, "authored_ac": 0,
		"ceiling_lights": 0, "bad_ceiling_lights": 0,
		"unlit_ceiling_fixtures": 0, "misaligned_ceiling_lights": 0,
		"fixture_architecture_intersections": 0,
		"wall_segments": 0, "seam_safe_wall_segments": 0,
		"unstable_wall_meshes": 0,
		"partitions": 0, "thin_walls": 0,
		"dim_zones": 0, "light_gaps": 0,
		"bad_light_zones": 0,
		"furniture_piles": 0, "small_room_piles": 0,
		"kinds": {},
	}
	var runtime_chunks := 0
	for si in mini(seed_count, 4):
		var ws := WorldGen.level_seed(4243 + si * 7919, 2)
		for x in range(-4, 5):
			for z in range(-4, 5):
				var chunk := Chunk.new(ws, Vector2i(x, z), 2)
				runtime_chunks += 1
				_walk(chunk, runtime)
				var door_bad := chunk.doorway_clearance_violations()
				if door_bad > 0:
					failures.append("doorway obstruction seed=%d cell=%s count=%d" % [
						si, Vector2i(x, z), door_bad])
				var support_bad := chunk.atomic_furnishing_support_violations()
				if support_bad > 0:
					failures.append("floating/orphaned Annex furnishing seed=%d cell=%s count=%d" % [
						si, Vector2i(x, z), support_bad])
				runtime["fixture_architecture_intersections"] += \
					chunk.annex_fixture_obstruction_violations()
				runtime["floating_utilities"] += \
					_utility_backing_violations(chunk)
				chunk.free()

	if int(runtime["legacy"]) > 0:
		failures.append("legacy sewer nodes/materials generated: %d" % runtime["legacy"])
	if int(runtime["particles"]) > 0:
		failures.append("particle effects generated in minimalist Annex: %d" % runtime["particles"])
	if int(runtime["foreign"]) > 0:
		failures.append("foreign prop assemblies generated: %d" % runtime["foreign"])
	if int(runtime["cameras"]) == 0:
		failures.append("no surveillance cameras generated")
	var camera_density := float(runtime["cameras"]) / float(maxi(runtime_chunks, 1))
	if camera_density > 0.32:
		failures.append("surveillance cameras too dense: %.3f/chunk" % camera_density)
	var architecture_density := float(runtime["architecture_assemblies"]) \
		/ float(maxi(runtime_chunks, 1))
	if architecture_density < 0.12:
		failures.append("interior architecture too sparse: %.3f/chunk" % architecture_density)
	if architecture_density > 0.55:
		failures.append("interior architecture too dense: %.3f/chunk" % architecture_density)
	for required_kind in ["annex_column", "annex_half_wall", "annex_wall_mass"]:
		if int(runtime["kinds"].get(required_kind, 0)) == 0:
			failures.append("reference architecture never generated: %s" % required_kind)
	if int(runtime["corridor_shells"]) == 0:
		failures.append("no physical narrow corridor shells generated")
	if int(runtime["cross_corners"]) == 0:
		failures.append("cross-corridor solid corners were not exercised")
	if int(runtime["bad_cross_corners"]) > 0:
		failures.append("cross-corridor corners still split wall finishes: %d" % [
			runtime["bad_cross_corners"]])
	if int(runtime["outlets"]) == 0 or int(runtime["switches"]) == 0:
		failures.append("Annex outlets/switches were not both generated")
	if int(runtime["bad_utilities"]) > 0:
		failures.append("Annex wall utilities have invalid theme/height metadata: %d" % [
			runtime["bad_utilities"]])
	if int(runtime["floating_utilities"]) > 0:
		failures.append("Annex utilities lack a wall in their own streamed chunk: %d" % [
			runtime["floating_utilities"]])
	var utility_density := float(runtime["wall_utilities"]) \
		/ float(maxi(runtime_chunks, 1))
	if utility_density > 1.35:
		failures.append("Annex wall utilities are too dense: %.3f/chunk" % [
			utility_density])
	if int(runtime["authored_chairs"]) == 0 \
			or int(runtime["authored_school_chairs"]) == 0 \
			or int(runtime["tipped_school_chairs"]) == 0 \
			or int(runtime["authored_shelving"]) == 0 \
			or int(runtime["authored_boxes"]) == 0 \
			or int(runtime["authored_ac"]) == 0:
		failures.append(
			"Annex authored dressing sample incomplete wood=%d school=%d tipped=%d shelves=%d boxes=%d ac=%d" % [
				runtime["authored_chairs"], runtime["authored_school_chairs"],
				runtime["tipped_school_chairs"], runtime["authored_shelving"],
				runtime["authored_boxes"], runtime["authored_ac"]])
	if int(runtime["floating_shelf_boxes"]) > 0:
		failures.append("Annex shelf boxes do not rest on measured decks: %d" % [
			runtime["floating_shelf_boxes"]])
	if int(runtime["ceiling_lights"]) == 0:
		failures.append("no tile-sized Annex ceiling lights generated")
	if int(runtime["bad_ceiling_lights"]) > 0:
		failures.append("Annex ceiling lights do not match one 1.20m tile: %d" % [
			runtime["bad_ceiling_lights"]])
	if int(runtime["unlit_ceiling_fixtures"]) > 0:
		failures.append("visible Annex fixtures are switched off: %d" % [
			runtime["unlit_ceiling_fixtures"]])
	if int(runtime["misaligned_ceiling_lights"]) > 0:
		failures.append("Annex fixtures are not centered in ceiling tiles: %d" % [
			runtime["misaligned_ceiling_lights"]])
	if int(runtime["fixture_architecture_intersections"]) > 0:
		failures.append("Annex fixtures intersect full-height architecture: %d" % [
			runtime["fixture_architecture_intersections"]])
	if int(runtime["wall_segments"]) == 0 or int(runtime["partitions"]) == 0:
		failures.append("Annex wall-thickness contract was not exercised")
	if int(runtime["thin_walls"]) > 0:
		failures.append("Annex still generated paper-thin wall sections: %d" % [
			runtime["thin_walls"]])
	if int(runtime["seam_safe_wall_segments"]) != int(runtime["wall_segments"]):
		failures.append("Annex wall runs still use capped or overlapping chunk seams")
	if int(runtime["unstable_wall_meshes"]) > 0:
		failures.append("Annex wall runs use a non-native render mesh: %d" % [
			runtime["unstable_wall_meshes"]])
	if int(runtime["dim_zones"]) == 0 or int(runtime["light_gaps"]) == 0:
		failures.append("runtime sample has no deliberate low-light areas")
	if int(runtime["bad_light_zones"]) > 0:
		failures.append("Annex sparse-light zoning is inconsistent: %d" % [
			runtime["bad_light_zones"]])
	if int(runtime["small_room_piles"]) > 0:
		failures.append("furniture pile generated outside a 24x24 room: %d" % [
			runtime["small_room_piles"]])

	print("Annex audit: %d seeds, radius %d, %d topology cells" % [
		seed_count, radius, checked])
	print("  styles open/maze/long/quiet/passage/lobby: %s" % [[
		style_counts[WorldGen.ANNEX_OPEN], style_counts[WorldGen.ANNEX_MAZE],
		style_counts[WorldGen.ANNEX_LONG], style_counts[WorldGen.ANNEX_QUIET],
		style_counts[WorldGen.ANNEX_PASSAGE], style_counts[WorldGen.ANNEX_LOBBY]]])
	print("  plain wall ratio: %.3f | room finishes: %s | wall-line finishes: %s" % [
		plain_ratio, finish_counts, wall_finish_counts])
	print("  mixed scale: %d corridors / %d rooms | widths %s | room sizes %s | large-room ratio %.3f | pile ratio %.3f (%d roots) | dim %.3f / gaps %.3f | %d open edges" % [
		corridor_cells, room_cells, corridor_widths, room_sizes,
		large_room_ratio, furniture_pile_ratio, furniture_pile_roots,
		dim_ratio, light_gap_ratio, open_edges])
	print("  runtime: %d chunks | %d corridor shells / %d solid corners | %d full-tile lights | %d dim zones / %d gaps | %d cameras | utilities %d (%d outlets/%d switches) | props chairs=%d+%d (%d tipped) shelves=%d boxes=%d ac=%d | %d furniture piles | %d wall segments / %d partitions | %d architecture assemblies %s" % [
		runtime_chunks, runtime["corridor_shells"], runtime["cross_corners"],
		runtime["ceiling_lights"],
		runtime["dim_zones"], runtime["light_gaps"], runtime["cameras"],
		runtime["wall_utilities"], runtime["outlets"], runtime["switches"],
		runtime["authored_chairs"], runtime["authored_school_chairs"],
		runtime["tipped_school_chairs"], runtime["authored_shelving"],
		runtime["authored_boxes"], runtime["authored_ac"],
		runtime["furniture_piles"], runtime["wall_segments"], runtime["partitions"],
		runtime["architecture_assemblies"], runtime["kinds"]])
	if failures.is_empty():
		print("  PASS — full-tile unobstructed fixtures, substantial seamless walls, deliberate dim zones, warm-yellow rooms, ambient-only audio, rare furniture piles, sparse CCTV")
		quit(0)
		return
	for failure in failures.slice(0, 20):
		push_error(failure)
	print("  FAIL — %d Annex contract violations" % failures.size())
	quit(1)

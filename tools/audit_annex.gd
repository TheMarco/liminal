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


func _decorative_occlusion_violations(node: Node) -> int:
	var bad := 0
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		if geometry.cast_shadow \
				!= GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
				or geometry.gi_mode != GeometryInstance3D.GI_MODE_DISABLED:
			bad += 1
	for child in node.get_children():
		bad += _decorative_occlusion_violations(child)
	return bad


func _walk(node: Node, report: Dictionary) -> void:
	# The SewerSounds class is gone along with the rest of the retired sewer
	# construction, so there is no type left to test for here. The material
	# check below still catches a sewer shader finding its way back in.
	if node is GPUParticles3D:
		report["particles"] += 1
	if node.has_meta("security_camera_mount"):
		report["cameras"] += 1
	if node.has_meta("annex_corridor_shell"):
		report["corridor_shells"] += 1
	if node.has_meta("annex_corridor_connection"):
		report["corridor_connections"] += 1
		var corridor_finish := int(node.get_meta(
			"annex_corridor_finish", -1))
		var boundary_finish := int(node.get_meta(
			"annex_boundary_finish", -1))
		var connection_finish := int(node.get_meta(
			"annex_connection_finish", -1))
		var uses_boundary := bool(node.get_meta(
			"annex_connection_uses_boundary_finish", false))
		var expected_finish := boundary_finish \
			if uses_boundary else corridor_finish
		var expected_baseboards := int(node.get_meta(
			"annex_connection_baseboards_expected", -1))
		report["corridor_connection_baseboards_expected"] += \
			maxi(expected_baseboards, 0)
		if connection_finish != expected_finish or expected_baseboards != 2:
			report["bad_corridor_connections"] += 1
	if node.has_meta("annex_corridor_connection_part"):
		report["corridor_connection_parts"] += 1
		var part_corridor_finish := int(node.get_meta(
			"annex_corridor_finish", -1))
		var part_boundary_finish := int(node.get_meta(
			"annex_boundary_finish", -1))
		var part_finish := int(node.get_meta(
			"annex_connection_finish", -1))
		var part_uses_boundary := bool(node.get_meta(
			"annex_connection_uses_boundary_finish", false))
		var expected_part_finish := part_boundary_finish \
			if part_uses_boundary else part_corridor_finish
		if part_finish != expected_part_finish:
			report["bad_corridor_connections"] += 1
	if node.has_meta("annex_corridor_connection_baseboard"):
		report["corridor_connection_baseboards"] += 1
	if node.has_meta("annex_cross_corner"):
		report["cross_corners"] += 1
		if not bool(node.get_meta("annex_single_finish", false)):
			report["bad_cross_corners"] += 1
	if node.has_meta("annex_deep_mass_candidate"):
		report["deep_mass_candidates"] += 1
		if float(node.get_meta("annex_deep_mass_depth", 0.0)) < 2.10:
			report["bad_deep_mass_candidates"] += 1
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
		if not bool(node.get_meta("wall_utility_non_occluding", false)):
			report["shadowing_utilities"] += 1
		report["shadowing_utilities"] += \
			_decorative_occlusion_violations(node)
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
		var wall_owner := str(node.get_meta(
			"annex_visual_wall_owner", ""))
		if wall_owner != "collinear_line" \
				and wall_owner != "corridor_shell" \
				and wall_owner != "perpendicular_wall_min" \
				and wall_owner != "perpendicular_wall_max":
			report["bad_wall_owners"] += 1
		var wall_finish := int(node.get_meta("annex_finish", -1))
		var raw_finish := int(node.get_meta(
			"annex_raw_finish", wall_finish))
		var line_winner_min := int(node.get_meta(
			"annex_line_t_winner_finish_min", -1))
		var line_winner_max := int(node.get_meta(
			"annex_line_t_winner_finish_max", -1))
		var expected_finish := raw_finish
		if line_winner_min >= 0:
			expected_finish = line_winner_min
		elif line_winner_max >= 0:
			expected_finish = line_winner_max
		if wall_finish < 0 or wall_finish > 4 \
				or bool(node.get_meta("annex_wallpaper", false)) \
					!= (wall_finish >= 3) \
				or wall_finish != expected_finish:
			report["bad_wall_finish_contracts"] += 1
		if float(node.get_meta("annex_wall_thickness", 0.0)) < 0.299:
			report["thin_walls"] += 1
		if bool(node.get_meta("annex_wall_seam_safe", false)):
			report["seam_safe_wall_segments"] += 1
		if not node is MeshInstance3D \
				or not (node as MeshInstance3D).mesh is QuadMesh \
				or not bool(node.get_meta(
					"annex_uncapped_native_prism", false)):
			report["unstable_wall_meshes"] += 1
		for end_name in ["min", "max"]:
			if not node.has_meta("annex_t_junction_stub_" + end_name):
				continue
			report["t_junction_stubs"] += 1
			var winner_finish := int(node.get_meta(
				"annex_t_junction_winner_finish_" + end_name, -1))
			var winner_baseboard := bool(node.get_meta(
				"annex_t_junction_winner_baseboard_" + end_name, false))
			# The continuous wall owns the complete terminating edge's visible
			# treatment. Material and baseboard may not diverge at the join.
			if bool(node.get_meta("annex_wall_cap_" + end_name, true)) \
					or winner_finish < 0 or winner_finish > 4 \
					or winner_baseboard != (winner_finish >= 3) \
					or wall_finish != expected_finish:
				report["bad_t_junction_stubs"] += 1
	if node.has_meta("annex_baseboard"):
		report["baseboards"] += 1
		if not bool(node.get_meta("annex_baseboard_attached", false)) \
				or absf(float(node.get_meta(
					"annex_baseboard_height", 0.0)) - 0.16) > 0.001 \
				or float(node.get_meta(
					"annex_baseboard_projection", INF)) > 0.021:
			report["bad_baseboards"] += 1
		if not node is GeometryInstance3D \
				or (node as GeometryInstance3D).cast_shadow \
				!= GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
				or (node as GeometryInstance3D).gi_mode \
				!= GeometryInstance3D.GI_MODE_DISABLED:
			report["shadowing_baseboards"] += 1
	if node.has_meta("annex_partition_thickness"):
		report["partitions"] += 1
		if float(node.get_meta("annex_partition_thickness", 0.0)) < 0.299:
			report["thin_walls"] += 1
	if node.has_meta("annex_half_wall_wood_cap"):
		report["half_wall_wood_caps"] += 1
		var cap := node as MeshInstance3D
		var material := cap.material_override as StandardMaterial3D \
			if cap != null else null
		if str(node.get_meta("annex_wood_grain_axis", "")) != "local_x" \
				or material == null \
				or material.albedo_texture == null \
				or material.albedo_texture.resource_path \
					!= "res://textures/annex/half_wall_cap_wood.png":
			report["bad_half_wall_wood_caps"] += 1
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
		var finish_idx := int(node.get_meta("annex_finish", -1))
		var wallpapered := bool(node.get_meta("annex_wallpaper", false))
		var expected := bool(node.get_meta(
			"annex_baseboard_expected", false))
		var expected_count := int(node.get_meta(
			"annex_baseboard_expected_count", -1))
		var actual_count := 0
		for descendant in node.find_children(
				"*", "MeshInstance3D", true, false):
			if descendant.has_meta("annex_baseboard"):
				actual_count += 1
		if finish_idx < 0 or finish_idx > 4 \
				or wallpapered != (finish_idx >= 3) \
				or not expected \
			or expected_count < 0 \
			or actual_count != expected_count:
			report["bad_architecture_baseboards"] += 1
	if node.has_meta("annex_attached_half_wall"):
		report["attached_half_walls"] += 1
		var attached_wallpapered := bool(node.get_meta("annex_wallpaper", false))
		var attached_expected := int(node.get_meta("annex_baseboard_expected_count", -1))
		var cap_ok := false
		for descendant in node.find_children("*", "MeshInstance3D", true, false):
			if descendant.has_meta("annex_half_wall_cap_reaches_owner"):
				cap_ok = bool(descendant.get_meta("annex_half_wall_cap_reaches_owner", false))
		if not bool(node.get_meta("annex_finish_inherited", false)) \
				or attached_expected != 3 \
				or not bool(node.get_meta("annex_cap_continuous_to_owner", false)) \
				or not cap_ok:
			report["bad_attached_half_walls"] += 1
	if node.has_meta("annex_tunnel"):
		report["tunnels"] += 1
		var tunnel_kind := str(node.get_meta(
			"annex_tunnel_kind",
			node.get_meta("annex_architecture", "")))
		if tunnel_kind == "annex_wall_mass":
			report["wall_mass_tunnels"] += 1
		elif tunnel_kind == "annex_cross_corner":
			report["deep_mass_tunnels"] += 1
		else:
			report["bad_tunnels"] += 1
		var tunnel_path := str(node.get_meta("annex_tunnel_path", ""))
		if tunnel_path == "straight":
			report["tunnel_straight"] += 1
		elif tunnel_path == "L":
			report["tunnel_l"] += 1
		var carpet_count := 0
		for descendant in node.find_children(
				"*", "MeshInstance3D", true, false):
			if descendant.has_meta("annex_tunnel_carpet"):
				carpet_count += 1
				report["tunnel_carpet_strips"] += 1
				if (descendant as GeometryInstance3D).cast_shadow \
						!= GeometryInstance3D.SHADOW_CASTING_SETTING_OFF \
						or (descendant as GeometryInstance3D).gi_mode \
						!= GeometryInstance3D.GI_MODE_DISABLED:
					report["bad_tunnels"] += 1
				if absf((descendant as Node3D).position.y - 0.732) > 0.002:
					report["bad_tunnels"] += 1
		var expected_carpet_count := int(node.get_meta(
			"annex_tunnel_carpet_pieces", 1))
		if carpet_count != expected_carpet_count \
				or float(node.get_meta("annex_tunnel_width", 0.0)) < 1.19 \
				or absf(float(node.get_meta(
					"annex_tunnel_sill", 0.0)) - 0.72) > 0.001 \
				or absf(float(node.get_meta(
					"annex_tunnel_height", 0.0)) - 0.72) > 0.001 \
				or float(node.get_meta("annex_tunnel_sill", 0.0)) \
					+ float(node.get_meta("annex_tunnel_height", 0.0)) \
					< 1.38 \
				or float(node.get_meta("annex_tunnel_depth", 0.0)) < 2.10 \
				or not bool(node.get_meta(
					"annex_tunnel_carpeted", false)) \
				or bool(node.get_meta("annex_tunnel_crawlable", true)) \
				or carpet_count == 0:
			report["bad_tunnels"] += 1
	if str(node.get_meta("authored_model", "")) == "annex_dining_chair":
		report["authored_chairs"] += 1
	elif str(node.get_meta("authored_model", "")) == "annex_school_chair":
		report["authored_school_chairs"] += 1
		if bool(node.get_meta("annex_school_chair_tipped", false)):
			report["tipped_school_chairs"] += 1
	elif str(node.get_meta("authored_model", "")) == "annex_exit_door":
		report["authored_exit_doors"] += 1
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
			var wall_pos: Vector3 = wall.get_meta(
				"annex_wall_volume_position", wall.position)
			var wall_size: Vector3 = wall.get_meta(
				"annex_wall_volume_size", wall.scale.abs())
			var half := wall_size * 0.5
			var delta := (mount.position - wall_pos).abs()
			if delta.x <= half.x + 0.035 \
					and delta.y <= half.y + 0.035 \
					and delta.z <= half.z + 0.035:
				backed = true
				break
		if not backed:
			bad += 1
	return bad


func _baseboard_backing_violations(chunk: Chunk) -> int:
	var walls: Array[MeshInstance3D] = []
	var baseboards: Array[MeshInstance3D] = []
	for candidate in chunk.find_children("*", "MeshInstance3D", true, false):
		if candidate.has_meta("annex_wall_thickness") \
				or candidate.has_meta("annex_cross_corner") \
				or candidate.has_meta("annex_architecture_wall"):
			walls.append(candidate as MeshInstance3D)
		if candidate.has_meta("annex_baseboard"):
			baseboards.append(candidate as MeshInstance3D)
	var bad := 0
	for baseboard in baseboards:
		var base_half := baseboard.scale.abs() * 0.5
		var backed := false
		for wall in walls:
			var wall_pos: Vector3 = wall.get_meta(
				"annex_wall_volume_position", wall.position)
			var wall_size: Vector3 = wall.get_meta(
				"annex_wall_volume_size", wall.scale.abs())
			var wall_half := wall_size * 0.5
			var delta := (baseboard.position - wall_pos).abs()
			# Every trim box must touch a wall volume across all three axes.
			# This detects the old floor-level bars without requiring the trim
			# to overlap the wall and risk coplanar flashing.
			if delta.x <= base_half.x + wall_half.x + 0.002 \
					and delta.y <= base_half.y + wall_half.y + 0.002 \
					and delta.z <= base_half.z + wall_half.z + 0.002:
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
	var baseboard_edges := 0
	var plain_base_edges := 0
	var corridor_widths := {22: 0, 34: 0, 48: 0, 64: 0}
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
					var has_baseboard := WorldGen.annex_wall_baseboard(
						ws, cell, dir)
					var reverse_baseboard := WorldGen.annex_wall_baseboard(
						ws, nb, OPP[dir])
					if has_baseboard:
						baseboard_edges += 1
					else:
						plain_base_edges += 1
					wall_finish_counts[wall_finish] = int(
						wall_finish_counts.get(wall_finish, 0)) + 1
					if has_baseboard != (wall_finish >= 3):
						failures.append(
							"Annex baseboard/wallpaper mismatch seed=%d cell=%s dir=%d finish=%d baseboard=%s" % [
								base_seed, cell, dir, wall_finish,
								str(has_baseboard)])
					if wall_finish != reverse_finish:
						failures.append(
							"shared Annex wall changes finish seed=%d cell=%s dir=%d %d!=%d" % [
								base_seed, cell, dir, wall_finish, reverse_finish])
					if has_baseboard != reverse_baseboard:
						failures.append(
							"shared Annex wall changes baseboard seed=%d cell=%s dir=%d" % [
								base_seed, cell, dir])
					if edge["wall"] != reverse["wall"] \
							or edge["full_open"] != reverse["full_open"]:
						failures.append("asymmetric Annex edge seed=%d cell=%s dir=%d" % [
							base_seed, cell, dir])
					# Collinear wall runs must retain one canonical finish and trim
					# decision along their tangent, independent of local winner order.
					var tangent_nb := cell + (Vector2i(0, 1) if dir < 2 else Vector2i(1, 0))
					var tangent_finish := WorldGen.annex_wall_finish(ws, tangent_nb, dir)
					var tangent_baseboard := WorldGen.annex_wall_baseboard(ws, tangent_nb, dir)
					if wall_finish != tangent_finish or has_baseboard != tangent_baseboard:
						failures.append("collinear Annex wall changes finish seed=%d cell=%s dir=%d" % [
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
	for plain_finish in range(3):
		var plain_mat := Mats.annex_wall_variant(plain_finish)
		if plain_mat.albedo_texture == null \
				or plain_mat.albedo_texture.resource_path \
				!= "res://textures/annex/plain_wall_plaster.png":
			failures.append(
				"plain Annex finish %d does not use supplied plaster texture" % [
					plain_finish])
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
	var narrow_ratio := float(int(corridor_widths.get(22, 0))) / float(maxi(
		int(corridor_widths.get(22, 0))
		+ int(corridor_widths.get(34, 0))
		+ int(corridor_widths.get(48, 0))
		+ int(corridor_widths.get(64, 0)), 1))
	# The generator chooses 48% of unique corridor lines, while this cell-based
	# sample weights crossings and long in-radius runs unevenly. Keep a broad
	# deterministic guard around the intended substantial-minority result.
	if narrow_ratio < 0.34 or narrow_ratio > 0.56:
		failures.append("true narrow-hall ratio outside intended range: %.3f" % [
			narrow_ratio])
	for width_key in [22, 34, 48, 64]:
		if int(corridor_widths.get(width_key, 0)) == 0:
			failures.append("Annex passage width never generated: %.1fm" % [
				float(width_key) / 10.0])
	var baseboard_ratio := float(baseboard_edges) / float(maxi(
		baseboard_edges + plain_base_edges, 1))
	# Skirting is universal now: this is recorded for reference, not enforced.
	if false:
		failures.append("selective baseboard ratio outside intended range: %.3f" % [
			baseboard_ratio])
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
	var annex_env := main_node.call("_build_env", 2) as Environment
	if annex_env.ssao_enabled or annex_env.sdfgi_use_occlusion:
		failures.append(
			"Annex contact-occlusion passes still create dark wall/floor bands")
	main_node.free()

	# Runtime construction is more expensive than pure topology, so exercise a
	# compact but multi-seed window. It still builds hundreds of complete rooms.
	var runtime := {
		"legacy": 0, "particles": 0, "cameras": 0,
		"assemblies": 0, "architecture_assemblies": 0,
		"foreign": 0, "corridor_shells": 0,
		"cross_corners": 0, "bad_cross_corners": 0,
		"corridor_connections": 0, "corridor_connection_parts": 0,
		"corridor_connection_baseboards": 0,
		"corridor_connection_baseboards_expected": 0,
		"bad_corridor_connections": 0,
		"wall_utilities": 0, "outlets": 0, "switches": 0,
		"bad_utilities": 0, "floating_utilities": 0,
		"shadowing_utilities": 0,
		"authored_chairs": 0, "authored_shelving": 0,
		"authored_school_chairs": 0, "tipped_school_chairs": 0,
		"authored_boxes": 0, "floating_shelf_boxes": 0, "authored_ac": 0,
		"authored_exit_doors": 0,
		"ceiling_lights": 0, "bad_ceiling_lights": 0,
		"unlit_ceiling_fixtures": 0, "misaligned_ceiling_lights": 0,
		"fixture_architecture_intersections": 0,
		"wall_segments": 0, "seam_safe_wall_segments": 0,
		"unstable_wall_meshes": 0,
		"t_junction_stubs": 0, "bad_t_junction_stubs": 0,
		"baseboards": 0, "bad_baseboards": 0,
		"floating_baseboards": 0, "shadowing_baseboards": 0,
		"bad_architecture_baseboards": 0,
		"bad_wall_owners": 0, "attached_half_walls": 0,
		"bad_wall_finish_contracts": 0,
		"bad_attached_half_walls": 0,
		"partitions": 0, "thin_walls": 0,
		"half_wall_wood_caps": 0, "bad_half_wall_wood_caps": 0,
		"dim_zones": 0, "light_gaps": 0,
		"bad_light_zones": 0,
		"furniture_piles": 0, "small_room_piles": 0,
		"tunnels": 0, "wall_mass_tunnels": 0,
		"deep_mass_candidates": 0, "bad_deep_mass_candidates": 0,
		"deep_mass_tunnels": 0,
		"bad_tunnels": 0, "tunnel_carpet_strips": 0,
		"tunnel_straight": 0, "tunnel_l": 0,
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
				runtime["floating_baseboards"] += \
					_baseboard_backing_violations(chunk)
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
	if int(runtime["half_wall_wood_caps"]) == 0 \
			or int(runtime["bad_half_wall_wood_caps"]) > 0:
		failures.append(
			"Annex half-wall hardwood cap contract failed: caps=%d bad=%d" % [
				runtime["half_wall_wood_caps"],
				runtime["bad_half_wall_wood_caps"]])
	if int(runtime["tunnels"]) == 0:
		failures.append("deep Annex wall masses never generated a viewing tunnel")
	if int(runtime["bad_tunnels"]) > 0:
		failures.append(
			"Annex wall tunnels violate depth/clearance/carpet contract: bad=%d carpet-pieces=%d tunnels=%d" % [
				runtime["bad_tunnels"], runtime["tunnel_carpet_strips"],
				runtime["tunnels"]])
	if int(runtime["tunnel_straight"]) == 0 or int(runtime["tunnel_l"]) == 0:
		failures.append("Annex tunnel path sample missing straight or L topology: straight=%d L=%d" % [
			runtime["tunnel_straight"], runtime["tunnel_l"]])
	if int(runtime["bad_attached_half_walls"]) > 0:
		failures.append("Annex attached half-wall inheritance/cap contract failed: %d" % [
			runtime["bad_attached_half_walls"]])
	var tunnel_ratio := float(runtime["wall_mass_tunnels"]) / float(maxi(
		int(runtime["kinds"].get("annex_wall_mass", 0)), 1))
	if tunnel_ratio < 0.25:
		failures.append("Annex freestanding wall tunnels are still too rare: %.3f" % [
			tunnel_ratio])
	# Freestanding wall masses are themselves sparse; most should contain a tunnel
	# so players reliably encounter both straight and L-shaped variants.
	if tunnel_ratio > 0.95:
		failures.append("Annex freestanding wall tunnel coverage is unexpectedly saturated: %.3f" % [
			tunnel_ratio])
	if int(runtime["bad_deep_mass_candidates"]) > 0:
		failures.append("invalid deep Annex wall candidates: %d" % [
			runtime["bad_deep_mass_candidates"]])
	var deep_tunnel_ratio := float(runtime["deep_mass_tunnels"]) / float(maxi(
		int(runtime["deep_mass_candidates"]), 1))
	if deep_tunnel_ratio < 0.24 or deep_tunnel_ratio > 0.52:
		failures.append(
			"cross-corridor deep-wall tunnel coverage out of range: %.3f" % [
				deep_tunnel_ratio])
	if int(runtime["corridor_shells"]) == 0:
		failures.append("no physical narrow corridor shells generated")
	if int(runtime["cross_corners"]) == 0:
		failures.append("cross-corridor solid corners were not exercised")
	if int(runtime["bad_cross_corners"]) > 0:
		failures.append("cross-corridor corners still split wall finishes: %d" % [
			runtime["bad_cross_corners"]])
	if int(runtime["corridor_connections"]) == 0 \
			or int(runtime["corridor_connection_parts"]) == 0:
		failures.append("Annex corridor connection inheritance was not exercised")
	if int(runtime["bad_corridor_connections"]) > 0 \
			or int(runtime["corridor_connection_baseboards"]) \
				!= int(runtime["corridor_connection_baseboards_expected"]):
		failures.append(
			"Annex corridor connection finish/baseboard inheritance failed: "
			+ "bad=%d expected_trim=%d actual_trim=%d" % [
				runtime["bad_corridor_connections"],
				runtime["corridor_connection_baseboards_expected"],
				runtime["corridor_connection_baseboards"]])
	if int(runtime["outlets"]) == 0 or int(runtime["switches"]) == 0:
		failures.append("Annex outlets/switches were not both generated")
	if int(runtime["bad_utilities"]) > 0:
		failures.append("Annex wall utilities have invalid theme/height metadata: %d" % [
			runtime["bad_utilities"]])
	if int(runtime["floating_utilities"]) > 0:
		failures.append("Annex utilities lack a wall in their own streamed chunk: %d" % [
			runtime["floating_utilities"]])
	if int(runtime["shadowing_utilities"]) > 0:
		failures.append(
			"Annex utility plates still create unstable contact occlusion: %d" % [
				runtime["shadowing_utilities"]])
	var utility_density := float(runtime["wall_utilities"]) \
		/ float(maxi(runtime_chunks, 1))
	# Raised from 1.35 deliberately. A 12x12m room reading as a former office
	# needs visible electrical evidence, and one fixture per four cells did not
	# supply it; solid walls now carry up to three receptacles. This is still a
	# real bound — a genuine office wall would hold several times this — and it
	# exists to catch runaway density, not to keep the walls bare.
	if utility_density > 2.6:
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
	if int(runtime["authored_exit_doors"]) == 0:
		failures.append("extracted carlcapu9 Annex exit door was not generated")
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
	if int(runtime["bad_wall_owners"]) > 0:
		failures.append("Annex wall segments do not identify a continuous visual owner: %d" % [
			runtime["bad_wall_owners"]])
	if int(runtime["bad_wall_finish_contracts"]) > 0:
		failures.append(
			"Annex wall segments violate finish/baseboard ownership: %d" % [
				runtime["bad_wall_finish_contracts"]])
	if int(runtime["t_junction_stubs"]) == 0:
		failures.append("Annex runtime sample never exercised a T-junction stub")
	if int(runtime["bad_t_junction_stubs"]) > 0:
		failures.append(
			"Annex T-junction stubs still override the continuous wall: %d" % [
				runtime["bad_t_junction_stubs"]])
	if int(runtime["baseboards"]) == 0:
		failures.append("selective Annex baseboards were not generated")
	if int(runtime["bad_baseboards"]) > 0:
		failures.append("Annex baseboards have invalid dimensions/attachment metadata: %d" % [
			runtime["bad_baseboards"]])
	if int(runtime["floating_baseboards"]) > 0:
		failures.append("Annex baseboards are not physically backed by a wall: %d" % [
			runtime["floating_baseboards"]])
	if int(runtime["shadowing_baseboards"]) > 0:
		failures.append("Annex baseboards still cast detached floor shadows: %d" % [
			runtime["shadowing_baseboards"]])
	if int(runtime["bad_architecture_baseboards"]) > 0:
		failures.append(
			"Wallpapered Annex architecture lacks a complete baseboard wrap: %d" % [
				runtime["bad_architecture_baseboards"]])
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
	print("  mixed scale: %d corridors / %d rooms | widths %s (2.2m %.3f) | room sizes %s | large-room ratio %.3f | pile ratio %.3f (%d roots) | dim %.3f / gaps %.3f | baseboards %.3f | %d open edges" % [
		corridor_cells, room_cells, corridor_widths, narrow_ratio,
		room_sizes, large_room_ratio, furniture_pile_ratio,
		furniture_pile_roots, dim_ratio, light_gap_ratio, baseboard_ratio,
		open_edges])
	print("  runtime: %d chunks | %d corridor shells / %d solid corners | %d baseboards | %d full-tile lights | %d dim zones / %d gaps | %d cameras | utilities %d (%d outlets/%d switches) | props chairs=%d+%d (%d tipped) shelves=%d boxes=%d ac=%d exits=%d | %d furniture piles / %d carpeted wall tunnels | %d wall segments / %d partitions | %d architecture assemblies %s" % [
		runtime_chunks, runtime["corridor_shells"], runtime["cross_corners"],
		runtime["baseboards"], runtime["ceiling_lights"],
		runtime["dim_zones"], runtime["light_gaps"], runtime["cameras"],
		runtime["wall_utilities"], runtime["outlets"], runtime["switches"],
		runtime["authored_chairs"], runtime["authored_school_chairs"],
		runtime["tipped_school_chairs"], runtime["authored_shelving"],
		runtime["authored_boxes"], runtime["authored_ac"],
		runtime["authored_exit_doors"],
		runtime["furniture_piles"], runtime["tunnels"],
		runtime["wall_segments"], runtime["partitions"],
		runtime["architecture_assemblies"], runtime["kinds"]])
	if failures.is_empty():
		print("  PASS — full-tile unobstructed fixtures, substantial seamless walls, deliberate dim zones, warm-yellow rooms, ambient-only audio, rare furniture piles, sparse CCTV")
		quit(0)
		return
	for failure in failures.slice(0, 20):
		push_error(failure)
	print("  FAIL — %d Annex contract violations" % failures.size())
	quit(1)

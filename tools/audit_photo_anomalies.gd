extends SceneTree
## Photography contract audit — pure, no scene boot.
## Run: godot --headless --path . --script tools/audit_photo_anomalies.gd
##
## Guarantees per audited objective floor:
##   - the plan places at least REQUIRED anomalies, and exactly REQUIRED of
##     them on the guided route's spine, so the tape gate can always be paid
##     without leaving the route;
##   - ids are unique and never sit on the origin or target cell;
##   - WRITING placements always resolved a fully closed wall;
##   - prop-based types only appear on themes whose own signature prop is
##     portable (PhotoAnomaly.PROP_THEMES).

const SEEDS := [7, 102, 1234577]
const FLOORS := [0, 2, 4, 6, 8, 9]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	if PhotoAnomaly.PHRASES.size() < 8:
		failures.append("phrase pool shrank to %d entries"
			% PhotoAnomaly.PHRASES.size())
	if PhotoDirector.REQUIRED != 3:
		failures.append("base REQUIRED drifted from 3 (got %d) — "
			% PhotoDirector.REQUIRED
			+ "deliberate retune? update this audit")
	if PhotoDirector.required_for(10, 11) != 3 \
			or PhotoDirector.required_for(10, 0) != 5 \
			or PhotoDirector.required_for(4, 0) != 4:
		failures.append("required_for ladder drifted from 3/4/5 with "
			+ "prop-less floors pinned at 3")
	await _check_writing_visibility(failures)
	_check_merged_office_evidence(failures)
	var plans := 0
	for world_seed in SEEDS:
		for floor_idx in FLOORS:
			var theme: int = DescentRun.FIXED_ORDER[floor_idx]
			var route := DescentRoute.build(
				WorldGen.level_seed(world_seed, theme), theme, floor_idx)
			var plan := PhotoDirector.build_plan(route)
			plans += 1
			var required := PhotoDirector.required_for(floor_idx, theme)
			var spine := PhotoDirector.spine_count_for(floor_idx, theme)
			var label := "seed %d floor %d theme %d" % [
				world_seed, floor_idx + 1, theme]
			if plan.size() < required:
				failures.append("%s: only %d anomalies planned" % [
					label, plan.size()])
				continue
			var ids := {}
			var on_route := 0
			var required_types := {}
			for at in plan:
				var spec: Dictionary = plan[at]
				var id := str(spec["id"])
				if ids.has(id):
					failures.append("%s: duplicate id %s" % [label, id])
				ids[id] = true
				if at == route.origin or at == route.target:
					failures.append("%s: anomaly on %s cell" % [label,
						"origin" if at == route.origin else "target"])
				if bool(spec["required"]):
					on_route += 1
					required_types[int(spec["type"])] = true
					if not route.is_path_cell(at):
						failures.append("%s: required anomaly %s off the spine"
							% [label, id])
				var wall_types := [PhotoAnomaly.Type.WRITING,
					PhotoAnomaly.Type.PRINT, PhotoAnomaly.Type.PORTAL]
				if int(spec["type"]) in wall_types \
						and int(spec["wall_dir"]) < 0:
					failures.append("%s: writing %s without a wall" % [
						label, id])
				if not int(spec["type"]) in wall_types \
						and not PhotoAnomaly.PROP_THEMES.has(theme):
					failures.append("%s: prop anomaly %s on prop-less theme"
						% [label, id])
			if on_route != spine:
				failures.append("%s: %d on-route anomalies, need exactly %d"
					% [label, on_route, spine])
			# The spine must offer at least `required` distinct kinds on
			# prop themes; WRITING-only themes cannot vary and are exempt.
			if PhotoAnomaly.PROP_THEMES.has(theme) \
					and required_types.size() < required:
				failures.append("%s: spine repeats down to %d kinds, need %d"
					% [label, required_types.size(), required])
	for failure in failures:
		print("  FAIL " + failure)
	if failures.is_empty():
		print("photo anomaly audit: PASS — %d plans across %d seeds" % [
			plans, SEEDS.size()])
		quit()
	else:
		quit(1)


## Seed 102 regression: the former PRINT variant must reveal its writing
## before the shutter, and documenting it must not remove that writing.
func _check_writing_visibility(failures: Array[String]) -> void:
	var at := Vector2i.ZERO
	var found := false
	for x in 64:
		for z in 64:
			if PhotoAnomaly.phrase_for(102, Vector2i(x, z)) == "WE COUNTED YOU":
				at = Vector2i(x, z)
				found = true
				break
		if found:
			break
	if not found:
		failures.append("seed 102 regression phrase not found")
		return
	for kind in [PhotoAnomaly.Type.WRITING, PhotoAnomaly.Type.PRINT]:
		var anomaly := PhotoAnomaly.new()
		root.add_child(anomaly)
		anomaly.configure("writing-regression", kind, at, 102, 0, 0, 6.0)
		var labels := anomaly.find_children("*", "Label3D", true, false)
		if labels.size() != 1:
			failures.append("writing variant %d did not create a label" % kind)
		else:
			var label := labels[0] as Label3D
			if label.text != "WE COUNTED YOU" or label.layers != PhotoAnomaly.PHOTO_LAYER:
				failures.append("writing variant %d not visible in live viewfinder" % kind)
			anomaly.resolve()
			await process_frame
			if not is_instance_valid(label) or not label.visible:
				failures.append("writing variant %d disappeared after photo" % kind)
		anomaly.free()


func _check_merged_office_evidence(failures: Array[String]) -> void:
	var ws := WorldGen.level_seed(102, 1)
	var route := DescentRoute.build(ws, 1, 2)
	# The first seed-102 member has an AC unit and the second has a print
	# at the former wall-writing location. Both have anchor-owned furnishings.
	for at: Vector2i in [Vector2i(-8, 4), Vector2i(2, 9)]:
		var anchor := Chunk.new(ws, WorldGen.room_id(ws, at), 1)
		var member := Chunk.new(ws, at, 1)
		var spot := PhotoAnomaly.writing_spot_for_chunk(route, at, member, anchor)
		var ac := at == Vector2i(-8, 4)
		var previous_dir := 3 if ac else 1
		var mount_along := 9.0 if ac else 3.3925364
		var mount_width := Chunk.OFFICE_AC_FACE_SIZE.x if ac else 1.72
		if not spot.is_empty() and spot.dir == previous_dir \
				and absf(spot.along - mount_along) < (mount_width + PhotoAnomaly.WRITING_MAX_WIDTH) * 0.5:
			failures.append("Office writing overlaps its wall fixture at %s" % at)
		if ac:
			var positions: Array[Vector3] = []
			var offset := Vector3(at.x - anchor.cell.x, 0, at.y - anchor.cell.y) * WorldGen.CELL_SIZE
			for owner_first in [true, false]:
				var manager := ChunkManager.new()
				var director := PhotoDirector.new()
				director.configure(route, 2, manager, [])
				director.plan = {at: {"id": "cooler", "type": PhotoAnomaly.Type.MISSING,
					"wall_dir": -1, "wall_along": 0.0}}
				var order := [anchor, member] if owner_first else [member, anchor]
				for part: Chunk in order:
					manager.chunks[part.cell] = part
					manager.chunk_built.emit(part)
					if part == member and not owner_first and director._live.has(at):
						failures.append("cooler spawned before its room furniture was available")
				var subject := director._live.get(at) as PhotoAnomaly
				if subject == null or subject.type != PhotoAnomaly.Type.MISSING:
					failures.append("clear Office floor spot did not retain the planned cooler")
				else:
					var floor_spot := (subject._resolvables[0] as Node3D).position
					if not anchor._floor_spot_clear(floor_spot + offset, 0.19, 1.38):
						failures.append("anomaly cooler intersects Office cubicle furniture")
					positions.append(floor_spot)
					subject.free()
				manager.chunks.clear()
				director.free()
				manager.free()
			if positions.size() == 2 and not positions[0].is_equal_approx(positions[1]):
				failures.append("cooler placement changed with chunk streaming order")
		member.free()
		anchor.free()

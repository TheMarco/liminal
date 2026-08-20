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

const SEEDS := [7, 1234577]
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
	var plans := 0
	for world_seed in SEEDS:
		for floor_idx in FLOORS:
			var theme: int = DescentRun.FIXED_ORDER[floor_idx]
			var route := DescentRoute.build(
				WorldGen.level_seed(world_seed, theme), theme, floor_idx)
			var plan := PhotoDirector.build_plan(route)
			plans += 1
			var required := PhotoDirector.required_for(floor_idx, theme)
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
					PhotoAnomaly.Type.PRINT]
				if int(spec["type"]) in wall_types \
						and int(spec["wall_dir"]) < 0:
					failures.append("%s: writing %s without a wall" % [
						label, id])
				if not int(spec["type"]) in wall_types \
						and not PhotoAnomaly.PROP_THEMES.has(theme):
					failures.append("%s: prop anomaly %s on prop-less theme"
						% [label, id])
			if on_route != required:
				failures.append("%s: %d on-route anomalies, need exactly %d"
					% [label, on_route, required])
			# Prop themes must vary the required set; WRITING-only themes
			# cannot and are exempt.
			if PhotoAnomaly.PROP_THEMES.has(theme) \
					and required_types.size() < required:
				failures.append("%s: required set repeats a type (%d kinds)"
					% [label, required_types.size()])
	for failure in failures:
		print("  FAIL " + failure)
	if failures.is_empty():
		print("photo anomaly audit: PASS — %d plans across %d seeds" % [
			plans, SEEDS.size()])
		quit()
	else:
		quit(1)

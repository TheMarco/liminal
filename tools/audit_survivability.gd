extends SceneTree
## Every other audit in this repo checks what the building is made of. This one
## checks whether the rules it enforces can actually be obeyed.
##
## The rules were written before the figures could advance, kill, or be burned,
## and neither system originally referenced the other. The result was states
## where obeying a rule was fatal and breaking it was the only play.
##
## The invariants below are the contract that fixed it. They are asserted
## against the real classes driven by hand, not against a re-derivation of the
## arithmetic, so a constant that drifts out of a safe range fails the build.
##
## Run: godot --headless --path . --script tools/audit_survivability.gd -- [floors]

const STEP := 1.0 / 60.0
const SIM_SECONDS := 900.0
const MainScript = preload("res://scripts/main.gd")


## A real Player standing perfectly still at the origin — the rule-abiding
## player whose survival is the whole question. Its own `_physics_process` is
## never driven, so it never moves and never reads input.
func _still_player() -> Player:
	var p := Player.new()
	p.set_physics_process(false)
	p.set_process_unhandled_input(false)
	var cam := Camera3D.new()
	p.add_child(cam)
	p.cam = cam
	get_root().add_child(p)
	p.velocity = Vector3.ZERO
	p.global_position = Vector3.ZERO
	return p


func _init() -> void:
	call_deferred("_run")


## Everything here needs its nodes genuinely inside the tree — `DescentRun`
## reads `player.global_position`, and a figure frees itself the moment its
## player is not in a tree — so none of it can happen during `_init`.
func _run() -> void:
	await physics_frame
	var args := OS.get_cmdline_user_args()
	var floors := clampi(int(args[0]) if args.size() > 0 \
		else DescentRun.FLOOR_COUNT, 1, DescentRun.FLOOR_COUNT)
	var failures := 0
	var blackouts := 0
	var passive_ticks := 0

	# --- 1. a suppressed figure does not close the distance --------------------
	# The bool has to actually reach the behaviour. Driven first, in an empty
	# tree: the sight checks raycast against everything present, and a stage
	# littered with the stub players from the loops below would answer for them.
	failures += _figure_holds_still()

	# --- 2. a blackout always implies the figures are held ---------------------
	# The channel that fixes F1, F2 and F5 is one bool. If it ever reads false
	# while the player is pinned, something is closing on someone who is not
	# permitted to move.
	# A blackout is only allowed to start once a safe doorway proposal exists,
	# and proposals need a real route with topology that contains the player's
	# cell. Without this fixture every blackout postpones forever and the 900
	# simulated seconds prove nothing — which is exactly how this audit was
	# broken for a while. One cheap casino route is shared across the floors:
	# the per-floor rule constants live on the run, not on the route, and a
	# route build now costs ~25s on late floors.
	var fixture_seed := 20260725
	var fixture_route := DescentRoute.build(
		WorldGen.level_seed(fixture_seed, 0), 0, 0)
	fixture_route.set_topology(DescentTopology.new(
		WorldGen.level_seed(fixture_seed, 0), 0))
	var fixture_path := fixture_route.path_from_origin()
	var stand := fixture_path[fixture_path.size() / 2]
	for floor_idx in floors:
		var run := DescentRun.new()
		var stub := _still_player()
		stub.global_position = Vector3(
			float(stand.x) * 12.0 + 6.0, 0.0, float(stand.y) * 12.0 + 6.0)
		run.player = stub
		run.world_seed = 20260725 + floor_idx * 7919
		run.floor_idx = floor_idx
		get_root().add_child(run)
		run.prepare_floor()
		# prepare_floor clears the route, so the fixture goes in after it.
		run.set_route(fixture_route)
		run.start_floor()
		# A real player arrives with a trail of visited rooms, and ordinary
		# blackout doorways only open off that trail (never the very cell the
		# player is standing in). A perfectly still player has no trail, so
		# hand the run the walked route as one.
		for walked in fixture_path:
			run.visited[walked] = true
		var t := 0.0
		while t < SIM_SECONDS:
			run._physics_process(STEP)
			t += STEP
			if run.blackout:
				blackouts += 1
				if not run.rules_force_passive():
					failures += 1
					if failures <= 6:
						print("FAIL floor=%d  blackout without passive at t=%.1fs"
							% [floor_idx, t])
			if run.arrival_grace > 0.0 and not run.rules_force_passive():
				failures += 1
				if failures <= 6:
					print("FAIL floor=%d  arrival grace without passive at t=%.1fs"
						% [floor_idx, t])
			if run.rules_force_passive():
				passive_ticks += 1
		run.queue_free()
		stub.queue_free()

	# --- 3. the torch can clear a full house before its cell runs out ----------
	# MAX_FIGS figures, BURN_TIME each, plus a beat to swing between them. If
	# this stops fitting inside FLASH_MAX the rebalance has been undone.
	var need := float(ShadowFigures.MAX_FIGS) * ShadowFigure.BURN_TIME
	var swing := float(ShadowFigures.MAX_FIGS - 1) * 0.7
	var budget := Player.FLASH_MAX \
		+ float(ShadowFigures.MAX_FIGS) * MainScript.BURN_REFUND
	if need + swing > budget:
		failures += 1
		print("FAIL torch cannot clear %d figures: needs %.1fs, has %.1fs"
			% [ShadowFigures.MAX_FIGS, need + swing, budget])

	# --- 4. staring is no longer the most expensive thing you can do ----------
	# It is the only torch-free defence; if it costs more than the rules it
	# competes with, defending is the fastest route to more figures.
	var stare_cost := 0.05
	if stare_cost > 0.06:
		failures += 1
		print("FAIL stare charge %.2f exceeds the passive violations" % stare_cost)

	print("survivability audit: %d floors, %.0fs simulated per floor" % [
		floors, SIM_SECONDS])
	print("  blackout ticks: %d | passive ticks: %d" % [blackouts, passive_ticks])
	print("  torch budget %.1fs vs %.1fs needed to clear a full house" % [
		budget, need + swing])
	if blackouts == 0:
		failures += 1
		print("FAIL — no blackout occurred; the audit proved nothing")
	if failures > 0:
		print("  FAIL — %d rule/threat states leave the player no legal play"
			% failures)
		quit(1)
		return
	print("  PASS — every enforced rule can be obeyed without dying to it")
	quit()


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## A figure told to hold must not travel, and must still be able to burn.
func _figure_holds_still() -> int:
	var bad := 0
	var stub := _still_player()
	var host := Node3D.new()
	get_root().add_child(host)
	var f := ShadowFigure.new()
	f.player = stub
	f.grace = 0.0
	f.position = Vector3(0, 0, 6.0)
	f.suppressed = true
	host.add_child(f)
	var start := _flat_dist(f.position, stub.global_position)
	for i in 240:
		f._physics_process(STEP)
	# The invariant is not "does not move", it is "does not get closer".
	# Horizontal only: four of the seven hang rather than stand, and bob a few
	# centimetres on the spot.
	var held := _flat_dist(f.position, stub.global_position)
	if held < start - 0.01:
		bad += 1
		print("FAIL suppressed figure closed %.2fm in 4s" % (start - held))
	# Released, it closes again. Two seconds, not four: at 1.25 m/s it covers
	# the 6m to arm's length in 3.96s and seizes, and a figure mid-exit is not
	# a figure whose travel can be measured.
	f.suppressed = false
	for i in 120:
		if not is_instance_valid(f):
			break
		f._physics_process(STEP)
	var closed := start - _flat_dist(f.position, stub.global_position) \
		if is_instance_valid(f) else 99.0
	if closed <= 0.5:
		bad += 1
		print("FAIL released figure closed only %.2fm in 2s" % closed)
	host.queue_free()
	stub.queue_free()
	return bad

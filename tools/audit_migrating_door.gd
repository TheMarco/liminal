extends SceneTree
## Package 2 gate: the migrating-doorway fixture. Unit proofs (mesh winding,
## UV anchoring, guard math, connectivity proofs) run off-tree; event proofs
## (lit/blackout presentation, safe closure, sprint crossing, camping
## timeout, reverse, persistence) run in-tree with real physics bodies.
##
## Run:
##   godot --headless --path . --script tools/audit_migrating_door.gd

var failures: Array[String] = []
var _finished: Array = []
var _persist_attempts := 0


func _init() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if not condition and failures.size() < 80:
		failures.append(message)


func _run() -> void:
	_audit_mesh()
	await _audit_site_unit()
	_audit_transaction_unit()
	_audit_mode_gate()
	await _audit_lit_event_chain()
	await _audit_blackout_event()
	await _audit_delayed_lights_on_recognition()
	await _audit_lights_on_cancel()
	await _audit_camping_timeout()
	await _audit_sprint_crossing()
	await _audit_camera_path()
	_audit_persistence()
	await physics_frame
	for failure in failures:
		print("  FAIL " + failure)
	if failures.is_empty():
		print("  PASS - migrating doorway holds")
		quit()
	else:
		quit(1)


func _frames(n: int) -> void:
	for _i in n:
		await physics_frame


# ---------------------------------------------------------------- unit: mesh

func _audit_mesh() -> void:
	var mesh := MigratingDoorSite.anchored_box_mesh(
		Vector3(2.0, 3.0, 0.5), 0.8)
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	_expect(verts.size() == 36, "anchored box must have 36 verts")
	# Every triangle winds clockwise seen from outside its face. For
	# clockwise winding, (b-a)x(c-a) points inward: BoxMesh itself scores
	# -1.0 on this measure, so the anchored mesh must match, not oppose.
	for t in verts.size() / 3:
		var a := verts[t * 3]
		var b := verts[t * 3 + 1]
		var c := verts[t * 3 + 2]
		var n: Vector3 = normals[t * 3]
		var geometric := (b - a).cross(c - a).normalized()
		_expect(geometric.dot(n) < -0.99,
			"triangle must wind clockwise (tri %d)" % t)
	# UVs are tile units: x span 2.0m / 0.8m = 2.5 tiles on z faces.
	var umin := INF
	var umax := -INF
	for i in verts.size():
		if absf(normals[i].z) > 0.5:
			umin = minf(umin, uvs[i].x)
			umax = maxf(umax, uvs[i].x)
	_expect(is_equal_approx(umax - umin, 2.5),
		"z-face UV span must be 2.5 tiles, got %f" % (umax - umin))


# ---------------------------------------------------------- unit: site math

func _offtree_fixture() -> SpatialDoorFixture:
	# Mounted (prepare needs the tree) but never frame-stepped: direct
	# advance_physics calls drive these unit proofs.
	var fx := SpatialDoorFixture.new()
	root.add_child(fx)
	fx.build()
	return fx


func _free_fixture(fx: SpatialDoorFixture) -> void:
	root.remove_child(fx)
	fx.queue_free()


func _audit_site_unit() -> void:
	var fx := _offtree_fixture()
	var site := fx.site
	# Bad prepares rejected.
	var loose := MigratingDoorSite.new()
	_expect(not loose.prepare(null, null, {}).ok,
		"prepare must reject off-tree sites")
	loose.queue_free()
	var bad := MigratingDoorSite.new()
	root.add_child(bad)
	var rejected := bad.prepare(null, null, {})
	_expect(not rejected.ok, "prepare must reject null spec")
	root.remove_child(bad)
	bad.queue_free()
	# Open timing: B opens in ~1.2s at 60Hz with no actors.
	site.set_targets(1.0, 1.0)
	var frames := 0
	while not is_equal_approx(site.current_clearance().openness["b"], 1.0) \
			and frames < 120:
		site.advance_physics(1.0 / 60.0, [])
		frames += 1
	_expect(frames >= 70 and frames <= 76,
		"B must open in ~72 frames, took %d" % frames)
	# Traversability flips at the collider-derived threshold.
	_expect(site.current_clearance().traversable["b"],
		"open B must be traversable")
	site.set_targets(1.0, 0.0)
	site.advance_physics(0.5, [])
	var mid := site.current_clearance()
	_expect(not mid.traversable["b"] or mid.clear_width["b"] >= 1.06,
		"partial B must respect the 1.06m threshold")
	# UV anchoring: offset tracks leaf displacement in tile units.
	var fx2 := _offtree_fixture()
	var site2 := fx2.site
	site2.set_targets(1.0, 1.0)
	for _i in 80:
		site2.advance_physics(1.0 / 60.0, [])
	var leaf_l: AnimatableBody3D = site2._leaves["b_l"]
	var mesh_instance := leaf_l.get_child(0) as MeshInstance3D
	var material := mesh_instance.material_override as StandardMaterial3D
	var openness: float = site2.current_clearance().openness["b"]
	_expect(is_equal_approx(material.uv1_offset.x, -openness * 1.6 / 0.8),
		"leaf UV offset must equal displacement in tiles")
	await physics_frame
	var dx: float = leaf_l.position.x - float(site2._closed_x["b_l"])
	_expect(is_equal_approx(dx, -1.6),
		"open leaf must travel 1.6m, moved %f" % dx)
	# Token grant and release with a scripted actor camping the passage.
	var fx3 := _offtree_fixture()
	var site3 := fx3.site
	site3.set_targets(1.0, 1.0)
	for _i in 80:
		site3.advance_physics(1.0 / 60.0, [])
	site3.set_targets(0.0, 1.0)
	var camper := {"id": "camper", "prev": Vector3(0, 0, -4),
		"curr": Vector3(0, 0, -4), "radius": 0.38}
	var result: MigratingDoorSite.PhaseResult = null
	for _i in 30:
		result = site3.advance_physics(1.0 / 60.0, [camper])
	_expect(result.close_blocked, "camper in passage must block closure")
	_expect(not result.tokens.is_empty(),
		"camper in passage must hold a token")
	_expect(site3.current_clearance().openness["a"] > 0.9,
		"blocked A must reopen fully")
	var away := {"id": "camper", "prev": Vector3(0, 0, -1),
		"curr": Vector3(0, 0, 0), "radius": 0.38}
	for _i in 30:
		result = site3.advance_physics(1.0 / 60.0, [away])
	_expect(result.tokens.is_empty(), "cleared actor must release tokens")
	# Sprint guard at low-rate physics: 0.62m swept step still blocks.
	var fx4 := _offtree_fixture()
	var site4 := fx4.site
	site4.set_targets(1.0, 1.0)
	for _i in 80:
		site4.advance_physics(1.0 / 60.0, [])
	site4.set_targets(0.0, 1.0)
	var sprinter := {"id": "run", "prev": Vector3(0, 0, -5.6),
		"curr": Vector3(0, 0, -4.98), "radius": 0.38}
	var slow := site4.advance_physics(0.1, [sprinter])
	_expect(slow.close_blocked,
		"sprinter swept step must block closure at dt=0.1")
	# Teleport clamp: a 10m jump is treated as a point, not a sweep.
	var jumper := {"id": "jump", "prev": Vector3(0, 0, -14),
		"curr": Vector3(0, 0, 2.5), "radius": 0.38}
	var jumped := site4.advance_physics(1.0 / 60.0, [jumper])
	_expect(not jumped.close_blocked,
		"teleport to clear ground must not block closure")
	_free_fixture(fx)
	_free_fixture(fx2)
	_free_fixture(fx3)
	_free_fixture(fx4)


# --------------------------------------------------- unit: transaction gate

func _audit_transaction_unit() -> void:
	var fx := _offtree_fixture()
	# A phase that disconnects the exit must fail begin, not the event.
	var plan := fx.make_plan("a_open", "b_open", "lit")
	plan.phase_pairs["b_open"] = [[SpatialDoorFixture.CELL_J,
		SpatialDoorFixture.CELL_EC], [Vector2i(9, 9),
		SpatialDoorFixture.CELL_EC]]
	var tx := SpatialSiteTransaction.new()
	var state := fx.make_state()
	var begin := tx.begin(plan, fx.site, state, fx.topology,
		Callable(fx, "base_probe"), fx.scanned_cells(),
		Callable(fx, "persist"))
	_expect(not begin.ok, "disconnected phase must fail begin")
	# Unknown site state must fail begin.
	var plan2 := fx.make_plan("a_open", "b_open", "lit")
	var tx2 := SpatialSiteTransaction.new()
	var wrong := SpatialSiteState.new()
	wrong.spec_id = "floor:0/site:door:9:9:9"
	var begin2 := tx2.begin(plan2, fx.site, wrong, fx.topology,
		Callable(fx, "base_probe"), fx.scanned_cells(),
		Callable(fx, "persist"))
	_expect(not begin2.ok, "mismatched state must fail begin")
	_free_fixture(fx)
	# Motion cannot begin unless its arrival-safe checkpoint is durable.
	var fx3 := _offtree_fixture()
	var tx3 := SpatialSiteTransaction.new()
	var state3 := fx3.make_state()
	var begin3 := tx3.begin(fx3.make_plan("a_open", "b_open", "lit"),
		fx3.site, state3, fx3.topology, Callable(fx3, "base_probe"),
		fx3.scanned_cells(), Callable(self, "_always_fail_persist"))
	_expect(not begin3.ok and begin3.persist_error == ERR_CANT_CREATE,
		"failed active checkpoint must reject begin with its save error")
	_expect(state3.progress < 0.0
		and fx3.site.current_clearance().traversable["a"]
		and not fx3.site.current_clearance().traversable["b"],
		"failed active checkpoint must leave exact initial geometry/state")
	_free_fixture(fx3)
	# A final atomic-save failure is a failed outcome, never a completed commit.
	var fx4 := _offtree_fixture()
	var tx4 := SpatialSiteTransaction.new()
	var state4 := fx4.make_state()
	_persist_attempts = 0
	var begin4 := tx4.begin(fx4.make_plan("a_open", "b_open", "lit"),
		fx4.site, state4, fx4.topology, Callable(fx4, "base_probe"),
		fx4.scanned_cells(), Callable(self, "_fail_final_persist"))
	_expect(begin4.ok, "active checkpoint must succeed before final-save test")
	var final := SpatialSiteTransaction.AdvanceResult.new()
	for _i in 300:
		final = tx4.advance(1.0 / 60.0, [])
		if final.done:
			break
	_expect(final.done and not final.durable
		and final.outcome == "persistence_failed"
		and final.persist_error == ERR_CANT_CREATE,
		"failed final checkpoint must surface a non-durable persistence outcome")
	_free_fixture(fx4)
	# Fault-inject an ownership/publication failure after successful preflight.
	# The physical assembly must settle safe and the result must stay non-durable.
	var fx5 := _offtree_fixture()
	var tx5 := SpatialSiteTransaction.new()
	var plan5 := fx5.make_plan("a_open", "b_open", "lit")
	var begin5 := tx5.begin(plan5, fx5.site, fx5.make_state(), fx5.topology,
		Callable(fx5, "base_probe"), fx5.scanned_cells(),
		Callable(fx5, "persist"), Callable(fx5, "note_graph_invalidated"))
	_expect(begin5.ok, "publication-failure fixture must pass preflight")
	plan5.aperture_edges["b"] = {"cell": Vector2i(99, 99), "dir": 0}
	var failed_publication := SpatialSiteTransaction.AdvanceResult.new()
	for _i in 300:
		failed_publication = tx5.advance(1.0 / 60.0, [])
		if failed_publication.done:
			break
	var safe := fx5.site.current_clearance()
	_expect(failed_publication.done and failed_publication.invariant_failed
		and not failed_publication.durable
		and failed_publication.outcome == "graph_publication_failed",
		"graph publication failure must be loud and non-durable")
	_expect(safe.traversable["a"] and safe.traversable["b"]
		and fx5.persisted.size() == 1,
		"publication failure must settle physically both-open and retain only the safe checkpoint")
	_free_fixture(fx5)


func _always_fail_persist(_state: SpatialSiteState) -> Error:
	return ERR_CANT_CREATE


func _fail_final_persist(_state: SpatialSiteState) -> Error:
	_persist_attempts += 1
	return OK if _persist_attempts == 1 else ERR_CANT_CREATE


func _audit_mode_gate() -> void:
	var fx := _offtree_fixture()
	var manager := ChunkManager.new()
	var horror := HorrorDirector.new()
	var director := _make_director(fx)
	_register(director, fx, manager, horror)
	director.set_mode_ready(Callable(self, "_deny_mode"))
	_make_eligible(director, SpatialDoorFixture.SITE_ID)
	var denied: Dictionary = director.request_event(
		SpatialDoorFixture.SITE_ID,
		fx.make_plan("a_open", "b_open", "lit"))
	_expect(not denied["ok"] and denied["reason"] == "player mode is not ready",
		"mode gate must reject before leases, motion, or presentation")
	_expect(not director.is_active() and manager._site_cells.is_empty()
		and horror.snapshot()["structural"] == false,
		"mode rejection must leave no active hold or site lease")
	_free_fixture(fx)
	manager.free()
	horror.free()


func _deny_mode(_presentation: String) -> bool:
	return false


# ------------------------------------------------- in-tree event plumbing

func _mount() -> SpatialDoorFixture:
	var fx := SpatialDoorFixture.new()
	root.add_child(fx)
	fx.build()
	return fx


func _make_director(fx: SpatialDoorFixture) -> SpatialMutationDirector:
	var director := SpatialMutationDirector.new()
	director.process_physics_priority = 100
	fx.add_child(director)
	return director


func _register(director: SpatialMutationDirector, fx: SpatialDoorFixture,
		manager: ChunkManager, horror: HorrorDirector) -> bool:
	director.configure(horror, manager, fx.topology)
	director.set_connectivity(Callable(fx, "base_probe"),
		fx.scanned_cells())
	director.set_blackout_driver(Callable(fx, "darken"),
		Callable(fx, "restore"))
	var keep := director.site_state(SpatialDoorFixture.SITE_ID)
	var state := keep if keep != null else fx.make_state()
	return director.register_door_site(fx.site, state,
		Callable(fx, "occupancy"), Callable(fx, "persist"),
		Callable(fx, "note_graph_invalidated"))


func _make_eligible(director: SpatialMutationDirector,
		site_id: String) -> void:
	var feed := {}
	for id in director.site_witness_ids(site_id):
		feed[id] = {"in_view": true, "unobstructed": true}
	var base := Time.get_ticks_msec() / 1000.0 - 2.0
	for i in 10:
		director.tracker.sample_with_visibility(0.1, feed, base + i * 0.1)


func _run_until_idle(director: SpatialMutationDirector,
		max_frames: int) -> int:
	var frames := 0
	while director.is_active() and frames < max_frames:
		await physics_frame
		frames += 1
	return frames


# ------------------------------------------------------- lit chain + reverse

func _audit_lit_event_chain() -> void:
	var fx := _mount()
	var manager := ChunkManager.new()
	var horror := HorrorDirector.new()
	var director := _make_director(fx)
	var plan := fx.make_plan("a_open", "b_open", "lit")
	_expect(_register(director, fx, manager, horror),
		"fixture site must register")
	# Forced visibility failure cannot start an architectural success.
	var denied: Dictionary = director.request_event(
		SpatialDoorFixture.SITE_ID, plan)
	_expect(not denied["ok"], "unwitnessed request must be rejected")
	_make_eligible(director, SpatialDoorFixture.SITE_ID)
	director.event_finished.connect(_on_event_finished)
	var furniture_before := []
	for node in fx.furniture:
		furniture_before.append((node as Node3D).global_transform)
	var revision_before: int = fx.topology.revision
	var started: Dictionary = director.request_event(
		SpatialDoorFixture.SITE_ID, plan)
	_expect(bool(started["ok"]),
		"eligible lit request must start: %s" % started["reason"])
	_expect(manager._site_cells.has(SpatialDoorFixture.CELL_J),
		"site cells must be leased during the event")
	var frames := await _run_until_idle(director, 600)
	_expect(frames < 600, "lit event must finish, ran %d frames" % frames)
	_expect(_finished == ["completed_b_open"],
		"lit event must complete to b_open, got %s" % str(_finished))
	_finished.clear()
	var clearance := fx.site.current_clearance()
	_expect(not clearance.traversable["a"]
		and clearance.traversable["b"], "A must be shut, B must be open")
	_expect(fx.topology.is_wall(SpatialDoorFixture.CELL_J, 3),
		"topology must show A closed")
	_expect(not fx.topology.is_wall(SpatialDoorFixture.CELL_J, 0),
		"topology must show B open")
	_expect(fx.topology.revision == revision_before + 2,
		"two passability flips must bump revision twice")
	_expect(fx.graph_invalidations >= 2,
		"routing must invalidate on each flip")
	_expect(manager._site_cells.is_empty(),
		"leases must release after completion")
	_expect(fx.persisted.size() == 2,
		"event must persist active-safe and settled checkpoints")
	var checkpoint: SpatialSiteState = fx.persisted[0]
	_expect(checkpoint.stable_phase == "both_open"
		and not checkpoint.completed,
		"active checkpoint must reconstruct both-open")
	var saved: SpatialSiteState = fx.persisted.back()
	_expect(saved.stable_phase == "b_open" and saved.completed,
		"persisted state must be completed b_open")
	for i in fx.furniture.size():
		_expect((fx.furniture[i] as Node3D).global_transform
			== furniture_before[i], "furniture must stay motionless")
	# Same-site reverse is blocked while recognition payoff pends.
	var plan_back := fx.make_plan("b_open", "a_open", "lit")
	var blocked: Dictionary = director.request_event(
		SpatialDoorFixture.SITE_ID, plan_back)
	_expect(not blocked["ok"], "reverse during payoff must be rejected")
	var after_base := Time.get_ticks_msec() / 1000.0
	for i in 10:
		director.tracker.sample_with_visibility(0.1, {
			"opening_a": {"in_view": true, "unobstructed": true},
		}, after_base + i * 0.1)
	await physics_frame
	_expect(bool(director.last_event.get("recognized", false)),
		"visible changed aperture must auto-record recognition")
	_expect((fx.persisted.back() as SpatialSiteState).last_seen_after >= 0.0,
		"automatic recognition must persist last_seen_after")
	var back: Dictionary = director.request_event(
		SpatialDoorFixture.SITE_ID, plan_back)
	_expect(bool(back["ok"]),
		"reverse after recognition must start: %s" % back["reason"])
	var frames_back := await _run_until_idle(director, 600)
	_expect(_finished == ["completed_a_open"],
		"reverse must complete to a_open, got %s" % str(_finished))
	_finished.clear()
	_expect(frames_back < 600, "reverse must finish")
	fx.queue_free()
	manager.free()
	horror.free()
	await physics_frame


func _on_event_finished(_site_id: String, outcome: String) -> void:
	_finished.append(outcome)


# ------------------------------------------------------------------ blackout

func _audit_blackout_event() -> void:
	var fx := _mount()
	var manager := ChunkManager.new()
	var horror := HorrorDirector.new()
	var director := _make_director(fx)
	var plan := fx.make_plan("a_open", "b_open", "blackout")
	_register(director, fx, manager, horror)
	_make_eligible(director, SpatialDoorFixture.SITE_ID)
	director.event_finished.connect(_on_event_finished)
	var started: Dictionary = director.request_event(
		SpatialDoorFixture.SITE_ID, plan)
	_expect(bool(started["ok"]), "blackout request must start")
	_expect(fx.is_dark, "lights must be out during the transition")
	var frames := await _run_until_idle(director, 600)
	_expect(_finished == ["completed_b_open"],
		"blackout event must complete, got %s" % str(_finished))
	_finished.clear()
	_expect(frames < 600, "blackout event must finish")
	_expect(not fx.is_dark, "lights must restore after completion")
	_expect(str(director.last_event.get("presentation", ""))
		== "blackout", "record must show blackout presentation")
	var reveal := director.take_blackout_reveal()
	_expect(reveal.has("position"),
		"moved blackout event must offer one reveal")
	_expect(director.take_blackout_reveal().is_empty(),
		"reveal must be consumed once")
	fx.queue_free()
	manager.free()
	horror.free()
	await physics_frame
	# Refused onset never moved: no reveal, no stuck leases.
	var fx2 := _mount()
	var manager2 := ChunkManager.new()
	var horror2 := HorrorDirector.new()
	var director2 := _make_director(fx2)
	var plan2 := fx2.make_plan("a_open", "b_open", "blackout")
	_register(director2, fx2, manager2, horror2)
	_make_eligible(director2, SpatialDoorFixture.SITE_ID)
	fx2.refuse_dark = true
	var refused: Dictionary = director2.request_event(
		SpatialDoorFixture.SITE_ID, plan2)
	_expect(not refused["ok"], "refused onset must fail the request")
	_expect(director2.take_blackout_reveal().is_empty(),
		"non-event must offer no reveal")
	_expect(manager2._site_cells.is_empty(),
		"aborted request must release leases")
	# Missing connectivity proof releases pacing and leases alike.
	var director3 := _make_director(fx2)
	director3.configure(horror2, manager2, fx2.topology)
	director3.set_blackout_driver(Callable(fx2, "darken"),
		Callable(fx2, "restore"))
	director3.register_door_site(fx2.site, fx2.make_state(),
		Callable(fx2, "occupancy"), Callable(fx2, "persist"))
	_make_eligible(director3, SpatialDoorFixture.SITE_ID)
	fx2.refuse_dark = false
	var unproven: Dictionary = director3.request_event(
		SpatialDoorFixture.SITE_ID, plan2)
	_expect(not unproven["ok"]
		and str(unproven["reason"]) == "connectivity proof unavailable",
		"missing proof must fail cleanly")
	_expect(manager2._site_cells.is_empty(),
		"unproven request must release leases")
	_expect(horror2.snapshot()["structural"] == false,
		"pacing hold must release on failure")
	fx2.queue_free()
	manager2.free()
	horror2.free()
	await physics_frame


# ------------------------------------------- blackout visibility/recognition

func _audit_delayed_lights_on_recognition() -> void:
	var fx := _mount()
	var manager := ChunkManager.new()
	var horror := HorrorDirector.new()
	var director := _make_director(fx)
	var plan := fx.make_plan("a_open", "b_open", "blackout")
	_register(director, fx, manager, horror)
	# Production owns restoration in DescentRun, so the spatial director has no
	# end callback and must wait for Main.notify_lights_on().
	director.set_blackout_driver(Callable(fx, "darken"), Callable())
	_make_eligible(director, SpatialDoorFixture.SITE_ID)
	var started: Dictionary = director.request_event(
		SpatialDoorFixture.SITE_ID, plan)
	_expect(bool(started["ok"]), "delayed-light blackout must start")
	var frames := await _run_until_idle(director, 600)
	_expect(frames < 600 and fx.is_dark,
		"completed event must remain dark until the campaign restores power")
	_expect(director.current_phase() == "awaiting_visibility",
		"recognition must wait while the settled change is still dark")
	var after_base := Time.get_ticks_msec() / 1000.0
	for i in 10:
		director.tracker.sample_with_visibility(0.1, {
			"opening_a": {"in_view": true, "unobstructed": true},
		}, after_base + i * 0.1)
	await physics_frame
	_expect(not bool(director.last_event.get("recognized", false)),
		"dark samples must not count as after-state recognition")
	var plan_back := fx.make_plan("b_open", "a_open", "lit")
	var blocked: Dictionary = director.request_event(
		SpatialDoorFixture.SITE_ID, plan_back)
	_expect(not blocked["ok"],
		"a second event must remain blocked until visibility returns")
	fx.restore()
	director.notify_lights_on()
	var visible_base := Time.get_ticks_msec() / 1000.0
	for i in 10:
		director.tracker.sample_with_visibility(0.1, {
			"opening_a": {"in_view": true, "unobstructed": true},
		}, visible_base + i * 0.1)
	await physics_frame
	_expect(bool(director.last_event.get("recognized", false)),
		"recognition window must begin when lights actually return")
	fx.queue_free()
	manager.free()
	horror.free()
	await physics_frame


# ------------------------------------------------------- lights-on interrupt

func _audit_lights_on_cancel() -> void:
	var fx := _mount()
	var manager := ChunkManager.new()
	var horror := HorrorDirector.new()
	var director := _make_director(fx)
	var plan := fx.make_plan("a_open", "b_open", "blackout")
	_register(director, fx, manager, horror)
	_make_eligible(director, SpatialDoorFixture.SITE_ID)
	director.event_finished.connect(_on_event_finished)
	director.request_event(SpatialDoorFixture.SITE_ID, plan)
	# Let B open (1.2s), then restore lights mid-closure.
	await _frames(100)
	director.notify_lights_on()
	_expect(director.take_blackout_reveal().is_empty(),
		"lights-on reveal must wait for stable geometry")
	var frames := await _run_until_idle(director, 600)
	_expect(_finished == ["cancelled_both_open"],
		"interrupted event must settle both-open, got %s" % str(_finished))
	_finished.clear()
	_expect(frames < 600, "cancelled event must finish settling")
	var clearance := fx.site.current_clearance()
	_expect(clearance.traversable["a"] and clearance.traversable["b"],
		"cancelled geometry must be both-open")
	_expect(not (fx.persisted.back() as SpatialSiteState).completed,
		"cancelled outcome must not claim completion")
	_expect(fx.persisted.size() == 2,
		"cancel must persist active-safe and final checkpoints")
	_expect(director.take_blackout_reveal().has("position"),
		"settled changed geometry must offer one lights-on reveal")
	_expect(director.take_blackout_reveal().is_empty(),
		"settled lights-on reveal must be consumed once")
	fx.queue_free()
	manager.free()
	horror.free()
	await physics_frame


# ------------------------------------------------------------------- camping

func _audit_camping_timeout() -> void:
	var fx := _mount()
	var manager := ChunkManager.new()
	var horror := HorrorDirector.new()
	var director := _make_director(fx)
	var plan := fx.make_plan("a_open", "b_open", "lit", 0.6)
	_register(director, fx, manager, horror)
	var camper := SpatialTestBody.create()
	camper.position = Vector3(0, 0.1, -4)
	fx.add_body("camper", camper)
	await _frames(30)
	_make_eligible(director, SpatialDoorFixture.SITE_ID)
	director.event_finished.connect(_on_event_finished)
	director.request_event(SpatialDoorFixture.SITE_ID, plan)
	var frames := await _run_until_idle(director, 600)
	_expect(_finished == ["both_open_timeout"],
		"camper must force both-open timeout, got %s" % str(_finished))
	_finished.clear()
	_expect(frames < 600, "timeout must settle")
	var clearance := fx.site.current_clearance()
	_expect(clearance.traversable["a"] and clearance.traversable["b"],
		"timeout geometry must be both-open")
	var saved: SpatialSiteState = fx.persisted.back()
	_expect(saved.stable_phase == "both_open" and saved.completed,
		"timeout must persist completed both-open")
	fx.queue_free()
	manager.free()
	horror.free()
	await physics_frame


# ------------------------------------------------------- sprint + enemy sides

func _audit_sprint_crossing() -> void:
	var fx := _mount()
	var manager := ChunkManager.new()
	var horror := HorrorDirector.new()
	var director := _make_director(fx)
	var plan := fx.make_plan("a_open", "b_open", "lit")
	_register(director, fx, manager, horror)
	var runner := SpatialTestBody.create()
	runner.position = Vector3(0, 0.1, -7)
	fx.add_body("runner", runner)
	var foe := SpatialTestBody.create()
	foe.position = Vector3(7, 0.1, 0)
	fx.add_body("foe", foe)
	await _frames(30)
	_make_eligible(director, SpatialDoorFixture.SITE_ID)
	director.event_finished.connect(_on_event_finished)
	director.request_event(SpatialDoorFixture.SITE_ID, plan)
	# Runner launches so it reaches A mid-closure; foe drifts to open B.
	foe.planar_velocity = Vector3(-1.0, 0, 0)
	await _frames(110)
	runner.planar_velocity = Vector3(0, 0, 6.2)
	var frames := 0
	while director.is_active() and frames < 600:
		await physics_frame
		frames += 1
		if runner.position.z > -1.0:
			runner.planar_velocity = Vector3.ZERO
		if foe.position.x < 5.5:
			foe.planar_velocity = Vector3.ZERO
	_expect(_finished == ["completed_b_open"],
		"sprint event must complete, got %s" % str(_finished))
	_finished.clear()
	_expect(frames < 600, "sprint event must finish")
	_expect(runner.position.z > -2.0,
		"sprinter must cross A, stopped at %s" % str(runner.position))
	_expect(foe.position.x < 5.5, "foe must use open B freely")
	_expect(not _inside_solid(fx, runner),
		"sprinter must never end inside wall leaves")
	fx.queue_free()
	manager.free()
	horror.free()
	await physics_frame


func _inside_solid(fx: SpatialDoorFixture, body: SpatialTestBody) -> bool:
	var params := PhysicsPointQueryParameters3D.new()
	params.position = body.global_position + Vector3(0, 0.9, 0)
	params.collision_mask = 1
	params.exclude = [body.get_rid()]
	var hits: Array = root.world_3d.direct_space_state \
		.intersect_point(params)
	for hit in hits:
		var collider: Object = hit.get("collider")
		if collider is AnimatableBody3D:
			return true
	return false


# ------------------------------------------------------------- camera witness

func _audit_camera_path() -> void:
	var fx := _mount()
	var camera := Camera3D.new()
	camera.fov = 70.0
	camera.position = Vector3(0, 1.6, 2.5)
	fx.add_child(camera)
	camera.look_at(Vector3(0, 1.4, -4.0))
	await physics_frame
	var tracker := SpatialWitnessTracker.new()
	tracker.track_feature("opening_a", Vector3(0, 1.4, -4.0),
		Vector2(1.6, 1.35))
	for i in 14:
		tracker.sample(camera, 0.1, 2000.0 + i * 0.1)
	_expect(tracker.witness_eligible("opening_a", 2001.4),
		"framed aperture must become witness_eligible")
	# Same camera facing away: no eligibility.
	var tracker2 := SpatialWitnessTracker.new()
	tracker2.track_feature("opening_a", Vector3(0, 1.4, -4.0),
		Vector2(1.6, 1.35))
	camera.look_at(Vector3(0, 1.4, 10.0))
	for i in 14:
		tracker2.sample(camera, 0.1, 3000.0 + i * 0.1)
	_expect(not tracker2.witness_eligible("opening_a", 3001.4),
		"aperture behind the camera must not be eligible")
	fx.queue_free()
	await physics_frame


# --------------------------------------------------------------- persistence

func _audit_persistence() -> void:
	var fx := _offtree_fixture()
	var state := fx.make_state()
	state.stable_phase = "b_open"
	state.activated = true
	state.completed = true
	state.door_openness = {"a": 0.0, "b": 1.0}
	var disk := state.to_disk()
	var loaded := SpatialSiteState.from_disk(disk)
	_expect(loaded != null and loaded.matches(fx.spec),
		"disk round trip must preserve spec match")
	_expect(loaded.stable_phase == "b_open"
		and loaded.door_openness["b"] == 1.0,
		"disk round trip must preserve outcome")
	# Active saves reconstruct to a proven phase without mutating live physics.
	var active := fx.make_state()
	active.door_openness = {"a": 0.62, "b": 0.41}
	active.progress = 0.37
	var active_disk := active.to_disk()
	_expect(active_disk["phase"] == "both_open"
		and active_disk["door_a"] == 1.0 and active_disk["door_b"] == 1.0,
		"active disk form must reconstruct both-open")
	_expect(active.stable_phase == "a_open" and active.progress == 0.37
		and active.door_openness["a"] == 0.62,
		"active checkpoint serialization must not mutate live state")
	# Malformed records are discarded in isolation.
	var bad_phase := disk.duplicate(true)
	bad_phase["phase"] = "impossible"
	_expect(SpatialSiteState.from_disk(bad_phase) == null,
		"unknown saved phase must be rejected")
	var bad_number := disk.duplicate(true)
	bad_number["door_a"] = NAN
	_expect(SpatialSiteState.from_disk(bad_number) == null,
		"non-finite saved openness must be rejected")
	var missing_door := disk.duplicate(true)
	missing_door.erase("door_b")
	_expect(SpatialSiteState.from_disk(missing_door) == null,
		"incomplete aperture state must be rejected")
	# Compatibility signatures cover rotations and the semantic junction.
	var rotated_endpoints: Dictionary = fx.spec.endpoints.duplicate(true)
	var rotated: Transform3D = rotated_endpoints["a"]
	rotated.basis = Basis(Vector3.UP, 0.2) * rotated.basis
	rotated_endpoints["a"] = rotated
	var rotated_spec := SpatialSiteSpec.make_door(fx.spec.id, fx.spec.theme,
		fx.spec.generation_version, fx.spec.cells, fx.spec.anchor_ids,
		rotated_endpoints, fx.spec.allowed_phases, fx.spec.swept_bounds,
		fx.spec.witness_points, fx.spec.protected_routes)
	_expect(rotated_spec.signature != fx.spec.signature,
		"endpoint rotation must change the compatibility signature")
	var cells_a: Array[Vector2i] = [SpatialDoorFixture.CELL_J,
		SpatialDoorFixture.CELL_NA]
	var cells_b: Array[Vector2i] = [SpatialDoorFixture.CELL_NA,
		SpatialDoorFixture.CELL_J]
	var junction_a := SpatialSiteSpec.make_door(fx.spec.id, fx.spec.theme,
		fx.spec.generation_version, cells_a, fx.spec.anchor_ids,
		fx.spec.endpoints, fx.spec.allowed_phases, fx.spec.swept_bounds,
		fx.spec.witness_points, fx.spec.protected_routes)
	var junction_b := SpatialSiteSpec.make_door(fx.spec.id, fx.spec.theme,
		fx.spec.generation_version, cells_b, fx.spec.anchor_ids,
		fx.spec.endpoints, fx.spec.allowed_phases, fx.spec.swept_bounds,
		fx.spec.witness_points, fx.spec.protected_routes)
	_expect(junction_a.signature != junction_b.signature,
		"changing cells[0] must change the semantic-junction signature")
	# Rebuild from the loaded state: identical installed geometry.
	var site2 := MigratingDoorSite.new()
	fx.add_child(site2)
	var prepared := site2.prepare(fx.spec, loaded, {
		"wall_material": fx.wall_material,
		"trim_material": fx.trim_material,
		"ceiling_h": SpatialDoorFixture.CEIL_H,
		"pattern_tile_m": SpatialDoorFixture.TILE_M,
	})
	_expect(prepared.ok, "rebuild from disk state must prepare")
	var clearance := site2.current_clearance()
	_expect(not clearance.traversable["a"]
		and clearance.traversable["b"],
		"rebuilt geometry must match persisted b_open")
	# Progress record/load with an isolated save path.
	var test_path := "/tmp/liminal_audit_spatial_progress.cfg"
	var progress := DescentProgress.new(test_path)
	progress.start_new(4242)
	progress.record_site_state(0, state)
	var reread := DescentProgress.new(test_path)
	var restored := reread.site_state_for_floor(0, SpatialDoorFixture.SITE_ID)
	_expect(restored != null and restored.stable_phase == "b_open",
		"progress must round-trip site state")
	var missing := reread.site_state_for_floor(0, "no/such/site")
	_expect(missing == null, "unknown site must load as null")
	# A failed atomic write must not leave an in-memory record that a later,
	# unrelated successful save could accidentally make durable.
	var broken_path := "/tmp/liminal_missing_spatial_%d/progress.cfg" \
		% OS.get_process_id()
	var broken := DescentProgress.new(broken_path)
	broken.run_seed = 4242
	broken.deepest_floor = 0
	var save_error := broken.record_site_state(0, state)
	_expect(save_error != OK and broken.site_states.is_empty(),
		"failed atomic site save must roll back its in-memory entry")
	reread.clear_from_disk()
	_free_fixture(fx)

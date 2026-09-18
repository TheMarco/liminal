extends SceneTree
## Focused audit for Data Center charging density, determinism and clearance.

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _count_meta(node: Node, key: String) -> int:
	var total := 0
	for child in node.find_children("*", "Node3D", true, false):
		if child.has_meta(key):
			total += 1
	return total

func _count_true_meta(node: Node, key: String) -> int:
	var total := 0
	for child in node.find_children("*", "Node3D", true, false):
		if bool(child.get_meta(key, false)):
			total += 1
	return total

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	var extra_total := 0
	for seed_base in [918273, 271828, 314159]:
		var baseline := 0
		var extras := 0
		var candidates := 0
		for x in range(-3, 6):
			for z in range(-3, 6):
				var cell := Vector2i(x, z)
				var a := Chunk.new(WorldGen.level_seed(seed_base, 10), cell, 10)
				candidates += int(a._is_charging_station_cell())
				var stations := _count_meta(a, "charging_station")
				var extra := _count_true_meta(a, "data_center_extra_station")
				if stations > 0:
					_check(stations == 1 and extra <= 1, "seed %d cell %s station count %d" % [seed_base, cell, stations])
					_check(a.doorway_clearance_violations() == 0, "seed %d cell %s charging doorway clearance violation" % [seed_base, cell])
					for child in a.get_children():
						if child is ChargingStation:
							_check(not child.broken, "extra supply includes a broken charger")
							var geometry := ChargingStationPlacement.new(a)
							_check(geometry.clear(child.position, child.rotation.y, false,
								a._doorway_clearance_rects()), "charger cabinet/standing space obstructed")
				baseline += stations - extra
				extras += extra
				a.free()
				var b := Chunk.new(WorldGen.level_seed(seed_base, 10), cell, 10)
				_check(_count_meta(b, "charging_station") == stations and _count_true_meta(b, "data_center_extra_station") == extra,
					"seed %d cell %s station placement is not deterministic" % [seed_base, cell])
				b.free()
		_check(candidates == 12, "seed %d selected %d candidates instead of 12" % [seed_base, candidates])
		_check(baseline == 9, "seed %d changed baseline charging coverage (%d)" % [seed_base, baseline])
		_check(extras == 3, "seed %d lost a known-clear extra station (%d)" % [seed_base, extras])
		extra_total += extras
		print("seed %d: baseline=%d extra=%d" % [seed_base, baseline, extras])
	_check(extra_total >= 3, "Data Center extra station availability did not improve across seeds")
	_check(not ChunkManager.BROKEN_STATION_FLOORS.has(10), "Data Center breaks the added charging supply")
	if failures == 0:
		print("datacenter charging audit pass")
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	quit(1 if failures > 0 else 0)

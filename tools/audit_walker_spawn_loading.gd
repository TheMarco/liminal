extends SceneTree
## Exercise deferred and ready gameplay spawns with a tiny animation fixture,
## without decoding the large source models just to test the loading boundary.
## godot --headless --path . --script tools/audit_walker_spawn_loading.gd

var failures: Array[String] = []
var spawn_count := 0


class LoadingManager extends ShadowFigures:
	var loading := true

	func _walker_model_ready(index: int) -> bool:
		return false if loading else super._walker_model_ready(index)


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _fixture_scene() -> PackedScene:
	var model := Node3D.new()
	var animation_player := AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	model.add_child(animation_player)
	animation_player.owner = model
	var library := AnimationLibrary.new()
	library.add_animation(&"Walking", Animation.new())
	animation_player.add_animation_library(&"", library)
	var scene := PackedScene.new()
	check(scene.pack(model) == OK, "could not pack small walking fixture")
	model.free()
	return scene


func _run() -> void:
	var scene := _fixture_scene()
	for index in ShadowWalkerVisual.model_count():
		ShadowWalkerVisual._model_scenes[index] = scene
	check(not ShadowWalkerVisual.is_model_ready(-1), "negative model index was ready")
	check(not ShadowWalkerVisual.is_model_ready(ShadowWalkerVisual.model_count()),
		"out-of-range model index was ready")
	check(ShadowWalkerVisual.is_model_ready(0), "cached model was not ready")
	check(ShadowWalkerVisual._model_scene(0) == scene,
		"visual creation did not reuse the scene retained by readiness")

	var player := Player.new()
	var director := HorrorDirector.new()
	director.enabled = true
	var manager := LoadingManager.new()
	manager.player = player
	manager.horror_director = director
	manager.use_walker_prototype = true
	root.add_child(manager)
	manager.set_physics_process(false)
	var bag := manager._walker_model_bag.duplicate()
	var selected: int = bag.back()
	var ground := Vector3(12.0, 0.0, 6.0)
	manager._force_at = ground
	manager._force_variant = ShadowFigure.PILGRIM
	manager.spawned.connect(func(): spawn_count += 1)
	for attempt in 3:
		check(not manager._try_spawn(), "unfinished decode allowed a gameplay spawn")
		check(manager._walker_model_bag == bag, "deferred spawn consumed a roster design")
		check(manager._force_variant == ShadowFigure.PILGRIM,
			"deferred spawn consumed the forced variant")
		check(manager._force_at == ground, "deferred spawn consumed the forced position")
	check(manager.active_figures().is_empty() and manager.get_child_count() == 0,
		"deferred spawn created a partial figure")
	check(spawn_count == 0 and director._hostile_count == 0,
		"deferred spawn announced or started an encounter")

	manager.loading = false
	check(manager._try_spawn(), "ready model did not spawn on the next attempt")
	check(manager._walker_model_bag.size() == bag.size() - 1,
		"ready spawn did not consume exactly one roster design")
	check(manager._force_variant == -1 and manager._force_at == Vector3.INF,
		"successful spawn did not consume its forced encounter settings")
	check(spawn_count == 1 and director._hostile_count == 1,
		"successful spawn did not announce exactly one encounter")
	var figures := manager.active_figures()
	check(figures.size() == 1, "ready spawn did not create exactly one figure")
	if not figures.is_empty():
		var figure := figures[0]
		figure.set_physics_process(false)
		check(figure.walker_model_index == selected and figure.variant == ShadowFigure.PILGRIM,
			"ready spawn lost its selected design or forced variant")
		check(figure._walker != null and figure._walker.animation_player() != null,
			"ready spawn did not instantiate the cached animated scene")
	var picked := {selected: true}
	for draw in ShadowWalkerVisual.model_count() - 1:
		picked[manager._next_walker_model()] = true
	check(picked.size() == ShadowWalkerVisual.model_count() and not picked.has(-1),
		"ready shuffle bag repeated a design before the prototype roster completed")
	for path in ShadowWalkerVisual.MODEL_PATHS:
		check(ResourceLoader.load_threaded_get_status(path)
			== ResourceLoader.THREAD_LOAD_INVALID_RESOURCE,
			"cached spawn started an unnecessary source-model decode")

	manager.free()
	player.free()
	director.free()
	ShadowWalkerVisual._model_scenes.clear()
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	print("WALKER SPAWN LOADING: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

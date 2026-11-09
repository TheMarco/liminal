extends SceneTree
## Reproduce selection cost separately from rendering and floor loading.
## Defaults to the reported Annex floor seed. --out=res://build/...json
var output := "res://build/blackout-freeze/selection-before.json"

func _init() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	var began := Time.get_ticks_usec()
	var route := DescentRoute.build(1027169375,2,8)
	var built := Time.get_ticks_usec()
	var topology := DescentTopology.new(route.world_seed,2)
	route.set_topology(topology)
	topology.plan_floor(route)
	route.refresh_topology()
	print("BLACKOUT_SETUP route_ms=",(built-began)/1000.0," plan_ms=",(Time.get_ticks_usec()-built)/1000.0,
		" origin=",route.origin," states=",topology.state_count()," cells=",route._target_distance.size())
	var report := {"world_seed":route.world_seed,"theme":2,"samples":[]}
	var path := route.path_from_origin()
	var visited := {}
	for index in mini(12,path.size()):
		visited[path[index]] = true
		var started := Time.get_ticks_usec()
		var proposal := topology.find_transition(route,path[index],visited,false)
		var selection_ms := (Time.get_ticks_usec()-started)/1000.0
		var distances := []
		for state in range(1,topology.state_count()):
			started = Time.get_ticks_usec()
			var distance := topology.distance_to_target_for_state(route,path[index],state)
			distances.append({"state":state,"distance":distance,"ms":(Time.get_ticks_usec()-started)/1000.0})
		var record := {"cell":str(path[index]),"selection_ms":selection_ms,"distances":distances,
			"selected_state":proposal.to_state if proposal != null else -1}
		report.samples.append(record)
		print("BLACKOUT_SELECT ",JSON.stringify(record))
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	quit()

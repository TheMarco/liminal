extends SceneTree
## At real basin/channel joints, rim, rendered deck, solid deck and water
## must agree on BOTH sides of the curve, including across chunk boundaries.
var failures: Array[String] = []
var cases := 0
var samples := 0
var tops: Array[PackedVector2Array] = []
func _init() -> void: call_deferred("run")
func run() -> void:
	for base in [473692151, 1, 240721, 7117, 31337, 918273645, 246813579, 135792468]:
		var ws := WorldGen.level_seed(base,9)
		var count := 0
		for x in range(-8,9):
			if count >= 4: break
			for z in range(-8,9):
				if count >= 4: break
				var cell := Vector2i(x,z)
				if WorldGen.cell_style(ws,cell,9) != WorldGen.POOL_BASIN: continue
				var eligible := false
				for dir in [0,1]:
					var nb := cell+Vector2i(WorldGen.DIRV[dir])
					if not WorldGen.is_wall(ws,cell,dir,9) and WorldGen.cell_style(ws,nb,9)==WorldGen.POOL_CHANNEL:
						eligible=true
				if not eligible:continue
				var chunk := Chunk.new(ws,cell,9)
				var turns: Array[Node] = []
				for node in chunk.get_children():
					if node.has_meta("pool_connected_coping_path"):turns.append(node)
				if turns.is_empty():chunk.free();continue
				var stage := Node3D.new();root.add_child(stage);stage.add_child(chunk)
				var neighbors := {}
				for turn in turns:
					var dir := int(turn.get_meta("pool_connected_coping_dir"))
					if neighbors.has(dir):continue
					var offset := Vector2i(WorldGen.DIRV[dir])
					var other := Chunk.new(ws,cell+offset,9)
					other.position=Vector3(offset.x*12,0,offset.y*12)
					stage.add_child(other);neighbors[dir]=other
				tops.clear()
				for room: Chunk in stage.get_children():isolate_decks(room)
				var fx := preload("res://scripts/pool_water_interaction.gd").new()
				stage.add_child(fx)
				await physics_frame
				for turn in turns:
					var path: PackedVector2Array = turn.get_meta("pool_connected_coping_path")
					var dir := int(turn.get_meta("pool_connected_coping_dir"))
					var high: bool = turn.get_meta("pool_connected_coping_side")=="high"
					var water_sign := (1.0 if dir==0 else -1.0)*(-1.0 if high else 1.0)
					for i in range(1,path.size()-1):
						var u := path[i] - path[i-1]
						var v := path[i+1] - path[i]
						var area2 := absf(u.cross(v))
						if area2 > .000001:
							var radius := u.length()*v.length()*(u+v).length()/(2*area2)
							check(radius>.32,"Coping folds on tight turn seed%d cell%s" % [base,cell])
						var tangent := (path[i+1]-path[i-1]).normalized()
						var normal := tangent.rotated(water_sign*PI/2)
						var dry := path[i]-normal*.18
						var wet := path[i]+normal*.18
						var label := "seed%d cell%s dir%d sample%d" % [base,cell,dir,i]
						check(rendered(dry),label+" missing visible deck behind rim")
						check(not rendered(wet),label+" tile spike protrudes beyond rim")
						check(solid(dry),label+" missing deck collision")
						check(not solid(wet),label+" invisible square deck in water")
						check(fx.surface_height(Vector3(wet.x,1.0,wet.y)) > 1.0,label+" water gap at curved throat")
						check(fx.surface_height(Vector3(dry.x,1.0,dry.y)) < -1e8,label+" dry deck creates water effects")
						samples+=1
				cases+=1;count+=1;stage.free();await process_frame
		if count<4:failures.append("Too few connected fixtures for seed%d" % base)
	await preload("res://tools/lib/audit_cleanup.gd").release(self)
	for failure in failures:printerr(failure)
	print("POOL CORNER BOUNDARIES %s: %d rooms, %d paired shore samples" % ["PASS" if failures.is_empty() else "FAIL",cases,samples])
	quit(0 if failures.is_empty() else 1)

func isolate_decks(chunk: Chunk) -> void:
	for node in chunk.get_children():
		if node==chunk.body or node.has_meta("pool_water_surface") or node.has_meta("pool_connected_coping_path"):continue
		if node is MeshInstance3D and (node.has_meta("pool_basin_deck") or node.has_meta("pool_square_basin_corner_fill") or node.has_meta("pool_rounded_basin_corner")):
			var faces: PackedVector3Array = node.mesh.get_faces()
			for i in range(0,faces.size(),3):
				var a: Vector3 = node.global_transform*faces[i]
				var b: Vector3 = node.global_transform*faces[i+1]
				var c: Vector3 = node.global_transform*faces[i+2]
				if absf(a.y-1.42)<.002 and absf(b.y-1.42)<.002 and absf(c.y-1.42)<.002:
					tops.append(PackedVector2Array([Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z)]))
		else:node.free()
	for shape: CollisionShape3D in chunk.body.get_children():
		var keep := shape.has_meta("pool_deck_outline_collider") or shape.has_meta("pool_square_basin_corner_collider") or shape.has_meta("pool_rounded_basin_corner_collider")
		if shape.shape is BoxShape3D:
			keep = absf(shape.position.y+shape.shape.size.y*.5-1.42)<.002
		if not keep:shape.free()

func rendered(p: Vector2) -> bool:
	for tri in tops:
		var a := (tri[1]-tri[0]).cross(p-tri[0])
		var b := (tri[2]-tri[1]).cross(p-tri[1])
		var c := (tri[0]-tri[2]).cross(p-tri[2])
		if minf(a,minf(b,c))>=-.00001 or maxf(a,maxf(b,c))<=.00001:return true
	return false
func solid(p: Vector2) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(Vector3(p.x,1.7,p.y),Vector3(p.x,1.2,p.y),1)
	return not root.world_3d.direct_space_state.intersect_ray(ray).is_empty()
func check(ok: bool, message: String) -> void:
	if not ok:failures.append(message)

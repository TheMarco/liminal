extends SceneTree
## Dev: print the combined mesh AABB of each downloaded asylum model.
## Run: godot --headless --path . --script tools/dump_aabb.gd

# Use the runtime inventories so retired library assets cannot linger here.
const MODELS := Chunk.ASY_PROP_NAMES
const CC0_MODELS := Chunk.CC0_PROP_NAMES

const CC_BY_MODELS := [
	["res://models/cc_by/light_switch/light_switch.glb", "light_switch"],
	["res://models/cc_by/outlet/outlet.glb", "outlet"],
	["res://models/cc_by/stainless_steel_shelving/stainless_steel_shelving.glb",
		"stainless_steel_shelving"],
	["res://models/cc_by/prison_toilet/prison_toilet.glb", "prison_toilet"],
	["res://models/cc_by/prison_door_old/prison_door_old.glb", "prison_door_old"],
	["res://models/cc_by/solitary_cell_door/solitary_cell_door.glb",
		"solitary_cell_door"],
	["res://models/cc_by/fluorescent_light_fixtures/fluorescent_light_fixtures.glb",
		"fluorescent_light_fixtures"],
	["res://models/cc_by/bunk_bed/bunk_bed.glb", "bunk_bed"],
	["res://models/cc_by/server_v2_console/server_v2_console.glb",
		"server_v2_console"],
	["res://models/cc_by/server_rack/server_rack.glb", "server_rack"],
	["res://models/cc_by/data_center_server_rack/data_center_server_rack.glb",
		"data_center_server_rack"],
	["res://models/cc_by/network_server_rack/network_server_rack.glb",
		"network_server_rack"],
	["res://models/cc_by/server_racking_system/server_racking_system.glb",
		"server_racking_system"],
	["res://models/cc_by/server/server.glb", "server"],
	["res://models/cc_by/tall_server_of_base_with_azure_lane_island/" +
		"tall_server_of_base_with_azure_lane_island.glb", "tall_server_azure"],
	["res://models/cc_by/air_conditioners/air_conditioners.glb",
		"air_conditioners"],
]


func _init() -> void:
	for m in MODELS:
		_dump("res://models/asylum/%s/%s_1k.gltf" % [m, m], m)
	for m in CC0_MODELS:
		var path := "res://models/cc0/%s/%s_1k.gltf" % [m, m]
		_dump(path, m)
	_dump(Chunk.OFFICE_CHAIR_PATH, "office_chair")
	for entry in CC_BY_MODELS:
		_dump(entry[0], entry[1])
	quit()


func _dump(path: String, m: String) -> void:
	var ps: PackedScene = load(path)
	if ps == null:
		print(m, "  LOAD FAILED")
		return
	var n: Node3D = ps.instantiate()
	var bb := _aabb(n, Transform3D.IDENTITY)
	print("%s  pos %s  size %s" % [m, bb.position, bb.size])
	n.free()


func _aabb(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	if n is Node3D:
		xf = xf * (n as Node3D).transform
	if n is MeshInstance3D:
		out = xf * (n as MeshInstance3D).mesh.get_aabb()
		first = false
	for c in n.get_children():
		var bb := _aabb(c, xf)
		if bb.size != Vector3.ZERO:
			out = bb if first else out.merge(bb)
			first = false
	return out

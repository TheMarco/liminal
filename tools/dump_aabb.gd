extends SceneTree
## Dev: print the combined mesh AABB of each downloaded asylum model.
## Run: godot --headless --path . --script tools/dump_aabb.gd

const MODELS := [
	"old_bed_frame", "wheelchair_01", "BarberShopChair_01", "metal_office_desk",
	"SchoolChair_01", "medical_box", "vintage_crutches_01", "Rockingchair_01",
	"mounted_fluorescent_lights",
]

const CC0_MODELS := [
	"sofa_03", "ArmChair_01", "CoffeeTable_01", "Chandelier_03",
	"fancy_picture_frame_01", "fancy_picture_frame_02", "bar_chair_round_01",
	"vintage_grandfather_clock_01", "potted_plant_01", "Ottoman_01",
	"television_02", "CoffeeCart_01", "drawer_cabinet", "clipboard",
	"wall_clock", "steel_frame_shelves_01", "potted_plant_02",
	"WetFloorSign_01", "coffee_table_round_01",
	"industrial_caged_sconce", "hanging_industrial_lamp", "Barrel_01",
	"barrel_03", "wooden_crate_02", "old_tyre", "rusted_wheel_rim_01",
	"power_box_01", "wooden_ladder", "trashbag", "plastic_crate_03",
	"street_lamp_01", "wooden_picnic_table", "Lantern_01",
	"wooden_barrels_01", "barrel_stove", "tree_stump_01",
	"rusted_wheel_rim_02", "wooden_crate_01", "vintage_suitcase",
]


func _init() -> void:
	for m in MODELS:
		_dump("res://models/asylum/%s/%s_1k.gltf" % [m, m], m)
	for m in CC0_MODELS:
		_dump("res://models/cc0/%s/%s_1k.gltf" % [m, m], m)
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

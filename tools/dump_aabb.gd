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
	"book_encyclopedia_set_01", "bunsen_burner", "chemistry_set",
	"office_notepads", "old_military_compressor", "projector_screen",
	"security_camera_01", "stationery_supplies", "office_chair",
	"CashRegister_01", "hand_truck", "industrial_storage_cart",
	"metal_trash_can", "long_life_food", "plunger", "drain_cleaner",
	"can_rusted",
]

const CC_BY_MODELS := [
	["res://models/cc_by/light_switch/light_switch.glb", "light_switch"],
	["res://models/cc_by/outlet/outlet.glb", "outlet"],
	["res://models/cc_by/stainless_steel_shelving/stainless_steel_shelving.glb",
		"stainless_steel_shelving"],
	["res://models/cc_by/slot_machine/slot_machine.glb", "slot_machine"],
	["res://models/cc_by/prison_toilet/prison_toilet.glb", "prison_toilet"],
	["res://models/cc_by/prison_door_old/prison_door_old.glb", "prison_door_old"],
	["res://models/cc_by/solitary_cell_door/solitary_cell_door.glb",
		"solitary_cell_door"],
	["res://models/cc_by_nc/prison_bunk_bed/prison_bunk_bed.glb",
		"prison_bunk_bed"],
]


func _init() -> void:
	for m in MODELS:
		_dump("res://models/asylum/%s/%s_1k.gltf" % [m, m], m)
	for m in CC0_MODELS:
		var path := "res://models/cc0/office_chair/Office_Chair.fbx" if m == "office_chair" \
			else "res://models/cc0/%s/%s_1k.gltf" % [m, m]
		_dump(path, m)
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

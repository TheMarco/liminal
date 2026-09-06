extends RefCounted

static func cases() -> Array:
	return [
		{"camera_fov":34.0, "name":"vegas-slot-classic", "theme":0, "method":"_authored_slot_machine", "args":[6.0,6.0,1.0,0,0], "baseline_method":"_slot_machine", "baseline_args":[6.0,6.0,1.0,0]},
		{"camera_fov":34.0, "name":"vegas-slot-wheel", "theme":0, "method":"_authored_slot_machine", "args":[6.0,6.0,1.0,0,1], "baseline_method":"_slot_machine", "baseline_args":[6.0,6.0,1.0,0]},
		{"camera_fov":34.0, "name":"vegas-slot-dual", "theme":0, "method":"_authored_slot_machine", "args":[6.0,6.0,1.0,0,2], "baseline_method":"_slot_machine_alt", "baseline_args":[6.0,6.0,1.0,0]},
		{"camera_fov":34.0, "name":"vegas-slot-triple", "theme":0, "method":"_authored_slot_machine", "args":[6.0,6.0,1.0,0,3], "baseline_method":"_slot_machine_alt", "baseline_args":[6.0,6.0,1.0,0]},
		{"name":"vegas-service-cart", "theme":0, "method":"_casino_service_cart", "args":[Vector3(6,0,6),7]},
		{"name":"vegas-ballroom", "theme":0, "method":"_casino_ballroom", "args":[]},
		{"name":"office-floor-files", "theme":1, "method":"_office_floor_files", "args":[Vector3(6,0,6),7]},
		{"name":"office-door-sign", "theme":1, "method":"_office_corridor_door", "args":[Vector3(6,0,6),0.0,0.0,-4.0,7]},
		{"name":"office-directory", "theme":1, "method":"_office_corridor_directory", "args":[Vector3(6,0,6),0.0,-4.0,0.0]},
		{"name":"office-desk", "theme":1, "method":"_office_desk", "args":[Vector3(6,0,6),Vector2(0,1),7]},
		{"name":"office-dept-sign", "theme":1, "method":"_office_dept_sign", "args":[true]},
		{"name":"office-break", "theme":1, "method":"_office_break", "args":[]},
		{"name":"office-boardroom", "theme":1, "method":"_office_boardroom", "args":[]},
		{"name":"annex-furniture-pile", "theme":2, "seed":2, "cell":Vector2i(-4, 6), "method":"_annex_furniture_pile", "args":[]},
		{"name":"mall-display-table", "theme":7, "method":"_mall_display_table", "args":[Vector3(6,0,6),0.0,7]},
		{"name":"mall-wall-shelves", "theme":7, "seed":1, "cell":Vector2i(-8, -8), "method":"_mall_shelves", "args":[0,7]},
		{"name":"mall-garment-rack", "theme":7, "method":"_mall_rack", "args":[Vector3(6,0,6),0.0,7]},
		{"name":"mall-checkout-counter", "theme":7, "method":"_mall_counter", "args":[Vector3(6,0,6),0.0]},
		{"name":"mall-gondola", "theme":7, "method":"_mall_gondola", "args":[Vector3(6,0,6),0.0,5.2,7]},
		{"name":"mall-atrium-fountain", "theme":7, "method":"_mall_atrium", "args":[]},
		{"name":"mall-kiosk", "theme":7, "method":"_mall_kiosk", "args":[Vector3(6,0,6),0.0,7]},
		{"name":"mall-food-vendor", "theme":7, "method":"_mall_foodcourt", "args":[]},
		{"name":"mall-cinema-counter-poster", "theme":7, "method":"_mall_cinema", "args":[]},
	]

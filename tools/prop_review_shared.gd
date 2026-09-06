extends RefCounted

static func cases() -> Array:
	return [
		{"name":"shared-filing", "theme":1, "method":"_filing_bank", "args":[3,0.075]},
		{"name":"shared-terminal", "theme":1, "method":"_vt100", "args":[Vector3(6,0,6),0.0]},
		{"name":"shared-keyboard", "theme":1, "method":"_vt100_keyboard", "args":[Vector3(6,0,6),0.0]},
		{"name":"shared-shelf", "theme":1, "method":"_shelf_unit", "args":[Vector3(6,0,6),true,7]},
		{"name":"shared-desk", "theme":1, "method":"_small_desk", "args":[Vector3(6,0,6),0.0]},
		{"name":"bloom-pod", "theme":11, "method":"_incubator_pod", "args":[Vector3(6,0,6),Vector3.ONE,0.3]},
		{"name":"bloom-bleachers", "theme":11, "method":"_bleachers", "args":[Vector3(6,0,6),0.0,false]},
		{"name":"bloom-hoop", "theme":11, "method":"_basketball_hoop", "args":[Vector3(6,0,6),0.0]},
		{"name":"data-beacon", "theme":10, "method":"_emergency_beacon", "args":[Vector3(6,0,6)]},
		{"name":"data-busway", "theme":10, "method":"_overhead_busways", "args":[true,[6.0],3.8,8.0]},
		{"name":"pool-ceiling-light", "theme":9, "method":"_pool_round_ceiling_fixture", "args":[Vector2(6,6),0]},
		{"name":"pool-handrail", "theme":9, "method":"_pool_handrail", "args":[3,1.4]},
	]

extends RefCounted


static func cases() -> Array:
	return [
		{"name":"airport-column", "theme":4, "method":"_air_column", "args":[Vector2(6, 6)]},
		{"name":"airport-trolley", "theme":4, "method":"_air_trolley", "args":[Vector3(6, 0, 6), 0.0, 7, 1]},
		{"name":"airport-stanchions", "theme":4, "method":"_stanchion_line", "args":[Vector3(3, 0, 6), Vector3(9, 0, 6), 4]},
		{"name":"airport-plane", "theme":4, "method":"_air_docked_plane", "parent":true, "args":[]},
		{"name":"airport-jetway", "theme":4, "method":"_air_jetway", "parent":true, "args":[]},
		{"name":"airport-gate-desk", "theme":4, "method":"_air_gate_desk", "args":[Vector3(6, 0, 6), 0.0, "B12"]},
		{"name":"airport-travelator", "theme":4, "method":"_travelator", "args":[Vector3(6, 0, 6), 0.0, 1.0, 7, 8.4]},
		{"name":"airport-baggage", "theme":4, "method":"_air_baggage", "args":[]},
		{"name":"airport-escalator-flight", "theme":4, "method":"_escalator_flight", "args":[Vector3(6, 0, 6), 0.0, 0.0]},
		{"name":"asylum-restraint", "theme":5, "method":"_asy_restraint_table", "args":[Vector3(6, 0, 6), 0.0]},
		{"name":"asylum-ect", "theme":5, "method":"_asy_ect", "args":[Vector3(6, 0, 6), 0.0, 7]},
		{"name":"asylum-wire", "theme":5, "method":"_asy_wire", "parent":true, "args":[Vector3(-0.3, 0.2, 0), Vector3(0.3, 1.0, 0)]},
		{"name":"asylum-tub", "theme":5, "method":"_asy_tub", "args":[Vector3(6, 0, 6), 0.0, 7]},
		{"name":"asylum-straitjacket", "theme":5, "method":"_asy_straitjacket", "args":[3, 0.075]},
		{"name":"asylum-noticeboard", "theme":5, "method":"_asy_noticeboard", "args":[3, 0.075]},
		{"name":"asylum-dayroom-table", "theme":5, "method":"_asy_dayroom_table", "args":[Vector3(6, 0, 6), 7]},
		{"name":"asylum-chemistry-counter", "theme":5, "method":"_asy_chemistry_counter", "args":[Vector3(6, 0, 6), 0.0, 7]},
	]

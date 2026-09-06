extends RefCounted


static func cases() -> Array:
	return [
		# School: standalone procedural families.
		{"name":"school-chalkboard", "theme":6, "seed":1, "cell":Vector2i(-8, -8), "method":"_sch_chalkboard", "args":[0]},
		{"name":"school-projector-screen", "theme":6, "method":"_sch_screen", "args":[3]},
		{"name":"school-cupboard", "theme":6, "method":"_sch_cupboard", "args":[Vector3(6, 0, 6), 0.0, 7]},
		{"name":"school-cafeteria-table", "theme":6, "method":"_sch_caf_table", "args":[Vector3(6, 0, 6), 0.0, 7]},
		{"name":"school-servery", "theme":6, "method":"_sch_servery", "args":[3]},
		{"name":"school-bathroom-stalls", "theme":6, "method":"_sch_stalls", "args":[3]},
		{"name":"school-mirror-sinks", "theme":6, "method":"_sch_sinks", "args":[3]},
		{"name":"school-basketball-hoop", "theme":6, "method":"_sch_hoop", "args":[Vector3(6, 0, 6), 0.0]},
		{"name":"school-bleachers", "theme":6, "method":"_sch_bleachers", "args":[Vector3(6, 0, 6), 0.0, 8.0]},
		{"name":"school-library-stack", "theme":6, "method":"_sch_stack", "args":[Vector3(6, 0, 6), 0.0, 7]},
		{"name":"school-lab-stool", "theme":6, "method":"_sch_stool", "args":[Vector3(6, 0, 6), 7]},
		{"name":"school-noticeboard", "theme":6, "method":"_sch_noticeboard", "args":[3, 0.075]},
		{"name":"school-trophy-case", "theme":6, "method":"_sch_case", "args":[3, 0.075]},

		# School rooms exercise wall selection and repeated inline placement.
		{"name":"school-classroom-room", "theme":6, "method":"_sch_classroom", "args":[]},
		{"name":"school-cafeteria-room", "theme":6, "method":"_sch_cafeteria", "args":[]},
		{"name":"school-bathroom-room", "theme":6, "method":"_sch_bathroom", "args":[]},
		{"name":"school-gym-room", "theme":6, "method":"_sch_gym", "args":[]},
		{"name":"school-library-room", "theme":6, "method":"_sch_library", "args":[]},
		{"name":"school-lab-room", "theme":6, "method":"_sch_lab", "args":[]},

		# Prison: standalone assemblies and room-bound fixture groups.
		{"name":"prison-gate-bars", "theme":8, "method":"_prison_bars", "args":[Vector3(6, 0, 6), 0.0, 4.1, 2.75, true, false]},
		{"name":"prison-shakedown-table-room", "theme":8, "method":"_prison_corridor", "args":[]},
		{"name":"prison-writing-table-room", "theme":8, "method":"_prison_cells", "args":[]},
		{"name":"prison-mess-table", "theme":8, "method":"_prison_mess_table", "args":[Vector3(6, 0, 6), 0.0]},
		{"name":"prison-mess-serving-room", "theme":8, "method":"_prison_mess", "args":[]},
		{"name":"prison-shower-station", "theme":8, "method":"_prison_shower_station", "args":[3, 6.0]},
		{"name":"prison-shower-room", "theme":8, "seed":1, "cell":Vector2i(-8, -8), "method":"_prison_shower", "args":[]},
		{"name":"prison-guard-room", "theme":8, "method":"_prison_guard", "args":[]},
		{"name":"prison-workshop-room", "theme":8, "method":"_prison_industry", "args":[]},
		{"name":"prison-visitation-booth", "theme":8, "method":"_prison_visitation_booth", "args":[Vector3(6, 0, 6)]},
		{"name":"prison-visitation-room", "theme":8, "method":"_prison_visitation", "args":[]},
	]

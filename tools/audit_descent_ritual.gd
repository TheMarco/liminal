extends SceneTree
## Structural contract for the end-of-floor ritual room: every non-final
## Descent objective cell must contain the lift, the media altar (table, CRT,
## VCR, screen, tape interactable) and its own charging station, and the
## bleed pass must decorate ordinary cells without touching objective cells.
## Run: godot --headless --path . --script tools/audit_descent_ritual.gd

const SEEDS := [405195947, 7, 1234577]


func _init() -> void:
	call_deferred("_run")


func _has_meta_node(node: Node, meta: String) -> bool:
	if node.has_meta(meta):
		return true
	for child in node.get_children():
		if _has_meta_node(child, meta):
			return true
	return false


func _has_enabled_gi(node: Node) -> bool:
	if node is GeometryInstance3D and (node as GeometryInstance3D).gi_mode \
			!= GeometryInstance3D.GI_MODE_DISABLED:
		return true
	for child in node.get_children():
		if _has_enabled_gi(child):
			return true
	return false


func _has_attributed_asset(node: Node, path: String) -> bool:
	if str(node.get_meta("attributed_asset", "")) == path:
		return true
	for child in node.get_children():
		if _has_attributed_asset(child, path):
			return true
	return false


func _run() -> void:
	var failures: Array[String] = []
	# Casino -> Mall carts are a late escape-lift cue, not ordinary Vegas
	# furnishing. Exercise both the spatial and timing halves of that contract.
	var casino_seed := WorldGen.level_seed(SEEDS[0], 0)
	var escape := Vector2i(17, 17)
	var early := Chunk.new(casino_seed, escape + Vector2i(1, 0), 0, {
		"descent": true, "bleed": 0.0, "bleed_theme": 7,
		"bleed_target": escape,
	})
	if _has_attributed_asset(early, Chunk.MALL_SHOPPING_CART_PATH):
		failures.append("Casino -> Mall cart appeared before bleed began")
	early.free()
	var far := Chunk.new(casino_seed, escape + Vector2i(2, 0), 0, {
		"descent": true, "bleed": 1.0, "bleed_theme": 7,
		"bleed_target": escape,
	})
	far._place_bleed_prop(Vector3(6.0, 0.0, 6.0), 0.0)
	if _has_attributed_asset(far, Chunk.MALL_SHOPPING_CART_PATH):
		failures.append("Casino -> Mall cart escaped the lift neighbourhood")
	far.free()
	var near := Chunk.new(casino_seed, escape + Vector2i(1, 0), 0, {
		"descent": true, "bleed": 1.0, "bleed_theme": 7,
		"bleed_target": escape,
	})
	near._place_bleed_prop(Vector3(6.0, 0.0, 6.0), 0.0)
	if not _has_attributed_asset(near, Chunk.MALL_SHOPPING_CART_PATH):
		failures.append("Casino -> Mall cart missing beside the escape lift")
	near.free()
	for base in SEEDS:
		var order := DescentRun.order_for(base)
		if order.size() != DescentRun.FLOOR_COUNT:
			failures.append("seed %d: order has %d floors" % [base, order.size()])
		if order != DescentRun.FIXED_ORDER:
			failures.append("seed %d: story order changed: %s" % [base, order])
		# One early, one late non-final floor per seed keeps this fast.
		for floor_idx in [1, 8]:
			var theme: int = order[floor_idx]
			var ws := WorldGen.level_seed(base, theme)
			var route := DescentRoute.build(ws, theme, floor_idx)
			if route.objective_ritual_cell() != route.target:
				failures.append("seed %d floor %d: mandatory altar is not at lift" % [
					base, floor_idx + 1])
			var target := Chunk.new(ws, route.target, theme, {
				"descent": true,
				"target": true,
				"target_wall": route.target_wall,
				"floor_idx": floor_idx,
				"base_seed": base,
			})
			var label := "seed %d floor %d theme %d" % [base, floor_idx + 1, theme]
			# The altar assembles its interactable in _ready, so it needs a
			# frame in the tree before it can be inspected.
			root.add_child(target)
			if not target.has_node("DescentRitual"):
				failures.append(label + ": objective has no ritual altar")
			else:
				var ritual := target.get_node("DescentRitual")
				if ritual.get_node_or_null("DescentTapePlay") == null:
					failures.append(label + ": ritual has no tape interactable")
			if not _has_meta_node(target, "charging_station"):
				failures.append(label + ": objective has no charging station")
			if target.find_children("DescentLiftCall", "", true, false).is_empty():
				failures.append(label + ": objective has no lift call")
			if target.descent_lift_ready():
				failures.append(label + ": lift admitted an unwatched player")
			target.descent_tape_watched = true
			if not target.descent_lift_ready():
				failures.append(label + ": watched tape did not unlock the lift")
			root.remove_child(target)
			target.free()
			# A fully bled ordinary neighbour must carry an intrusion for at
			# least one lattice cell nearby; scan a handful for one hit.
			var bled_hit := false
			for probe in 8:
				var at := route.target + Vector2i(2 + probe, 1)
				var bled := Chunk.new(ws, at, theme, {
					"descent": true,
					"bleed": 1.0,
					"bleed_theme": order[floor_idx + 1],
				})
				var found := false
				for child in bled.get_children():
					if child.has_meta("bleed_prop"):
						found = true
						if _has_enabled_gi(child):
							failures.append(label \
								+ ": streamed bleed prop still participates in SDFGI")
						break
				bled.free()
				if found:
					bled_hit = true
					break
			if not bled_hit:
				failures.append(label + ": full bleed decorated none of 8 cells")
	for failure in failures:
		print("  FAIL " + failure)
	if failures.is_empty():
		print("descent ritual audit: PASS — tape-only lift gate, altar, station, fixed order, bleed")
		quit()
	else:
		quit(1)

extends SceneTree
## Structural fingerprint of generated chunks. The refactor contract is that
## observable generation does not change, and Chunk._r() is a pure hash of
## (seed, cell, salt) rather than a sequential stream, so moving code between
## files must reproduce the scene graph exactly. This walks a fixed matrix of
## (seed, theme, cell) chunks and prints one digest line per chunk: any change
## to a transform, mesh, light, collider, label, material or attribution meta
## moves that line's hash.
##
## Cells are chosen by style so every WorldGen.cell_style value a theme can
## produce is represented, plus the spawn cell, a multi-cell room anchor and a
## member cell of the same room. Descent variants cover the lift rig, the
## arrival car, the final floor and a blackout.
##
## Run:
##   godot --headless --path . --script tools/audit_world_hash.gd -- [args]
##
##   --out=PATH      write the digest to PATH (default tools/golden/world_hash.txt)
##   --check=PATH    compare against PATH and fail on any differing line
##   --dump=PATH     also write the per-node detail used to build each hash,
##                   so a changed hash can be diffed down to the node
##
## Typical use around a refactor phase:
##   godot --headless --path . --script tools/audit_world_hash.gd -- --dump=/tmp/before.txt
##   ...make the change...
##   godot --headless --path . --script tools/audit_world_hash.gd \
##       -- --check=tools/golden/world_hash.txt --dump=/tmp/after.txt
##   diff /tmp/before.txt /tmp/after.txt
##
## The digest is only comparable between runs of the SAME Godot build: it
## records exact geometry to 5 decimals, and patch releases are free to change
## float formatting or mesh generation internals. It is a local phase gate,
## not a cross-version CI assertion.

const SEEDS := [1, 31337, 240721]
const SCAN_R := 18
const DEFAULT_OUT := "res://tools/golden/world_hash.txt"

## A real chunk is floor, ceiling and four wall segments at minimum. Anything at
## or below this is evidence that construction did not run.
const MIN_NODES := 6

var _dump_lines: PackedStringArray = []
var _dump_wanted := false
var _thin_chunks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var out_path := DEFAULT_OUT
	var check_path := ""
	var dump_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
		elif arg.begins_with("--check="):
			check_path = arg.trim_prefix("--check=")
		elif arg.begins_with("--dump="):
			dump_path = arg.trim_prefix("--dump=")
	_dump_wanted = not dump_path.is_empty()

	var lines: PackedStringArray = []
	lines.append("# liminal world structure digest")
	lines.append("# columns: seed theme cell style nodes hash")
	var chunk_count := 0
	for ws_base in SEEDS:
		for theme in WorldGen.THEMES:
			var ws := WorldGen.level_seed(ws_base, theme)
			for entry in _cells_for(ws, theme):
				var cell: Vector2i = entry[0]
				var label: String = entry[1]
				var config: Dictionary = entry[2]
				lines.append(_digest(ws_base, ws, theme, cell, label, config))
				chunk_count += 1

	print("world hash: %d chunks over %d seeds x %d themes" % [
		chunk_count, SEEDS.size(), WorldGen.THEMES.size()])

	# A GDScript compile failure anywhere in the preload graph (chunk.gd pulls in
	# every level builder) does not stop this script: Chunk.new() keeps returning
	# an object that builds nothing, and the digest silently becomes a file full
	# of empty rooms that compares equal to itself. Refuse to emit that.
	if _thin_chunks > 0:
		printerr(("world hash: %d of %d chunks produced almost no nodes. " +
			"That means Chunk failed to compile or build, not that the world " +
			"changed — fix the compile error before trusting any digest.") % [
				_thin_chunks, chunk_count])
		quit(1)
		return

	if _dump_wanted:
		_write(dump_path, _dump_lines)
		print("  node detail written to %s (%d lines)" % [
			dump_path, _dump_lines.size()])

	Chunk.finish_prop_preloads()

	if check_path.is_empty():
		_write(out_path, lines)
		print("  digest written to %s" % out_path)
		quit()
		return

	var expected := _read(check_path)
	if expected.is_empty():
		push_error("world hash: golden file %s is missing or empty" % check_path)
		quit(1)
		return
	var diffs := 0
	var limit := maxi(lines.size(), expected.size())
	for i in limit:
		var got := lines[i] if i < lines.size() else "<missing>"
		var want := expected[i] if i < expected.size() else "<missing>"
		if got == want:
			continue
		diffs += 1
		if diffs <= 20:
			printerr("  CHANGED  expected: %s" % want)
			printerr("                got: %s" % got)
	if diffs > 0:
		printerr("WORLD HASH CHANGED: %d of %d lines differ from %s" % [
			diffs, limit, check_path])
		printerr("Generation is not byte-identical. Re-run with --dump= before " +
			"and after to find the node that moved.")
		quit(1)
		return
	print("  PASS — generation identical to %s" % check_path)
	quit()


## Cells worth fingerprinting for a theme: the spawn cell, one representative of
## every style the theme produces within SCAN_R, a multi-cell room anchor and a
## member of that same room (anchors furnish, members do not), and the descent
## variants. Selecting by style keeps coverage complete without hard-coding
## cells that a generation change could silently make uninteresting.
func _cells_for(ws: int, theme: int) -> Array:
	var result: Array = []
	var seen_styles := {}
	var anchor_found := Vector2i.ZERO
	var member_found := Vector2i.ZERO
	var have_pair := false

	result.append([Vector2i.ZERO, "spawn", {}])
	seen_styles[WorldGen.cell_style(ws, Vector2i.ZERO, theme)] = true

	for r in range(1, SCAN_R + 1):
		for x in range(-r, r + 1):
			for z in range(-r, r + 1):
				# ring walk keeps the first match for a style at the smallest
				# radius, so the selection is stable and near the origin
				if maxi(absi(x), absi(z)) != r:
					continue
				var cell := Vector2i(x, z)
				var style := WorldGen.cell_style(ws, cell, theme)
				if not seen_styles.has(style):
					seen_styles[style] = true
					result.append([cell, "style", {}])
				if have_pair:
					continue
				var root: Vector2i = WorldGen.annex_room_id(ws, cell) if theme == 2 \
					else WorldGen.room_id(ws, cell)
				var size: int = WorldGen.annex_room_size(ws, root) if theme == 2 \
					else WorldGen.room_size(ws, root)
				if size >= 2 and root != cell and root != Vector2i.ZERO:
					anchor_found = root
					member_found = cell
					have_pair = true
	if have_pair:
		result.append([anchor_found, "anchor", {}])
		result.append([member_found, "member", {}])

	# Descent dressing is generated construction too: the objective lift, the
	# arrival car, the final floor's exit and a blacked-out room all add nodes
	# during _init and would otherwise go unfingerprinted.
	result.append([Vector2i(2, 1), "descent", {
		"descent": true, "floor_idx": 1,
	}])
	result.append([Vector2i(2, 1), "descent_target", {
		"descent": true, "target": true, "target_wall": 0, "floor_idx": 1,
	}])
	result.append([Vector2i(3, -2), "descent_target_called", {
		"descent": true, "target": true, "target_wall": 2, "floor_idx": 2,
		"lift_called": true, "lift_open": true, "lift_wait": 0.0,
	}])
	result.append([Vector2i(-1, 4), "descent_arrival", {
		"descent": true, "arrival": true, "arrival_wall": 1, "floor_idx": 1,
	}])
	result.append([Vector2i(1, 5), "descent_final", {
		"descent": true, "target": true, "target_wall": 3, "final": true,
		"floor_idx": 8,
	}])
	result.append([Vector2i(-3, -3), "descent_blackout", {
		"descent": true, "floor_idx": 3, "blackout": true,
	}])
	return result


func _digest(ws_base: int, ws: int, theme: int, cell: Vector2i, label: String,
		config: Dictionary) -> String:
	var chunk := Chunk.new(ws, cell, theme, config)
	var parts: PackedStringArray = []
	_walk(chunk, "", parts)
	var body := "\n".join(parts)
	if _dump_wanted:
		_dump_lines.append("=== seed %d theme %d cell %s %s (style %d) ===" % [
			ws_base, theme, cell, label, chunk.style])
		_dump_lines.append_array(parts)
	var style := chunk.style
	if parts.size() <= MIN_NODES:
		_thin_chunks += 1
	chunk.free()
	return "%d %d %s %s %d %d %s" % [
		ws_base, theme, "%d,%d" % [cell.x, cell.y], label, style,
		parts.size(), _hash(body)]


## Depth-first in child order, which GDScript guarantees is construction order.
## The path prefix is index-based rather than name-based: Godot appends numeric
## suffixes to duplicate node names using a global counter, so names are not
## stable between runs that build different chunk sets.
func _walk(node: Node, path: String, parts: PackedStringArray) -> void:
	parts.append("%s|%s" % [path, _node_sig(node)])
	var index := 0
	for child in node.get_children():
		_walk(child, "%s/%d" % [path, index], parts)
		index += 1


func _node_sig(node: Node) -> String:
	var bits: PackedStringArray = [node.get_class()]
	if node is Node3D:
		var t: Transform3D = (node as Node3D).transform
		bits.append("x=%s" % _v3(t.origin))
		bits.append("bx=%s" % _v3(t.basis.x))
		bits.append("by=%s" % _v3(t.basis.y))
		bits.append("bz=%s" % _v3(t.basis.z))
		if not (node as Node3D).visible:
			bits.append("hidden")
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mesh := mi.mesh
		if mesh == null:
			bits.append("mesh=null")
		else:
			bits.append("mesh=%s" % mesh.get_class())
			bits.append("aabb=%s+%s" % [_v3(mesh.get_aabb().position),
				_v3(mesh.get_aabb().size)])
			bits.append("surf=%d" % mesh.get_surface_count())
			for s in mesh.get_surface_count():
				bits.append("m%d=%s" % [s, _mat_sig(mi.get_active_material(s))])
		bits.append("cast=%d" % mi.cast_shadow)
		if mi.material_override != null:
			bits.append("over=%s" % _mat_sig(mi.material_override))
	if node is Light3D:
		var l := node as Light3D
		bits.append("col=%s" % _col(l.light_color))
		bits.append("e=%s" % _f(l.light_energy))
		bits.append("shadow=%s" % ("1" if l.shadow_enabled else "0"))
		bits.append("fade=%s/%s/%s" % [
			"1" if l.distance_fade_enabled else "0",
			_f(l.distance_fade_begin), _f(l.distance_fade_length)])
		if l is OmniLight3D:
			bits.append("range=%s" % _f((l as OmniLight3D).omni_range))
		if l is SpotLight3D:
			bits.append("spot=%s/%s" % [_f((l as SpotLight3D).spot_range),
				_f((l as SpotLight3D).spot_angle)])
	if node is CollisionShape3D:
		bits.append("shape=%s" % _shape_sig((node as CollisionShape3D).shape))
	if node is CollisionObject3D:
		var co := node as CollisionObject3D
		bits.append("layer=%d/%d" % [co.collision_layer, co.collision_mask])
	if node is Label3D:
		var lb := node as Label3D
		bits.append("text=%s" % lb.text.replace("\n", "\\n"))
		bits.append("fs=%d" % lb.font_size)
		bits.append("px=%s" % _f(lb.pixel_size))
		bits.append("mod=%s" % _col(lb.modulate))
	if node is GPUParticles3D:
		var p := node as GPUParticles3D
		bits.append("amount=%d" % p.amount)
		bits.append("emitting=%s" % ("1" if p.emitting else "0"))
	if node is AudioStreamPlayer3D:
		var a := node as AudioStreamPlayer3D
		bits.append("bus=%s" % a.bus)
		bits.append("db=%s" % _f(a.volume_db))
		bits.append("maxd=%s" % _f(a.max_distance))
	# Attribution meta is load-bearing: the doorway-clearance and atomic
	# furnishing audits read it, so a lost meta key is a real regression. The
	# order set_meta happened to be called in is not, and must not leak into the
	# digest: get_meta_list returns StringNames, whose < operator compares the
	# interned pointer rather than the text, so sorting them directly gives an
	# order that varies between runs. Convert to String first.
	var metas: Array[String] = []
	for key in node.get_meta_list():
		metas.append(String(key))
	metas.sort()
	for key in metas:
		bits.append("@%s=%s" % [key, _meta_val(node.get_meta(key))])
	if not node.get_script() == null:
		var scr: Script = node.get_script()
		bits.append("script=%s" % scr.resource_path.get_file())
	var groups: PackedStringArray = []
	for g in node.get_groups():
		groups.append(str(g))
	groups.sort()
	if not groups.is_empty():
		bits.append("groups=%s" % ",".join(groups))
	return " ".join(bits)


func _mat_sig(mat: Material) -> String:
	if mat == null:
		return "null"
	if mat is ShaderMaterial:
		var sm := mat as ShaderMaterial
		var shader_path := "none"
		if sm.shader != null:
			shader_path = sm.shader.resource_path.get_file()
		var names: PackedStringArray = []
		if sm.shader != null:
			for p in sm.shader.get_shader_uniform_list():
				names.append(str(p["name"]))
		names.sort()
		var vals: PackedStringArray = []
		for n in names:
			vals.append("%s=%s" % [n, _meta_val(sm.get_shader_parameter(n))])
		return "shader:%s(%s)" % [shader_path, ";".join(vals)]
	if mat is StandardMaterial3D:
		var sd := mat as StandardMaterial3D
		var sig := "std:%s r=%s m=%s cull=%d tr=%d" % [
			_col(sd.albedo_color), _f(sd.roughness), _f(sd.metallic),
			sd.cull_mode, sd.transparency]
		if sd.emission_enabled:
			sig += " em=%s/%s" % [_col(sd.emission), _f(sd.emission_energy_multiplier)]
		if sd.albedo_texture != null:
			sig += " tex=%s" % sd.albedo_texture.resource_path.get_file()
		if sd.uv1_scale != Vector3.ONE:
			sig += " uv=%s" % _v3(sd.uv1_scale)
		return sig
	return mat.get_class()


func _shape_sig(shape: Shape3D) -> String:
	if shape == null:
		return "null"
	if shape is BoxShape3D:
		return "box%s" % _v3((shape as BoxShape3D).size)
	if shape is CylinderShape3D:
		var c := shape as CylinderShape3D
		return "cyl%s/%s" % [_f(c.radius), _f(c.height)]
	if shape is SphereShape3D:
		return "sph%s" % _f((shape as SphereShape3D).radius)
	if shape is CapsuleShape3D:
		var cp := shape as CapsuleShape3D
		return "cap%s/%s" % [_f(cp.radius), _f(cp.height)]
	if shape is ConvexPolygonShape3D:
		return "convex%d" % (shape as ConvexPolygonShape3D).points.size()
	if shape is ConcavePolygonShape3D:
		return "concave%d" % (shape as ConcavePolygonShape3D).get_faces().size()
	return shape.get_class()


func _meta_val(v: Variant) -> String:
	match typeof(v):
		TYPE_FLOAT:
			return _f(v)
		TYPE_VECTOR3:
			return _v3(v)
		TYPE_VECTOR2:
			return "(%s,%s)" % [_f(v.x), _f(v.y)]
		TYPE_COLOR:
			return _col(v)
		TYPE_OBJECT:
			# Instance ids are per-run; record only that a reference exists.
			return "obj" if v != null else "null"
		TYPE_ARRAY:
			var out: PackedStringArray = []
			for item in v:
				out.append(_meta_val(item))
			return "[%s]" % ",".join(out)
	return str(v)


## 5 decimals resolves geometry far below anything visible while staying clear
## of the last bits of a float, where a harmless reassociation could otherwise
## produce a spurious diff. Adding zero normalises -0.0 to 0.0.
func _f(v: float) -> String:
	return "%.5f" % (v + 0.0)


func _v3(v: Vector3) -> String:
	return "(%s,%s,%s)" % [_f(v.x), _f(v.y), _f(v.z)]


func _col(c: Color) -> String:
	return "#%s" % c.to_html(true)


## FNV-1a over the UTF-8 bytes, masked to 63 bits so it prints as a positive
## integer. Written out rather than using String.hash() so the digest does not
## depend on an engine hashing detail. The offset basis is the low 63 bits of
## the standard 64-bit constant: GDScript integers are signed, so the literal
## itself will not parse.
const FNV_OFFSET := 0x4bf29ce484222325
const FNV_PRIME := 0x100000001b3
const FNV_MASK := 0x7fffffffffffffff


func _hash(text: String) -> int:
	var h := FNV_OFFSET
	for b in text.to_utf8_buffer():
		h = (h ^ b) & FNV_MASK
		h = (h * FNV_PRIME) & FNV_MASK
	return h


func _write(path: String, lines: PackedStringArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("world hash: cannot write %s (%d)" % [
			path, FileAccess.get_open_error()])
		return
	for line in lines:
		f.store_line(line)
	f.close()


func _read(path: String) -> PackedStringArray:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var lines: PackedStringArray = []
	while not f.eof_reached():
		var line := f.get_line()
		if f.eof_reached() and line.is_empty():
			break
		lines.append(line)
	f.close()
	return lines

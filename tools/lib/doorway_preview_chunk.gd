extends Chunk
## Isolated fixture adapter. Only the reserved edge differs from native generation.
## Furnishing sees an ordinary opening from the start and reserves its approach.
var site_dir := 2
var site_nodes: Array[Node] = []
var site_shapes: Array[CollisionShape3D] = []

func _init(ws: int, at: Vector2i, direction: int) -> void:
	site_dir = direction
	super(ws, at, 1)

func _edge_info(at: Vector2i, dir: int) -> Dictionary:
	if at == cell and dir == site_dir:
		return {"wall": false, "full_open": false, "t": 6.0, "w": 3.2,
			"exit_sign": false, "runtime_shortcut": true}
	return super(at, dir)

func _wall_seg(dir: int, plane: float, from: float, to: float, y0: float, y1: float) -> void:
	var n := get_child_count()
	var c := body.get_child_count()
	super(dir, plane, from, to, y0, y1)
	if dir == site_dir: _remember(n, c)

func _door_casing(dir: int, plane: float, a: float, b: float) -> void:
	var n := get_child_count()
	super(dir, plane, a, b)
	if dir == site_dir: _remember(n, body.get_child_count())

func _wall_utilities(dir: int, plane: float, info: Dictionary) -> void:
	# The whole animated wall must be free of fixed plates/art, not just its hole.
	if dir != site_dir: super(dir, plane, info)

func _remember(n: int, c: int) -> void:
	for i in range(n, get_child_count()): site_nodes.append(get_child(i))
	for i in range(c, body.get_child_count()): site_shapes.append(body.get_child(i))

func show_native(value: bool, update_collision := true) -> void:
	for node in site_nodes:
		if node is Node3D: node.visible = value
	if update_collision:
		for shape in site_shapes: shape.disabled = not value


func native_doorway_site(dir: int) -> Dictionary:
	return {"nodes": site_nodes, "shapes": site_shapes, "t": 6.0, "w": 3.2} \
		if dir == site_dir else {}


func show_native_doorway(dir: int, value: bool, update_collision := true,
		_transitioning := false) -> void:
	if dir == site_dir: show_native(value, update_collision)

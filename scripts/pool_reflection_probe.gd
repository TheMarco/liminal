extends ReflectionProbe
## One static capture per wet room. Defer until its streamed neighbourhood is
## present, then stop processing. Never spend six extra renders every frame.
const WATER_LAYER := 1 << 15
var required_cells: Array[Vector2i] = []
var _manager: Node
var _settle := 12
var _capturing := false
var _blackout := false

func _init() -> void:
	visible = false
	update_mode = ReflectionProbe.UPDATE_ONCE
	reflection_mask = WATER_LAYER
	box_projection = true
	interior = true
	ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	blend_distance = 1.5
	set_meta("pool_water_reflection", true)

func _ready() -> void:
	_manager = get_parent().get_parent()
	if _manager != null and _manager.has_signal("chunk_built"):
		_manager.connect("chunk_built", _on_chunk_built)
	set_process(not _blackout)

func _on_chunk_built(chunk: Node3D) -> void:
	if _capturing or visible:
		return
	var at := Vector2i(floori(chunk.position.x / 12.0), floori(chunk.position.z / 12.0))
	if at in required_cells:
		_settle = 12
		set_process(not _blackout)

func set_blackout(on: bool) -> void:
	_blackout = on
	# A bright cached room must not remain reflected through a blackout.
	intensity = 0.0 if on else 1.0
	if not visible:
		_settle = 12
		set_process(not on)

func _process(_delta: float) -> void:
	if _blackout:
		set_process(false)
		return
	_settle -= 1
	if _settle > 0:
		return
	if _manager != null and _manager.has_signal("chunk_built"):
		var resident: Dictionary = _manager.get("chunks")
		for cell in required_cells:
			if not resident.has(cell):
				set_process(false) # the next relevant chunk wakes this probe
				return
	visible = true
	_capturing = true
	set_process(false)
	if _manager != null and _manager.has_signal("chunk_built") \
			and _manager.is_connected("chunk_built", _on_chunk_built):
		_manager.disconnect("chunk_built", _on_chunk_built)

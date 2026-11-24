class_name FloorResourcePreloader
extends RefCounted

## One pending threaded PackedScene prefetch with a bounded strong cache.
## The active floor has priority. Extra scenes use the remaining slots in LRU order.
## This service has no scene-tree or Chunk dependencies; callers own scheduling.

const CACHE_LIMIT := 64
const FLOOR_LOAD_BATCH := 3

static var _queue: Array[String] = []
static var _pending: String = ""
static var _ready: Dictionary = {}
static var _ready_order: Array[String] = []
static var _floor_paths: Dictionary[String, bool] = {}

## Called only behind a floor-transition fade. Retain this floor's complete
## manifest before streaming starts, so the first gate/slot room cannot block
## on a decode. Inactive floors have no strong-cache allowance. Live scenes
## keep their own resources (including actors and realm previews) alive.
static func prepare_floor(paths: Array[String]) -> void:
	var started := Time.get_ticks_usec()
	_floor_paths.clear()
	for path in paths:
		_floor_paths[path] = true
	if not _pending.is_empty():
		var status := ResourceLoader.load_threaded_get_status(_pending)
		if status in [ResourceLoader.THREAD_LOAD_IN_PROGRESS, ResourceLoader.THREAD_LOAD_LOADED]:
			var scene := ResourceLoader.load_threaded_get(_pending) as PackedScene
			if scene != null and _floor_paths.has(_pending): _store(_pending, scene)
		_pending = ""
	_queue.clear()
	for path in _ready.keys():
		if not _floor_paths.has(path):
			_ready.erase(path)
			_ready_order.erase(path)
	# Overlap independent scene decodes only while the floor is covered. Keep the
	# same manifest order and bound decoder scratch space on lower-memory PCs.
	# Concurrent scene loads can leave the headless renderer with invalid shader handles.
	var threaded := not OS.has_feature("web") and DisplayServer.get_name() != "headless"
	var requests: Array[String] = []
	for path in paths:
		if _ready.has(path) or requests.has(path): continue
		if not threaded or ResourceLoader.load_threaded_request(path, "PackedScene", false) != OK:
			_collect_floor_scene(path, false)
			continue
		requests.append(path)
		if requests.size() == FLOOR_LOAD_BATCH:
			_collect_floor_scene(requests.pop_front(), true)
	for path in requests:
		_collect_floor_scene(path, true)
	RuntimeDiagnostics.slow("floor_resource_prepare", started, {"scenes": paths.size()})

static func _collect_floor_scene(path: String, threaded: bool) -> void:
	var started := Time.get_ticks_usec()
	var scene := (ResourceLoader.load_threaded_get(path) if threaded else load(path)) as PackedScene
	RuntimeDiagnostics.slow("floor_asset_load", started, {"asset": path, "threaded": threaded})
	if scene != null: _store(path, scene)

static func configure(paths: Array[String]) -> void:
	var next: Array[String] = []
	for path in paths:
		if path == _pending or _ready.has(path) or next.has(path):
			continue
		next.append(path)
	_queue = next

static func poll() -> bool:
	if _pending.is_empty():
		return false
	var status := ResourceLoader.load_threaded_get_status(_pending)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return true
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var path := _pending
		var resource := ResourceLoader.load_threaded_get(path)
		_pending = ""
		if resource is Resource:
			_store(path, resource)
		return false
	_pending = ""
	return false

static func request_next() -> void:
	if not _pending.is_empty():
		return
	while not _queue.is_empty():
		var path: String = _queue.pop_front()
		if _ready.has(path):
			continue
		if ResourceLoader.has_cached(path):
			var cached := ResourceLoader.get_cached_ref(path)
			if cached is PackedScene:
				_store(path, cached)
			continue
		var error := ResourceLoader.load_threaded_request(path, "PackedScene", false)
		if error == OK:
			_pending = path
			return

static func cached_scene(path: String) -> PackedScene:
	var resource = _ready.get(path)
	if resource != null:
		_touch(path)
	return resource as PackedScene

static func cached_count() -> int:
	return _ready.size()

## Also retain synchronous first-use loads. ResourceLoader's cache is weak:
## instantiating a scene retains its meshes, but not the PackedScene itself.
static func retain_scene(path: String, scene: PackedScene) -> PackedScene:
	if scene != null:
		_store(path, scene)
	return scene

static func finish() -> void:
	if not _pending.is_empty():
		var path := _pending
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED \
				or status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var resource := ResourceLoader.load_threaded_get(path)
			if resource is Resource:
				_store(path, resource)
	_queue.clear()
	_ready.clear()
	_ready_order.clear()
	_floor_paths.clear()
	_pending = ""

static func _store(path: String, resource: Resource) -> void:
	if _ready.has(path):
		_touch(path)
		return
	if _ready_order.size() >= CACHE_LIMIT:
		var oldest := -1
		for i in _ready_order.size():
			if not _floor_paths.has(_ready_order[i]):
				oldest = i
				break
		if oldest < 0:
			# All slots belong to the active floor. A preview still receives
			# its loaded scene from retain_scene without displacing a floor prop.
			if not _floor_paths.has(path):
				return
			# Preserve bounded replacement even for an oversized custom manifest.
			oldest = 0
		var retired: String = _ready_order.pop_at(oldest)
		_ready.erase(retired)
	_ready[path] = resource
	_ready_order.append(path)

static func _touch(path: String) -> void:
	if _floor_paths.has(path):
		return
	_ready_order.erase(path)
	_ready_order.append(path)

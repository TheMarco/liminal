class_name FloorResourcePreloader
extends RefCounted

## One pending threaded PackedScene prefetch with a bounded FIFO strong cache.
## This service has no scene-tree or Chunk dependencies; callers own scheduling.

const CACHE_LIMIT := 64

static var _queue: Array[String] = []
static var _pending: String = ""
static var _ready: Dictionary = {}
static var _ready_order: Array[String] = []

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
	return resource as PackedScene

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
	_pending = ""

static func _store(path: String, resource: Resource) -> void:
	if _ready.has(path):
		return
	while _ready_order.size() >= CACHE_LIMIT:
		var oldest: String = _ready_order.pop_front()
		_ready.erase(oldest)
	_ready[path] = resource
	_ready_order.append(path)

extends SceneTree

const PATHS: Array[String] = [
	"res://tools/preview_credits.tscn",
	"res://tools/cross_video_review.tscn",
]

var failures := 0

func _init() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("PRELOADER_AUDIT_FAIL " + message)

func run() -> void:
	FloorResourcePreloader.finish()
	var doubled: Array[String] = []
	doubled.append_array(PATHS)
	doubled.append_array([PATHS[0], PATHS[1], PATHS[0]])
	FloorResourcePreloader.configure(doubled)
	check(FloorResourcePreloader._queue.size() == PATHS.size(), "queue was not deduplicated")
	FloorResourcePreloader.request_next()
	var pending := FloorResourcePreloader._pending
	FloorResourcePreloader.request_next()
	check(FloorResourcePreloader._pending == pending, "a second request replaced the pending load")
	FloorResourcePreloader.configure([PATHS[1], PATHS[0], PATHS[1]])
	check(FloorResourcePreloader._pending == pending, "configuration lost the pending load")
	var deadline := Time.get_ticks_msec() + 5000
	while FloorResourcePreloader.poll() and Time.get_ticks_msec() < deadline:
		await process_frame
	check(Time.get_ticks_msec() < deadline, "request did not complete")
	check(FloorResourcePreloader.cached_scene(PATHS[0]) != null,
		"completed request was not cached")
	FloorResourcePreloader.request_next()
	deadline = Time.get_ticks_msec() + 5000
	while FloorResourcePreloader.poll() and Time.get_ticks_msec() < deadline:
		await process_frame
	check(FloorResourcePreloader.cached_scene(PATHS[1]) != null,
		"reconfigured queue request was not cached")
	for path in PATHS:
		FloorResourcePreloader.configure([path])
		FloorResourcePreloader.request_next()
		deadline = Time.get_ticks_msec() + 5000
		while FloorResourcePreloader.poll() and Time.get_ticks_msec() < deadline:
			await process_frame
	check(FloorResourcePreloader.cached_scene(PATHS[0]) != null,
		"cache was evicted below expected live entries")
	var fixture := FloorResourcePreloader.cached_scene(PATHS[0])
	for i in 65:
		FloorResourcePreloader._store("audit:%d" % i, fixture)
	check(FloorResourcePreloader.cached_scene("audit:0") == null,
		"cache exceeded 64 entries")
	check(FloorResourcePreloader.cached_scene("audit:64") != null,
		"newest cache entry was not retained")
	check(ResourceLoader.has_cached(PATHS[0]), "loaded fixture was not adopted by engine cache")
	FloorResourcePreloader.finish()
	check(FloorResourcePreloader.cached_scene(PATHS[0]) == null,
		"finish did not clear cache")
	# The engine may retain an asset after this service evicts it. Adopt that
	# reference without another disk load.
	FloorResourcePreloader.configure([PATHS[0]])
	FloorResourcePreloader.request_next()
	check(FloorResourcePreloader.cached_scene(PATHS[0]) == fixture, "engine cache was not adopted")
	FloorResourcePreloader.finish()
	check(FloorResourcePreloader._pending.is_empty() and FloorResourcePreloader._queue.is_empty()
		and FloorResourcePreloader._ready.is_empty(), "finish left pending work or cache entries")
	print("PRELOADER_AUDIT failures=%d" % failures)
	quit(1 if failures else 0)

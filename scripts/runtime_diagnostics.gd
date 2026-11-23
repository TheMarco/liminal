class_name RuntimeDiagnostics
extends Node
## Captures diagnostics on the game thread. Disk writes run on a dedicated thread.
## Engine allocation/VRAM estimates are NOT Windows process commit or GPU budget.

const LOG_PATH := "user://logs/performance.jsonl"
const LogWriter := preload("res://scripts/performance_log_writer.gd")
const MAX_BYTES := 1024 * 1024
const HITCH_USEC := 100000
const SLOW_USEC := 20000
const REPORT_USEC := 2000000
const SAMPLE_USEC := 30000000
static var _instance: RuntimeDiagnostics
static var world_viewport: Viewport:
	set(value):
		world_viewport = value
		if is_instance_valid(value) and is_instance_valid(_instance) and _instance._measure_world_render:
			RenderingServer.viewport_set_measure_render_time(value.get_viewport_rid(), true)

var _writer := LogWriter.new()
var _enabled := false
var _path := LOG_PATH
var _context := Callable()
var _last_frame := 0
var _last_physics_frame := 0
var _last_report := 0
var _last_sample := 0
var _hitches := 0
var _worst_gap := 0
var _worst_gap_physics_steps := 0
var _slow_last: Dictionary = {}
var _slow_counts: Dictionary = {}
var _last_write_usec := 0
var _max_write_usec := 0
var _measure_world_render := false


func _ready() -> void:
	_instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000000
	_measure_world_render = OS.get_cmdline_user_args().has("--profile-world-render") and DisplayServer.get_name() != "headless"
	# Audits/support can isolate this file without changing player settings.
	if _path == LOG_PATH:
		var audit_path := OS.get_environment("LIMINAL_DIAGNOSTICS_LOG")
		if not audit_path.is_empty(): _path = audit_path
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--diagnostics-log="):
				_path = argument.trim_prefix("--diagnostics-log=")
	var error := _writer.start(ProjectSettings.globalize_path(_path), MAX_BYTES)
	if error != OK:
		push_warning("Performance diagnostics could not start its writer: %s" % error_string(error))
		set_process(false)
		return
	_enabled = true
	_last_frame = Time.get_ticks_usec()
	_last_physics_frame = Engine.get_physics_frames()
	_last_sample = _last_frame
	_write("session_start", {
		"schema": 1, "diagnostics_revision": "frame-pacing-8", "utc": Time.get_datetime_string_from_system(true),
		"world_render_timing_requested": _measure_world_render,
		"engine": Engine.get_version_info().string, "os": OS.get_name(),
		"game_version": ProjectSettings.get_setting("application/config/version", "unknown"),
		"os_version": OS.get_version(), "cpu": OS.get_processor_name(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"gpu_type": RenderingServer.get_video_adapter_type(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"d3d12_resource_descriptors": ProjectSettings.get_setting("rendering/rendering_device/d3d12/max_resource_descriptors",65536),
		"gpu_driver": OS.get_video_adapter_driver_info(),
		"debug_build": OS.is_debug_build(),
		"memory_note": "System memory and engine estimates; process commit, dedicated VRAM budget, temperatures and clocks are not measured. Performance monitors may lag or be unavailable in release builds. Invalid memory counter values are null.",
	}, true)


static func mark(event: String, fields: Dictionary = {}, snapshot := false) -> void:
	if OS.get_thread_caller_id() != OS.get_main_thread_id(): return
	if is_instance_valid(_instance):
		_instance._write(event, fields, snapshot)


static func set_context(provider: Callable) -> void:
	if is_instance_valid(_instance):
		_instance._context = provider


static func slow(event: String, started_usec: int, fields: Dictionary = {}) -> void:
	if OS.get_thread_caller_id() != OS.get_main_thread_id(): return
	if not is_instance_valid(_instance): return
	var elapsed := Time.get_ticks_usec() - started_usec
	if elapsed < SLOW_USEC: return
	_instance._slow_counts[event] = int(_instance._slow_counts.get(event, 0)) + 1
	var now := Time.get_ticks_usec()
	if now - int(_instance._slow_last.get(event, -REPORT_USEC)) < REPORT_USEC: return
	_instance._slow_last[event] = now
	var details := fields.duplicate()
	details["elapsed_ms"] = elapsed / 1000.0
	details["occurrences"] = _instance._slow_counts[event]
	_instance._write(event, details)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var gap := now - _last_frame
	var physics_frame := Engine.get_physics_frames()
	_last_frame = now
	if gap >= HITCH_USEC:
		_hitches += 1
		if gap > _worst_gap:
			_worst_gap = gap
			_worst_gap_physics_steps = physics_frame - _last_physics_frame
	_last_physics_frame = physics_frame
	if _hitches > 0 and now - _last_report >= REPORT_USEC:
		_write("frame_hitch", {"count": _hitches, "worst_gap_ms": _worst_gap / 1000.0,
			"worst_gap_physics_steps": _worst_gap_physics_steps}, true)
		_hitches = 0
		_worst_gap = 0
		_last_report = now
	if now - _last_sample >= SAMPLE_USEC:
		_write("health", {"slow_operation_counts": _slow_counts.duplicate()}, true)
		_last_sample = now


func _snapshot() -> Dictionary:
	var result := {
		"system_memory_bytes": OS.get_memory_info(),
		"engine_static_bytes": OS.get_static_memory_usage() if OS.is_debug_build() else null,
		"engine_video_memory_bytes": _valid_memory_counter(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
		"engine_texture_memory_bytes": _valid_memory_counter(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)),
		"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"frame_work": {
			# These are engine counters, not GPU timestamps or wall-clock FPS.
			"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"rendered_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		},
		# Main-thread snapshot, serialization and enqueue cost for the previous event.
		"diagnostic_write_ms": {"last": _last_write_usec / 1000.0, "max": _max_write_usec / 1000.0},
		"diagnostic_disk_ms": _writer.disk_stats(),
		"pipelines": {
			"canvas": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS),
			"mesh": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH),
			"surface": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),
			"draw": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),
			"specialization": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION),
		},
		"focused": get_window().has_focus(), "paused": get_tree().paused,
		"window_size": str(get_window().size), "fps": Engine.get_frames_per_second(),
		"frame_limit": Engine.max_fps, "physics_ticks_per_second": Engine.physics_ticks_per_second,
		"vsync_mode": DisplayServer.window_get_vsync_mode(get_window().get_window_id()) if DisplayServer.get_name() != "headless" else null,
	}
	if _context.is_valid(): result["game"] = _context.call()
	# Per-viewport draw counts are live in release builds. Both moving casters
	# and shadow atlas eviction can cause recurring shadow draws at a fixed view.
	if is_instance_valid(world_viewport):
		var rid := world_viewport.get_viewport_rid()
		result["world_draws"] = {
			"visible": RenderingServer.viewport_get_render_info(rid,
				RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
			"shadow": RenderingServer.viewport_get_render_info(rid,
				RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),
		}
		if _measure_world_render:
			# The latest completed world draw can precede this snapshot. These
			# timings exclude presentation and the separate VHS/CRT viewport.
			var gpu_ms := RenderingServer.viewport_get_measured_render_time_gpu(rid)
			var cpu_ms := RenderingServer.viewport_get_measured_render_time_cpu(rid)
			result["world_render_ms"] = {
				"gpu": gpu_ms if is_finite(gpu_ms) and gpu_ms > 0.0 else null,
				"cpu": cpu_ms if is_finite(cpu_ms) and cpu_ms > 0.0 else null,
			}
	return result


static func _valid_memory_counter(value: float) -> Variant:
	# Some renderer counters underflow to ~2^64 after resource retirement.
	# Do not turn that into a false exabyte memory-leak report. 1 PiB is far
	# above any plausible allocation for this game, not an estimate of VRAM.
	return value if is_finite(value) and value >= 0.0 and value < 1125899906842624.0 else null


func _write(event: String, fields: Dictionary = {}, snapshot := false, final_record := false) -> void:
	if not _enabled: return
	var started := Time.get_ticks_usec()
	var record := {"event": event, "uptime_ms": Time.get_ticks_msec(), "details": fields}
	if snapshot: record["snapshot"] = _snapshot()
	if _writer.submit(JSON.stringify(record), final_record) == ERR_UNAVAILABLE:
		_enabled = false
		set_process(false)
	_last_write_usec = Time.get_ticks_usec() - started
	_max_write_usec = maxi(_max_write_usec, _last_write_usec)


func _exit_tree() -> void:
	_write("session_end", {}, false, true)
	_writer.close()
	if _instance == self: _instance = null

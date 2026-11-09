class_name RuntimeDiagnostics
extends Node
## Bounded, flushed diagnostics for exported builds. Main-thread calls only.
## Engine allocation/VRAM estimates are NOT Windows process commit or GPU budget.

const LOG_PATH := "user://logs/performance.jsonl"
const MAX_BYTES := 1024 * 1024
const HITCH_USEC := 100000
const SLOW_USEC := 20000
const REPORT_USEC := 2000000
const SAMPLE_USEC := 30000000
static var _instance: RuntimeDiagnostics

var _file: FileAccess
var _path := LOG_PATH
var _context := Callable()
var _last_frame := 0
var _last_report := 0
var _last_sample := 0
var _hitches := 0
var _worst_gap := 0
var _slow_last: Dictionary = {}
var _slow_counts: Dictionary = {}


func _ready() -> void:
	_instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000000
	# Audits/support can isolate this file without changing player settings.
	if _path == LOG_PATH:
		var audit_path := OS.get_environment("LIMINAL_DIAGNOSTICS_LOG")
		if not audit_path.is_empty(): _path = audit_path
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--diagnostics-log="):
				_path = argument.trim_prefix("--diagnostics-log=")
	_open_log()
	_last_frame = Time.get_ticks_usec()
	_last_sample = _last_frame
	_write("session_start", {
		"schema": 1, "diagnostics_revision": "frame-recovery-2", "utc": Time.get_datetime_string_from_system(true),
		"engine": Engine.get_version_info().string, "os": OS.get_name(),
		"game_version": ProjectSettings.get_setting("application/config/version", "unknown"),
		"os_version": OS.get_version(), "cpu": OS.get_processor_name(),
		"gpu": RenderingServer.get_video_adapter_name(),
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
	_last_frame = now
	if gap >= HITCH_USEC:
		_hitches += 1
		_worst_gap = maxi(_worst_gap, gap)
	if _hitches > 0 and now - _last_report >= REPORT_USEC:
		_write("frame_hitch", {"count": _hitches, "worst_gap_ms": _worst_gap / 1000.0}, true)
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
		"pipelines": {
			"canvas": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS),
			"mesh": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH),
			"surface": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),
			"draw": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),
			"specialization": Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION),
		},
		"focused": get_window().has_focus(), "paused": get_tree().paused,
		"window_size": str(get_window().size), "fps": Engine.get_frames_per_second(),
	}
	if _context.is_valid(): result["game"] = _context.call()
	return result


static func _valid_memory_counter(value: float) -> Variant:
	# Some renderer counters underflow to ~2^64 after resource retirement.
	# Do not turn that into a false exabyte memory-leak report. 1 PiB is far
	# above any plausible allocation for this game, not an estimate of VRAM.
	return value if is_finite(value) and value >= 0.0 and value < 1125899906842624.0 else null


func _open_log() -> void:
	_file = null
	var absolute := ProjectSettings.globalize_path(_path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK: return
	if FileAccess.file_exists(absolute + ".2"):
		DirAccess.remove_absolute(absolute + ".2")
	if FileAccess.file_exists(absolute + ".1"):
		DirAccess.rename_absolute(absolute + ".1", absolute + ".2")
	if FileAccess.file_exists(absolute):
		DirAccess.rename_absolute(absolute, absolute + ".1")
	_file = FileAccess.open(absolute, FileAccess.WRITE)
	if _file == null:
		push_warning("Performance diagnostics could not open its log: %s" % FileAccess.get_open_error())


func _write(event: String, fields: Dictionary = {}, snapshot := false) -> void:
	if _file == null: return
	if _file.get_position() >= MAX_BYTES: _open_log()
	if _file == null: return
	var record := {"event": event, "uptime_ms": Time.get_ticks_msec(), "details": fields}
	if snapshot: record["snapshot"] = _snapshot()
	_file.store_line(JSON.stringify(record))
	_file.flush()


func _exit_tree() -> void:
	_write("session_end")
	_file = null
	if _instance == self: _instance = null

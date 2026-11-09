class_name GameplayFrameGuard
extends Node
## Give control back before threats resume after a stalled main/render loop.
## Physics catch-up ticks must not consume the player's recovery window.

const STALL_USEC := 250000
const RECOVERY_USEC := 750000
static var _instance: GameplayFrameGuard
var remaining_usec := 0
var _last_physics := 0
var _last_frame := 0
var _last_report := -2000000
var _watch_clock := true

func _ready() -> void:
	_instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -1000000
	process_physics_priority = -1000000
	# Headless audits have no displayed frames and deliberately do many seconds
	# of synchronous simulation. Their guard tests inject wall-clock samples.
	_watch_clock = DisplayServer.get_name() != "headless"
	reset_clock(Time.get_ticks_usec())
	if _watch_clock: RenderingServer.frame_post_draw.connect(_frame_drawn)

func _exit_tree() -> void:
	if RenderingServer.frame_post_draw.is_connected(_frame_drawn):
		RenderingServer.frame_post_draw.disconnect(_frame_drawn)
	if _instance == self: _instance = null

static func is_recovering() -> bool:
	return is_instance_valid(_instance) and _instance.remaining_usec > 0

static func hold_for_presentation() -> void:
	if is_instance_valid(_instance): _instance.remaining_usec = RECOVERY_USEC

func reset_clock(now_usec: int) -> void:
	_last_physics = now_usec
	_last_frame = now_usec
	remaining_usec = 0

func observe_physics(now_usec: int) -> int:
	var gap := now_usec - _last_physics if _last_physics > 0 else 0
	_last_physics = now_usec
	# A responsive simulation is not proof that a fresh picture was drawn.
	if _last_frame > 0: gap = maxi(gap,now_usec - _last_frame)
	if gap >= STALL_USEC: remaining_usec = RECOVERY_USEC
	return gap

func observe_frame(now_usec: int) -> int:
	var gap := now_usec - _last_frame if _last_frame > 0 else 0
	_last_frame = now_usec
	if gap >= STALL_USEC:
		remaining_usec = RECOVERY_USEC
	else:
		# Count only responsive frames, never the stall or repeated physics
		# catch-up steps. Very low frame rates earn a longer reaction window.
		remaining_usec = maxi(0,remaining_usec - clampi(gap,0,100000))
	return gap

func _physics_process(_delta: float) -> void:
	if not _watch_clock: return
	var now := Time.get_ticks_usec()
	if get_tree().paused:
		reset_clock(now)
		return
	_report(observe_physics(now),now)

func _process(_delta: float) -> void:
	if not _watch_clock: return
	var now := Time.get_ticks_usec()
	if get_tree().paused:
		reset_clock(now)
		return
	if now - _last_frame >= STALL_USEC:
		remaining_usec = RECOVERY_USEC
		_report(now - _last_frame,now)

func _frame_drawn() -> void:
	var now := Time.get_ticks_usec()
	if get_tree().paused:
		reset_clock(now)
		return
	_report(observe_frame(now),now)

func _report(gap: int, now: int) -> void:
	if gap < STALL_USEC or now - _last_report < 2000000: return
	_last_report = now
	RuntimeDiagnostics.mark("threat_stall_recovery", {"gap_ms": gap / 1000.0,
		"recovery_ms": RECOVERY_USEC / 1000.0})

class_name HdrOutput
extends RefCounted
## Version-safe bridge to Godot 4.7's display HDR API. Keeping the API calls
## dynamic lets an older editor still report a useful Settings message instead
## of failing while the project is being upgraded.

const REQUIRED_MAJOR := 4
const REQUIRED_MINOR := 7


static func engine_supported() -> bool:
	var version := Engine.get_version_info()
	var major := int(version.get("major", 0))
	var minor := int(version.get("minor", 0))
	return major > REQUIRED_MAJOR or (major == REQUIRED_MAJOR \
		and minor >= REQUIRED_MINOR)


static func display_server_supported() -> bool:
	return engine_supported() \
		and DisplayServer.has_feature(DisplayServer.FEATURE_HDR_OUTPUT)


static func request(window: Window, enabled: bool) -> bool:
	if window == null or not engine_supported() \
			or not window.has_method("set_hdr_output_requested"):
		return false
	# Unsupported backends stay in SDR without issuing a meaningless HDR
	# request. Supported backends own per-display detection and automatically
	# switch as the window moves between HDR and SDR screens.
	if enabled and not display_server_supported():
		return false
	window.call("set_hdr_output_requested", enabled)
	return true


static func is_active(window: Window) -> bool:
	if window == null or not display_server_supported() \
			or not DisplayServer.has_method("window_is_hdr_output_enabled"):
		return false
	return bool(DisplayServer.call("window_is_hdr_output_enabled"))


static func output_max_linear_value(window: Window) -> float:
	if window == null or not engine_supported() \
			or not window.has_method("get_output_max_linear_value"):
		return 1.0
	return maxf(1.0, float(window.call("get_output_max_linear_value")))


static func status(window: Window, requested: bool) -> String:
	if not engine_supported():
		return "HDR OUTPUT REQUIRES A GODOT 4.7+ BUILD"
	if not requested:
		return "HDR OUTPUT OFF — SDR PRESENTATION"
	if DisplayServer.get_name() == "headless":
		return "HDR REQUESTED — DISPLAY CHECK UNAVAILABLE"
	if not display_server_supported():
		return "HDR REQUESTED — CURRENT DISPLAY SERVER USES SDR"
	if not is_active(window):
		return "HDR REQUESTED — CURRENT DISPLAY IS SDR"
	var headroom := output_max_linear_value(window)
	return "HDR ACTIVE — %.2fx DISPLAY HEADROOM" % headroom

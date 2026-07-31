extends SceneTree
## Poolrooms distance-horizon contract:
## - unloaded space clears to a warm tile color, never Godot's black default;
## - fog reaches through the chunk streaming horizon and masks visible pop-in.
##
## Run:
##   godot --headless --path . --script tools/audit_pool_environment.gd


func _init() -> void:
	var env := EnvBuilder.build(9)
	var failures: Array[String] = []
	if env.background_mode != Environment.BG_COLOR:
		failures.append("background mode is not BG_COLOR")
	var bg := env.background_color
	var bg_luminance := bg.get_luminance()
	if bg_luminance < 0.60:
		failures.append(
			"background is too dark to match tile: luminance %.3f" % bg_luminance)
	if maxf(bg.r, maxf(bg.g, bg.b)) - minf(bg.r, minf(bg.g, bg.b)) > 0.10:
		failures.append("background is too saturated to read as white tile")
	if not env.fog_enabled or env.fog_density < 0.008:
		failures.append(
			"depth fog is too weak at the streaming horizon: %.4f" % env.fog_density)
	if not env.volumetric_fog_enabled:
		failures.append("volumetric fog is disabled")
	var streaming_horizon := \
		ChunkManager.CELL * (float(ChunkManager.LOAD_R) + 0.5)
	if env.volumetric_fog_length < streaming_horizon:
		failures.append(
			"volumetric fog ends at %.1fm before %.1fm streaming horizon" % [
				env.volumetric_fog_length, streaming_horizon])
	for failure in failures:
		print("  FAIL " + failure)
	if not failures.is_empty():
		quit(1)
		return
	print(("pool environment audit: PASS — tile clear %.2f/%.2f/%.2f, " +
		"fog %.3f through %.0fm") % [
		bg.r, bg.g, bg.b, env.fog_density, env.volumetric_fog_length])
	quit()

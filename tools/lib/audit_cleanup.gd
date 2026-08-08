extends RefCounted
## Shared teardown for construction-heavy SceneTree audits.
##
## Production intentionally keeps imported scenes, materials, audio streams and
## VHS models alive for the process lifetime. A short audit must explicitly
## release those caches and give the servers frame boundaries to retire RIDs,
## otherwise Godot correctly reports the audit process itself as leaking.


static func release(tree: SceneTree) -> void:
	Chunk.clear_runtime_caches()
	SoundBank._c.clear()
	Sfx._c.clear()
	Mats.clear_runtime_caches()
	VhsRitual.clear_runtime_cache()
	await tree.process_frame
	await tree.physics_frame
	await tree.create_timer(0.1).timeout

extends "res://tools/capture_photo_doorway.gd"
## GPU integration capture: a real photo opens a passage and triggers the effect.
## godot --path . --minimized --audio-driver Dummy --script tools/capture_reality_aftershock.gd \
##   -- --test-mode --first-obstruction=2 --seed=21

var effect: CanvasLayer
var marker: CanvasLayer
var plain_review: Image

func shot(label: String) -> void:
	out = "/tmp/liminal-reality-aftershock"
	DirAccess.make_dir_recursive_absolute(out)
	if effect == null:
		effect = game._reality_aftershock
		assert(effect != null, "automatic perception effect not installed")
		effect.set_process(false)
		assert(game._post_process._scene_copy != null, "post-process copy not installed")
		marker = CanvasLayer.new()
		marker.layer = 2
		view.add_child(marker)
		var plate := ColorRect.new()
		plate.position = Vector2(24, 24)
		plate.size = Vector2(430, 45)
		plate.color = Color(0.08, 0.12, 0.18)
		marker.add_child(plate)
		var text := Label.new()
		text.position = Vector2(36, 31)
		text.text = "REALITY AFTERSHOCK / SHARP HUD CHECK"
		text.add_theme_font_size_override("font_size", 17)
		marker.add_child(text)
	if label == "03-photograph":
		assert(effect.pulse_count == 0, "aftershock started before photo review finished")
		plain_review = game._photo_camera._photo.texture.get_image()
	if label == "04-reveal":
		assert(effect.pulse_count == 1, "real photo mutation did not trigger exactly one pulse")
		assert(effect.presentation_allowed(), "real after-photo state blocks presentation")
		effect.elapsed = effect.DURATION
		effect._process(0.0)
		await super.shot("04a-reveal-before")
		var before := view.get_texture().get_image()
		var before_hud := before.get_region(Rect2i(24, 24, 430, 45)).get_data()
		var camera_transform: Transform3D = game.player.cam.global_transform
		for at in [0.35, 0.9, 1.65, 2.5, 4.0]:
			effect.elapsed = at
			effect._process(0.0)
			await super.shot("04b-aftershock-%.2f" % at)
			var after := view.get_texture().get_image()
			assert(before_hud == after.get_region(Rect2i(24, 24, 430, 45)).get_data(), "world effect changed sharp HUD pixels")
			assert(before.get_data() != after.get_data(), "world effect has no visible output")
			assert(game.player.cam.global_transform == camera_transform, "aftershock moved camera")
		assert(plain_review.get_data() == game._photo_camera._photo.texture.get_image().get_data(), "aftershock changed saved photograph")
		effect.elapsed = 1.65
		effect._process(0.0)
		game._osd_layer.visible = true
		game._descent_hud.visible = true
		marker.visible = false
		game._post_process.set_effects(true, false)
		await super.shot("04c-aftershock-vhs-with-hud")
		game._post_process.set_effects(false, true)
		await super.shot("04d-aftershock-crt-with-hud")
		game._post_process.set_effects(true, true)
		await super.shot("04e-aftershock-vhs-crt-with-hud")
		game._post_process.set_effects(false, false)
		effect.cancel()
		assert(not effect.visible, "completed effect remains visible")
		print("REALITY AFTERSHOCK GPU PASS: real photo trigger, sharp HUD, unchanged photo/camera, clean/VHS/CRT/combined composition")
	await super.shot(label)

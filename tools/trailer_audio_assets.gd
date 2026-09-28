extends SceneTree
func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/promo-trailer/audio")
	SoundBank.key_click().save_to_wav("res://build/promo-trailer/audio/shutter.wav")
	SoundBank.portal_hum().save_to_wav("res://build/promo-trailer/audio/portal.wav")
	quit()

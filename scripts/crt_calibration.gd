extends RefCounted
## Shared game/workshop calibration. The original shaders remain model-specific.
## Royale retains its original field handling and beam profile.
const DEFAULTS := {
	"aperture": {
		"SCANLINE_SIZE_MIN": 1.0,
		"MASK_STRENGTH": 0.2,
		"GAMMA_OUTPUT": 2.6
	},
	"royale": {
		"lcd_gamma": 2.8,
		"beam_min_sigma": 0.12,
		"mask_type": 2.0
	},
	"easymode": {
		"SCANLINE_CUTOFF": 1000.0,
		"SCANLINE_STRENGTH": 0.65,
		"SCANLINE_BRIGHT_MIN": 0.2,
		"SCANLINE_BRIGHT_MAX": 0.55
	},
	"hyllian": {
		"SCANLINES_CUTOFF": 1000.0,
		"SCANLINES_STRENGTH": 0.6
	},
	"sim": {
		"mask_toggle": 1.0,
		"Tuning_Mask_Opacity": 0.65,
		"Tuning_Mask_Brightness": 0.6,
		"CRTMask_Scale": 4.0
	}
}
const LEGACY_HOME := {
	"aperture": {
		"SCANLINE_SIZE_MIN": 1.0,
		"MASK_STRENGTH": 0.2,
		"GAMMA_OUTPUT": 2.6
	},
	"royale": {
		"lcd_gamma": 2.8,
		"beam_min_sigma": 0.12
	}
}
const UPDATES := {
	"easymode": {
		"SCANLINE_CUTOFF": 1000.0,
		"SCANLINE_STRENGTH": 0.65,
		"SCANLINE_BRIGHT_MIN": 0.2,
		"SCANLINE_BRIGHT_MAX": 0.55
	},
	"hyllian": {
		"SCANLINES_CUTOFF": 1000.0,
		"SCANLINES_STRENGTH": 0.6
	},
	"sim": {
		"mask_toggle": 1.0,
		"Tuning_Mask_Opacity": 0.65,
		"Tuning_Mask_Brightness": 0.6,
		"CRTMask_Scale": 4.0
	}
}
## Fingerprints of complete, untouched former defaults and authored CRT looks.
## Exact matching preserves deliberate custom beam/mask/colour settings.
const LEGACY_SIGNATURES := {
	"easymode": [
		"771130379ea5687674359c3352ba8ff9bbb1f613930fb1e9123e0b6482c7ee3f",
		"1dc2c2a3362b6baa79e1ae05d2edb5bfe828d537329c725983aa90726d1bd878"
	],
	"hyllian": [
		"c81d3523c4af326b3977e984117a1ba5ecb55496fefb6585abc5d00f246f43bb",
		"83b1fffb9999cf4debcf30c270c3563c2468fe88d00d02b1a26b4a2312199da8"
	],
	"sim": [
		"1c147fc1b2bf5b6e35eeb7bb54e99936a9d375c0026c841ec840ae68c64b4278",
		"944e1e8ce8764a81883bea0727717c36b8d141a1eff16f909bc39a8c24402a3e"
	]
}
## Restore only the Royale settings introduced by the rejected raster tuning.
## The living-room recipe previously used a broader beam than automatic Home.
const ROYALE_RESTORE := {
	"446149a8654978b9d7ae5f381c19705b9fdf928d6023e55087c88348b0042d93": 0.3,
	"bfb5c6de14b0f6956c7e11572cbb8924560e100148b8a49f54ccda3814892129": 0.32,
}
const ROYALE_SPARSE_RESTORE := "675b7cd68b54c93d4743956ba5a924df65348012e5873653e2e6c09a80ae411f"

static func fingerprint(parameters: Dictionary) -> String:
	var keys := parameters.keys()
	keys.sort()
	var fields := PackedStringArray()
	for key in keys: fields.append("%s=%.6f" % [key,float(parameters[key])])
	return "|".join(fields).sha256_text()

static func upgrade_saved(parameters: Dictionary) -> Dictionary:
	if parameters == LEGACY_HOME: return DEFAULTS.duplicate(true)
	var result := parameters.duplicate(true)
	if result.get("royale") is Dictionary:
		var signature := fingerprint(result.royale)
		if signature == ROYALE_SPARSE_RESTORE:
			result.royale = LEGACY_HOME.royale.duplicate(true)
		elif ROYALE_RESTORE.has(signature):
			result.royale.merge({"interlace_detect_toggle":1.0,"beam_max_sigma":ROYALE_RESTORE[signature]},true)
	for model: String in UPDATES:
		if result.get(model) is Dictionary and fingerprint(result[model]) in LEGACY_SIGNATURES[model]:
			result[model].merge(UPDATES[model],true)
	return result

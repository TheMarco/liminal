extends SceneTree
## Dev: confirm the handwriting fonts load and actually rasterise glyphs.
## Run: godot --headless --path . --script tools/font_check.gd

const FONTS := [
	"res://fonts/RockSalt-Regular.ttf",
	"res://fonts/Caveat-Regular.ttf",
]
const SAMPLE := "LET ME OUT"


func _init() -> void:
	for path in FONTS:
		var f: FontFile = load(path)
		if f == null:
			print("FAIL  %s — did not load" % path)
			continue
		var size := f.get_string_size(SAMPLE, HORIZONTAL_ALIGNMENT_LEFT, -1, 64)
		# a font that loads but has no glyphs still reports a zero-width string
		var ok := size.x > 1.0 and size.y > 1.0
		print("%s  %-34s family=%-12s  \"%s\" @64pt = %.1f x %.1f px" % [
			"OK  " if ok else "FAIL", path.get_file(), f.get_font_name(),
			SAMPLE, size.x, size.y])
	quit()

class_name VhsOsd
extends Object
## The HUD's one voice: everything the player is told in-game is on-screen
## display burned into recovered video playback. Bare shadowed VT323 text, no
## panels, no chrome — the CRT/tape post filter supplies the rest of the look.
##
## Static helpers style Labels; the inner classes are the two drawn widgets:
## Meter (segmented block gauge, optionally wrapped in a battery outline) and
## Frame (PLAY state, tape counter, clock/date and tracking interference).

const FONT := preload("res://fonts/VT323-Regular.ttf")

## Slightly green-grey white: pure white reads as UI, this reads as phosphor.
const INK := Color(0.92, 0.96, 0.90, 0.94)
const INK_DIM := Color(0.92, 0.96, 0.90, 0.78)
## Title-safe margin as a fraction of each viewport dimension. Every OSD
## element sits inside it so nothing is lost to the tube's warp, vignette or
## an overscanning display.
const SAFE_FRACTION := 0.06
## Everything the OSD says is read through the CRT pass, which emulates a
## 320-row signal: strokes thinner than a scanline vanish. Labels are set
## with a same-ink outline that fattens VT323's hairline into a stroke that
## survives, plus a hard shadow for contrast on bright rooms.
const STROKE := 2
const SHADOW_OFFSET := 3
const RED := Color(1.0, 0.28, 0.20)
const AMBER := Color(1.0, 0.72, 0.25)
const SHADOW := Color(0.0, 0.0, 0.0, 0.85)


## In-place restyle so existing Labels keep their layout containers.
static func style_label(label: Label, size: int, color := INK) -> void:
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", SHADOW)
	label.add_theme_constant_override("shadow_offset_x", SHADOW_OFFSET)
	label.add_theme_constant_override("shadow_offset_y", SHADOW_OFFSET)
	label.add_theme_color_override("font_outline_color", color)
	label.add_theme_constant_override("outline_size", STROKE)
	label.add_theme_constant_override("shadow_outline_size", STROKE)


## Recolour a styled label: ink and stroke move together, or a red caption
## keeps a white fringe.
static func set_ink(label: Label, color: Color) -> void:
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", color)


## Drawn-widget twin of style_label: shadowed, stroked OSD text.
static func draw_osd_string(ci: CanvasItem, f: Font, at: Vector2, text: String,
		size: int, ink: Color) -> void:
	var off := Vector2(SHADOW_OFFSET, SHADOW_OFFSET)
	ci.draw_string_outline(f, at + off, text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		size, STROKE, SHADOW)
	ci.draw_string(f, at + off, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		SHADOW)
	ci.draw_string_outline(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		STROKE, ink)
	ci.draw_string(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)


## Safe-area inset in pixels for a viewport of the given size.
static func safe_inset(viewport_size: Vector2) -> Vector2:
	return viewport_size * SAFE_FRACTION


## HUD scale for a viewport: 1.0 at 720p, growing with height and never
## clamped — a 3.0x display gets 3.0x text, or the tube eats it.
static func hud_scale(viewport_size: Vector2) -> float:
	return maxf(1.0, viewport_size.y / 720.0)


static func make_label(size: int, color := INK) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style_label(label, size, color)
	return label


## Segmented block gauge in viewfinder idiom: a caption above a row of solid
## cells that empty right-to-left. `battery_glyph` wraps the cells in a battery
## outline with a terminal nub. Below `low_threshold` the fill turns red and,
## with `blink_when_low`, strobes — a camcorder never whispers about power.
class Meter extends Control:
	var text := ""
	var value := 1.0
	var segments := 8
	var low_threshold := 0.15
	var warn_threshold := 0.35
	var blink_when_low := true
	var battery_glyph := false
	var font_size := 18
	var right_align := false
	## Width of each break between cells, as a fraction of the whole channel.
	## Individual HUD meters tune this against the tape pass's horizontal bloom.
	var gap_ratio := 0.014
	## Optional black rail behind the cells. This keeps their rhythm legible over
	## bright rooms without adding a modern UI panel around the meter.
	var channel_alpha := 0.0
	var _blink_t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(dt: float) -> void:
		_blink_t += dt
		if visible:
			queue_redraw()

	func _draw() -> void:
		var s := size
		var text_h := 0.0
		if not text.is_empty():
			var f: Font = VhsOsd.FONT
			text_h = f.get_height(font_size)
			var text_w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT,
				-1, font_size).x
			var tx := s.x - text_w if right_align else 0.0
			var ty := f.get_ascent(font_size)
			var ink := VhsOsd.INK
			if value <= low_threshold:
				ink = VhsOsd.RED
			elif value <= warn_threshold:
				ink = VhsOsd.AMBER
			VhsOsd.draw_osd_string(self, f, Vector2(tx, ty), text,
				font_size, ink)
		var low := value <= low_threshold
		if low and blink_when_low and fmod(_blink_t, 0.9) > 0.55:
			return
		var bar := Rect2(Vector2(0.0, text_h + 3.0),
			Vector2(s.x, s.y - text_h - 3.0))
		var line := maxf(2.0, bar.size.y * 0.10)
		var nub_w := 0.0
		if battery_glyph:
			nub_w = maxf(4.0, bar.size.x * 0.035)
			var body := Rect2(bar.position, bar.size - Vector2(nub_w, 0.0))
			draw_rect(Rect2(body.position + Vector2(2, 2), body.size),
				VhsOsd.SHADOW, false, line)
			draw_rect(body, VhsOsd.INK, false, line)
			var nub_h := body.size.y * 0.44
			draw_rect(Rect2(
				Vector2(body.end.x + 1.0, body.position.y
					+ (body.size.y - nub_h) * 0.5),
				Vector2(nub_w - 1.0, nub_h)), VhsOsd.INK)
			bar = body.grow(-(line + 2.0))
		if channel_alpha > 0.0:
			draw_rect(bar, Color(0.0, 0.0, 0.0, channel_alpha))
		var fill := VhsOsd.RED if low else (
			VhsOsd.AMBER if value <= warn_threshold else VhsOsd.INK)
		var gap := maxf(2.0, bar.size.x * gap_ratio)
		var seg_w := (bar.size.x - gap * float(segments - 1)) / float(segments)
		var lit := int(ceil(clampf(value, 0.0, 1.0) * float(segments) - 0.0001))
		for i in segments:
			var r := Rect2(
				bar.position + Vector2(float(i) * (seg_w + gap), 0.0),
				Vector2(seg_w, bar.size.y))
			if i < lit:
				if not battery_glyph:
					draw_rect(Rect2(r.position + Vector2(2, 2), r.size),
						VhsOsd.SHADOW)
				draw_rect(r, fill)
			elif not battery_glyph:
				draw_rect(r, VhsOsd.INK_DIM, false, 1.0)


## Recovered-tape playback metadata. This is intentionally not a camera
## viewfinder: the still camera owns that language while raised. Normal play
## reads as footage already being watched, with transport state, tape counter,
## an uncanny fixed recording date and tracking damage.
class Frame extends Control:
	var font_size := 22
	var inset := Vector2(24.0, 24.0)
	## 0..1: something photographable is near. Tracking bars crawl through the
	## footage — the tape picks up what the eye does not, growing with
	## proximity. Set by PhotoCamera; purely presentational here.
	var interference := 0.0
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _process(dt: float) -> void:
		_t += dt
		if visible:
			queue_redraw()

	func _draw() -> void:
		var s := size
		# Interference: 1-3 translucent tracking bars, thicker and brighter
		# the nearer the thing is, drifting down the frame at uneven speeds.
		if interference > 0.01:
			var k := clampf(interference, 0.0, 1.0)
			var bars := 1 + int(k * 2.99)
			for i in bars:
				var speed := 0.16 + 0.11 * float(i)
				var y := fposmod(_t * speed * s.y + float(i) * s.y * 0.37, s.y)
				var thick := (3.0 + 9.0 * k) * (1.0 + 0.5 * float(i % 2))
				var a := 0.06 + 0.16 * k
				draw_rect(Rect2(0.0, y, s.x, thick), Color(1, 1, 1, a))
				draw_rect(Rect2(0.0, y + thick, s.x, 1.5),
					Color(0, 0, 0, a * 0.8))
		var f: Font = VhsOsd.FONT
		var top_y := inset.y + f.get_ascent(font_size)
		var play_at := Vector2(inset.x, top_y)
		VhsOsd.draw_osd_string(self, f, play_at, "PLAY", font_size,
			VhsOsd.INK)
		# A transport glyph, drawn instead of sourced from the font so it stays
		# a clean little playback triangle after the low-resolution tape pass.
		var play_w := f.get_string_size("PLAY", HORIZONTAL_ALIGNMENT_LEFT,
			-1, font_size).x
		var tri_h := float(font_size) * 0.36
		var tri_x := play_at.x + play_w + float(font_size) * 0.22
		var tri_y := top_y - f.get_ascent(font_size) * 0.48
		var tri := PackedVector2Array([
			Vector2(tri_x, tri_y - tri_h * 0.5),
			Vector2(tri_x, tri_y + tri_h * 0.5),
			Vector2(tri_x + tri_h * 0.78, tri_y),
		])
		var tri_shadow := PackedVector2Array()
		for p in tri:
			tri_shadow.append(p + Vector2(VhsOsd.SHADOW_OFFSET,
				VhsOsd.SHADOW_OFFSET))
		draw_colored_polygon(tri_shadow, VhsOsd.SHADOW)
		draw_colored_polygon(tri, VhsOsd.INK)

		var counter := _tape_counter()
		var counter_x := _right_x(f, counter)
		VhsOsd.draw_osd_string(self, f, Vector2(counter_x, top_y), counter,
			font_size, VhsOsd.INK)

		var date_text := "Jan. 01 1986"
		var clock_text := _clock_text()
		var line_h := f.get_height(font_size) * 1.05
		var date_y := s.y - inset.y
		var clock_y := date_y - line_h
		VhsOsd.draw_osd_string(self, f,
			Vector2(_right_x(f, clock_text), clock_y), clock_text,
			font_size, VhsOsd.INK)
		VhsOsd.draw_osd_string(self, f,
			Vector2(_right_x(f, date_text), date_y), date_text,
			font_size, VhsOsd.INK)

	func _right_x(f: Font, text: String) -> float:
		return size.x - inset.x - f.get_string_size(text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

	func _tape_counter() -> String:
		var total := maxi(0, floori(_t))
		var hours := int(total / 3600)
		var minutes := int(total / 60) % 60
		var seconds := total % 60
		return "%02d:%02d:%02d" % [hours, minutes, seconds]

	func _clock_text() -> String:
		var total_minutes := maxi(0, floori(_t / 60.0))
		var hour := int(total_minutes / 60) % 24
		var minute := total_minutes % 60
		var meridiem := "AM" if hour < 12 else "PM"
		return "%s %02d:%02d" % [meridiem, hour % 12, minute]

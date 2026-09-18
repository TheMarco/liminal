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


## Shared archive/confirmation controls: quiet until hovered or focused.
static func style_button(button: Button, size: int) -> void:
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", size)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.83))
	button.add_theme_color_override("font_focus_color", Color(1.0, 0.96, 0.83))
	button.add_theme_color_override("font_disabled_color", Color(0.44, 0.44, 0.40))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.045, 0.039, 0.031, 0.94)
	normal.border_color = Color(0.38, 0.35, 0.28)
	normal.set_border_width_all(1)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.11, 0.095, 0.065, 0.98)
	hover.border_color = Color(0.81, 0.74, 0.55)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color(0.93, 0.86, 0.65)
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color.a = 0.45
	disabled.border_color.a = 0.45
	button.add_theme_stylebox_override("disabled", disabled)


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


## Small drawn lightning icon used by the OSD without relying on a font glyph.
class FlashIcon extends Control:
	var held := false:
		set(value):
			if held == value:
				return
			held = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		var s := size
		var points := PackedVector2Array([
			Vector2(0.58, 0.06) * s,
			Vector2(0.17, 0.55) * s,
			Vector2(0.46, 0.55) * s,
			Vector2(0.33, 0.94) * s,
			Vector2(0.85, 0.40) * s,
			Vector2(0.55, 0.40) * s,
		])
		var closed := PackedVector2Array(points)
		closed.append(points[0])
		var stroke := maxf(2.0, s.y / 30.0)
		var shadow := PackedVector2Array()
		for point in points:
			shadow.append(point + Vector2(VhsOsd.SHADOW_OFFSET,
				VhsOsd.SHADOW_OFFSET))
		var shadow_closed := PackedVector2Array(shadow)
		shadow_closed.append(shadow[0])
		if held:
			draw_colored_polygon(shadow, VhsOsd.SHADOW)
			draw_colored_polygon(points, VhsOsd.INK)
			draw_polyline(closed, VhsOsd.INK, stroke, false)
		else:
			draw_polyline(shadow_closed, VhsOsd.SHADOW, stroke, false)
			draw_polyline(closed, VhsOsd.INK_DIM, stroke, false)


## Recovered-tape playback metadata. This is intentionally not a camera
## viewfinder: the still camera owns that language while raised. Normal play
## reads as footage already being watched, with transport state, tape counter,
## a recording date that advances with the Descent and tracking damage.
class Frame extends Control:
	const RECORDING_YEAR := 1986
	const MONTH_NAMES := ["Jan.", "Feb.", "Mar.", "Apr.", "May", "Jun.",
		"Jul.", "Aug.", "Sep.", "Oct.", "Nov.", "Dec."]
	const MONTH_DAYS := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

	var font_size := 22
	var inset := Vector2(24.0, 24.0)
	## Campaign floors are separate recovered recording days. Elapsed playback
	## can still roll the calendar naturally if a session somehow lasts a day.
	var recording_day_offset := 0:
		set(value):
			var next := maxi(0, value)
			if recording_day_offset == next:
				return
			recording_day_offset = next
			queue_redraw()
	## 0..1: something photographable is near. One faint tracking sweep hints
	## at proximity; the camera's sound and focus provide the stronger cues.
	## Set by PhotoCamera; purely presentational here.
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
		# Proximity must never stack bright full-screen bars over the CRT.
		# Keep a single thin sweep even at maximum detector strength, without
		# the old dark trailing edge that made each bar look like two lines.
		if interference > 0.01:
			var k := clampf(interference, 0.0, 1.0)
			var y := fposmod(_t * 0.075, 1.0) * s.y
			var thick := maxf(1.0, s.y / 720.0)
			draw_rect(Rect2(0.0, y, s.x, thick), Color(1, 1, 1, k * 0.045))
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

		var date_text := _date_text()
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
		var hour_12 := hour % 12
		if hour_12 == 0:
			hour_12 = 12
		return "%s %02d:%02d" % [meridiem, hour_12, minute]

	func _date_text() -> String:
		var elapsed_days := maxi(0, floori(_t / 86400.0))
		return recording_date_for_day(recording_day_offset + elapsed_days)

	static func recording_date_for_day(day_offset: int) -> String:
		var remaining := maxi(0, day_offset)
		var year := RECORDING_YEAR
		while true:
			var days_in_year := 366 if _is_leap_year(year) else 365
			if remaining < days_in_year:
				break
			remaining -= days_in_year
			year += 1
		var month := 0
		while month < MONTH_DAYS.size():
			var days_in_month: int = MONTH_DAYS[month]
			if month == 1 and _is_leap_year(year):
				days_in_month += 1
			if remaining < days_in_month:
				break
			remaining -= days_in_month
			month += 1
		return "%s %02d %04d" % [MONTH_NAMES[mini(month,
			MONTH_NAMES.size() - 1)], remaining + 1, year]

	static func _is_leap_year(year: int) -> bool:
		return year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)

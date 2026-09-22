extends RefCounted
## One continuous room-space warp for architecture, fixtures and collision.
## A travelling inward swell stays in the original lit room volume. Signed
## outward displacement enters static SDFGI occluders and produces dark patches.
## Both horizontal axes are pinned at the cell boundary, including galleries.
const DURATION := 8.0
const KEYS := 21
const AMPLITUDE := 0.35
const BAND := 2.8

static func pulse(along: float, phase: float) -> float:
	if phase <= 0.0 or phase >= 1.0: return 0.0
	var center := lerpf(-6.0-BAND, 6.0+BAND, phase)
	var u := (along-center)/BAND
	if absf(u) >= 1.0: return 0.0
	return AMPLITUDE * pow(cos(PI*0.5*u), 2.0) * smoothstep(0.0, 0.8, 6.0-absf(along))

static func deform(p: Vector3, phase: float, width: float, height: float) -> Vector3:
	return p + pulse(p.z, phase) * field(p, width, height)

## Time-independent displacement coefficient, cached once per mesh vertex.
static func field(p: Vector3, width: float, height: float) -> Vector3:
	var half := width*0.5
	# Keep at least 2.25 m headroom, including in the low Annex passages.
	var wave := clampf((height-2.25)/(2*AMPLITUDE), 0.0, 1.0)
	wave *= smoothstep(0.0, 0.8, 6.0-absf(p.x))
	var transverse := cos(PI*0.5*clampf(p.x/half, -1.0, 1.0))
	var vertical := wave * transverse * transverse * cos(PI*clampf(p.y/height, 0.0, 1.0))
	var height_weight := sin(PI*clampf(p.y/height, 0.0, 1.0))
	var side := smoothstep(half*0.45, half, absf(p.x)) * (1.0-smoothstep(half+0.15, half+0.65, absf(p.x)))
	return Vector3(-signf(p.x)*wave*height_weight*height_weight*side, vertical, 0)

static func posed(p: Vector3, phase: float, width: float, height: float) -> Vector3:
	var at := clampf(phase, 0.0, 1.0) * (KEYS-1)
	var lo := mini(KEYS-2, floori(at))
	return deform(p, float(lo)/(KEYS-1), width, height).lerp(deform(p, float(lo+1)/(KEYS-1), width, height), at-lo)

static func jacobian(p: Vector3, phase: float, width: float, height: float) -> Basis:
	const E := 0.005
	return Basis(
		(deform(p+Vector3.RIGHT*E, phase, width, height)-deform(p-Vector3.RIGHT*E, phase, width, height))/(2*E),
		(deform(p+Vector3.UP*E, phase, width, height)-deform(p-Vector3.UP*E, phase, width, height))/(2*E),
		(deform(p+Vector3.BACK*E, phase, width, height)-deform(p-Vector3.BACK*E, phase, width, height))/(2*E))

static func posed_jacobian(p: Vector3, phase: float, width: float, height: float) -> Basis:
	var at := clampf(phase, 0.0, 1.0) * (KEYS-1)
	var lo := mini(KEYS-2, floori(at))
	var a := jacobian(p, float(lo)/(KEYS-1), width, height)
	var b := jacobian(p, float(lo+1)/(KEYS-1), width, height)
	return Basis(a.x.lerp(b.x, at-lo), a.y.lerp(b.y, at-lo), a.z.lerp(b.z, at-lo))

// Camera-only wall tear (PhotoAnomaly PORTAL, 2026-08-20). A doorway-shaped
// opening that looks out onto somewhere that cannot be on the other side of
// this wall: a vast dead horizon, tinted toward the next floor's air when
// one exists. Pure shader illusion — parallax from the view direction fakes
// a volume behind the wall; no second camera, no captures, and the image is
// the CAMERA'S claim, so the mystery contract holds. GI-disabled and
// lens-only via render layers set by the spawner.
shader_type spatial;
// fog_disabled: the room's fog inscatter flattened the dark interior to a
// pale sheet — the tear is not in this room's air.
render_mode unshaded, cull_back, fog_disabled;

uniform vec3 tint : source_color = vec3(0.10, 0.11, 0.12);
uniform float seed_phase = 0.0;

float h21(vec2 p){
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise2(vec2 p){
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x),
		mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

void fragment(){
	// Parallax: shift the interior by the view direction so the opening
	// reads as depth, not decal. Deeper layers shift more.
	vec3 view = normalize(-VIEW);
	vec2 base_uv = UV - 0.5;
	float t = TIME * 0.03 + seed_phase;

	// A hole needs depth grammar, not murk: a pale dead sky far behind the
	// wall, a black ridge silhouetted against it, and parallax strong
	// enough to notice while strafing (a timid version read as "a grey
	// blanket", owner 2026-08-20). The tint arrives at any brightness (it
	// is a fog colour), so it is hard-normalised to a hue.
	float tmax = max(tint.r, max(tint.g, tint.b));
	vec3 hue = tint / max(tmax, 1e-4);

	// One fixed interior horizon; parallax comes ONLY from each layer's uv
	// offset (a view-dependent horizon fought the layer offsets and pushed
	// the composition out of frame). Quad UV y runs DOWN.
	const float H = 0.16;
	// Sky: far layer, big parallax, slow cloud bands drifting sideways.
	vec2 sky_uv = base_uv + view.xy * vec2(2.6, 1.4);
	float bands = noise2(vec2(sky_uv.x * 1.6 + t * 2.0, sky_uv.y * 3.0));
	vec3 sky = mix(vec3(0.055, 0.058, 0.054), hue * 0.10, 0.45)
		+ vec3(0.055) * bands;
	sky *= 1.0 + 1.3 * exp(-abs(sky_uv.y - H) * 5.0);
	// Dies overhead (negative y), breathes at the horizon.
	sky *= mix(0.25, 1.0, smoothstep(-0.75, H, sky_uv.y));
	sky *= 0.85;

	// Ground: a black ridge against the sky, nearer, so less parallax.
	vec2 ridge_uv = base_uv + view.xy * vec2(1.1, 0.6);
	float ridge_h = H - 0.02
		+ (noise2(vec2(ridge_uv.x * 3.5 + seed_phase, 3.7)) - 0.5) * 0.22;
	float ground = smoothstep(ridge_h - 0.015, ridge_h + 0.015, ridge_uv.y);
	vec3 col = mix(sky, vec3(0.004, 0.004, 0.005), ground);
	// Dust that never settles, drifting in front of everything.
	col += vec3(noise2(base_uv * 9.0 + vec2(t * 5.0, -t * 2.0))) * 0.012;
	// Grain that never settles.
	col += (h21(base_uv * 371.0 + fract(TIME) * vec2(13.7, 7.9)) - 0.5) * 0.05;

	// Ragged hard edges: alpha-scissor keeps the opaque pipeline, so the
	// tear silhouette is noise-torn plaster with no blend halo (the soft
	// feather composited a pale glow against the wall).
	vec2 e = abs(base_uv) * 2.0;
	float tear = noise2(base_uv * 7.0 + seed_phase) * 0.12;
	float shape = max(e.x, e.y) + tear;
	float edge = smoothstep(1.0, 0.92, shape);
	// A dark inner rim: the wall has thickness, the hole has a lip.
	col *= smoothstep(1.0, 0.88, shape) * 0.85 + 0.15;

	ALBEDO = col;
	ALPHA = edge;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}

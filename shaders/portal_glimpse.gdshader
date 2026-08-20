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

	// The tear is a hole first: near-black void, murk barely breathing in
	// it, and one dead horizon as the only light. The tint arrives at any
	// brightness (it is a fog colour), so it is hard-normalised to a dim
	// hue before use — a bright fill reads as a glowing sheet, not an
	// opening.
	float tmax = max(tint.r, max(tint.g, tint.b));
	vec3 hue = tint / max(tmax, 1e-4);
	vec3 col = hue * 0.004;
	for(int i = 0; i < 3; i++){
		float depth = 0.35 + 0.5 * float(i);
		vec2 uv = base_uv + view.xy * depth * 0.35;
		float n = noise2(uv * (3.0 + float(i) * 2.0)
			+ vec2(t * (0.4 + float(i) * 0.3), float(i) * 7.0));
		col += hue * n * (0.014 - 0.004 * float(i));
	}
	// A dead horizon line, low in the frame, faintly luminous.
	vec2 huv = base_uv + view.xy * 0.9 * 0.35;
	float horizon = exp(-abs(huv.y + 0.18) * 16.0);
	col += mix(hue, vec3(0.75, 0.76, 0.72), 0.55) * horizon * 0.10;
	// Grain that never settles.
	col += (h21(base_uv * 371.0 + fract(TIME) * vec2(13.7, 7.9)) - 0.5) * 0.05;

	// Ragged hard edges: alpha-scissor keeps the opaque pipeline, so the
	// tear silhouette is noise-torn plaster with no blend halo (the soft
	// feather composited a pale glow against the wall).
	vec2 e = abs(base_uv) * 2.0;
	float tear = noise2(base_uv * 7.0 + seed_phase) * 0.22;
	float edge = smoothstep(1.0, 0.90, max(e.x, e.y) + tear);

	ALBEDO = col;
	ALPHA = edge;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}

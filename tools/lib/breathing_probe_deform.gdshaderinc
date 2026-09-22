// Applied after the native vertex function: native pattern coordinates stay
// tied to the undeformed wall, while position, normals and tangents bow.
uniform mat4 probe_from_mesh;
uniform mat4 probe_to_mesh;
uniform vec2 probe_size;
uniform float probe_amount = 0.0;
uniform float probe_amplitude = 0.30;

void probe_deform(inout vec3 vertex, inout vec3 normal,
        inout vec3 tangent, inout vec3 binormal) {
    vec3 p = (probe_from_mesh * vec4(vertex, 1.0)).xyz;
    vec2 uv = p.xy / probe_size + vec2(0.5);
    if (uv.x <= 0.0 || uv.x >= 1.0 || uv.y <= 0.0 || uv.y >= 1.0) { return; }
    vec2 s = sin(PI * uv);
    float a = probe_amplitude * probe_amount;
    float dx = a * PI * sin(2.0 * PI * uv.x) * s.y * s.y / probe_size.x;
    float dy = a * PI * sin(2.0 * PI * uv.y) * s.x * s.x / probe_size.y;
    p.z += a * s.x * s.x * s.y * s.y;
    mat3 frame = mat3(probe_from_mesh);
    vec3 n = transpose(inverse(frame)) * normal;
    n = vec3(n.x - dx * n.z, n.y - dy * n.z, n.z);
    normal = normalize(transpose(frame) * n);
    vec3 t = frame * tangent;
    t.z += dx * t.x + dy * t.y;
    tangent = normalize(mat3(probe_to_mesh) * t);
    vec3 b = frame * binormal;
    b.z += dx * b.x + dy * b.y;
    binormal = normalize(mat3(probe_to_mesh) * b);
    vertex = (probe_to_mesh * vec4(p, 1.0)).xyz;
}

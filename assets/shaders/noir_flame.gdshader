shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// Язык пламени над чашей-жаровней (как на концепте): всегда лицом к камере, живой (шум по времени),
// ядро ярче единицы — его подхватывает glow окружения и даёт тёплый ореол.

uniform vec3 core : source_color = vec3(1.0, 0.86, 0.55);
uniform vec3 outer : source_color = vec3(1.0, 0.38, 0.06);
uniform float intensity = 2.6;
uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	// полный билборд: плоскость смотрит в камеру, размер — из меша
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	float h = 1.0 - UV.y;                       // 0 — основание, 1 — верх
	float t = TIME * 1.0 + seed * 13.0;
	float n = noise(vec2(UV.x * 4.0 + seed, UV.y * 3.0 + t * 2.6));
	float n2 = noise(vec2(UV.x * 9.0 - seed, UV.y * 7.0 + t * 4.1));
	float x = (UV.x - 0.5) * 2.0 + (n - 0.5) * 0.7 * h;
	float width = mix(0.95, 0.12, pow(h, 0.8));
	float shape = 1.0 - smoothstep(width * 0.45, width, abs(x));
	shape *= smoothstep(0.0, 0.1, h) * (1.0 - smoothstep(0.45 + n2 * 0.35, 0.95, h));
	float heat = shape * (1.0 - smoothstep(0.05, 0.65, h + abs(x) * 0.8));
	ALBEDO = mix(outer, core, heat) * shape * intensity * (0.85 + 0.3 * n2);
}

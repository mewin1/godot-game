shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// Язык пламени над чашей-жаровней (как на концепте): всегда лицом к камере, живой (шум по времени),
// ядро ярче единицы — его подхватывает glow окружения и даёт тёплый ореол.

uniform vec3 core : source_color = vec3(1.0, 0.86, 0.55);
uniform vec3 outer : source_color = vec3(1.0, 0.38, 0.06);
uniform float intensity = 3.3;
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
	float h = 1.0 - UV.y;
	float t = TIME * 1.65 + seed * 11.0;
	float n = noise(vec2(UV.x * 4.0, h * 5.0 - t * 2.4));
	float x = (UV.x - 0.5) * 2.0;
	float sway = (n - 0.5) * 0.66 * h + sin(h * 6.0 - t) * 0.15 * h;
	float width = mix(0.72, 0.025, smoothstep(0.04, 0.86, h));
	float body = (1.0 - smoothstep(width * 0.43, width, abs(x - sway)))
			* (1.0 - smoothstep(0.46 + 0.23 * n, 0.91, h));
	// Два несимметричных языка сходятся у углей и закручиваются на разной высоте.
	float fork = sin(t * 1.06 + h * 7.3);
	float side_x = x + 0.34 - 0.17 * fork;
	float side = (1.0 - smoothstep(0.03, 0.215 * (1.0 - h) + 0.039, abs(side_x)))
			* (1.0 - smoothstep(0.28, 0.69 + 0.12 * sin(t), h));
	float lick_x = x - 0.28 - 0.14 * sin(t * 0.83 - h * 8.1);
	float lick = (1.0 - smoothstep(0.01, 0.16 * (1.0 - h) + 0.028, abs(lick_x)))
			* (1.0 - smoothstep(0.23, 0.53 + 0.13 * fork, h));
	float heat = max(body, max(side * 0.93, lick * 0.81)) * smoothstep(0.0, 0.055, h);
	float heart = body * (1.0 - smoothstep(0.0, 0.63, h + abs(x - sway) * 0.80));
	float sp = fract(t * 0.34);
	vec2 ember = vec2((x - 0.25 * sin(t + sp * 4.0)) * 0.63, h - (0.47 + 0.49 * sp));
	float spark = (1.0 - smoothstep(0.004, 0.022, length(ember))) * sin(sp * 3.14159);
	ALBEDO = (mix(outer, core, heart) * heat + core * spark * 0.73) * intensity;
}

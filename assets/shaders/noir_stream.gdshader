shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
// Лесной ручей (арена «нуар»): тёмная вода с лунными бликами, рябь течёт вдоль русла.
// UV.x — вдоль течения (метры), UV.y — поперёк (0..1); у берегов вода мельче и светлее.

uniform vec3 deep : source_color = vec3(0.02, 0.05, 0.06);
uniform vec3 shallow : source_color = vec3(0.09, 0.14, 0.13);
uniform float flow = 0.6;  // м/с
uniform float ripple_scale = 1.4;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float ripples(vec2 p) {
	return noise(p) * 0.6 + noise(p * 2.3 + 7.1) * 0.4;
}

void fragment() {
	vec2 p = vec2(UV.x - TIME * flow, UV.y * 2.4) * ripple_scale;
	float e = 0.05;
	float h = ripples(p);
	float hx = ripples(p + vec2(e, 0.0));
	float hy = ripples(p + vec2(0.0, e));
	NORMAL_MAP = normalize(vec3((h - hx) / e * 0.35, (h - hy) / e * 0.35, 1.0)) * 0.5 + 0.5;
	float edge = 1.0 - abs(UV.y * 2.0 - 1.0);
	ALBEDO = mix(shallow, deep, smoothstep(0.0, 0.6, edge));
	ROUGHNESS = 0.22;
	SPECULAR = 0.2;  // мало тёплых бликов от факелов: иначе ручей читается как лава
	// холодные лунные отсветы на гребнях ряби — вода, а не тёмная полоса
	EMISSION = vec3(0.32, 0.5, 0.58) * pow(h, 5.0) * 0.5 * smoothstep(0.1, 0.5, edge);
	METALLIC = 0.1;
	// мягкий край: русло растворяется в берегу, без резкой ленты
	ALPHA = smoothstep(0.0, 0.25, edge);
}

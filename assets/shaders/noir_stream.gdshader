shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
// Лесной ручей (арена «нуар»): тёмная прозрачная вода, в ней отражается небо (по углу взгляда)
// и луна — дрожащим пятном на ряби в точке moon_spot. Рябь течёт вдоль русла.
// UV.x — вдоль течения (метры), UV.y — поперёк (0..1).

uniform vec3 deep : source_color = vec3(0.025, 0.06, 0.075);
uniform vec3 shallow : source_color = vec3(0.07, 0.13, 0.14);
uniform vec3 sky : source_color = vec3(0.3, 0.4, 0.48);  // отражённое ночное небо
uniform vec3 moon_color : source_color = vec3(0.92, 0.96, 1.0);
uniform vec3 moon_spot = vec3(12.0, 0.0, 7.0);  // мир: где на ручье видно отражение луны
uniform float moon_radius = 1.3;  // м
uniform float flow = 0.5;  // м/с
uniform float ripple_scale = 0.9;

varying vec3 world;

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

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = vec2(UV.x - TIME * flow, UV.y * 2.4) * ripple_scale;
	float e = 0.05;
	float h = ripples(p);
	vec2 slope = vec2(h - ripples(p + vec2(e, 0.0)), h - ripples(p + vec2(0.0, e))) / e;
	vec3 n_world = normalize(vec3(slope.x * 0.12, 1.0, slope.y * 0.12));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	float edge = 1.0 - abs(UV.y * 2.0 - 1.0);
	// чем положе взгляд, тем больше вода отражает небо (Френель)
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(shallow, deep, smoothstep(0.0, 0.6, edge));
	// луна: светлое пятно, растянутое вдоль взгляда камеры (ось x), дрожит на ряби
	vec2 d = (world.xz - moon_spot.xz + slope * 0.25) / vec2(moon_radius * 1.8, moon_radius);
	float disc = smoothstep(1.0, 0.55, length(d)) * (0.65 + 0.35 * h);
	float glow = exp(-dot(d, d) * 0.35) * 0.35;
	EMISSION = sky * (0.12 + fresnel * 0.5) * smoothstep(0.05, 0.4, edge) + moon_color * (disc * 1.8 + glow * 1.2);
	ROUGHNESS = 0.05;
	SPECULAR = 0.15;  // тёплые блики факелов почти не берёт: иначе вода выглядит как нефть
	ALPHA = smoothstep(0.0, 0.25, edge);
}

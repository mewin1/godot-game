shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
// Лесной ручей (арена «нуар»): тёмная прозрачная вода, в ней отражается небо (по углу взгляда)
// и луна — дрожащим пятном на ряби в точке moon_spot. Рябь течёт вдоль русла.
// UV.x — вдоль течения (метры), UV.y — поперёк (0..1).

uniform sampler2D bed : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 deep : source_color = vec3(0.025, 0.06, 0.075);
uniform vec3 shallow : source_color = vec3(0.16, 0.25, 0.23);
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
	return noise(p * vec2(2.3, 0.81)) * 0.61 + noise(p * vec2(4.1, 2.7) + 7.1) * 0.39;
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = vec2(UV.x - TIME * flow, UV.y * 2.4) * ripple_scale;
	float e = 0.05;
	float h = ripples(p) + 0.16 * sin(p.x * 6.4 + p.y * 2.8 + ripples(p * 0.7) * 3.0);
	vec2 slope = vec2(ripples(p) - ripples(p + vec2(e, 0.0)), ripples(p) - ripples(p + vec2(0.0, e))) / e;
	slope += vec2(0.5, 0.18) * cos(p.x * 6.4 + p.y * 2.8 + ripples(p * 0.7) * 3.0);
	// Длинные волны поворачивают вместе с руслом.
	vec2 dx = dFdx(world.xz);
	vec2 dy = dFdy(world.xz);
	vec2 along = dx * dFdy(UV.y) - dy * dFdx(UV.y);
	float det = dFdx(UV.x) * dFdy(UV.y) - dFdy(UV.x) * dFdx(UV.y);
	along = normalize(along * sign(det) + vec2(0.000001));
	vec2 gradient = along * slope.x + vec2(-along.y, along.x) * slope.y;
	vec3 n_world = normalize(vec3(gradient.x * 0.12, 1.0, gradient.y * 0.12));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	float edge = 1.0 - abs(UV.y * 2.0 - 1.0);
	// чем положе взгляд, тем больше вода отражает небо (Френель)
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec2 bed_uv = world.xz * 0.85 + gradient * 0.018;
	vec3 gravel = texture(bed, bed_uv).rgb;
	float shoal = 1.0 - smoothstep(0.12, 0.79, edge);
	ALBEDO = mix(deep, mix(shallow, gravel * vec3(0.46, 0.61, 0.57), 0.68), shoal);
	// луна: светлое пятно, растянутое вдоль взгляда камеры (ось x), дрожит на ряби
	vec2 d = (world.xz - moon_spot.xz + slope * 0.08) / vec2(moon_radius * 1.8, moon_radius);
	float disc = (1.0 - smoothstep(0.2, 1.0, length(d))) * (0.85 + 0.15 * h) * smoothstep(0.15, 0.6, edge);  // мягкий край, у берега гаснет
	float glow = exp(-dot(d, d) * 0.35) * 0.35;
	float crest = smoothstep(0.62, 0.84, h + gradient.y * 0.12);
	float ribbon = crest * (0.16 + fresnel) * smoothstep(0.08, 0.5, edge);
	EMISSION = sky * ((0.08 + fresnel * 0.28) * smoothstep(0.05, 0.4, edge) + ribbon * 0.28)
			+ moon_color * (disc * 0.34 + glow * 0.15) * mix(0.18, 1.10, crest);
	ROUGHNESS = mix(0.21, 0.43, shoal);
	SPECULAR = 0.15;  // тёплые блики факелов почти не берёт: иначе вода выглядит как нефть
	ALPHA = smoothstep(0.0, 0.25, edge);
}

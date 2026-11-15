// Общая вода «нуар» (ручей и пруд): тёмная прозрачная вода, в ней отражается небо (по углу
// взгляда) и луна — дрожащим пятном на ряби в точке moon_spot. Вынесено из noir_stream.gdshader:
// цвет и рябь воды правятся здесь сразу для ручья и пруда.
// Ручей (#define WATER_STREAM): UV.x — вдоль течения (метры), UV.y — поперёк (0..1), рябь течёт вдоль русла.
// Пруд: рябь в метрах мира по обеим осям, течения нет; UV.y — расстояние до берега (0 на урезе,
// 0,5 — глубже 1,1 м), так что мель и прозрачность идут по всему контуру.

uniform sampler2D bed : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 deep : source_color = vec3(0.025, 0.06, 0.075);
uniform vec3 shallow : source_color = vec3(0.16, 0.25, 0.23);
uniform vec3 sky : source_color = vec3(0.3, 0.4, 0.48);  // отражённое ночное небо
uniform vec3 moon_color : source_color = vec3(0.92, 0.96, 1.0);
uniform vec3 moon_spot = vec3(12.0, 0.0, 7.0);  // мир: где на ручье видно отражение луны
uniform float moon_radius = 1.3;  // м
uniform float flow = 0.5;  // м/с
uniform float ripple_scale = 0.9;
uniform float water_specular = 0.15;
// Светлые гребни ряби (пруду ночью — x0,3, critique_3 п. 29: без белых «запятых»).
uniform float crest_gain = 1.0;

varying vec3 world;

float hash(vec2 p) {
#ifdef WATER_STREAM
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
#else
	// Пруд: рябь в метрах мира, координаты шума крупные — синус больших чисел давал соседним
	// ячейкам разные значения на общем углу, и вода шла прямоугольными плашками. Хэш без синуса.
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
#endif
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
#ifdef WATER_STREAM
	vec2 p = vec2(UV.x - TIME * flow, UV.y * 2.4) * ripple_scale;
#else
	vec2 p = vec2(world.x - TIME * flow, world.z) * ripple_scale;
#endif
	float e = 0.05;
	float h = ripples(p) + 0.16 * sin(p.x * 6.4 + p.y * 2.8 + ripples(p * 0.7) * 3.0);
	vec2 slope = vec2(ripples(p) - ripples(p + vec2(e, 0.0)), ripples(p) - ripples(p + vec2(0.0, e))) / e;
	slope += vec2(0.5, 0.18) * cos(p.x * 6.4 + p.y * 2.8 + ripples(p * 0.7) * 3.0);
#ifdef WATER_STREAM
	// Длинные волны поворачивают вместе с руслом.
	vec2 dx = dFdx(world.xz);
	vec2 dy = dFdy(world.xz);
	vec2 along = dx * dFdy(UV.y) - dy * dFdx(UV.y);
	float det = dFdx(UV.x) * dFdy(UV.y) - dFdy(UV.x) * dFdx(UV.y);
	along = normalize(along * sign(det) + vec2(0.000001));
#else
	vec2 along = vec2(1.0, 0.0);
#endif
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
	EMISSION = sky * ((0.08 + fresnel * 0.28) * smoothstep(0.05, 0.4, edge) + ribbon * 0.28 * crest_gain)
			+ moon_color * (disc * 0.34 + glow * 0.15) * mix(0.18, 1.10, crest * crest_gain);
	ROUGHNESS = mix(0.21, 0.43, shoal);
	SPECULAR = water_specular;  // тёплые блики факелов почти не берёт: иначе вода выглядит как нефть
	ALPHA = smoothstep(0.0, 0.25, edge);
}

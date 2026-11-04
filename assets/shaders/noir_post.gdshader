shader_type canvas_item;
// Постобработка 3D-арены «нуар» (вариант F с листа new_concept/compare/day/post_variants.jpg).
// Только на картинку 3D-сцены (ArenaStage3D рисует ею свой SubViewport), интерфейс не трогает.
// Порядок как в образце: мягкий контраст → ясность → палитра концепта → виньетка → зерно.
// Свечение огня и луны — glow окружения сцены, мягкий дальний лес — DOF камеры (match_arena_noir.tscn).

uniform float curve : hint_range(0.0, 1.0) = 0.25;
uniform float clarity : hint_range(0.0, 1.0) = 0.25;
uniform float clarity_radius = 7.0;  // пикселей
// Палитра концепта: по каналам YCbCr (0..1) кадра игры и верха 05_arena.jpg. Яркость — умножением
// (чёрное остаётся чёрным), цветность — растяжением вокруг серого.
uniform float grade_amount : hint_range(0.0, 1.0) = 0.6;
uniform vec3 src_mean = vec3(0.1001, 0.4950, 0.5005);
uniform vec3 src_std = vec3(0.1196, 0.0231, 0.0297);
uniform vec3 dst_mean = vec3(0.1379, 0.4965, 0.4970);
uniform vec3 dst_std = vec3(0.1173, 0.0314, 0.0358);
uniform vec3 shadow_tint = vec3(-0.008, 0.004, 0.01);
uniform vec3 light_tint = vec3(0.03, 0.012, -0.01);
uniform float black_point = 0.012;
uniform float vignette : hint_range(0.0, 1.0) = 0.42;
uniform vec2 vignette_center = vec2(0.6, 0.55);  // двор правее центра (слева панели)
uniform float grain : hint_range(0.0, 0.05) = 0.008;

vec3 to_ycc(vec3 c) {
	float y = dot(c, vec3(0.299, 0.587, 0.114));
	return vec3(y, (c.b - y) * 0.564 + 0.5, (c.r - y) * 0.713 + 0.5);
}

vec3 from_ycc(vec3 v) {
	float cb = v.y - 0.5;
	float cr = v.z - 0.5;
	return vec3(v.x + 1.403 * cr, v.x - 0.344 * cb - 0.714 * cr, v.x + 1.773 * cb);
}

void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	c = mix(c, c * c * (3.0 - 2.0 * c), curve);

	// ясность: разница с размытым (кольца по 8 точек) — формы чётче, без пересвета
	vec3 blurred = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.7854;
		vec2 dir = vec2(cos(a), sin(a)) * TEXTURE_PIXEL_SIZE * clarity_radius;
		blurred += texture(TEXTURE, UV + dir).rgb + texture(TEXTURE, UV + dir * 0.5).rgb;
	}
	blurred /= 16.0;
	vec3 base = mix(blurred, blurred * blurred * (3.0 - 2.0 * blurred), curve);
	c += (c - base) * clarity;

	vec3 y = to_ycc(clamp(c, 0.0, 1.0));
	vec3 graded = vec3(y.x * dst_mean.x / src_mean.x, (y.yz - 0.5) * dst_std.yz / src_std.yz + 0.5);
	c = from_ycc(mix(y, graded, grade_amount));
	// нуар: глубокие холодные тени (бирюза), тепло — только в светлом (огонь)
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	c += (1.0 - smoothstep(0.0, 0.3, l)) * shadow_tint + smoothstep(0.45, 0.9, l) * light_tint;
	c = max(c - black_point, 0.0) / (1.0 - black_point);

	vec2 d = (UV - vignette_center) / vec2(0.75, 0.65);
	c *= 1.0 - vignette * smoothstep(0.45, 1.15, length(d));

	float n = fract(sin(dot(UV * vec2(1931.0, 1777.0) + fract(TIME) * 7.0, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	c += n * grain * 2.0 * (1.0 - dot(c, vec3(0.333)) * 0.6);
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}

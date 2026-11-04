shader_type spatial;
render_mode cull_disabled;
// Грунтовая дорожка «нуар» (как на концепте): бледная серо-бежевая утоптанная земля, две колеи,
// тёмные края и кайма мха с травой по обочине. UV.x — поперёк (0..1), UV.y — вдоль (м / 4).

uniform vec3 dirt : source_color = vec3(0.42, 0.37, 0.31);  // тёплый беж (концепт)
uniform vec3 dirt_dark : source_color = vec3(0.24, 0.235, 0.21);
uniform vec3 moss_color : source_color = vec3(0.12, 0.17, 0.07);
uniform vec3 border : source_color = vec3(0.22, 0.16, 0.12);

varying vec3 world;

float hash1(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 15731.743);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash1(i), hash1(i + vec2(1, 0)), f.x), mix(hash1(i + vec2(0, 1)), hash1(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world.xz;
	float u = UV.x;
	float wobble = (noise(vec2(UV.y * 9.0, 0.5)) - 0.5) * 0.05;  // колеи чуть виляют
	float ruts = 0.0;
	for (int k = 0; k < 2; k++) {
		float center = (k == 0 ? 0.27 : 0.73) + wobble;
		ruts = max(ruts, 1.0 - smoothstep(0.03, 0.09, abs(u - center)));
	}
	float side = min(u, 1.0 - u);                       // 0 — край, 0.5 — середина
	vec3 col = mix(dirt_dark, dirt, smoothstep(0.02, 0.22, side));
	col = mix(border, col, smoothstep(0.1, 0.15, side));  // бурый бортик по краю
	col *= 0.86 + 0.28 * noise(p * 2.3) * noise(p * 7.0 + 3.0);
	col = mix(col, col * 0.6, ruts);  // колеи — темнее, светлый гребень посередине
	// обочина: мох и трава заходят на край неровно
	float moss = 1.0 - smoothstep(0.02, 0.05, side + (noise(p * 4.0) - 0.5) * 0.04);
	col = mix(col, moss_color * (0.8 + 0.4 * noise(p * 13.0)), moss);
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.75, ruts);
	SPECULAR = 0.3;
}

shader_type fog;

// Плотность в мировых метрах. Тени от хвои и свет луны вносит сам объём Godot.
uniform vec4 yard_rect;
// снос ветром (NoirWind): в порыв дымка летит быстрее
global uniform vec3 noir_wind_drift;
float hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float cloud(vec3 p) {
	vec3 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec2 rows = mix(vec2(hash3(i), hash3(i + vec3(0, 0, 1))),
			vec2(hash3(i + vec3(1, 0, 0)), hash3(i + vec3(1, 0, 1))), f.x);
	vec2 next_rows = mix(vec2(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(0, 1, 1))),
			vec2(hash3(i + vec3(1, 1, 0)), hash3(i + vec3(1))), f.x);
	vec2 slices = mix(rows, next_rows, f.y);
	return mix(slices.x, slices.y, f.z);
}

void fog() {
	vec3 p = WORLD_POSITION;
	vec2 bank = max(yard_rect.xy - p.xz, p.xz - yard_rect.zw);
	float woods = smoothstep(0.0, 4.5, length(max(bank, vec2(0.0))));
	vec3 q = (p - noir_wind_drift) * vec3(0.11, 0.26, 0.078);
	float body = cloud(q);
	float fold = cloud(q * 2.3 + vec3(body * 0.7, 9.2, 2.5));
	float lee = smoothstep(-5.0, 15.0, dot(p.xz - vec2(9, -10), vec2(-0.89, 0.46)));
	float ceiling = 1.8 + 5.8 * body + 1.7 * lee;
	float height = 1.0 - smoothstep(0.1, ceiling, p.y);
	float patch = smoothstep(0.24, 0.78, body * 0.68 + fold * 0.32);
	float edge = smoothstep(0.0, 0.07, min(min(UVW.x, 1.0 - UVW.x), min(UVW.z, 1.0 - UVW.z)));
	DENSITY = (0.007 + 0.125 * patch) * height * woods * edge * mix(0.20, 1.0, lee);
	ALBEDO = vec3(0.48, 0.71, 0.74);
	// Едва заметный рассеянный свет только внутри завесы.
	EMISSION = vec3(0.015, 0.037, 0.043) * patch * height * woods * lee * edge;
}

shader_type spatial;
render_mode cull_disabled;
// Четыре квадратных метра по каждой стороне карты фактуры.
// R/G рельефа — уклон по мировым X/Z, B — шероховатость.
uniform sampler2D setts : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D relief : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 origin = vec2(0.0);
// У «Обряда» своя ночная палитра на этой же кладке.
uniform bool custom_palette = false;
uniform vec3 stone_dark : source_color;
uniform vec3 stone_light : source_color;
uniform vec3 grout_color : source_color;
varying vec2 ground;
varying float border;

void vertex() {
	ground = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz - origin;
	border = COLOR.r;
}

void fragment() {
	vec2 uv = ground * 0.25;
	vec3 r = texture(relief, uv).rgb;
	vec3 stone = texture(setts, uv).rgb;
	if (custom_palette) {
		float value = dot(stone, vec3(0.29, 0.58, 0.13));
		vec3 slab = mix(stone_dark, stone_light, smoothstep(0.03, 0.115, value));
		stone = mix(grout_color, slab, smoothstep(0.022, 0.047, value))
				* (0.86 + 0.28 * clamp(value * 9.0, 0.0, 1.0));
	}
	// Поворот пятен относительно кладки скрывает повтор, швы остаются по клеткам.
	float patch = 0.5 + 0.23 * sin(ground.x * 0.71 + ground.y * 0.42)
			+ 0.19 * sin(ground.y * 1.21 - ground.x * 0.38) + 0.08 * sin(ground.x * 2.4 + ground.y * 1.1);
	float face = 1.0 - smoothstep(0.74, 0.90, r.b);
	float wet = smoothstep(0.48, 0.74, patch) * face;
	if (!custom_palette) {
		// Вода собирается во впадинах между камнями. Сухие грани сохраняют свой цвет.
		float well = smoothstep(0.72, 0.88, r.b) * smoothstep(0.53, 0.80, patch);
		wet = max(wet, well * 0.79);
		float facet = smoothstep(-0.16, 0.19, r.g - r.r);
		stone *= mix(vec3(0.87, 0.92, 1.00), vec3(1.03, 1.01, 0.95), facet);
	}
	float rim = smoothstep(0.45, 1.0, border) * smoothstep(0.70, 0.94, r.b);
	vec3 moss = vec3(0.035, 0.049, 0.023);
	ALBEDO = mix(stone * mix(1.02, 0.64, wet), moss, rim * 0.65);
	ROUGHNESS = mix(clamp(r.b + rim * 0.12, 0.50, 0.96), 0.32, wet);
	SPECULAR = 0.42;
	CLEARCOAT = wet * 0.24;
	CLEARCOAT_ROUGHNESS = 0.23;
	vec2 slope = (r.rg * 2.0 - 1.0) * 0.85;
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(vec3(slope.x, 1.0, slope.y)), 0.0)).xyz);
}

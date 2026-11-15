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
// Без «кафеля» (critique_3 п. 23): каждая клетка 2 м берёт одну из четырёх плиток карты без рамки,
// повёрнутую по хэшу клетки; границы клеток волнистые. Выключено — прежняя кладка PvP.
uniform bool scatter = false;
varying vec2 ground;
varying float border;

void vertex() {
	ground = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz - origin;
	border = COLOR.r;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 uv = ground * 0.25;
	vec2 du = dFdx(uv);
	vec2 dv = dFdy(uv);
	mat2 turn = mat2(1.0);
	if (scatter) {
		vec2 warp = vec2(value_noise(ground * 0.45), value_noise(ground * 0.45 + 17.3)) * 0.8 - 0.4;
		vec2 g = (ground + warp) * 0.5;
		vec2 cell = floor(g);
		vec2 local = fract(g) - 0.5;
		float h = hash(cell);
		float quarter = floor(h * 4.0);
		float c = quarter == 1.0 ? 0.0 : (quarter == 3.0 ? 0.0 : (quarter == 2.0 ? -1.0 : 1.0));
		float s = quarter == 1.0 ? 1.0 : (quarter == 3.0 ? -1.0 : 0.0);
		turn = mat2(vec2(c, s), vec2(-s, c));
		local = turn * local + 0.5;
		vec2 tile = vec2(floor(fract(h * 7.13) * 2.0), floor(fract(h * 3.77) * 2.0));
		const float CROP = 0.08;
		uv = (tile + CROP + local * (1.0 - 2.0 * CROP)) * 0.5;
		du = turn * du * (1.0 - 2.0 * CROP);
		dv = turn * dv * (1.0 - 2.0 * CROP);
	}
	vec3 r = textureGrad(relief, uv, du, dv).rgb;
	vec3 stone = textureGrad(setts, uv, du, dv).rgb;
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
	if (custom_palette) {
		// Без «лавы» у огней (critique_3 п. 8): мокрые пятна матовее, без лака.
		SPECULAR = 0.25;
		CLEARCOAT = 0.0;
		ROUGHNESS = max(ROUGHNESS, 0.55);
	}
	CLEARCOAT_ROUGHNESS = 0.23;
	vec2 slope = transpose(turn) * ((r.rg * 2.0 - 1.0) * 0.85);
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(vec3(slope.x, 1.0, slope.y)), 0.0)).xyz);
}

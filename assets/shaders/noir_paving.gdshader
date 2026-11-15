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
// Без «кафеля» и без швов (critique_4 п. 15): булыжник строится в шейдере (ячейки Вороного) —
// камни непрерывны по всему двору, сетки клеток нет. Выключено — прежняя кладка PvP по карте фактуры.
uniform bool scatter = false;
// Средний размер камня, м.
uniform float stone_size = 0.42;
// Облицовка стен (подклет терема, critique_4 п. 11): на боковых гранях кладка по (x+z, y), свет — по
// нормали грани; мох по швам выключен.
uniform bool walls = false;
varying vec2 ground;
varying float border;

varying float upright;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 facing = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	upright = walls ? 1.0 - step(0.5, abs(facing.y)) : 0.0;
	ground = upright > 0.5 ? vec2(world.x + world.z, world.y) : world.xz - origin;
	border = walls ? 0.0 : COLOR.r;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

// Кладка Вороного (по И. Квилесу): x — расстояние до шва, yz — смещение от центра камня, w — хэш камня.
vec4 cobble(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	vec2 mg;
	vec2 mr;
	float md = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = 0.12 + 0.76 * hash2(n + g);
			vec2 r = g + o - f;
			float d = dot(r, r);
			if (d < md) {
				md = d;
				mr = r;
				mg = g;
			}
		}
	}
	float edge = 8.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			vec2 g = mg + vec2(float(i), float(j));
			vec2 o = 0.12 + 0.76 * hash2(n + g);
			vec2 r = g + o - f;
			if (dot(mr - r, mr - r) > 0.00001) {
				edge = min(edge, dot(0.5 * (mr + r), normalize(r - mr)));
			}
		}
	}
	return vec4(edge, -mr, hash(n + mg));
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
	vec3 r;
	vec3 stone;
	if (scatter) {
		// Камни: тёмный шов, скруглённый край (уклон наружу у шва), свой тон и наклон каждого камня.
		vec2 q = ground / stone_size + vec2(value_noise(ground * 1.7), value_noise(ground * 1.7 + 9.1)) * 0.35;
		vec4 c = cobble(q);
		float px = length(fwidth(q));
		float seam = 1.0 - smoothstep(0.035, 0.075 + px, c.x);
		float bevel = 1.0 - smoothstep(0.0, 0.2, c.x);
		vec2 tilt = (hash2(vec2(c.w * 91.7, c.w * 17.3)) - 0.5) * 0.25;
		vec2 out_dir = normalize(c.yz + vec2(0.0001));
		vec2 slope = out_dir * bevel * 0.9 + tilt;
		float grain = value_noise(ground * 9.0) * 0.5 + value_noise(ground * 23.0) * 0.5;
		float tone = 0.075 + 0.05 * fract(c.w * 13.7) + 0.02 * (grain - 0.5);
		// Тон в шкале карты фактуры: дальше та же палитра custom_palette, что и у прежней кладки.
		stone = vec3(mix(tone * (1.0 - 0.25 * bevel), 0.0, seam));
		r = vec3(clamp(slope * 0.5 + 0.5, 0.0, 1.0), mix(0.62 + 0.1 * grain, 0.95, max(seam, bevel * 0.35)));
	} else {
		r = textureGrad(relief, uv, du, dv).rgb;
		stone = textureGrad(setts, uv, du, dv).rgb;
	}
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
	if (upright < 0.5) {
		NORMAL = normalize((VIEW_MATRIX * vec4(normalize(vec3(slope.x, 1.0, slope.y)), 0.0)).xyz);
	}
}

shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D finishes : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform int roof_column : hint_range(0, 6) = 0;
// Крыша (critique_3 п. 5): 0 — цвет школы, но приглушённый (яркость <= 0,42, насыщенность -40%);
// 1 — тёмная тёсовая крыша с лёгким оттенком школы (цвет — у машины).
uniform int roof_mode : hint_range(0, 1) = 1;
// Working faces and windows share the atlas so that one mesh needs one surface.
instance uniform float working_light = 1.0;
// Износ (critique_3 п. 64): копоть пятнами и тёмные пробоины на кровле; 0 — цел, 1 — молчит.
instance uniform float wear = 0.0;
// Ночь 0..1 (critique_4 п. 1): тёмный тёс ночью светлее и с лунным блеском — дом средним тоном
// между лесом-рамкой и дорогой, а не чёрным провалом. Задаёт RitualDaylight через RitualTownHouse.
uniform float night = 0.0;
// Маска для замеров пробника: крыша — красный, окна — зелёный, рабочие грани машины — синий.
uniform bool debug_mask = false;
varying flat int swatch;
varying vec2 atlas_uv;
varying vec3 body;

void vertex() {
	body = VERTEX;
	ivec2 slot = ivec2(floor(UV * vec2(8., 4.)));
	swatch = slot.y * 8 + slot.x;
	atlas_uv = UV;
	if (swatch == 8) {
		atlas_uv.x += float(roof_column) / 8.;
	}
}

vec3 to_srgb(vec3 c) { return pow(max(c, vec3(0.0)), vec3(1.0 / 2.2)); }
vec3 to_linear(vec3 c) { return pow(max(c, vec3(0.0)), vec3(2.2)); }

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

// Средний цвет плашки атласа — по мелкому мипу её центра.
vec3 swatch_mean(vec2 uv) {
	vec2 cell = (floor(uv * vec2(8.0, 4.0)) + 0.5) / vec2(8.0, 4.0);
	return to_srgb(textureLod(finishes, cell, 6.0).rgb);
}

// Насколько светлеет тёс ночью (по sRGB): крыши ночью 40-55 при рамке <= 30 (critique_4 п. 1).
const float ROOF_NIGHT_LIFT = 0.3;

vec3 quiet_roof(vec3 paint) {
	vec3 srgb = to_srgb(paint);
	vec3 mean = swatch_mean(atlas_uv);
	float mean_value = max(max(mean.r, mean.g), mean.b);
	if (roof_mode == 0) {
		vec3 hsv = rgb2hsv(srgb);
		hsv.y *= 0.6;
		hsv.z *= min(1.0, 0.42 / max(mean_value, 0.01));
		return to_linear(hsv2rgb(hsv));
	}
	// Тёмный тёс: рисунок черепицы сохраняется, цвет школы — четвертью.
	float detail = dot(srgb, vec3(0.299, 0.587, 0.114)) / max(dot(mean, vec3(0.299, 0.587, 0.114)), 0.01);
	vec3 hue = hsv2rgb(vec3(rgb2hsv(mean).x, 0.5, 0.4));
	vec3 roof = mix(vec3(0.26, 0.21, 0.18), hue, mix(0.4, 0.5, night)) * detail;
	return to_linear(roof * (1.0 + ROOF_NIGHT_LIFT * night));
}

float wear_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = fract(sin(dot(i, vec2(127.1, 311.7))) * 43758.5453);
	float b = fract(sin(dot(i + vec2(1.0, 0.0), vec2(127.1, 311.7))) * 43758.5453);
	float c = fract(sin(dot(i + vec2(0.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	float d = fract(sin(dot(i + vec2(1.0, 1.0), vec2(127.1, 311.7))) * 43758.5453);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec3 paint = texture(finishes, atlas_uv).rgb;
	ALBEDO = paint;
	if (swatch == 8) {
		ALBEDO = quiet_roof(paint);
	}
	if (wear > 0.0) {
		// critique_4 п. 30: пятна копоти крупные — по объёму дома (видны с игровой камеры), а не по атласу;
		// весь дом темнее и серее.
		vec2 spot = vec2(body.x + body.z, body.y + 0.6 * body.z) * 5.0;
		float n = wear_noise(spot) * 0.65 + wear_noise(spot * 2.3 + 5.1) * 0.35;
		float soot = smoothstep(0.6 - 0.2 * wear, 0.74 - 0.18 * wear, n);
		float gray = dot(ALBEDO, vec3(0.3, 0.59, 0.11));
		ALBEDO = mix(ALBEDO, vec3(gray), 0.55 * wear) * (1.0 - 0.3 * wear);
		ALBEDO *= 1.0 - 0.75 * soot;
		if (swatch == 8) {
			// Пробоины в кровле: чёрные провалы с краем.
			float hole = smoothstep(0.86 - 0.18 * wear, 0.9 - 0.18 * wear, wear_noise(spot * 0.7 + 13.0));
			ALBEDO = mix(ALBEDO, vec3(0.012, 0.01, 0.01), hole * step(0.3, wear));
		}
	}
	ROUGHNESS = 0.88;
	if (swatch == 8) {
		// Лунный блеск на тёсе: ночью крыша ловит луну и отделяется от леса.
		ROUGHNESS = mix(0.88, 0.7, night);
		SPECULAR = mix(0.5, 0.6, night);
	}
	if ((swatch >= 16 && swatch <= 19) || swatch == 31) {
		METALLIC = 0.52;
		ROUGHNESS = 0.51;
	}
	if (swatch == 22) {
		// Молчащий дом — тёмные окна (critique_4 п. 30).
		// Вечером и днём окна тише (critique_4 п. 55: ярче врагов), ночью — как были.
		EMISSION = paint * 0.42 * mix(0.7, 1.0, night) * (1.0 - smoothstep(0.7, 1.0, wear));
		ALBEDO *= 1.0 - 0.6 * smoothstep(0.7, 1.0, wear);
	}
	if (swatch >= 24 && swatch <= 28) {
		// Рабочие грани машины (critique_3 п. 6): тело темнее, свечение — цветом стихии и слабее;
		// белые «фонари» Инея и Росника больше не самые яркие пятна ночи.
		// critique_4 п. 3: ядро не белее value 0,7 (ледяные лезвия были ярче врагов и идолов ночью).
		float strength = swatch == 26 ? 0.38 : (swatch == 24 ? 0.66 : 1.0);
		vec3 hsv = rgb2hsv(to_srgb(paint));
		vec3 mean = rgb2hsv(swatch_mean(atlas_uv));
		vec3 core = to_linear(hsv2rgb(vec3(mean.x, max(mean.y, 0.55), min(hsv.z, 0.6))));
		ALBEDO = mix(paint, core, 0.6) * 0.42;
		EMISSION = core * working_light * strength * 0.55;
		ROUGHNESS = swatch == 24 ? 0.78 : 0.28;
	}
	if (debug_mask) {
		ALBEDO = vec3(0.0);
		SPECULAR = 0.0;
		ROUGHNESS = 1.0;
		METALLIC = 0.0;
		EMISSION = swatch == 8 ? vec3(0.5, 0.0, 0.0) : (swatch == 22 ? vec3(0.0, 0.5, 0.0)
				: ((swatch >= 24 && swatch <= 28) ? vec3(0.0, 0.0, 0.5) : vec3(0.0)));
	}
}

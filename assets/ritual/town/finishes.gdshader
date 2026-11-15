shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D finishes : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform int roof_column : hint_range(0, 6) = 0;
// Крыша (critique_3 п. 5): 0 — цвет школы, но приглушённый (яркость <= 0,42, насыщенность -40%);
// 1 — тёмная тёсовая крыша с лёгким оттенком школы (цвет — у машины).
uniform int roof_mode : hint_range(0, 1) = 1;
// Working faces and windows share the atlas so that one mesh needs one surface.
instance uniform float working_light = 1.0;
varying flat int swatch;
varying vec2 atlas_uv;

void vertex() {
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
	return to_linear(mix(vec3(0.26, 0.21, 0.18), hue, 0.4) * detail);
}

void fragment() {
	vec3 paint = texture(finishes, atlas_uv).rgb;
	ALBEDO = paint;
	if (swatch == 8) {
		ALBEDO = quiet_roof(paint);
	}
	ROUGHNESS = 0.88;
	if ((swatch >= 16 && swatch <= 19) || swatch == 31) {
		METALLIC = 0.52;
		ROUGHNESS = 0.51;
	}
	if (swatch == 22) {
		EMISSION = paint * 0.42;
	}
	if (swatch >= 24 && swatch <= 28) {
		// Рабочие грани машины (critique_3 п. 6): тело темнее, свечение — цветом стихии и слабее;
		// белые «фонари» Инея и Росника больше не самые яркие пятна ночи.
		float strength = swatch == 26 ? 0.38 : (swatch == 24 ? 0.66 : 1.0);
		vec3 hsv = rgb2hsv(to_srgb(paint));
		vec3 mean = rgb2hsv(swatch_mean(atlas_uv));
		vec3 core = to_linear(hsv2rgb(vec3(mean.x, max(mean.y, 0.55), hsv.z)));
		ALBEDO = mix(paint, core, 0.6) * 0.5;
		EMISSION = core * working_light * strength * 0.55;
		ROUGHNESS = swatch == 24 ? 0.78 : 0.28;
	}
}

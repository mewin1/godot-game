shader_type spatial;
render_mode cull_disabled;
// UV.x — поперёк колеи, UV.y — длина пути в отрезках по четыре метра.
uniform sampler2D cartway : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D earth : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D earth_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// Ночью в «Обряде» дорога слегка светится своим цветом (docs/37 SCN-3: дорога ярче двора); 0 — как в PvP.
uniform float moonlit = 0.0;
// Лесная тропа за воротами (docs/37 SCN-8): темнее и уже дороги, конец тает в лесу.
// wild 0 — дорога двора; fade_from..fade_to — UV.y, где тропа редеет до нуля.
uniform float wild = 0.0;
uniform float fade_from = 1e6;
uniform float fade_to = 2e6;
varying vec2 ground;

void vertex() {
	ground = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec3 soil = texture(earth, ground * 0.44).rgb;
	float grit = clamp(dot(soil, vec3(0.29, 0.58, 0.13)) * 3.8, 0.0, 1.0);
	float edge = min(UV.x, 1.0 - UV.x);
	// У края между дорожными камнями проглядывает мостовая.
	if (edge < 0.016 + 0.04 * grit + wild * 0.12 * grit) {
		discard;
	}
	if (smoothstep(fade_from, fade_to, UV.y) > fract(grit * 7.13 + soil.r * 3.1)) {
		discard;
	}
	vec2 uv = UV + vec2(0.012 * sin(UV.y * 1.42) * smoothstep(0.02, 0.16, edge), 0.0);
	vec3 worn = texture(cartway, uv).rgb;
	float tread = smoothstep(0.18, 0.31, edge);
	// Два следа тележных колёс: сырой желоб с сухим выдавленным гребнем.
	float wheel = abs(abs(uv.x - 0.5) - 0.266);
	float rut = (1.0 - smoothstep(0.012, 0.052, wheel)) * (0.55 + 0.45 * grit);
	float lip = (1.0 - smoothstep(0.0, 0.016, abs(wheel - 0.049))) * grit;
	ALBEDO = worn * (0.73 + 0.57 * grit) * (1.0 - 0.36 * rut + 0.12 * lip);
	// Тропа темнее дороги двора (ночью дорога должна быть самой светлой линией кадра).
	ALBEDO = mix(ALBEDO, mix(soil * 0.42, ALBEDO * 0.36, 0.5), wild);
	// Лесная тропа ночью почти не светится: лес за частоколом должен оставаться тёмным (SCN-3).
	EMISSION = ALBEDO * moonlit * (1.0 - 0.8 * wild) * vec3(0.78, 0.86, 1.0);
	ROUGHNESS = mix(mix(0.89, 0.65, tread * (1.0 - grit)), 0.39, rut);
	SPECULAR = 0.26;
	vec2 slope = (texture(earth_normal, ground * 0.44).rg * 2.0 - 1.0) * mix(0.29, 0.13, tread);
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(vec3(slope.x, 1.0, slope.y)), 0.0)).xyz);
}

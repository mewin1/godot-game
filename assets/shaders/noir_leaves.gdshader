shader_type spatial;
render_mode cull_disabled;
// Цвет у корня и на сгибе каждого листа записан в 3D-модель.
// сила порыва ветра 0..1 (NoirWind): трава гнётся сильнее
global uniform float noir_wind;
varying float tip_light;
varying float grass_tone;

void vertex() {
	vec2 foot = MODEL_MATRIX[3].xz;
	float tip = smoothstep(0.025, 0.42, VERTEX.y);
	tip_light = tip;
	grass_tone = 0.5 + 0.5 * sin(dot(foot, vec2(0.57, 0.34)));
	float breeze = sin(dot(foot, vec2(0.68, 0.39)) + TIME * (1.24 + 1.2 * noir_wind))
			+ 0.34 * sin(dot(foot, vec2(-0.27, 0.82)) + TIME * 2.02);
	VERTEX.xz += vec2(0.017, 0.009) * breeze * tip * tip * (1.0 + 2.5 * noir_wind);
	// в порыв трава ложится по ветру (−x, +z)
	vec3 lee = inverse(mat3(MODEL_MATRIX)) * vec3(-0.884, 0.0, 0.468);
	VERTEX.xz += lee.xz * 0.05 * noir_wind * tip * tip;
	NORMAL = normalize(mix(vec3(NORMAL.x, abs(NORMAL.y), NORMAL.z), vec3(0, 1, 0), 0.34));
}

void fragment() {
	float value = dot(COLOR.rgb, vec3(0.25, 0.60, 0.15));
	vec3 tint = mix(vec3(0.76, 0.94, 0.88), vec3(1.09, 1.04, 0.80), grass_tone);
	ALBEDO = mix(vec3(value), COLOR.rgb, 0.83) * tint * mix(0.53, 0.96, tip_light);
	AO = mix(0.60, 1.0, tip_light);
	ROUGHNESS = 0.76;
	SPECULAR = 0.14;
	BACKLIGHT = ALBEDO * 0.09;
}

shader_type spatial;
render_mode cull_disabled;
// Цвет у корня и на сгибе каждого листа записан в 3D-модель.
// сила порыва ветра 0..1 (NoirWind): трава гнётся сильнее
global uniform float noir_wind;
// поляна вокруг двора: за ней трава днём в тени леса (noir_forest_shade.gdshaderinc)
uniform vec4 glade_a = vec4(-1e5, -1e5, 1e5, 1e5);
uniform vec4 glade_b = vec4(-1e5, -1e5, 1e5, 1e5);
#include "res://assets/shaders/noir_forest_shade.gdshaderinc"
varying float tip_light;
varying float grass_tone;
varying vec2 foot_at;

void vertex() {
	vec2 foot = MODEL_MATRIX[3].xz;
	foot_at = foot;
	float tip = smoothstep(0.025, 0.42, VERTEX.y);
	tip_light = tip;
	grass_tone = 0.5 + 0.5 * sin(dot(foot, vec2(0.57, 0.34)));
	// порыв идёт по траве медленной волной вдоль ветра (−x, +z)
	float front = 0.5 + 0.5 * sin(dot(foot, vec2(-0.884, 0.468)) * 0.35 - TIME * 1.2);
	float wind = noir_wind * mix(0.35, 1.0, front);
	// Частоты постоянные: множитель от силы ветра при большом TIME сбивал фазу на сотни
	// оборотов за секунду нарастания порыва — трава дёргалась. Порыв меняет только размах.
	float breeze = sin(dot(foot, vec2(0.68, 0.39)) + TIME * 1.05)
			+ 0.34 * sin(dot(foot, vec2(-0.27, 0.82)) + TIME * 1.6);
	VERTEX.xz += vec2(0.012, 0.006) * breeze * tip * tip * (1.0 + 1.5 * wind);
	// в порыв трава плавно клонится по ветру
	mat3 basis = mat3(MODEL_MATRIX);  // поворот и равный масштаб: обратная = транспонированная / масштаб²
	vec3 lee = transpose(basis) * vec3(-0.884, 0.0, 0.468) / dot(basis[0], basis[0]);
	VERTEX.xz += lee.xz * (0.075 + 0.015 * breeze) * wind * tip * tip;
	NORMAL = normalize(mix(vec3(NORMAL.x, abs(NORMAL.y), NORMAL.z), vec3(0, 1, 0), 0.34));
}

void fragment() {
	float value = dot(COLOR.rgb, vec3(0.25, 0.60, 0.15));
	vec3 tint = mix(vec3(0.76, 0.94, 0.88), vec3(1.09, 1.04, 0.80), grass_tone);
	ALBEDO = noir_floor_shaded(noir_day_tinted(mix(vec3(value), COLOR.rgb, 0.83) * tint * mix(0.53, 0.96, tip_light)),
			foot_at, glade_a, glade_b);
	AO = mix(0.60, 1.0, tip_light);
	ROUGHNESS = 0.76;
	SPECULAR = 0.14;
	BACKLIGHT = ALBEDO * 0.09;
}

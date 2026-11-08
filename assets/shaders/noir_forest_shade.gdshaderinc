// Дневная тень леса: под кронами и днём темновато — свет туда почти не доходит.
// noir_forest_shade 0..1 задаёт RitualDaylight (днём 1, к ночи 0; в PvP всегда 0 — ночь и так тёмная).
// open — насколько точка на виду у неба: 0 — глубина кроны и стволы, 1 — верх и края лап.
global uniform float noir_forest_shade;

const vec3 FOREST_DEEP = vec3(0.40, 0.46, 0.46);
const vec3 FOREST_OPEN = vec3(0.66, 0.72, 0.71);

vec3 noir_forest_shaded(vec3 albedo, float open) {
	return albedo * mix(vec3(1.0), mix(FOREST_DEEP, FOREST_OPEN, open), noir_forest_shade);
}

// Земля и трава под пологом леса: за краем поляны (до двух прямоугольников x0, z0, x1, z1 в мире)
// темнеют вместе с деревьями. По умолчанию поляна — весь мир (в PvP земля не темнеет).
const vec3 FOREST_FLOOR = vec3(0.56, 0.62, 0.62);

float noir_under_canopy(vec2 p, vec4 ga, vec4 gb) {
	float da = length(max(max(ga.xy - p, p - ga.zw), vec2(0.0)));
	float db = length(max(max(gb.xy - p, p - gb.zw), vec2(0.0)));
	return smoothstep(1.5, 9.0, min(da, db));
}

vec3 noir_floor_shaded(vec3 albedo, vec2 p, vec4 ga, vec4 gb) {
	return albedo * mix(vec3(1.0), FOREST_FLOOR, noir_forest_shade * noir_under_canopy(p, ga, gb));
}

// Днём (noir_forest_shade > 0) трава и земля приглушены: без лимонной желтизны и кислотной зелени,
// ближе к серо-оливковому. amount — сколько цвета убрать в полдень (0..1). Ночью не действует.
uniform float day_mute = 0.0;

vec3 noir_day_muted(vec3 albedo) {
	float value = dot(albedo, vec3(0.30, 0.55, 0.15));
	vec3 grey = value * vec3(0.97, 1.0, 1.0);
	return mix(albedo, grey, day_mute * noir_forest_shade);
}

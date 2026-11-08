// Общий изгиб дерева ветром для коры (вместе с ветками) и для хвои/листвы.
// Сдвиг — функция только от точки модели и самого дерева, поэтому лапы не съезжают с веток.
// Модель дерева — высотой 1 (VERTEX.y 0…1), копии — поворот и равный масштаб.
// noir_wind — сила порыва 0..1 (NoirWind). Большие деревья качаются медленно: ~0,2–0,3 Гц.
global uniform float noir_wind;

vec3 noir_tree_bend(vec3 v, mat4 model, float flex, float time) {
	vec2 base = model[3].xz;
	float z = clamp(v.y, 0.0, 1.0);
	float bend = z * z;
	float outer = clamp(length(v.xz) / max(0.04, 0.25 * (1.1 - z)), 0.0, 1.0);
	// порыв идёт по лесу медленной волной вдоль ветра (−x, +z): соседние деревья клонятся не разом
	vec2 lee_dir = vec2(-0.884, 0.468);
	float front = 0.5 + 0.5 * sin(dot(base, lee_dir) * 0.09 - time * 0.5);
	float wind = noir_wind * mix(0.7, 1.0, front);
	float phase = dot(base, vec2(0.21, 0.13));
	// частоты постоянные (как у травы): от силы ветра зависит только размах, иначе в порыв дерево дёргается
	float sway = sin(time * 1.25 + phase);
	float side = sin(time * 1.6 + phase * 1.7 + 1.3);
	// направление ветра в пространстве модели (единичное: сдвиг в долях высоты дерева)
	vec3 lee = normalize(transpose(mat3(model)) * vec3(lee_dir.x, 0.0, lee_dir.y));
	vec2 across = vec2(-lee.z, lee.x);
	float amp = 0.0035 + 0.006 * wind;
	vec2 shift = lee.xz * (sway * amp + wind * 0.015 * (0.85 + 0.15 * sway)) + across * side * amp * 0.45;
	v.xz += shift * bend * flex;
	// концы ветвей чуть покачиваются вверх-вниз
	v.y += 0.0012 * (1.0 + wind) * outer * sin(time * 1.9 + phase * 3.0 + z * 4.0) * flex;
	return v;
}

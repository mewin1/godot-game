shader_type spatial;
// Мостовая двора «нуар» (как на концепте арены):
// плиты 2×2 на клетку со светлыми бурыми швами, внутри — мягкий рисунок колотого камня; мокрые пятна, мох у частокола.
// COLOR.r вершин = 1 на краю двора (мох), 0 внутри.

uniform float square = 2.0;          // крупный квадрат = клетка поля, м
uniform float slabs_per_square = 2.0;
uniform float grout = 0.025;          // половина ширины шва, м
uniform float bevel = 0.05;           // скос края плиты, м
uniform float cracks_per_meter = 3.2;
uniform vec3 stone_dark : source_color = vec3(0.11, 0.12, 0.135);
uniform vec3 stone_light : source_color = vec3(0.2, 0.21, 0.215);
uniform vec3 grout_color : source_color = vec3(0.32, 0.29, 0.25);  // швы светлее камня, бурые (концепт)
uniform vec3 moss_color : source_color = vec3(0.2, 0.25, 0.08);
uniform vec3 dirt_color : source_color = vec3(0.16, 0.12, 0.085);
uniform vec2 origin = vec2(0.0, 0.0);  // угол поля в мире — швы по клеткам

varying vec3 world;
varying float edge;

float hash1(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 15731.743);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash1(i), hash1(i + vec2(1, 0)), f.x), mix(hash1(i + vec2(0, 1)), hash1(i + vec2(1, 1)), f.x), f.y);
}

// рисунок колотого камня внутри плиты (вороной): x — до центра куска, y — ширина трещины (F2−F1)
vec2 cracks(vec2 p) {
	vec2 n = floor(p);
	vec2 f = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = vec2(hash1(n + g), hash1(n + g + 17.3)) * 0.7 + 0.15;
			float d = length(g + o - f);
			if (d < f1) {
				f2 = f1;
				f1 = d;
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	return vec2(f1, f2 - f1);
}

// плиты: square/2 м (2×2 на клетку поля); x — до шва (м), yz — id плиты
vec3 slab(vec2 p) {
	float size = square / slabs_per_square;
	vec2 q = (p - origin) / size;
	vec2 id = floor(q);
	vec2 d = min(fract(q), 1.0 - fract(q)) * size;
	float wear = (noise(p * 7.0 + id * 1.7) - 0.5) * 0.02;  // края чуть сбитые
	return vec3(min(d.x, d.y) + wear, id);
}

float height(vec2 p) {
	float edge_h = smoothstep(grout, grout + bevel, slab(p).x);
	float crack = smoothstep(0.0, 0.12, cracks(p * cracks_per_meter).y);
	return edge_h * (0.8 + 0.2 * crack);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	edge = COLOR.r;
}

void fragment() {
	vec2 p = world.xz;
	vec3 c = slab(p);
	vec2 k = cracks(p * cracks_per_meter);
	float tone = hash1(c.yz);
	vec3 stone = mix(stone_dark, stone_light, tone * 0.6 + noise(p * 5.0) * 0.25);
	stone *= 0.9 + 0.2 * noise(p * 0.7);                // пятна сырости крупнее плит
	stone *= 1.0 - 0.13 * (1.0 - smoothstep(0.0, 0.12, k.y));  // трещины колотого камня — мягко
	stone *= 0.92 + 0.16 * (1.0 - k.x);
	float seam = 1.0 - smoothstep(grout * 0.6, grout, c.x);
	float body = 1.0 - seam;
	vec3 col = mix(stone, grout_color * (0.8 + 0.4 * noise(p * 8.0)), seam);

	// мох: у частокола полосой, в зазорах — пятнами
	float rim = smoothstep(0.2, 0.75, edge + (noise(p * 3.0) - 0.5) * 0.35);
	float in_gaps = seam * smoothstep(0.6, 0.8, noise(p * 1.3));
	float moss = clamp(rim + in_gaps * 0.8, 0.0, 1.0);
	col = mix(col, moss_color * (0.8 + 0.4 * noise(p * 11.0)), moss);

	// двор не однотонный (как на концепте): островки мха и грязи, выбитые плиты, светлые выветренные плиты
	// пятна по шуму поверх швов (не по плиткам — иначе «шахматка»)
	float patch = smoothstep(0.62, 0.85, noise(p * 0.32 + 3.1) + (noise(p * 1.7) - 0.5) * 0.25) * (0.5 + 0.5 * noise(p * 2.7));
	col = mix(col, mix(dirt_color, moss_color, noise(p * 1.9)) * (0.75 + 0.5 * noise(p * 9.0)), patch * (0.45 + 0.55 * seam));
	moss = max(moss, patch);

	ALBEDO = col;
	// влажный блик на гладких камнях, зазоры и мох матовые
	float wet = smoothstep(0.55, 0.75, noise(p * 0.45 + 7.0));  // мокрые пятна ~30% площади
	ROUGHNESS = mix(0.95, mix(0.82, 0.5, wet) + (tone - 0.5) * 0.1, body * (1.0 - moss));
	SPECULAR = 0.32;  // мокрый блик, но плиты не вспыхивают целиком

	// скос краёв плит и трещины — нормаль по разности высот
	float e = 0.01;
	float h0 = height(p);
	float hx = height(p + vec2(e, 0.0));
	float hz = height(p + vec2(0.0, e));
	vec3 n_world = normalize(vec3((h0 - hx) * 0.025 / e, 1.0, (h0 - hz) * 0.025 / e));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
}

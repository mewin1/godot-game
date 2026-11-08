shader_type spatial;
render_mode cull_disabled, alpha_to_coverage;
// Лапа и берёзовая ветвь используют свой рисованный силуэт. Свет идёт по массе кроны.
uniform sampler2D foliage : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 pigment : source_color = vec4(1.0);
uniform bool broadleaf = false;
uniform float cut = 0.28;
// сила порыва ветра 0..1 (NoirWind): кроны качаются сильнее и чаще
global uniform float noir_wind;
varying float open_sky;
varying float tree_tone;

void vertex() {
	vec2 base = MODEL_MATRIX[3].xz;
	float z = clamp(VERTEX.y, 0.0, 1.0);
	float outer = clamp(length(VERTEX.xz) / max(0.04, 0.25 * (1.1 - z)), 0.0, 1.0);
	// порыв идёт волной по направлению ветра (−x, +z): соседние деревья клонятся не разом
	vec2 lee_dir = vec2(-0.884, 0.468);
	float front = 0.5 + 0.5 * sin(dot(base, lee_dir) * 0.16 - TIME * 1.7);
	float wind = noir_wind * mix(0.45, 1.0, front);
	float gust = sin(dot(base, vec2(0.21, 0.13)) - TIME * (0.83 + 1.2 * wind));
	float ripple = sin(TIME * (1.6 + 4.5 * wind) + dot(base, vec2(0.47, -0.31)) + z * 5.4);
	float sway = 1.0 + 5.0 * wind;
	VERTEX.xz += vec2(gust, ripple * 0.4 + gust * 0.5) * z * z * (broadleaf ? 0.012 : 0.007) * sway;
	// наклон кроны по ветру (в метрах мира: направление переведено в пространство модели)
	// у копий только поворот и равный масштаб: обратная матрица = транспонированная / масштаб²
	mat3 basis = mat3(MODEL_MATRIX);
	vec3 lee = transpose(basis) * vec3(lee_dir.x, 0.0, lee_dir.y) / dot(basis[0], basis[0]);
	VERTEX.xz += lee.xz * wind * (0.75 + 0.25 * gust) * z * z * (broadleaf ? 0.7 : 0.45);
	VERTEX.y += 0.0035 * outer * ripple * sway;
	vec3 crown = normalize(vec3(VERTEX.x * 3.2, 0.62 + z * 0.53, VERTEX.z * 3.2));
	vec3 upper = vec3(NORMAL.x, abs(NORMAL.y), NORMAL.z);
	NORMAL = normalize(mix(upper, crown, broadleaf ? 0.60 : 0.73));
	open_sky = clamp(outer * 0.58 + z * 0.36, 0.0, 1.0);
	tree_tone = 0.5 + 0.5 * sin(dot(base, vec2(1.31, 0.79)));
}

void fragment() {
	vec4 leaf = texture(foliage, UV);
	ALPHA = leaf.a;
	ALPHA_SCISSOR_THRESHOLD = cut;
	ALPHA_ANTIALIASING_EDGE = cut * 0.77;
	ALPHA_TEXTURE_COORDINATE = UV * vec2(textureSize(foliage, 0));
	vec3 col = leaf.rgb * pigment.rgb;
	if (broadleaf) {
		float green = dot(col, vec3(0.29, 0.59, 0.12));
		col = mix(col, green * vec3(0.78, 1.07, 0.61), 0.64);
	}
	ALBEDO = col * mix(vec3(0.73,0.81,0.80), vec3(1.04,1.07,0.93), tree_tone) * mix(0.74, 1.22, open_sky);
	ROUGHNESS = 0.83;
	SPECULAR = 0.13;
	AO = mix(0.57, 1.0, open_sky);
	BACKLIGHT = ALBEDO * (broadleaf ? 0.13 : 0.06);
}

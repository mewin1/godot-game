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
	float gust = sin(dot(base, vec2(0.21, 0.13)) - TIME * 0.83);
	float ripple = sin(TIME * (1.6 + 1.4 * noir_wind) + dot(base, vec2(0.47, -0.31)) + z * 5.4);
	float sway = 1.0 + 2.2 * noir_wind;
	VERTEX.xz += vec2(gust, ripple * 0.4 + gust * 0.5) * z * z * (broadleaf ? 0.012 : 0.007) * sway;
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

shader_type spatial;
render_mode cull_disabled, alpha_to_coverage;
// Лапа и берёзовая ветвь используют свой рисованный силуэт. Свет идёт по массе кроны.
uniform sampler2D foliage : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 pigment : source_color = vec4(1.0);
uniform bool broadleaf = false;
uniform float cut = 0.28;
// изгиб ветром — общий с корой и ветками (noir_tree_wind.gdshaderinc)
#include "res://assets/shaders/noir_tree_wind.gdshaderinc"
#include "res://assets/shaders/noir_forest_shade.gdshaderinc"
varying float open_sky;
varying float tree_tone;

void vertex() {
	vec2 base = MODEL_MATRIX[3].xz;
	float z = clamp(VERTEX.y, 0.0, 1.0);
	float outer = clamp(length(VERTEX.xz) / max(0.04, 0.25 * (1.1 - z)), 0.0, 1.0);
	VERTEX = noir_tree_bend(VERTEX, MODEL_MATRIX, broadleaf ? 1.4 : 1.0, TIME);
	// берёзовые листья ещё чуть трепещут (на ~1 см: от ветки не отходят)
	if (broadleaf) {
		VERTEX.y += 0.0009 * outer * (1.0 + noir_wind) * sin(TIME * 4.3 + dot(VERTEX.xz, vec2(41.0, 29.0)));
	}
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
	ALBEDO = noir_forest_shaded(col * mix(vec3(0.73,0.81,0.80), vec3(1.04,1.07,0.93), tree_tone) * mix(0.74, 1.22, open_sky),
			open_sky);
	ROUGHNESS = 0.83;
	SPECULAR = 0.13;
	AO = mix(0.57, 1.0, open_sky);
	BACKLIGHT = ALBEDO * (broadleaf ? 0.13 : 0.06);
}

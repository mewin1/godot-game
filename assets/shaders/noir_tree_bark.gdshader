shader_type spatial;
render_mode cull_disabled;
// Кора с ветками у копий леса: как прежний StandardMaterial3D (цвет × фактура, лунный контур),
// но гнётся ветром той же функцией, что и листва (noir_tree_wind.gdshaderinc).
#include "res://assets/shaders/noir_tree_wind.gdshaderinc"
#include "res://assets/shaders/noir_forest_shade.gdshaderinc"
uniform sampler2D bark : source_color, filter_linear_mipmap;
uniform bool use_texture = true;
uniform vec4 tint : source_color = vec4(1.0);
uniform float flex = 1.0;
uniform float rim = 0.045;
uniform float rim_tint = 0.4;

void vertex() {
	VERTEX = noir_tree_bend(VERTEX, MODEL_MATRIX, flex, TIME);
}

void fragment() {
	vec3 col = tint.rgb;
	if (use_texture) {
		col *= texture(bark, UV).rgb;
	}
	// стволы и ветки — в глубине леса, затеняются как низ кроны
	ALBEDO = noir_forest_shaded(col, 0.15);
	ROUGHNESS = 0.8;
	SPECULAR = mix(0.5, 0.25, noir_forest_shade);
	RIM = rim * (1.0 - 0.5 * noir_forest_shade);
	RIM_TINT = rim_tint;
}

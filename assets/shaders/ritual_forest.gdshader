shader_type spatial;
render_mode unshaded, cull_disabled, skip_vertex_transform;
// Рисованный лес PvP: размер каждой MultiMesh-копии сохраняется при развороте к камере.
uniform sampler2D artwork : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 tint : source_color = vec4(0.82, 0.96, 0.9, 1.0);
void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	vec3 world = center + right * VERTEX.x * sx + vec3(0.0, VERTEX.y * sy, 0.0);
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
}
void fragment() {
	vec4 ink = texture(artwork, UV);
	ALBEDO = ink.rgb * tint.rgb;
	ALPHA = ink.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
}

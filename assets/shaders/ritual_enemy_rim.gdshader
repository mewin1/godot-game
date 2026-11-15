shader_type spatial;
// Холодный контур врага ночью (critique_3 п. 34, docs/37 VIS-3): тёмная фигура отделяется от тёмной
// травы и брусчатки. Накладывается поверх материала модели (material_overlay), складывается со светом.
render_mode blend_add, unshaded, cull_back, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 rim_color : source_color = vec3(0.55, 0.78, 1.0);
// 0 днём, до 1 ночью: задаёт RitualStage3D по фазе суток.
uniform float strength : hint_range(0.0, 2.0) = 0.0;
uniform float power : hint_range(0.5, 8.0) = 2.6;

void fragment() {
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), power);
	ALBEDO = rim_color * edge * strength;
}

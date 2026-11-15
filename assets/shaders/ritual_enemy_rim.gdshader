shader_type spatial;
// Контур врага ночью (critique_3 п. 34, docs/37 VIS-3): тёмная фигура отделяется от тёмной
// травы и брусчатки. Накладывается поверх материала модели (material_overlay), складывается со светом.
render_mode blend_add, unshaded, cull_back, depth_draw_never, shadows_disabled, fog_disabled;

// Тёпло-белый (critique_4 п. 21): голубой — цвет статуса «холод», без него враг не должен казаться замёрзшим.
uniform vec3 rim_color : source_color = vec3(0.96, 0.9, 0.78);
// 0 днём, до 1 ночью: задаёт RitualStage3D по фазе суток.
uniform float strength : hint_range(0.0, 2.0) = 0.0;
uniform float power : hint_range(0.5, 8.0) = 2.6;

void fragment() {
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), power);
	ALBEDO = rim_color * edge * strength;
}

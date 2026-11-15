shader_type spatial;
// Круг дальности на земле (critique_3 п. 66, critique_4 п. 27/31): мягкий светящийся край цветом
// стихии и лёгкая заливка; у выбранного дома и у призрака — один и тот же круг.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 color : source_color = vec3(0.95, 0.8, 0.5);
uniform float strength = 0.9;
// Заливка внутри круга (у призрака почти нет — цвет только по краю).
uniform float fill = 0.06;

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float rim = smoothstep(0.86, 0.97, r) * (1.0 - smoothstep(0.97, 1.0, r));
	float inside = (1.0 - smoothstep(0.9, 1.0, r)) * fill;
	ALBEDO = color * (rim + inside) * strength;
}

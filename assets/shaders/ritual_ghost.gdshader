shader_type spatial;
// Призрак дома в режиме постройки (critique_3 п. 66, UI-7): полупрозрачная модель цветом стихии,
// края ярче (видно форму), дышит. Красный — сюда нельзя.
render_mode unshaded, blend_mix, depth_prepass_alpha, cull_back, shadows_disabled;

uniform vec3 color : source_color = vec3(0.95, 0.85, 0.6);
uniform float alpha = 0.6;

void fragment() {
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float breath = 0.85 + 0.15 * sin(TIME * 3.0);
	ALBEDO = color * (0.85 + 0.9 * edge);
	ALPHA = clamp(alpha * breath + edge * 0.35, 0.0, 0.9);
}

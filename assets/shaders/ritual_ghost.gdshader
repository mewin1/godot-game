shader_type spatial;
// Призрак дома в режиме постройки (critique_4 п. 27, UI-7): тёмная полупрозрачная модель (40%) с цветным
// краем — форма видна и на светлой мостовой. Сюда нельзя — серый призрак (blocked) без цвета стихии.
render_mode unshaded, blend_mix, depth_prepass_alpha, cull_back, shadows_disabled;

uniform vec3 color : source_color = vec3(0.95, 0.85, 0.6);
uniform float alpha = 0.4;
uniform bool blocked = false;

void fragment() {
	float edge = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float breath = blocked ? 1.0 : 0.85 + 0.15 * sin(TIME * 3.0);
	vec3 rim = blocked ? vec3(0.62, 0.62, 0.6) : color;
	vec3 body = blocked ? vec3(0.16, 0.16, 0.17) : color * 0.22;
	ALBEDO = mix(body, rim * 1.15, smoothstep(0.15, 0.7, edge));
	ALPHA = clamp(alpha * breath + edge * 0.5, 0.0, 0.92);
}

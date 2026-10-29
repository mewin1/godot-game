shader_type canvas_item;
// Мягкое затемнение краёв экрана и тёплый оттенок — «нуар» в духе ночной корчмы.

uniform float strength : hint_range(0.0, 1.0) = 0.55;
uniform float inner_radius : hint_range(0.0, 1.5) = 0.55;
uniform float outer_radius : hint_range(0.0, 2.0) = 1.15;
uniform vec4 shade_color : source_color = vec4(0.05, 0.025, 0.01, 1.0);

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float distance_to_center = length(centered * vec2(1.25, 1.0)) * 1.414;
	float shade = smoothstep(inner_radius, outer_radius, distance_to_center);
	COLOR = vec4(shade_color.rgb, shade * strength);
}

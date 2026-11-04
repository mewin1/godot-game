shader_type canvas_item;
// Картинка концепта на тёмном фоне растворяется по краям — без светлого прямоугольника на карточке.

uniform float feather : hint_range(0.0, 0.5) = 0.3;

void fragment() {
	vec2 edge = min(UV, 1.0 - UV);
	COLOR.a *= smoothstep(0.0, feather, edge.x) * smoothstep(0.0, feather, edge.y);
}

shader_type canvas_item;
// Медленно плывущий туман внизу экрана меню: несколько слоёв синусоидальных «волн».

uniform vec4 fog_color : source_color = vec4(0.55, 0.52, 0.6, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.35;
uniform float speed = 0.03;

float wave(vec2 uv, float scale, float offset) {
	return 0.5 + 0.5 * sin(uv.x * scale + TIME * speed * 60.0 * offset + sin(uv.y * 7.0 + offset));
}

void fragment() {
	float height = smoothstep(0.45, 1.0, UV.y);
	float bands = wave(UV, 5.0, 1.0) * 0.5 + wave(UV, 9.0, -0.7) * 0.3 + wave(UV, 13.0, 0.4) * 0.2;
	COLOR = vec4(fog_color.rgb, height * bands * strength);
}

shader_type canvas_item;
render_mode unshaded;

uniform float clock = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

void fragment() {
	float height = 1.0 - UV.y;
	float curl = noise(vec2(UV.x * 5.0, UV.y * 4.0 + clock * 2.0));
	float fine = noise(vec2(UV.x * 11.0, UV.y * 9.0 + clock * 3.3));
	float sway = sin(height * 6.0 - clock * 2.4) * height * 0.12;
	float width = (1.0 - height) * 0.32 + curl * 0.15;
	float body = 1.0 - smoothstep(width * 0.4, width,
		abs(UV.x - 0.5 + sway));
	body *= smoothstep(0.0, 0.12, UV.y) * smoothstep(0.0, 0.08, height);
	body *= smoothstep(height * 0.50, height * 0.50 + 0.35, curl + fine * 0.25);
	vec3 fire = mix(vec3(1.0, 0.22, 0.015), vec3(1.0, 0.87, 0.35),
		pow(body, 2.0) * (1.0 - height * 0.6));
	COLOR = vec4(fire, body * 0.55);
}

shader_type canvas_item;
render_mode unshaded;

uniform float clock = 0.0;
uniform vec4 board = vec4(0.0, 0.0, 1.0, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = (UV - board.xy) / board.zw;
	vec2 flow = vec2(p.x * 4.0 - clock * 0.035, p.y * 9.0 + clock * 0.012);
	float cloud = noise(flow) * 0.65 + noise(flow * 2.1 + 7.0) * 0.35;
	float inside = smoothstep(-0.04, 0.06, p.x) * (1.0 - smoothstep(0.94, 1.04, p.x))
		* smoothstep(-0.05, 0.08, p.y) * (1.0 - smoothstep(0.94, 1.04, p.y));
	// Low mist by the walls; keep the playable centre clear.
	float edge = max(pow(clamp(p.x, 0.0, 1.0), 3.0),
		(1.0 - smoothstep(0.0, 0.30, p.y)) * 0.5);
	float haze = smoothstep(0.33, 0.79, cloud) * edge * inside;
	float beam = exp(-pow((p.x - p.y * 0.42 - 0.02) * 5.0, 2.0));
	beam *= (1.0 - smoothstep(0.1, 1.0, p.y)) * inside * 0.085;
	float alpha = haze * 0.23 + beam;
	vec3 air = mix(vec3(0.46, 0.60, 0.70), vec3(0.94, 0.73, 0.43),
		beam / max(alpha, 0.001));
	COLOR = vec4(air, alpha);
}

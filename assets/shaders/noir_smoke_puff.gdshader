shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled;
// Клуб дыма над огнём (частица): у огня подсвечен рыжим, выше — холодный серый и тает.
// INSTANCE_CUSTOM.y — доля жизни; клуб растёт к концу жизни.
uniform vec4 warm : source_color = vec4(0.55, 0.26, 0.10, 1.0);
uniform vec4 cool : source_color = vec4(0.16, 0.18, 0.19, 1.0);
uniform float opacity = 0.22;
varying float life;
varying float seed;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	seed = fract(sin(float(INSTANCE_ID) * 4.123) * 9631.77);
	life = INSTANCE_CUSTOM.y;
	vec3 at = MODEL_MATRIX[3].xyz;
	float size = length(MODEL_MATRIX[0].xyz) * mix(0.5, 1.6, life);
	float a = seed * 6.283 + TIME * 0.3;
	vec2 v = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * VERTEX.xy;
	MODELVIEW_MATRIX = VIEW_MATRIX;
	VERTEX = at + (INV_VIEW_MATRIX[0].xyz * v.x + INV_VIEW_MATRIX[1].xyz * v.y) * size;
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float n = noise(UV * 3.0 + seed * 17.0 + vec2(0.0, -TIME * 0.2)) * 0.6 + noise(UV * 7.0 + seed * 5.0) * 0.4;
	float puff = smoothstep(1.0, 0.15, length(c) + (n - 0.5) * 0.7);
	float fade = smoothstep(0.0, 0.15, life) * (1.0 - smoothstep(0.45, 1.0, life));
	ALBEDO = mix(warm.rgb, cool.rgb, smoothstep(0.0, 0.35, life));
	ALPHA = puff * fade * opacity;
}

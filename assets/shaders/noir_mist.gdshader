shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Клубы тумана в лесу за частоколом (как на концепте 05_arena): полотно всегда стоит к камере
// (поворот только вокруг вертикали), плотность — клубящийся шум с провалами, медленно плывёт.
// У земли и у стволов растворяется мягко (сравнение с глубиной сцены) — нет резких срезов.

uniform vec3 tint : source_color = vec3(0.55, 0.6, 0.6);
uniform float opacity : hint_range(0.0, 1.0) = 0.5;
uniform vec2 card_size = vec2(20.0, 7.0);  // метры — шум не растягивается по полотну
uniform float billow = 0.14;  // клубов на метр
uniform float drift = 0.25;  // метров в секунду
uniform float seed = 0.0;
uniform float soft_distance = 2.5;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float sum = 0.0;
	float amp = 0.55;
	for (int i = 0; i < 5; i++) {
		sum += noise(p) * amp;
		p = p * 2.03 + vec2(1.7, 9.2);
		amp *= 0.5;
	}
	return sum;
}

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], MODEL_MATRIX[1],
			vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, MODEL_MATRIX[1].xyz)), 0.0), MODEL_MATRIX[3]);
}

void fragment() {
	vec2 meters = vec2(UV.x, 1.0 - UV.y) * card_size;  // y — высота над низом полотна
	float t = TIME * drift;
	vec2 p = meters * billow + vec2(seed * 7.3, seed * 3.1);
	// клубы закручиваются: шум сдвигается другим шумом
	vec2 warp = vec2(fbm(p * 0.7 + vec2(t * 0.2, 0.0)), fbm(p * 0.7 + vec2(5.2, t * 0.15)));
	float n = fbm(p + warp * 1.6 + vec2(t * billow, 0.0));
	float h = meters.y / card_size.y;
	// внизу туман плотный и ровный, вверху — рваные клочья
	float shape = smoothstep(0.32 + h * 0.28, 0.72 + h * 0.1, n);
	shape *= 1.0 - smoothstep(0.55, 1.0, h);
	shape *= smoothstep(0.0, 0.18, UV.x) * smoothstep(0.0, 0.18, 1.0 - UV.x);
	// мягко у земли и у стволов
	float depth = texture(depth_texture, SCREEN_UV).x;
	vec4 scene = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	scene.xyz /= scene.w;
	float soft = clamp((VERTEX.z - scene.z) / soft_distance, 0.0, 1.0);
	ALBEDO = tint * (0.8 + 0.35 * n);
	ALPHA = clamp(shape * opacity * soft, 0.0, 1.0);
}

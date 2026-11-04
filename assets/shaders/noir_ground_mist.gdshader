shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;
// Низовой туман в лесу (как вверху концепта 05_arena): слой у земли высотой layer_top, клубы — шум.
// Рисуется на весь экран: для каждого пикселя луч от камеры до предмета (по глубине сцены) проходит
// через слой тумана, и туман копится только на отрезке внутри слоя. Поэтому подножия стволов стоят
// в тумане, кроны торчат над ним, а у стволов нет вертикальных срезов (нет плоских полотен).
// Двор внутри yard_rect остаётся чистым — туман начинается за частоколом.

uniform vec3 tint : source_color = vec3(0.5, 0.56, 0.57);
uniform vec3 shade : source_color = vec3(0.16, 0.2, 0.21);
uniform float density = 0.16;  // на метр пути в самой густой части
uniform float layer_top = 3.2;  // высота слоя, м
uniform float clump_scale = 0.07;  // клубов на метр
uniform float clump_contrast = 2.2;
uniform float drift = 0.35;  // м/с
uniform vec4 yard_rect = vec4(-1.5, -21.5, 19.5, 1.5);  // x0, z0, x1, z1 — двор без тумана
uniform float yard_fade = 7.0;  // м — от частокола туман густеет плавно
uniform float far_boost = 0.03;  // вдали дымка плотнее (к горизонту лес растворяется)
uniform float max_distance = 160.0;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

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
	for (int i = 0; i < 4; i++) {
		sum += noise(p) * amp;
		p = p * 2.07 + vec2(1.7, 9.2);
		amp *= 0.5;
	}
	return sum;
}

// плотность в точке мира: клубы по земле, вверх редеют, во дворе нет
float mist_at(vec3 p, float t) {
	vec2 q = p.xz * clump_scale;
	vec2 warp = vec2(fbm(q * 0.6 + vec2(t * 0.03, 0.0)), fbm(q * 0.6 + vec2(4.1, t * 0.02)));
	float n = fbm(q + warp * 1.3 + vec2(t * drift * clump_scale, 0.0));
	float h = clamp(p.y / layer_top, 0.0, 1.0);
	// клуб выше там, где шум сильнее: верх слоя рваный, а не ровная крышка
	float clump = clamp((n - 0.42 - h * 0.3) * clump_contrast * 2.0, 0.0, 1.0);
	float base = (1.0 - h) * (1.0 - h) * 0.12;  // тонкая ровная пелена у самой земли
	vec2 out_yard = max(yard_rect.xy - p.xz, p.xz - yard_rect.zw);
	float yard_dist = length(max(out_yard, vec2(0.0))) + min(max(out_yard.x, out_yard.y), 0.0);
	float yard = smoothstep(0.0, yard_fade, yard_dist);
	return (clump + base) * yard;
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).x;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
	vec3 ray = world - cam;
	float total = length(ray);
	if (total > max_distance) {
		ray *= max_distance / total;
		total = max_distance;
	}
	vec3 dir = ray / total;
	// отрезок луча внутри слоя 0..layer_top
	float s0 = 0.0;
	float s1 = total;
	if (abs(dir.y) > 1e-4) {
		float a = (layer_top - cam.y) / dir.y;
		float b = (0.0 - cam.y) / dir.y;
		s0 = max(min(a, b), 0.0);
		s1 = min(max(a, b), total);
	} else if (cam.y > layer_top) {
		s1 = 0.0;
	}
	float alpha = 0.0;
	vec3 color = vec3(0.0);
	if (s1 > s0) {
		const int STEPS = 14;
		float step_len = (s1 - s0) / float(STEPS);
		// сдвиг выборок по пикселю (против полос)
		float jitter = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
		float transmit = 1.0;
		float t = TIME;
		for (int i = 0; i < STEPS; i++) {
			float s = s0 + (float(i) + jitter) * step_len;
			vec3 p = cam + dir * s;
			float d = mist_at(p, t) * density * (1.0 + s * far_boost);
			float absorb = exp(-d * step_len);
			// верх клуба светлее (луна), низ — в тени леса
			vec3 lit = mix(shade, tint, clamp(0.35 + p.y / layer_top * 0.9, 0.0, 1.0));
			color += transmit * (1.0 - absorb) * lit;
			transmit *= absorb;
		}
		alpha = 1.0 - transmit;
		color /= max(alpha, 1e-4);
	}
	ALBEDO = color;
	ALPHA = clamp(alpha, 0.0, 0.92);
}

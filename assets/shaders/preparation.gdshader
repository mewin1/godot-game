shader_type canvas_item;
render_mode unshaded;

// Fit the illustrated walls to the live board, leaving the UI in screen space.
uniform vec4 court = vec4(0.40, 0.16, 0.91, 0.82);
uniform vec4 home = vec4(0.55, 0.20, 0.95, 0.80);
uniform vec4 away = vec4(0.05, 0.20, 0.45, 0.80);
uniform float duel = 0.0;
uniform float clock = 0.0;

float mist(vec2 p) {
	return sin(p.x * 3.1 + sin(p.y * 2.7)) * sin(p.y * 2.3 + p.x * 0.7) * 0.5 + 0.5;
}

float fit_axis(float t, float a, float b, float src_a, float src_b) {
	if (t < a) {
		return src_a * t / a;
	}
	if (t > b) {
		return mix(src_b, 1.0, (t - b) / (1.0 - b));
	}
	return mix(src_a, src_b, (t - a) / (b - a));
}

vec4 landscape(sampler2D painting_texture, vec2 uv, vec4 bounds, float left_crop) {
	float depth = clamp((uv.y - bounds.y) / (bounds.w - bounds.y), 0.0, 1.0);
	float left = mix(0.434, 0.404, depth);
	float u = fit_axis(uv.x, bounds.x, bounds.z, left, mix(0.869, 0.927, depth));
	if (uv.x < bounds.x) {
		u = mix(left_crop, left, uv.x / bounds.x);
	}
	float v = fit_axis(uv.y, bounds.y, bounds.w, 0.216, 0.646);
	vec2 source = vec2(u, v);
	vec4 painting = texture(painting_texture, source);
	// Only the hot painted cores move; stonework and the board never wobble.
	float fire = smoothstep(0.12, 0.38, painting.r - painting.b)
		* smoothstep(0.5, 0.95, painting.r);
	source.x += fire * sin(v * 610.0 - clock * 4.3) * 0.0012;
	source.y += fire * sin(u * 520.0 + clock * 3.2) * 0.0018;
	painting = texture(painting_texture, source);
	painting.rgb += vec3(0.11, 0.045, 0.006) * fire
		* (0.55 + 0.45 * sin(clock * 6.7 + u * 97.0));
	float outside = 1.0 - step(bounds.x, uv.x) * step(uv.x, bounds.z)
		* step(bounds.y, uv.y) * step(uv.y, bounds.w);
	float haze = mist(vec2(u * 15.0 - clock * 0.13, v * 28.0 + clock * 0.04));
	haze *= haze * outside * smoothstep(0.04, 0.22, v);
	painting.rgb = mix(painting.rgb, vec3(0.40, 0.52, 0.64), haze * 0.13);
	return painting;
}

void fragment() {
	vec4 painting = vec4(0.0);
	if (duel < 1.0) {
		painting = landscape(TEXTURE, UV, court, 0.0);
	}
	if (duel > 0.0) {
		bool own = UV.x >= 0.5;
		vec4 bounds = own ? home : away;
		float offset = own ? 0.5 : 0.0;
		vec2 uv = vec2((UV.x - offset) * 2.0, UV.y);
		bounds.xz = (bounds.xz - offset) * 2.0;
		if (!own) {
			uv.x = 1.0 - uv.x;
			bounds.xz = 1.0 - bounds.zx;
		}
		vec4 arena = landscape(TEXTURE, uv, bounds, 0.29);
		float edge = smoothstep(0.0, 0.025, min(uv.x, 1.0 - uv.x));
		arena.rgb *= mix(0.66, 1.0, edge);
		// Один горизонт за двумя дворами; к боевым стенам возвращается локальный ракурс.
		float sky = 1.0 - smoothstep(bounds.y * 0.16, bounds.y * 0.67, UV.y);
		vec3 ridge = texture(TEXTURE, vec2(UV.x, UV.y / max(bounds.y, 0.01) * 0.115)).rgb;
		arena.rgb = mix(arena.rgb, ridge, sky);
		painting = mix(painting, arena, duel);
	}
	// Keep the sunset, but give the HUD a quiet dark silhouette behind its text.
	float header = (1.0 - smoothstep(0.02, 0.15, UV.y))
		* (1.0 - smoothstep(0.30, 0.48, UV.x));
	painting.rgb *= 1.0 - header * 0.56;
	COLOR = painting;
}

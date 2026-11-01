shader_type canvas_item;
render_mode unshaded;

// Fit the illustrated walls to the live board, leaving the UI in screen space.
uniform vec4 court = vec4(0.40, 0.16, 0.91, 0.82);
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

void fragment() {
	float depth = clamp((UV.y - court.y) / (court.w - court.y), 0.0, 1.0);
	float u = fit_axis(UV.x, court.x, court.z,
		mix(0.434, 0.404, depth), mix(0.869, 0.927, depth));
	float v = fit_axis(UV.y, court.y, court.w, 0.216, 0.646);
	vec2 source = vec2(u, v);
	vec4 painting = texture(TEXTURE, source);
	// Only the hot painted cores move; stonework and the board never wobble.
	float fire = smoothstep(0.12, 0.38, painting.r - painting.b)
		* smoothstep(0.5, 0.95, painting.r);
	source.x += fire * sin(v * 610.0 - clock * 4.3) * 0.0012;
	source.y += fire * sin(u * 520.0 + clock * 3.2) * 0.0018;
	painting = texture(TEXTURE, source);
	painting.rgb += vec3(0.11, 0.045, 0.006) * fire
		* (0.55 + 0.45 * sin(clock * 6.7 + u * 97.0));
	float outside = 1.0 - step(court.x, UV.x) * step(UV.x, court.z)
		* step(court.y, UV.y) * step(UV.y, court.w);
	float haze = mist(vec2(u * 15.0 - clock * 0.13, v * 28.0 + clock * 0.04));
	haze *= haze * outside * smoothstep(0.04, 0.22, v);
	painting.rgb = mix(painting.rgb, vec3(0.40, 0.52, 0.64), haze * 0.13);
	// Keep the sunset, but give the HUD a quiet dark silhouette behind its text.
	float header = (1.0 - smoothstep(0.02, 0.15, UV.y))
		* (1.0 - smoothstep(0.30, 0.48, UV.x));
	painting.rgb *= 1.0 - header * 0.56;
	COLOR = painting;
}

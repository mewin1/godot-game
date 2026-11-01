shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec4 paint = texture(TEXTURE, UV);
	float flame = smoothstep(0.14, 0.40, paint.r - paint.b) * smoothstep(0.46, 0.9, paint.r);
	float flicker = sin(TIME * 5.0 + UV.y * 113.0) * sin(TIME * 2.1 + UV.x * 87.0);
	paint.rgb += vec3(0.18, 0.075, 0.012) * flame * flicker;
	float shade = 1.0 - smoothstep(0.13, 0.56, UV.x);
	paint.rgb = mix(paint.rgb, vec3(0.016, 0.030, 0.045), shade * 0.80);
	COLOR = paint;
}

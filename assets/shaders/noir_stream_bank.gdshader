shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
// UV.y идёт от воды к лесу. Гравий у уреза сменяется землёй на гребне берега.
uniform sampler2D gravel : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec2 ground;

void vertex() {
	ground = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec3 pebbles = texture(gravel, ground * 0.82).rgb;
	vec3 earth = texture(soil, ground * 0.27).rgb;
	float dry = smoothstep(0.25, 0.92, UV.y + pebbles.g * 0.28);
	ALBEDO = mix(pebbles * vec3(0.42, 0.48, 0.46), earth * vec3(0.32, 0.36, 0.28), dry);
	ROUGHNESS = mix(0.60, 0.94, dry);
	SPECULAR = 0.22;
	// Края отмелей распадаются на влажные пятна под осокой.
	float edge = UV.y + (pebbles.g - 0.12) * 0.43;
	ALPHA = 1.0 - smoothstep(0.51, 0.93, edge);
}

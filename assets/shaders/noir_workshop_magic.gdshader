shader_type spatial;
render_mode cull_disabled;
uniform vec4 spark_color : source_color;
uniform float power = 1.0;
uniform int kind = 0; // 1 — жар, 2 — поток, 3 — разряд, 4 — ветер.
uniform float plume_floor = 8.0;
varying vec3 local;
varying float phase;
varying float facet;

void vertex() {
	local = VERTEX;
	facet = clamp(0.42 + dot(NORMAL, normalize(vec3(-0.58,0.73,-0.36))) * 0.50, 0.0, 1.0);
	phase = dot(MODEL_MATRIX[3].xz, vec2(0.61, 0.47));
	if (kind == 1) {
		float tip = smoothstep(plume_floor, plume_floor + 0.61, VERTEX.y);
		VERTEX.xz += tip * vec2(0.052*sin(3.7*TIME+phase+7.0*VERTEX.y),
				0.036*sin(2.9*TIME-phase+4.5*VERTEX.y));
	}
}

void fragment() {
	float value = 0.90;
	if (kind == 1) {
		value = 0.89 + 0.11*sin(3.8*TIME+phase+6.0*local.y) + 0.06*sin(6.3*TIME+phase);
	} else if (kind == 2) {
		value = 0.82 + 0.18*smoothstep(-0.6,0.8,cos(length(local.xz)*29.0+local.y*16.0-TIME*3.3));
	} else if (kind == 3) {
		float beat = 0.5+0.5*sin(1.9*TIME+phase);
		value = 0.75 + 0.35*pow(beat,5.0);
	} else if (kind == 4) {
		value = 0.87 + 0.13*sin(atan(local.z,local.x)*3.0-TIME*2.4);
	}
	float rim = pow(1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 2.2);
	vec3 col = spark_color.rgb;
	float light = 0.20 + 0.46 * facet + rim * 0.25;
	if (kind == 1) {
		float edge = smoothstep(0.15, 0.88, facet);
		col = mix(col * vec3(0.80,0.46,0.29), col, edge);
		light = 0.24 + 0.68 * edge + 0.18 * rim;
	} else if (kind == 2 || kind == 5) {
		vec3 shade = kind == 2 ? vec3(0.053,0.48,0.46) : vec3(0.20,0.45,0.70);
		col = mix(col * shade, col, facet * 0.70 + rim * 0.28);
		light = 0.24 + 0.51 * facet + 0.34 * rim;
	} else if (kind == 6) {
		light = 0.27 + 0.47 * facet + 0.35 * rim;
	}
	ALBEDO = col * 0.35;
	EMISSION = col * power * value * light;
	ROUGHNESS = 0.32;
	SPECULAR = 0.32;
}

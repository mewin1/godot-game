shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
// Светящаяся точка-частица лицом к камере: светлячки, лунная пыль, искры над огнём.
// INSTANCE_CUSTOM.y — доля жизни (ParticleProcessMaterial). Цвет идёт от start к end за жизнь.
uniform vec4 start_color : source_color = vec4(1.0, 0.8, 0.4, 1.0);
uniform vec4 end_color : source_color = vec4(1.0, 0.3, 0.1, 1.0);
uniform float energy = 1.0;
// 0 — ровный свет, 1 — светлячок: вспыхивает и гаснет
uniform float blink = 0.0;
// прямоугольник двора (x0, z0, x1, z1): внутри точки гаснут (поле боя остаётся чистым); нулевой — без ограничения
uniform vec4 hide_rect = vec4(0.0);
// пятно туманится вместе со сценой: на дальнем плане тусклее
uniform float distance_fade = 150.0;
varying float life;
varying float glow;

void vertex() {
	float seed = fract(sin(float(INSTANCE_ID) * 78.233) * 43758.5453);
	vec3 at = MODEL_MATRIX[3].xyz;
	float size = length(MODEL_MATRIX[0].xyz);
	life = INSTANCE_CUSTOM.y;
	float pulse = pow(max(0.0, sin(TIME * (0.9 + seed * 1.3) + seed * 31.0)), 4.0);
	glow = mix(1.0, pulse, blink);
	if (hide_rect.z > hide_rect.x) {
		vec2 d = max(hide_rect.xy - at.xz, at.xz - hide_rect.zw);
		glow *= smoothstep(-0.2, 1.6, max(d.x, d.y));
	}
	float far = length((VIEW_MATRIX * vec4(at, 1.0)).xyz);
	glow *= 1.0 - smoothstep(distance_fade * 0.6, distance_fade, far);
	MODELVIEW_MATRIX = VIEW_MATRIX;
	VERTEX = at + (INV_VIEW_MATRIX[0].xyz * VERTEX.x + INV_VIEW_MATRIX[1].xyz * VERTEX.y) * size;
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = dot(c, c);
	float core = exp(-r * 9.0) + 0.35 * exp(-r * 2.5);
	float fade = smoothstep(0.0, 0.12, life) * (1.0 - smoothstep(0.7, 1.0, life));
	ALBEDO = mix(start_color.rgb, end_color.rgb, life) * core * fade * glow * energy;
}

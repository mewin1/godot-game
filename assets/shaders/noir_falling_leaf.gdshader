shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
// Падающий лист (частица): в воздухе кувыркается лицом к камере, на земле лежит плашмя и тает.
// INSTANCE_CUSTOM от ParticleProcessMaterial: x — угол, y — доля жизни, z — кадр атласа 2×2.
uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform float brightness = 1.25;
varying float life;
varying float grounded;

void vertex() {
	float seed = fract(sin(float(INSTANCE_ID) * 12.9898) * 43758.5453);
	float frame = floor(INSTANCE_CUSTOM.z * 4.0);
	UV = UV * 0.5 + vec2(mod(frame, 2.0), floor(frame / 2.0)) * 0.5;
	life = INSTANCE_CUSTOM.y;
	vec3 at = MODEL_MATRIX[3].xyz;
	float size = length(MODEL_MATRIX[0].xyz);
	grounded = 1.0 - smoothstep(0.03, 0.12, at.y);
	// кувырок: лист то ребром, то плашмя к камере
	float flip = cos(TIME * (2.2 + seed * 3.4) + seed * 40.0);
	vec3 local = VERTEX * size;
	vec3 air = local;
	air.x *= mix(0.18, 1.0, abs(flip));
	float a = INSTANCE_CUSTOM.x;
	air.xy = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * air.xy;
	vec3 air_world = at + INV_VIEW_MATRIX[0].xyz * air.x + INV_VIEW_MATRIX[1].xyz * air.y;
	// на земле: плашмя, поворот от сида (угол частицы продолжает вращаться)
	float b = seed * 6.283;
	vec2 flat_xz = mat2(vec2(cos(b), sin(b)), vec2(-sin(b), cos(b))) * local.xy;
	vec3 ground_world = vec3(at.x + flat_xz.x, 0.03 + seed * 0.02, at.z + flat_xz.y);
	vec3 world = mix(air_world, ground_world, grounded);
	MODELVIEW_MATRIX = VIEW_MATRIX;
	VERTEX = world;
	MODELVIEW_NORMAL_MATRIX = mat3(VIEW_MATRIX);
	NORMAL = normalize(mix(INV_VIEW_MATRIX[2].xyz, vec3(0.0, 1.0, 0.0), grounded));
}

void fragment() {
	vec4 leaf = texture(atlas, UV);
	float fade = smoothstep(0.0, 0.04, life) * (1.0 - smoothstep(0.8, 1.0, life));
	ALBEDO = leaf.rgb * brightness;
	ALPHA = leaf.a * fade;
	ROUGHNESS = 0.85;
	SPECULAR = 0.1;
	BACKLIGHT = leaf.rgb * 0.35;
}

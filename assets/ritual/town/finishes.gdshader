shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D finishes : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform int roof_column : hint_range(0, 6) = 0;
// Working faces and windows share the atlas so that one mesh needs one surface.
instance uniform float working_light = 1.0;
varying flat int swatch;
varying vec2 atlas_uv;

void vertex() {
	ivec2 slot = ivec2(floor(UV * vec2(8., 4.)));
	swatch = slot.y * 8 + slot.x;
	atlas_uv = UV;
	if (swatch == 8) {
		atlas_uv.x += float(roof_column) / 8.;
	}
}

void fragment() {
	vec3 paint = texture(finishes, atlas_uv).rgb;
	ALBEDO = paint;
	ROUGHNESS = 0.88;
	if ((swatch >= 16 && swatch <= 19) || swatch == 31) {
		METALLIC = 0.52;
		ROUGHNESS = 0.51;
	}
	if (swatch == 22) {
		EMISSION = paint * 0.42;
	}
	if (swatch >= 24 && swatch <= 28) {
		float strength = swatch == 26 ? 0.38 : (swatch == 24 ? 0.66 : 1.0);
		EMISSION = paint * working_light * strength;
		ROUGHNESS = swatch == 24 ? 0.78 : 0.28;
	}
}

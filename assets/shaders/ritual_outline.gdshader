shader_type spatial;
// Контур дома по его сетке (critique_3 п. 63, UI-11): «вывернутая оболочка» — та же сетка чуть
// раздута по нормалям, видна только изнанка. Накладывается как material_overlay, цвет — стихия.
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, fog_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.89, 0.65);
uniform float width = 0.035;
uniform float glow = 1.6;
// Оболочка раздувается от центра детали, а не по нормалям: у плоских граней нормали разные
// в одном углу, и оболочка рвалась на осколки.
uniform vec3 pivot = vec3(0.0, 0.6, 0.0);

void vertex() {
	VERTEX += normalize(VERTEX - pivot + vec3(0.0, 0.0001, 0.0)) * width;
}

void fragment() {
	ALBEDO = color * glow;
}

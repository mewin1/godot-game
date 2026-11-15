shader_type spatial;
// Контур дома по его сетке (critique_3 п. 63, critique_4 п. 25-26, UI-11): «вывернутая оболочка» —
// сетка стен и крыши чуть раздута, видна только изнанка. Накладывается как material_overlay.
// Плита под домом срезана (cut_below): вокруг дома нет квадрата клетки. Выбранный — толще и пульсирует.
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, fog_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.89, 0.65);
uniform float width = 0.035;
uniform float glow = 1.6;
// Оболочка раздувается от центра детали, а не по нормалям: у плоских граней нормали разные
// в одном углу, и оболочка рвалась на осколки.
uniform vec3 pivot = vec3(0.0, 0.6, 0.0);
// Ниже этой высоты (единицы модели) — плита участка, её не обводим.
uniform float cut_below = 0.0;
// Пульс выбранного (0 — ровный контур).
uniform float pulse = 0.0;
// Гладкие фигуры (идолы) раздуваются по нормалям: у них нет плоских граней, а центр сетки неизвестен.
uniform bool along_normal = false;
varying float height;

void vertex() {
	height = VERTEX.y;
	if (along_normal) {
		VERTEX += NORMAL * width;
	} else {
		VERTEX += normalize(VERTEX - pivot + vec3(0.0, 0.0001, 0.0)) * width;
	}
}

void fragment() {
	if (height < cut_below) {
		discard;
	}
	ALBEDO = color * glow * (1.0 + pulse * (0.5 + 0.5 * sin(TIME * 4.0)));
}

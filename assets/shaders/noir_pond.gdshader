shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
// Пруд «Городища»: та же вода, что у ручья (noir_water.gdshaderinc), но рябь — в метрах мира
// по обеим осям, без течения; UV.y — расстояние до берега (0 на урезе, 0,5 — глубже 1,1 м).
#include "res://assets/shaders/noir_water.gdshaderinc"

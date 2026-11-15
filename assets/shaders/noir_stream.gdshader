shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
// Лесной ручей (арена «нуар»): общая вода noir_water.gdshaderinc, рябь течёт вдоль русла.
// UV.x — вдоль течения (метры), UV.y — поперёк (0..1).
#define WATER_STREAM
#include "res://assets/shaders/noir_water.gdshaderinc"

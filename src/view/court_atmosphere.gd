class_name CourtAtmosphere
extends RefCounted
## Живой свет и угольки поверх объёмных рисунков. Время принадлежит только отображению.

const SOFT_LIGHT: Texture2D = preload("res://data/visuals/soft_light.tres")
const EMBER_COUNT: int = 7


## Тёплый свет на полу под башнями огня.
static func draw_lamp(canvas: CanvasItem, foot: Vector2, cell_size: float,
		time: float, phase: float) -> void:
	var flicker: float = (0.87 + 0.08 * sin(time * 5.3 + phase)
			+ 0.05 * sin(time * 8.7 - phase))
	var extent: Vector2 = Vector2(2.5, 1.2) * cell_size
	canvas.draw_texture_rect(SOFT_LIGHT, Rect2(foot - extent * 0.5, extent), false,
			Color(1.0, 0.48, 0.14, 0.24 * flicker))


## Искры поднимаются от чаши, исчезая до верхнего края следующей клетки.
static func draw_embers(canvas: CanvasItem, source: Vector2, height: float,
		time: float, phase: float) -> void:
	var halo: Vector2 = Vector2(0.55, 0.55) * height
	var pulse: float = 0.20 + 0.06 * sin(time * 6.7 + phase)
	canvas.draw_texture_rect(SOFT_LIGHT, Rect2(source - halo * 0.5, halo), false,
			Color(1.0, 0.43, 0.07, pulse))
	for index: int in EMBER_COUNT:
		var age: float = fposmod(time * (0.27 + index * 0.013) + index * 0.147 + phase, 1.0)
		var sway: float = sin(time * 1.4 + index * 2.7) * 0.07 + age * 0.09
		var at: Vector2 = source + Vector2(sway, -age * 0.52) * height
		var alpha: float = sin(age * PI) * 0.83
		canvas.draw_line(at, at + Vector2(-0.4, 1.8), Color(1.0, 0.64, 0.22, alpha),
				maxf(0.8, height * 0.009), true)

class_name FpsLabel
extends Label
## Счётчик кадров в секунду (временный, для проверки нагрузки): FPS и время кадра ГП 3D-сцены.
## Обновляется дважды в секунду, мышь пропускает.

const REFRESH: float = 0.5
## Чей 3D рисуется: время кадра видеокарты берётся у этого вьюпорта (может быть не задан).
var viewport: Viewport
var _wait: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_size_override(&"font_size", 15)
	add_theme_color_override(&"font_color", Color("e8dcc0"))
	add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.85))
	add_theme_constant_override(&"outline_size", 4)
	if viewport != null:
		RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = REFRESH
	var line: String = "FPS %d" % roundi(Engine.get_frames_per_second())
	if viewport != null:
		line += " · ГП %.1f мс" % RenderingServer.viewport_get_measured_render_time_gpu(viewport.get_viewport_rid())
	text = line

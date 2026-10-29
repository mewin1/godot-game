class_name ScreenFit
extends RefCounted
## Базовый размер интерфейса под ориентацию окна: на высоком экране (телефон) — 720×1280,
## на широком — 1280×720. Иначе в портрете всё ужимается под ширину 1280 и становится мелким.

const LANDSCAPE: Vector2i = Vector2i(1280, 720)
const PORTRAIT: Vector2i = Vector2i(720, 1280)


static func apply(window: Window) -> void:
	var target: Vector2i = PORTRAIT if window.size.y > window.size.x else LANDSCAPE
	if window.content_scale_size != target:
		window.content_scale_size = target

class_name RitualPauseMark
extends Control
## Значок паузы у таймера шапки (critique_3 п. 11, 45): две янтарные полосы вместо слова «пауза».

const COLOR: Color = Color("f0c869")


func _init() -> void:
	custom_minimum_size = Vector2(22, 26)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_text = "Пауза (Пробел)"


func _draw() -> void:
	var bar: Vector2 = Vector2(6, size.y * 0.7)
	var top: float = (size.y - bar.y) * 0.5
	draw_rect(Rect2(Vector2(3, top), bar), COLOR)
	draw_rect(Rect2(Vector2(13, top), bar), COLOR)

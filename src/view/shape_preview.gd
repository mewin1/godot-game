class_name ShapePreview
extends Control
## Фигура башни из квадратиков — для витрины и для «призрака» при перетаскивании.

var data: TowerData
var rotation_turns: int = 0
var level: int = 1
var cell_px: float = 20.0
## true — фигура рисуется с центром в (0, 0): так её удобно держать под пальцем.
var is_centered: bool = false


static func create_drag_preview(tower_data: TowerData, turns: int, tower_level: int,
		cell_size: float) -> ShapePreview:
	var preview: ShapePreview = ShapePreview.new()
	preview.data = tower_data
	preview.rotation_turns = turns
	preview.level = tower_level
	preview.cell_px = cell_size
	preview.is_centered = true
	preview.modulate = Color(1, 1, 1, 0.7)
	return preview


## Рисует фигуру в любой ноде: левый верхний угол — top_left.
static func draw_shape(canvas: CanvasItem, tower_data: TowerData, turns: int, tower_level: int,
		top_left: Vector2, cell_size: float) -> void:
	var inset: float = maxf(1.0, cell_size * 0.06)
	var cells: Array[Vector2i] = TowerState.rotated_shape(tower_data.shape, turns)
	for cell: Vector2i in cells:
		var rect: Rect2 = Rect2(top_left + Vector2(cell) * cell_size, Vector2.ONE * cell_size)
		canvas.draw_rect(rect.grow(-inset), tower_data.color)
		canvas.draw_rect(rect.grow(-inset), tower_data.color.darkened(0.45), false, 2.0)
	# Точки уровня — на первой клетке фигуры: угол рамки у повёрнутой фигуры может быть пустым.
	var pip_cell: Vector2 = top_left + Vector2(cells[0]) * cell_size
	for i: int in tower_level:
		var pip: Vector2 = pip_cell + Vector2(cell_size * (0.25 + 0.25 * i), cell_size * 0.25)
		canvas.draw_circle(pip, cell_size * 0.09, Color.WHITE)


static func get_shape_size(tower_data: TowerData, turns: int) -> Vector2i:
	var bounds: Vector2i = Vector2i.ZERO
	for cell: Vector2i in TowerState.rotated_shape(tower_data.shape, turns):
		bounds = Vector2i(maxi(bounds.x, cell.x + 1), maxi(bounds.y, cell.y + 1))
	return bounds


func _draw() -> void:
	if data == null:
		return
	var shape_size: Vector2 = Vector2(get_shape_size(data, rotation_turns)) * cell_px
	var top_left: Vector2 = -shape_size / 2.0 if is_centered else (size - shape_size) / 2.0
	draw_shape(self, data, rotation_turns, level, top_left, cell_px)

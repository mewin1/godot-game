class_name ShapePreview
extends Control
## Фигура башни (плиты и картинка) — для витрины и для «призрака» при перетаскивании.

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


## Рисует башню в любой ноде: левый верхний угол рамки фигуры — top_left.
static func draw_shape(canvas: CanvasItem, tower_data: TowerData, turns: int, tower_level: int,
		top_left: Vector2, cell_size: float) -> void:
	TowerPainter.draw_tower(canvas, tower_data, turns, tower_level, top_left, cell_size)


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

class_name TowerPainter
extends RefCounted
## Рисует башню в любой ноде: «плиты» на клетках фигуры (клетки видно всегда — это основа
## сетки) и картинку поверх, в центре фигуры. Уровень — звёздочки и цвет обводки.

const MILLI: float = 1000.0
const LEVEL_EDGE_COLORS: Array[Color] = [
	Color(0, 0, 0, 0), Color(0.78, 0.8, 0.82), Color(0.95, 0.75, 0.3)]
const OUTLINE_COLOR: Color = Color(0.11, 0.08, 0.06)
## Картинка чуть выше центра фигуры: башня «стоит» на плитах.
const ICON_LIFT: float = 0.12
const STAR_SIZE: float = 0.3
## Тёплое свечение под картинкой башни максимального уровня.
const GLOW_COLOR: Color = Color(1.0, 0.8, 0.4, 0.22)
const GLOW_LEVEL: int = 3
const NEIGHBORS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]


## Рисует башню; top_left — левый верхний угол рамки фигуры. pulse (0..1) — «отдача» выстрела.
static func draw_tower(canvas: CanvasItem, data: TowerData, turns: int, level: int,
		top_left: Vector2, cell_size: float, pulse: float = 0.0) -> void:
	var visual: TowerVisual = VisualCatalog.get_default().get_tower(data.id)
	var cells: Array[Vector2i] = TowerState.rotated_shape(data.shape, turns)
	draw_plates(canvas, cells, top_left, cell_size, visual, level)
	var center: Vector2 = top_left + Vector2(TowerState.center_of(cells)) / MILLI * cell_size
	if level >= GLOW_LEVEL:
		canvas.draw_circle(center, cell_size * 0.55, GLOW_COLOR)
		canvas.draw_circle(center, cell_size * 0.38, GLOW_COLOR)
	draw_icon(canvas, visual, center, cell_size, pulse)
	draw_stars(canvas, level, center + Vector2(0, cell_size * 0.36), cell_size)


## Плиты: каждая клетка фигуры — скруглённый «камень», внешний край обведён.
static func draw_plates(canvas: CanvasItem, cells: Array[Vector2i], top_left: Vector2,
		cell_size: float, visual: TowerVisual, level: int) -> void:
	var inset: float = maxf(1.0, cell_size * 0.06)
	var edge_width: float = maxf(1.5, cell_size * 0.05)
	var edge_color: Color = visual.plate_edge_color
	if level > 1:
		edge_color = LEVEL_EDGE_COLORS[mini(level, LEVEL_EDGE_COLORS.size()) - 1]
		edge_width *= 1.5
	for cell: Vector2i in cells:
		var rect: Rect2 = Rect2(top_left + Vector2(cell) * cell_size, Vector2.ONE * cell_size)
		canvas.draw_rect(rect.grow(-inset), OUTLINE_COLOR)
	# Перемычки между соседними клетками: фигура читается одним куском.
	for cell: Vector2i in cells:
		var rect: Rect2 = Rect2(top_left + Vector2(cell) * cell_size, Vector2.ONE * cell_size)
		canvas.draw_rect(rect.grow(-inset - edge_width * 0.5), visual.plate_color)
		if cells.has(cell + Vector2i.RIGHT):
			canvas.draw_rect(Rect2(rect.position + Vector2(cell_size * 0.5, inset + edge_width),
					Vector2(cell_size, cell_size - 2.0 * (inset + edge_width))), visual.plate_color)
		if cells.has(cell + Vector2i.DOWN):
			canvas.draw_rect(Rect2(rect.position + Vector2(inset + edge_width, cell_size * 0.5),
					Vector2(cell_size - 2.0 * (inset + edge_width), cell_size)), visual.plate_color)
	for cell: Vector2i in cells:
		_draw_outer_edges(canvas, cells, cell, top_left, cell_size, inset, edge_color, edge_width)


static func draw_icon(canvas: CanvasItem, visual: TowerVisual, center: Vector2, cell_size: float,
		pulse: float) -> void:
	var icon_size: float = cell_size * visual.icon_scale * (1.0 + 0.12 * pulse)
	var position: Vector2 = center - Vector2(icon_size * 0.5, icon_size * (0.5 + ICON_LIFT))
	canvas.draw_texture_rect(visual.icon, Rect2(position, Vector2.ONE * icon_size), false)


## Звёздочки уровня в ряд с центром в point.
static func draw_stars(canvas: CanvasItem, level: int, point: Vector2, cell_size: float) -> void:
	var star_icon: Texture2D = VisualCatalog.get_default().field.star_icon
	var star_size: float = cell_size * STAR_SIZE
	var step: float = star_size * 0.8
	var left: float = point.x - step * (level - 1) * 0.5 - star_size * 0.5
	for i: int in level:
		var rect: Rect2 = Rect2(Vector2(left + step * i, point.y - star_size * 0.5),
				Vector2.ONE * star_size)
		canvas.draw_texture_rect(star_icon, rect, false)


static func _draw_outer_edges(canvas: CanvasItem, cells: Array[Vector2i], cell: Vector2i,
		top_left: Vector2, cell_size: float, inset: float, color: Color, width: float) -> void:
	var rect: Rect2 = Rect2(top_left + Vector2(cell) * cell_size, Vector2.ONE * cell_size)
	rect = rect.grow(-inset - width * 0.5)
	var corners: Array[Vector2] = [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)]
	var reach: float = inset + width * 0.5
	for side: int in NEIGHBORS.size():
		if cells.has(cell + NEIGHBORS[side]):
			continue
		var start: Vector2 = corners[side]
		var end: Vector2 = corners[(side + 1) % 4]
		# Край продолжается до соседней клетки фигуры — без разрывов в обводке.
		var start_neighbor: Vector2i = NEIGHBORS[(side + 3) % 4]
		var end_neighbor: Vector2i = NEIGHBORS[(side + 1) % 4]
		if cells.has(cell + start_neighbor):
			start += Vector2(start_neighbor) * reach
		if cells.has(cell + end_neighbor):
			end += Vector2(end_neighbor) * reach
		canvas.draw_line(start, end, color, width)

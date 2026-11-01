class_name CourtyardPainter
extends RefCounted
## Модульный каменный двор: каждая клетка и дорога берутся из настоящего FieldState.

const ENVIRONMENT: Texture2D = preload("res://assets/dusk/environment.png")
const MATERIALS: Texture2D = preload("res://assets/dusk/materials.png")
const EXIT_WEAPON: Texture2D = preload("res://assets/visual_slice/cannon.png")
const FLOOR_AREA: Rect2 = Rect2(0.10, 0.16, 0.80, 0.68)
const GRID_ASPECT: float = 0.66
const BRASS: Color = Color("746147")
const LOCK_COLOR: Color = Color("75808c")


## Фон с рамкой точно совмещён с модульным полем любой формы.
static func draw_field(canvas: CanvasItem, field: FieldState, origin: Vector2,
		cell_size: float, time: float, match_court: bool = false) -> void:
	var step: Vector2 = Vector2(cell_size, cell_size * GRID_ASPECT)
	var board: Rect2 = Rect2(origin, Vector2(field.layout.width, field.layout.height) * step)
	var backdrop_size: Vector2 = board.size / FLOOR_AREA.size
	canvas.draw_texture_rect(ENVIRONMENT,
			Rect2(origin - backdrop_size * FLOOR_AREA.position, backdrop_size), false)
	if match_court:
		# Общий фрагмент двора даёт непрерывный свет под всей сеткой двух арен.
		var painting: Texture2D = PreparationCourt.PAINTING
		var region: Rect2 = Rect2(Vector2(painting.get_size()) * Vector2(0.445, 0.23),
				Vector2(painting.get_size()) * Vector2(0.40, 0.39))
		canvas.draw_texture_rect_region(painting, board, region)
		draw_preparation(canvas, field, origin, cell_size)
		draw_gate_mark(canvas, origin, step, field.layout.path_cells, time)
		canvas.draw_rect(board.grow(1), BRASS, false, 2.0)
		return
	var road: Array[Vector2i] = field.get_active_path()
	var future: Array[Vector2i] = field.get_future_path()
	for y: int in field.layout.height:
		for x: int in field.layout.width:
			var cell: Vector2i = Vector2i(x, y)
			var rect: Rect2 = Rect2(origin + Vector2(cell) * step, step)
			_draw_cell(canvas, rect, cell, field.is_buildable(cell),
					road.has(cell), future.has(cell))
	canvas.draw_rect(board.grow(1), BRASS, false, 2.0)
	_draw_entrance(canvas, origin + (Vector2(road[0]) + Vector2.ONE * 0.5) * step,
			cell_size, time)


static func _draw_cell(canvas: CanvasItem, rect: Rect2, cell: Vector2i,
		buildable: bool, road: bool, future: bool) -> void:
	var quadrant: Vector2i = Vector2i.ZERO
	if road:
		quadrant = Vector2i(1, 0)
	elif not buildable:
		quadrant = Vector2i(0, 1)
	elif (cell.x + cell.y) % 3 == 0:
		quadrant = Vector2i.ONE
	var material_size: Vector2 = Vector2(MATERIALS.get_size()) * 0.5
	var source: Rect2 = Rect2(Vector2(quadrant) * material_size + Vector2.ONE * 2,
			material_size - Vector2.ONE * 4)
	var tint: Color = Color(0.66, 0.72, 0.82)
	if road:
		tint = Color(0.65, 0.58, 0.48)
	elif not buildable:
		tint = Color(0.37, 0.43, 0.52)
	canvas.draw_texture_rect_region(MATERIALS, rect, source, tint)
	canvas.draw_rect(rect.grow(-0.6), BRASS.darkened(0.3), false, 1.0)
	canvas.draw_line(rect.position + Vector2(2, 2),
			Vector2(rect.end.x - 2, rect.position.y + 2), Color(0.65, 0.72, 0.8, 0.1))
	if road:
		canvas.draw_rect(rect.grow(-2), Color(1.0, 0.73, 0.38, 0.08))
	elif future:
		canvas.draw_circle(rect.get_center(), rect.size.x * 0.035,
				Color(0.7, 0.6, 0.4, 0.5), true, -1, true)
	elif not buildable:
		_draw_lock(canvas, rect.get_center(), rect.size.x * 0.12)


static func _draw_lock(canvas: CanvasItem, center: Vector2, radius: float) -> void:
	canvas.draw_arc(center - Vector2(0, radius * 0.4), radius * 0.5, PI, TAU,
			12, Color(LOCK_COLOR, 0.6), 1.6, true)
	canvas.draw_rect(Rect2(center - Vector2(radius * 0.7, radius * 0.4),
			Vector2(radius * 1.4, radius)), Color(LOCK_COLOR, 0.5))


static func _draw_entrance(canvas: CanvasItem, center: Vector2,
		cell_size: float, time: float) -> void:
	var alpha: float = 0.45 + 0.15 * sin(time * 2.0)
	canvas.draw_set_transform(center, 0, Vector2(1, GRID_ASPECT))
	canvas.draw_arc(Vector2.ZERO, cell_size * 0.36, 0, TAU, 40,
			Color(0.96, 0.65, 0.25, alpha), 2, true)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


## Орудие героя отмечает реальный конец активного пути, а не нарисованную на фоне точку.
static func draw_exit(canvas: CanvasItem, foot: Vector2, cell_size: float) -> void:
	var dimensions: Vector2 = Vector2.ONE * cell_size * 1.25
	canvas.draw_texture_rect(EXIT_WEAPON,
			Rect2(foot - dimensions * Vector2(0.5, 0.82), dimensions), false)


## Сквозь материал каждой плиты виден общий свет двора. Швы рисуются один раз.
static func draw_preparation(canvas: CanvasItem, field: FieldState, origin: Vector2,
		cell_size: float) -> void:
	var step: Vector2 = Vector2(cell_size, cell_size * GRID_ASPECT)
	var road: Array[Vector2i] = field.get_active_path()
	var future: Array[Vector2i] = field.get_future_path()
	for y: int in field.layout.height:
		for x: int in field.layout.width:
			var cell: Vector2i = Vector2i(x, y)
			var rect: Rect2 = Rect2(origin + Vector2(cell) * step, step)
			var tint: Color = Color(0.62, 0.71, 0.79, 0.12)
			if not road.has(cell) and not field.is_buildable(cell):
				tint = Color(0.045, 0.08, 0.135, 0.46)
				if future.has(cell):
					canvas.draw_circle(rect.get_center(), 2, Color(0.73, 0.65, 0.52, 0.48))
				elif (x + y) % 2 == 0:
					_draw_lock(canvas, rect.get_center(), cell_size * 0.09)
			canvas.draw_rect(rect, tint)
	_draw_lane(canvas, road, origin, cell_size, Vector2(field.layout.width, field.layout.height))
	var end: Vector2 = origin + Vector2(field.layout.width, field.layout.height) * step
	var seam: Color = Color(0.06, 0.08, 0.10, 0.43)
	for x: int in range(1, field.layout.width):
		var px: float = origin.x + x * step.x
		canvas.draw_line(Vector2(px, origin.y), Vector2(px, end.y), seam, 1, true)
	for y: int in range(1, field.layout.height):
		var py: float = origin.y + y * step.y
		canvas.draw_line(Vector2(origin.x, py), Vector2(end.x, py), seam, 1, true)
		canvas.draw_line(Vector2(origin.x, py + 1), Vector2(end.x, py + 1),
				Color(0.68, 0.72, 0.75, 0.13), 1, true)


## Дорожная кладка с загибами проходит через центры тех же клеток, что и отряды.
static func _draw_lane(canvas: CanvasItem, road: Array[Vector2i], origin: Vector2,
		cell_size: float, board_cells: Vector2) -> void:
	if road.size() < 2:
		return
	var points: PackedVector2Array = []
	var first: Vector2 = Vector2(road[0]) + Vector2.ONE * 0.5
	var inward: Vector2 = Vector2(road[1] - road[0])
	points.append((first - inward * 0.5) * cell_size)
	for i: int in range(1, road.size() - 1):
		var center: Vector2 = Vector2(road[i]) + Vector2.ONE * 0.5
		var before: Vector2 = Vector2(road[i - 1] - road[i])
		var after: Vector2 = Vector2(road[i + 1] - road[i])
		if before == -after:
			continue
		var a: Vector2 = center + before * 0.48
		var b: Vector2 = center + after * 0.48
		for sample: int in 9:
			var t: float = sample / 8.0
			points.append(a.lerp(center, t).lerp(center.lerp(b, t), t) * cell_size)
	var last: Vector2 = Vector2(road[-1]) + Vector2.ONE * 0.5
	points.append((last + Vector2(road[-1] - road[-2]) * 0.36) * cell_size)
	canvas.draw_set_transform(origin, 0, Vector2(1, GRID_ASPECT))
	_draw_lane_band(canvas, points, Color(0.12, 0.12, 0.13, 0.48), cell_size * 0.82)
	_draw_lane_band(canvas, points, Color(0.76, 0.69, 0.60, 0.52), cell_size * 0.78)
	_draw_lane_band(canvas, points, Color(0.87, 0.84, 0.80, 0.22), cell_size * 0.78,
			board_cells * cell_size)
	_draw_lane_band(canvas, points, Color(0.91, 0.84, 0.69, 0.14), cell_size * 0.65)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


static func _draw_lane_band(canvas: CanvasItem, points: PackedVector2Array,
		color: Color, width: float, extent: Vector2 = Vector2.ZERO) -> void:
	# One filled outline avoids translucent triangle seams at rounded corners.
	var left: PackedVector2Array = []
	var right: PackedVector2Array = []
	for index: int in points.size():
		var before: Vector2 = points[maxi(0, index - 1)]
		var after: Vector2 = points[mini(points.size() - 1, index + 1)]
		var normal: Vector2 = (after - before).normalized().orthogonal() * width * 0.5
		left.append(points[index] + normal)
		right.append(points[index] - normal)
	right.reverse()
	left.append_array(right)
	if extent == Vector2.ZERO:
		canvas.draw_colored_polygon(left, color)
		return
	# Одна выборка дорожного камня на весь двор, без повторяющихся плиток.
	var uvs: PackedVector2Array = []
	for vertex: Vector2 in left:
		uvs.append(Vector2(0.51, 0.01) + vertex / extent * 0.48)
	canvas.draw_colored_polygon(left, color, uvs, MATERIALS)


## Движущийся знак входа поверх неподвижной кладки.
static func draw_gate_mark(canvas: CanvasItem, origin: Vector2, step: Vector2,
		road: Array[Vector2i], time: float) -> void:
	if road.size() < 2:
		return
	var center: Vector2 = origin + (Vector2(road[0]) + Vector2.ONE * 0.5) * step
	var travel: Vector2 = Vector2(road[1] - road[0])
	var flank: Vector2 = travel.orthogonal() * 0.14
	var tip: Vector2 = center + travel * step * 0.06
	var color: Color = Color(1.0, 0.86, 0.62, 0.72 + 0.1 * sin(time * 2))
	for i: int in 2:
		var heel: Vector2 = tip - travel * step * 0.15
		canvas.draw_polyline(PackedVector2Array([heel - flank * step, tip, heel + flank * step]),
				color, 2, true)
		tip -= travel * step * 0.18

## Команды статичного слоя хранятся в CanvasItem между кадрами движения.
class FloorLayer extends Node2D:
	var field: FieldState
	var path_length: int = -1
	var cell_size: float

	func sync(source: FieldState, origin: Vector2, cell: float) -> void:
		position = origin
		if source == field and cell == cell_size and path_length == source.path_length:
			return
		field = source
		path_length = source.path_length
		cell_size = cell
		queue_redraw()

	func _draw() -> void:
		if field != null:
			CourtyardPainter.draw_preparation(self, field, Vector2.ZERO, cell_size)

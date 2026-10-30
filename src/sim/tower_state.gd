class_name TowerState
extends RefCounted
## Башня, поставленная на поле: вид, уровень, место, поворот и вложенное золото.

const MILLI: int = 1000
const ROTATIONS: int = 4

var id: int = 0
var data: TowerData
var level: int = 1
## Левый верхний угол фигуры после поворота.
var anchor: Vector2i = Vector2i.ZERO
## Поворот на 90° по часовой стрелке: 0–3.
var rotation: int = 0
var cooldown_left: int = 0
## Всё золото, вложенное в башню (с учётом слитых копий).
var invested_total: int = 0
## Часть вложенного в текущую фазу подготовки — возвращается при продаже полностью.
var invested_this_phase: int = 0
## Бонусы от соседей-усилителей (считает FieldState, когда башни меняются).
var bonus_damage_percent: int = 0
var bonus_fire_rate_percent: int = 0
var bonus_range_milli: int = 0


## Фигура, повёрнутая rotation раз на 90° и сдвинутая так, чтобы минимум x и y был 0.
static func rotated_shape(shape: Array[Vector2i], turns: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in shape:
		var rotated: Vector2i = cell
		for i: int in posmod(turns, ROTATIONS):
			rotated = Vector2i(-rotated.y, rotated.x)
		result.append(rotated)
	var min_corner: Vector2i = result[0]
	for cell: Vector2i in result:
		min_corner = Vector2i(mini(min_corner.x, cell.x), mini(min_corner.y, cell.y))
	for i: int in result.size():
		result[i] -= min_corner
	return result


## Клетки фигуры с поворотом, поставленной в anchor.
static func shape_cells_at(shape: Array[Vector2i], at_anchor: Vector2i,
		turns: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = rotated_shape(shape, turns)
	for i: int in result.size():
		result[i] += at_anchor
	return result


## Центр фигуры в тысячных долях клетки — из него башня стреляет.
static func center_of(shape_cells: Array[Vector2i]) -> Vector2i:
	var sum: Vector2i = Vector2i.ZERO
	for cell: Vector2i in shape_cells:
		sum += cell * MILLI + Vector2i(MILLI / 2, MILLI / 2)
	return sum / shape_cells.size()


func cells() -> Array[Vector2i]:
	return shape_cells_at(data.shape, anchor, rotation)


func center_milli() -> Vector2i:
	return center_of(cells())

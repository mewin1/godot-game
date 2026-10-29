class_name BoardLayout
extends Resource
## Площадка поля: размер сетки и путь мобов.
## Путь хранится один — для максимального уровня магазина. Путь уровня N — это первые
## path_length_by_level[N - 1] клеток списка, поэтому новая форма всегда продолжает старую.

@export var width: int = 9
@export var height: int = 10
## Клетки пути по порядку: от входа мобов до героя (для максимального уровня магазина).
@export var path_cells: Array[Vector2i] = []
## Сколько первых клеток пути открыто на уровне магазина 1, 2, 3, 4.
@export var path_length_by_level: Array[int] = []


## Длина пути (в клетках) для уровня магазина.
func get_path_length(shop_level: int) -> int:
	var index: int = clampi(shop_level, 1, path_length_by_level.size()) - 1
	return path_length_by_level[index]


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height

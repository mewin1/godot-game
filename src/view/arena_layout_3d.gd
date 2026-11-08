class_name ArenaLayout3D
extends RefCounted
## Высоты лесной арены для отображения: террасы клеток и линия дороги (из Blender).
## Переводит координаты поля (тысячные клетки) и прогресс мобов в точки 3D-сцены.
## Только для вида: симуляция по-прежнему ходит по центрам клеток.

const LAYOUT_PATH: String = "res://assets/arenas/forest/arena_layout.json"
## Арена «нуар» — проезд между мощёными кровлями подклетов (tools/blender/noir/arena_layout.py); есть файл — берётся он.
const NOIR_LAYOUT_PATH: String = "res://assets/noir/arena/arena_layout.json"
const MILLI: float = 1000.0
## Площадка ставится чуть выше самой высокой террасы своей полосы.
const DECK_LIFT: float = 0.15

static var _shared: ArenaLayout3D

## Метров на клетку.
var cell_m: float = 2.0
var _terraces: Dictionary[Vector2i, float] = {}
## Ровная высота площадки: все места одной полосы между дорогами — на одном уровне,
## чтобы фигура на 2+ клетки стояла ровно.
var _decks: Dictionary[Vector2i, float] = {}
## Границы каждой площадки в клетках (для жаровен по углам).
var deck_bounds: Array[Rect2i] = []
## Точки дороги в координатах Godot (y — высота) и длина вдоль дороги от входа на поле.
var _road_points: PackedVector3Array = PackedVector3Array()
var _road_lengths: PackedFloat32Array = PackedFloat32Array()
## Длина дороги для центра каждой клетки полного пути (индекс = номер клетки пути).
var _path_lengths: PackedFloat32Array = PackedFloat32Array()
var _path_cells: Array[Vector2i] = []


static func get_shared(board: BoardLayout) -> ArenaLayout3D:
	if _shared == null:
		_shared = ArenaLayout3D.new()
		_shared._load(board)
	return _shared


## Центр клетки на её террасе (для дороги — на дороге).
func cell_center(cell: Vector2i) -> Vector3:
	var milli: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * MILLI
	return Vector3(milli.x / MILLI * cell_m, cell_height(cell), milli.y / MILLI * cell_m - 20.0)


## Высота верха клетки: терраса или дорога у центра клетки.
func cell_height(cell: Vector2i) -> float:
	if _decks.has(cell):
		return _decks[cell]
	var index: int = _path_cells.find(cell)
	if index >= 0:
		return road_point(_path_lengths[index]).y
	return 0.0


## Высота склона под площадкой (низ каменного основания).
func terrain_height(cell: Vector2i) -> float:
	return _terraces.get(cell, 0.0)


## Все клетки мест (не дорога).
func deck_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	cells.assign(_decks.keys())
	return cells


## Точка поля (тысячные клетки) на поверхности арены.
func milli_to_world(milli: Vector2) -> Vector3:
	var cell: Vector2i = Vector2i(floori(milli.x / MILLI), floori(milli.y / MILLI))
	return Vector3(milli.x / MILLI * cell_m, cell_height(cell), milli.y / MILLI * cell_m - 20.0)


## Плоская точка (x, z) для угла клетки — высоту задаёт вызывающий.
func corner_xz(milli: Vector2) -> Vector2:
	return Vector2(milli.x / MILLI * cell_m, milli.y / MILLI * cell_m - 20.0)


## Длина вдоль дороги для прогресса моба (тысячные клетки по полному пути).
func progress_to_length(progress: float) -> float:
	var last: int = _path_lengths.size() - 1
	var index: int = clampi(floori(progress / MILLI), 0, last)
	if index >= last:
		return _path_lengths[last]
	var fraction: float = progress / MILLI - index
	return lerpf(_path_lengths[index], _path_lengths[index + 1], fraction)


## Точка на гладкой линии дороги по длине.
func road_point(length: float) -> Vector3:
	var index: int = _road_index(length)
	if index >= _road_points.size() - 1:
		return _road_points[_road_points.size() - 1]
	var span: float = maxf(0.0001, _road_lengths[index + 1] - _road_lengths[index])
	var fraction: float = clampf((length - _road_lengths[index]) / span, 0.0, 1.0)
	return _road_points[index].lerp(_road_points[index + 1], fraction)


## Направление дороги (по горизонтали) в точке.
func road_direction(length: float) -> Vector3:
	var ahead: Vector3 = road_point(length + 0.3)
	var behind: Vector3 = road_point(length - 0.3)
	var flat: Vector3 = Vector3(ahead.x - behind.x, 0.0, ahead.z - behind.z)
	return flat.normalized() if flat.length() > 0.001 else Vector3.FORWARD


func road_end_length() -> float:
	return _road_lengths[_road_lengths.size() - 1]


func path_length_at(index: int) -> float:
	return _path_lengths[clampi(index, 0, _path_lengths.size() - 1)]


func _road_index(length: float) -> int:
	var index: int = _road_lengths.bsearch(length) - 1
	return clampi(index, 0, _road_points.size() - 1)


func _load(board: BoardLayout) -> void:
	_path_cells = board.path_cells
	var path: String = NOIR_LAYOUT_PATH if FileAccess.file_exists(NOIR_LAYOUT_PATH) else LAYOUT_PATH
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("Нет таблицы высот арены: %s" % path)
		return
	var data: Dictionary = parsed
	var cell_value: float = data.get("cell_m", 2.0)
	cell_m = cell_value
	var terraces: Dictionary = data["terraces"]
	for key: String in terraces:
		var parts: PackedStringArray = key.split(",")
		var height: float = terraces[key]
		_terraces[Vector2i(parts[0].to_int(), parts[1].to_int())] = height
	var road: Array = data["road"]
	for entry: Array in road:
		var x: float = entry[0]
		var y: float = entry[1]
		var z: float = entry[2]
		var length: float = entry[3]
		_road_points.append(Vector3(x, z, -y))
		_road_lengths.append(length)
	_match_path_to_road()
	_level_decks()


## Связные группы мест (между дорогами) выравниваются по самой высокой террасе группы.
func _level_decks() -> void:
	var left: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in _terraces:
		left[cell] = true
	while not left.is_empty():
		var group: Array[Vector2i] = []
		var first: Vector2i = left.keys()[0]
		var stack: Array[Vector2i] = [first]
		var top: float = -INF
		while not stack.is_empty():
			var cell: Vector2i = stack.pop_back()
			if not left.has(cell):
				continue
			left.erase(cell)
			group.append(cell)
			top = maxf(top, _terraces[cell])
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if left.has(cell + step):
					stack.append(cell + step)
		var bounds: Rect2i = Rect2i(group[0], Vector2i.ONE)
		for cell: Vector2i in group:
			_decks[cell] = top + DECK_LIFT
			bounds = bounds.expand(cell).merge(Rect2i(cell, Vector2i.ONE))
		deck_bounds.append(bounds)


## Центры клеток пути → ближайшие точки дороги, только вперёд (развороты не путают).
func _match_path_to_road() -> void:
	var start: int = 0
	for cell: Vector2i in _path_cells:
		var center: Vector2 = corner_xz((Vector2(cell) + Vector2(0.5, 0.5)) * MILLI)
		var best: int = start
		var best_distance: float = INF
		for i: int in range(start, _road_points.size()):
			var point: Vector3 = _road_points[i]
			var distance: float = Vector2(point.x, point.z).distance_squared_to(center)
			if distance < best_distance:
				best_distance = distance
				best = i
			elif distance > best_distance + 16.0:
				break
		_path_lengths.append(_road_lengths[best])
		start = best

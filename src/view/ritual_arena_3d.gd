class_name RitualArena3D
extends NoirArena3D
## Двор «Обряда» (мостовая, частокол, терем, чаши — свои) внутри леса PvP-двора.
## Лес, камни, ручей, луг, туман и звери — из мастер-сцены PvP, повёрнуты на четверть
## оборота и сдвинуты: ручей идёт слева у ворот, терем справа, как в кадре PvP.
## Где PvP-камера не смотрела и мастер-сцена ничего не ставила, лес, камни и траву досаживает
## ritual_fill.tres (tools/concepts/ritual_forest_fill.py — поляна и терем там те же, что здесь).

## Двор «Обряда» с частоколом в мире (x, z): клетки 1..23 × 2..12 по 2 м (с площадью терема).
const YARD: Rect2 = Rect2(1.0, -17.0, 48.0, 24.0)
## Расстановка PvP → мир «Обряда»: −90° вокруг вертикали (терем PvP с −z уходит на +x),
## ручей встаёт к воротам слева, брод — напротив входа (z = −15).
const ENV: Transform3D = Transform3D(Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0)),
		Vector3(1.5, 0.0, -18.0))
## Поляна без деревьев: двор с полосой луга и площадка терема; ближе к камере (+x, +z) — шире.
const CLEARINGS: Array[Rect2] = [Rect2(-2.5, -23.0, 48.0, 38.0), Rect2(32.0, -6.0, 20.0, 23.0)]
## Площадь у конца дороги (клетки поля за его краем тоже): терем стоит внутри частокола,
## иначе враги шли бы через город к терему, который можно обойти.
const PLAZA: Rect2i = Rect2i(16, 8, 8, 5)
## Терем на площади фасадом к дороге (−x), крупнее PvP-терема.
const TEREM_AT: Vector3 = Vector3(43.5, 0.0, 1.0)
const TEREM_FRONT: Vector3 = Vector3(-1.0, 0.0, 0.0)
const TEREM_SIZE: float = 1.9
const FILL: CourtyardForestLayout = preload("res://assets/noir/courtyard/ritual_fill.tres")
## Запас от открытой клетки до травы и камней (частокол стоит в 1 м от клетки).
const GRASS_GAP: float = 1.6
## Открытые клетки поля (путь и места построек) — задаёт RitualStage3D до постройки леса.
var yard_cells: Dictionary[Vector2i, bool] = {}


func _yard_rect() -> Rect2:
	return YARD


func _terem_side() -> Side:
	return SIDE_RIGHT


func _env_transform() -> Transform3D:
	return ENV


func _forest_layouts() -> Array[CourtyardForestLayout]:
	var layouts: Array[CourtyardForestLayout] = super._forest_layouts()
	layouts.append(FILL)
	return layouts


func _rock_layouts() -> Array[CourtyardForestLayout]:
	var layouts: Array[CourtyardForestLayout] = super._rock_layouts()
	layouts.append(FILL)
	return layouts


## Деревья — вне поляны; камни и трава — вне двора с теремом.
func _keep_env(at: Vector3, tree: bool) -> bool:
	var point: Vector2 = Vector2(at.x, at.z)
	return not (_in_clearing(point) if tree else _in_yard(point))


func _in_clearing(point: Vector2) -> bool:
	for rect: Rect2 in CLEARINGS:
		if rect.has_point(point):
			return true
	return false


## Двор по настоящим клеткам: в «кармане» между поворотами частокола растёт трава.
func _in_yard(p: Vector2) -> bool:
	var cell: Vector2i = Vector2i(floori(p.x / CELL), floori((p.y - BOARD_MIN.y) / CELL))
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var near: Vector2i = cell + Vector2i(dx, dy)
			if not yard_cells.has(near) and not PLAZA.has_point(near):
				continue
			var area: Rect2 = Rect2(near.x * CELL, near.y * CELL + BOARD_MIN.y, CELL, CELL).grow(GRASS_GAP)
			if area.has_point(p):
				return true
	return yard_cells.is_empty() and YARD.grow(1.2).has_point(p)


func _open_cells(field: FieldState, path: Array[Vector2i]) -> Dictionary[Vector2i, bool]:
	var cells: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in field.get_buildable_cells() + path:
		cells[cell] = true
	for y: int in range(PLAZA.position.y, PLAZA.end.y):
		for x: int in range(PLAZA.position.x, PLAZA.end.x):
			cells[Vector2i(x, y)] = true
	return cells


func _build_terem(_at: Vector3, _out3: Vector3) -> void:
	terem_bounds = AABB()
	if _terem_scene == null:
		return
	var house: Node3D = _terem_scene.instantiate() as Node3D
	_yard.add_child(house)
	house.position = TEREM_AT
	# Фасад модели смотрит на +z (в PvP — навстречу дороге); здесь дорога подходит слева.
	house.rotation.y = atan2(TEREM_FRONT.x, TEREM_FRONT.z)
	house.scale = Vector3.ONE * TEREM_SIZE
	terem_bounds = house.transform * _bounds(house)
	_warm_light(TEREM_AT + TEREM_FRONT * 4.0 + Vector3(0, 2.4, 0), 4.0, 9.0)


## Терем внутри частокола — проёма у крыльца, как в PvP, нет (ворота остаются только у входа).
func _build_walls(fine: Dictionary[Vector2i, bool], entry: Vector2, _door: Vector2) -> void:
	super._build_walls(fine, entry, Vector2(INF, INF))


## Дорога от конца пути сворачивает к крыльцу терема на площади.
func _build_road(finish: float, _door: Vector3, out3: Vector3) -> PackedVector2Array:
	return super._build_road(finish, TEREM_AT + TEREM_FRONT * 3.6, out3)


## Трава и подлесок не растут во дворе и под теремом (двор «Обряда» чистый).
## Весь двор «Обряда» в кадре близко — рисованные картинки заменяются объёмными, как у двора PvP.
func _collect(into: Dictionary[String, Array], id: String, at: Vector2, scale_by: float, yaw: float = -1.0) -> void:
	if _in_yard(at):
		return
	if id.begins_with("bb/grass_"):
		id = "seed_grass" if id.ends_with("52") else "sedge"
	elif id.begins_with("bb/fern_"):
		id = "fern"
	elif id.begins_with("bb/sapling_") or id.begins_with("bb/spruce_"):
		id = "spruce"
	elif id.begins_with("bb/birch_"):
		id = "birch"
	super._collect(into, id, at, scale_by, yaw)


## Расстояние от точки русла (координаты вида) до края поляны; меньше нуля — внутри.
func _clearance(p: Vector2) -> float:
	var at: Vector2 = _w(p)
	var best: float = INF
	for rect: Rect2 in CLEARINGS:
		var dx: float = maxf(rect.position.x - at.x, at.x - rect.end.x)
		var dy: float = maxf(rect.position.y - at.y, at.y - rect.end.y)
		var gap: float = maxf(dx, dy) if dx < 0.0 and dy < 0.0 else Vector2(maxf(dx, 0.0), maxf(dy, 0.0)).length()
		best = minf(best, gap)
	return best


func _wild_zone() -> Rect2:
	return CLEARINGS[0].merge(CLEARINGS[1]).grow(-0.8)


## Дымка леса PvP, перенесённая вместе с лесом.
func _build_mist() -> void:
	super._build_mist()
	var volume: FogVolume = get_node("ForestMist") as FogVolume
	volume.position = ENV * volume.position
	volume.size = Vector3(volume.size.z, volume.size.y, volume.size.x)


func _build_fires(_fine: Dictionary[Vector2i, bool], _terem: Vector2) -> void:
	# по углам двора и по сторонам крыльца терема
	var porch: Vector3 = TEREM_AT + TEREM_FRONT * 4.2
	for point: Vector2 in [Vector2(1, -13), Vector2(35, -13), Vector2(1, 4), Vector2(32, 6),
			Vector2(porch.x + 1.2, porch.z - 4.2), Vector2(porch.x + 1.2, porch.z + 4.6)]:
		var at: Vector3 = Vector3(point.x, 0, point.y)
		var bowl: Node3D = _place("fire_bowl", at, 0, 1.6)
		_add_flame(bowl, 1.25)
		_warm_light(at + Vector3(0, 1.2, 0), 3.2, 7.0)


func _build_paving(fine: Dictionary[Vector2i, bool]) -> Material:
	var paving: Material = super._build_paving(fine)
	for child: Node in _yard.get_children():
		if child is MeshInstance3D:
			var mesh: MeshInstance3D = child as MeshInstance3D
			var material: ShaderMaterial = mesh.material_override as ShaderMaterial
			if material != null and material.shader == PAVING_SHADER:
				material.set_shader_parameter("custom_palette", true)
				material.set_shader_parameter("grout_color", Color("343c3b"))
				material.set_shader_parameter("stone_dark", Color("222a2b"))
				material.set_shader_parameter("stone_light", Color("3a4140"))
	return paving

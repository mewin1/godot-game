class_name RitualArena3D
extends NoirArena3D
## Двор «Обряда» (мостовая, частокол, терем — свои; свет площади — огни идолов) внутри леса PvP-двора.
## Лес, камни, ручей, луг, туман и звери — из мастер-сцены PvP, повёрнуты на четверть
## оборота и сдвинуты: ручей идёт слева у ворот, терем справа, как в кадре PvP.
## Где PvP-камера не смотрела и мастер-сцена ничего не ставила, лес, камни и траву досаживает
## ritual_fill.tres (tools/concepts/ritual_forest_fill.py — поляна и терем там те же, что здесь).

## Двор «Городища» с частоколом в мире (x, z): клетки 5..23 × 5..15 по 2 м — стартовая улица
## по 10-й строке, площадь терема и оба квартала, которые можно пристроить (docs/34 §3).
const YARD: Rect2 = Rect2(9.0, -11.0, 40.0, 24.0)
## Расстановка PvP → мир «Обряда»: −90° вокруг вертикали (терем PvP с −z уходит на +x),
## ручей встаёт к воротам слева, брод — напротив входа (z = −15).
const ENV: Transform3D = Transform3D(Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0)),
		Vector3(1.5, 0.0, -18.0))
## Поляна без деревьев: двор с полосой луга и площадка терема; ближе к камере (+x, +z) — шире.
## Верхняя и нижняя улицы (4 и 16 строки поля) тоже на поляне: лес растёт один раз.
const CLEARINGS: Array[Rect2] = [Rect2(-2.5, -19.0, 48.0, 38.0), Rect2(32.0, -6.0, 20.0, 25.0)]
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
## Карта «Городища» (решение автора 15 ноября, вариант "Слобода у пруда"). Изгибы дорог объясняют
## преграды: подкова главной дороги огибает пруд, северная сворачивает у капища, южная идёт
## вдоль берега. Дворы за тыном. Только вид: враги и так идут по маршрутам поля.
## Дома стоят севернее широтных дорог (камера смотрит с юга): дом x2 южнее дороги закрывал бы её.
const TOWN_BOARD: String = "res://data/ritual/board_city2.tres"
const POND: Rect2i = Rect2i(7, 7, 7, 6)
const SHRINE: Rect2i = Rect2i(10, 4, 1, 1)
## Тын ниже 0,4 клетки (docs/37 SCN-4), чтобы не закрывать врагов.
const FENCE_HEIGHT: float = 0.7
const FENCE_COLOR: Color = Color(0.17, 0.12, 0.08)
## Клетки поля (пути и места, включая ещё не пристроенные кварталы) — задаёт RitualStage3D
## до постройки леса: лес, камни и луг сюда не садятся.
var yard_cells: Dictionary[Vector2i, bool] = {}
## Дорога каждого входа (вид) — задаёт RitualStage3D; 0 — главная.
var lane_layouts: Array[ArenaLayout3D] = []
## Проулок каждой улицы (вид; null — проулка нет): рисуется дорогой, когда улица пристроена.
var alley_layouts: Array[ArenaLayout3D] = []
## Проулки-срезки (вид) и уровень города, с которого каждый рисуется (docs/37 ALY-1).
var shortcut_layouts: Array[ArenaLayout3D] = []
var shortcut_levels: Array[int] = []
var _city_level: int = 1
## Сколько входов открыто сейчас и какие клетки двора уже открыты (подлесок их обходит).
var _open_lanes: int = 1
var _open_now: Dictionary[Vector2i, bool] = {}
var _roads_now: Dictionary[Vector2i, bool] = {}
var _plots_now: Dictionary[Vector2i, bool] = {}
var _town: bool = false


func _yard_rect() -> Rect2:
	return YARD


func _terem_side() -> Side:
	return SIDE_RIGHT


func _glades() -> Array[Rect2]:
	return CLEARINGS


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
	return _in_cells(p, yard_cells)


func _in_cells(p: Vector2, cells: Dictionary[Vector2i, bool]) -> bool:
	var cell: Vector2i = Vector2i(floori(p.x / CELL), floori((p.y - BOARD_MIN.y) / CELL))
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var near: Vector2i = cell + Vector2i(dx, dy)
			if not cells.has(near) and not PLAZA.has_point(near):
				continue
			var area: Rect2 = Rect2(near.x * CELL, near.y * CELL + BOARD_MIN.y, CELL, CELL).grow(GRASS_GAP)
			if area.has_point(p):
				return true
	return yard_cells.is_empty() and YARD.grow(1.2).has_point(p)


## У дома на участке свой цоколь. Каменная стенка PvP закрывала двери и окна.
func _uses_cellar_walls(field: FieldState) -> bool:
	return not (field as RitualField).settings.uses_plots()


## Двор растёт улицами: открытые дороги и места всех пристроенных кварталов.
func set_open(field: FieldState) -> void:
	var ritual: RitualField = field as RitualField
	_open_lanes = 1
	_city_level = 1
	if ritual != null:
		_city_level = 1 + ritual.open_streets
		# Уровень без входа (детинец) своей дороги не рисует.
		for index: int in mini(ritual.open_streets, ritual.settings.streets.size()):
			_open_lanes += int(not ritual.settings.streets[index].path_cells.is_empty())
	super.set_open(field)


func _open_cells(field: FieldState, path: Array[Vector2i]) -> Dictionary[Vector2i, bool]:
	var cells: Dictionary[Vector2i, bool] = {}
	var roads: Array[Vector2i] = path
	if field is RitualField:
		roads = (field as RitualField).open_road_cells()
	_town = field.layout.resource_path == TOWN_BOARD
	_roads_now.clear()
	_plots_now.clear()
	for cell: Vector2i in roads:
		_roads_now[cell] = true
	for cell: Vector2i in field.get_buildable_cells():
		_plots_now[cell] = true
	for cell: Vector2i in field.get_buildable_cells() + roads:
		cells[cell] = true
	# Участки (docs/37 P3) стоят в цельных кварталах уровня города: частокол обходит квартал,
	# а не каждый участок отдельно.
	if field is RitualField and (field as RitualField).settings.uses_plots():
		for region: Rect2i in (field as RitualField).open_regions():
			for y: int in range(region.position.y, region.end.y):
				for x: int in range(region.position.x, region.end.x):
					cells[Vector2i(x, y)] = true
	for y: int in range(PLAZA.position.y, PLAZA.end.y):
		for x: int in range(PLAZA.position.x, PLAZA.end.x):
			cells[Vector2i(x, y)] = true
	_open_now = cells
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


## Дорога от конца пути сворачивает к крыльцу терема на площади. Дороги улиц кончаются
## у сторожки (их обочины и ворота — для подклетов и частокола).
func _build_road(finish: float, _door: Vector3, out3: Vector3) -> PackedVector2Array:
	var main_bank: PackedVector2Array = super._build_road(finish, TEREM_AT + TEREM_FRONT * 3.6, out3)
	_extra_lanes.clear()
	_extra_entries.clear()
	var main: ArenaLayout3D = _layout
	for lane: int in range(1, mini(_open_lanes, lane_layouts.size())):
		_layout = lane_layouts[lane]
		var end: float = _layout.road_end_length()
		var heading: Vector3 = _layout.road_direction(end)
		_extra_lanes.append(super._build_road(end, _layout.road_point(end) + heading * 0.05, heading))
		var entry: Vector3 = _layout.road_point(0.0)
		_extra_entries.append(Vector2(entry.x, entry.z))
		var alley: ArenaLayout3D = alley_layouts[lane - 1] if lane - 1 < alley_layouts.size() else null
		if alley != null:
			_layout = alley
			var tail: float = alley.road_end_length()
			var along: Vector3 = alley.road_direction(tail)
			_extra_lanes.append(super._build_road(tail, alley.road_point(tail) + along * 0.05, along))
	for index: int in shortcut_layouts.size():
		if shortcut_levels[index] > _city_level:
			continue
		_layout = shortcut_layouts[index]
		var tail: float = _layout.road_end_length()
		var along: Vector3 = _layout.road_direction(tail)
		_extra_lanes.append(super._build_road(tail, _layout.road_point(tail) + along * 0.05, along))
	_layout = main
	return main_bank


## Трава и подлесок не растут во дворе и под теремом (двор «Обряда» чистый).
## Весь двор «Обряда» в кадре близко — рисованные картинки заменяются объёмными, как у двора PvP.
func _collect(into: Dictionary[String, Array], id: String, at: Vector2, scale_by: float, yaw: float = -1.0) -> void:
	# Подлесок двора пересобирается с ростом города — он обходит только уже открытые клетки;
	# луг и лес сажаются один раз — они обходят и будущие кварталы.
	var inside: bool = _in_cells(at, _open_now) if is_same(into, _yard_grass) else _in_yard(at)
	if inside:
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


## Чаш на поле нет (docs/37 VIS-2): свет площади дают огни идолов (RitualIdols3D),
## огромные чаши закрывали участки и были ярче всего игрового.
func _build_fires(_fine: Dictionary[Vector2i, bool], _terem: Vector2) -> void:
	if _town:
		_build_pond()
		_build_shrine()
		_build_fences()


func _cell_rect(cells: Rect2i) -> Rect2:
	return Rect2(Vector2(cells.position) * CELL + BOARD_MIN, Vector2(cells.size) * CELL)


## Пруд внутри подковы главной дороги. Проулок через него (с города 2) рисуется дорогой поверх воды - кладки.
func _build_pond() -> void:
	# Полоса берега у дорог - мостовая.
	var area: Rect2 = _cell_rect(POND).grow(-0.3)
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_normal(Vector3.UP)
	var corners: Array[Vector2] = [area.position, Vector2(area.end.x, area.position.y), area.end,
		Vector2(area.position.x, area.end.y)]
	for index: int in [0, 1, 2, 0, 2, 3]:
		var corner: Vector2 = corners[index]
		# Шейдер ручья: UV.x - метры вдоль, UV.y - поперек 0..1 (темнее к середине).
		tool.set_uv(Vector2(corner.x, (corner.y - area.position.y) / area.size.y))
		tool.add_vertex(Vector3(corner.x, 0.005, corner.y))
	tool.generate_tangents()
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = STREAM_SHADER
	material.set_shader_parameter("bed", preload("res://assets/noir/courtyard/river_gravel.png"))
	material.set_shader_parameter("flow", 0.05)
	var center: Vector2 = area.get_center()
	material.set_shader_parameter("moon_spot", Vector3(center.x, 0.0, center.y))
	var water: MeshInstance3D = MeshInstance3D.new()
	water.name = "Pond"
	water.mesh = tool.commit()
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_yard.add_child(water)


## Капище перед северными воротами: из-за него северная дорога сворачивает на восток.
## Ниже домов: стоит южнее дороги и не должно закрывать врагов.
func _build_shrine() -> void:
	var area: Rect2 = _cell_rect(SHRINE)
	var holder: Node3D = Node3D.new()
	holder.name = "Shrine"
	holder.position = Vector3(area.get_center().x, 0.0, area.get_center().y)
	_yard.add_child(holder)
	var wood: StandardMaterial3D = ArenaMaterials3D.solid(ArenaMaterials3D.DARK_WOOD)
	ArenaMaterials3D.part(holder, ArenaMaterials3D.cylinder(0.85, 0.92, 0.1, 12),
		ArenaMaterials3D.stone(ArenaMaterials3D.DARK_STONE), Vector3(0, 0.05, 0))
	ArenaMaterials3D.part(holder, ArenaMaterials3D.cylinder(0.17, 0.14, 1.3, 8), wood, Vector3(0, 0.65, 0))
	ArenaMaterials3D.part(holder, ArenaMaterials3D.cylinder(0.24, 0.17, 0.2, 8), wood, Vector3(0, 1.35, 0))
	for index: int in 8:
		var angle: float = TAU * index / 8.0
		ArenaMaterials3D.part(holder, ArenaMaterials3D.cylinder(0.06, 0.05, 0.6, 6), wood,
			Vector3(cos(angle) * 0.72, 0.3, sin(angle) * 0.72))


## Тын вдоль улиц: дворы между домами закрыты, путь врага - только по дороге.
func _build_fences() -> void:
	var panels: Array[Transform3D] = []
	var posts: Array[Transform3D] = []
	for road: Vector2i in _roads_now:
		for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not _is_fenced_yard(road + side):
				continue
			var center: Vector3 = _layout.cell_center(road) + Vector3(side.x, 0, side.y) * (CELL * 0.5 + 0.08)
			var axes: Basis = Basis(Vector3.UP, atan2(float(side.x), float(side.y)))
			panels.append(Transform3D(axes, center + Vector3.UP * FENCE_HEIGHT * 0.55))
			for offset: float in [-0.9, 0.0, 0.9]:
				posts.append(Transform3D(axes, center + axes.x * offset + Vector3.UP * FENCE_HEIGHT * 0.5))
	var wood: StandardMaterial3D = ArenaMaterials3D.solid(FENCE_COLOR)
	_fence_multimesh("FencePanels", ArenaMaterials3D.box(Vector3(1.96, FENCE_HEIGHT * 0.7, 0.07)), wood, panels)
	_fence_multimesh("FencePosts", ArenaMaterials3D.cylinder(0.05, 0.045, FENCE_HEIGHT, 5), wood, posts)


func _is_fenced_yard(cell: Vector2i) -> bool:
	return _open_now.has(cell) and not _roads_now.has(cell) and not _plots_now.has(cell) \
		and not POND.has_point(cell) and not SHRINE.has_point(cell) and not PLAZA.has_point(cell)


func _fence_multimesh(title: String, mesh: Mesh, material: Material, poses: Array[Transform3D]) -> void:
	var instances: MultiMesh = MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = poses.size()
	for index: int in poses.size():
		instances.set_instance_transform(index, poses[index])
	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.name = title
	node.multimesh = instances
	node.material_override = material
	_yard.add_child(node)


func _build_paving(fine: Dictionary[Vector2i, bool]) -> Material:
	var paving: Material = super._build_paving(fine)
	for child: Node in _yard.get_children():
		if child is MeshInstance3D:
			var mesh: MeshInstance3D = child as MeshInstance3D
			var material: ShaderMaterial = mesh.material_override as ShaderMaterial
			if material != null and material.shader == PAVING_SHADER:
				material.set_shader_parameter("custom_palette", true)
				material.set_shader_parameter("grout_color", Color("47514f"))
				material.set_shader_parameter("stone_dark", Color("343e3e"))
				material.set_shader_parameter("stone_light", Color("545e5c"))
	return paving

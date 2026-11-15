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
## Пруд (critique_2 п. 1-6): естественный контур-«боб» внутри подковы дорог — от осей дорог не ближе
## 2,2 м (обочина + берег), от южного частокола не ближе 1,8 м. Вода ниже мостовой, берег —
## откос как у ручья, мостовая обрывается за полосой земли POND_SHORE, под водой — чаша в земле.
const POND_CENTER: Vector2 = Vector2(21.0, 0.35)
const POND_RADII: Vector2 = Vector2(5.3, 4.7)
const POND_STEPS: int = 96
const POND_WATER_Y: float = -0.06
const POND_SHORE: float = 1.0
const POND_DEPTH: float = 0.5
## Кольца сетки воды — расстояния от уреза внутрь (м): мель и прозрачность по всему берегу.
const POND_RINGS: Array[float] = [0.0, 0.3, 0.75, 1.5]
## Отражение луны — у дальнего (северного) берега, небольшое, как у ручья.
const POND_MOON: Vector3 = Vector3(21.5, 0.0, -2.9)
## Лесные тропы за воротами (docs/37 SCN-8, critique_2 п. 11): нежить выходит из леса по ним.
## Длина тропы от ворот (м) и сдвиг её конца вбок (м) по входам: запад, север, юг.
const TRAIL_LENGTH: float = 20.0
const TRAIL_BENDS: Array[float] = [-5.0, 5.5, -5.0]
## Коридор без деревьев вдоль тропы (м); трава и камни отступают на TRAIL_GRASS.
const TRAIL_CLEAR: float = 2.4
const TRAIL_GRASS: float = 1.1
const DEAD_WOOD: Color = Color(0.07, 0.065, 0.06)
const BONE: Color = Color(0.7, 0.67, 0.58)
## Южные (к камере) стены у дороги ниже: за ними враг на въезде виден целиком (critique_2 п. 13).
const LOW_WALL: float = 0.72
## Кладки и мостки пруда: верх настила на уровне колеи дорог; доски светлее двора ночью.
const DECK_Y: float = 0.08
const DECK_WOOD: Color = Color(0.5, 0.38, 0.26)
## Мостки для рыбалки — у восточного берега, лицом к камере (юго-восток).
const PIER_DIRECTION: Vector2 = Vector2(0.85, 0.53)
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
## Тропа каждого входа (мир x, z): от ворот наружу в лес; задаётся до посадки леса.
var trails: Array[PackedVector2Array] = []
var _trail_boxes: Array[Rect2] = []
## Проулок над прудом рисуется настилом: дорога там, где мостовой нет, не кладётся.
var _road_over_water: bool = false
var _land: PackedVector2Array = PackedVector2Array()


func _yard_rect() -> Rect2:
	return YARD


## Тропы считаются до леса: лес сажается один раз и оставляет вдоль них коридор.
func build_for_layout(layout: ArenaLayout3D) -> void:
	if _layout == null:
		trails.clear()
		_trail_boxes.clear()
		for lane: int in lane_layouts.size():
			var trail: PackedVector2Array = _make_trail(lane)
			trails.append(trail)
			var box: Rect2 = Rect2(trail[0], Vector2.ZERO)
			for point: Vector2 in trail:
				box = box.expand(point)
			_trail_boxes.append(box.grow(TRAIL_CLEAR))
	super.build_for_layout(layout)


## Тропа входа lane: начинается под воротами, идёт наружу и конец уводит вбок, в лес.
func _make_trail(lane: int) -> PackedVector2Array:
	var road: ArenaLayout3D = lane_layouts[lane]
	var entry: Vector3 = road.road_point(0.0)
	var heading: Vector3 = road.road_direction(0.0)
	var out: Vector2 = -Vector2(heading.x, heading.z).normalized()
	var side: Vector2 = Vector2(-out.y, out.x)
	var bend: float = TRAIL_BENDS[lane % TRAIL_BENDS.size()]
	var points: PackedVector2Array = PackedVector2Array()
	var steps: int = 40
	for k: int in steps + 1:
		var t: float = TRAIL_LENGTH * k / steps
		var sway: float = bend * smoothstep(0.2, 1.0, t / TRAIL_LENGTH) \
				+ 0.4 * sin(t * 0.43 + lane * 1.7) * smoothstep(2.0, 6.0, t)
		points.append(Vector2(entry.x, entry.z) + out * (t + 1.2) + side * sway)
	return points


## Расстояние от точки до ближайшей тропы (INF — троп рядом нет).
func trail_gap(point: Vector2) -> float:
	var best: float = INF
	for lane: int in trails.size():
		if not _trail_boxes[lane].has_point(point):
			continue
		var trail: PackedVector2Array = trails[lane]
		for index: int in trail.size() - 1:
			var near: Vector2 = Geometry2D.get_closest_point_to_segment(point, trail[index], trail[index + 1])
			best = minf(best, near.distance_to(point))
	return best

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


## Деревья — вне поляны и коридоров троп; камни и трава — вне двора с теремом и не на тропах.
func _keep_env(at: Vector3, tree: bool) -> bool:
	var point: Vector2 = Vector2(at.x, at.z)
	if trail_gap(point) < (TRAIL_CLEAR if tree else TRAIL_GRASS):
		return false
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
		# Над прудом проулок — кладки (_build_boardwalk), дорога кладётся только на суше.
		_road_over_water = _town
		_extra_lanes.append(super._build_road(tail, _layout.road_point(tail) + along * 0.05, along))
		_road_over_water = false
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
	if trail_gap(at) < (TRAIL_CLEAR if id in ["spruce", "birch"] else TRAIL_GRASS):
		return
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
	for lane: int in mini(_open_lanes, trails.size()):
		_build_trail(lane)
	if _town:
		_build_pond()
		# Капище стоит на своей клетке, открытой с города 2; раньше оно вставало на линию частокола.
		if _open_now.has(SHRINE.position):
			_build_shrine()
		_build_fences()


## Тропа открытого входа: тёмная колея, к концу уже и тает; через ручей — бревенчатые кладки;
## в конце — сухие деревья, костяной тотем и туман (docs/37 SCN-8).
func _build_trail(lane: int) -> void:
	var trail: PackedVector2Array = trails[lane]
	var crossing: Vector2 = _stream_crossing(trail)
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var along: float = 0.0
	for index: int in trail.size() - 1:
		var a: Vector2 = trail[index]
		var b: Vector2 = trail[index + 1]
		var step: float = a.distance_to(b)
		if crossing.is_finite() and (a.distance_to(crossing) < 2.3 or b.distance_to(crossing) < 2.3):
			along += step
			continue
		var direction: Vector2 = (b - a).normalized()
		var side: Vector2 = Vector2(-direction.y, direction.x)
		var half_a: float = lerpf(0.95, 0.6, along / TRAIL_LENGTH)
		var half_b: float = lerpf(0.95, 0.6, (along + step) / TRAIL_LENGTH)
		var corners: Array[Vector3] = [_trail_vertex(a - side * half_a), _trail_vertex(a + side * half_a),
				_trail_vertex(b + side * half_b), _trail_vertex(b - side * half_b)]
		var uvs: Array[Vector2] = [Vector2(0.0, along / 4.0), Vector2(1.0, along / 4.0),
				Vector2(1.0, (along + step) / 4.0), Vector2(0.0, (along + step) / 4.0)]
		for corner: int in [0, 1, 2, 0, 2, 3]:
			tool.set_normal(Vector3.UP)
			tool.set_uv(uvs[corner])
			tool.add_vertex(corners[corner])
		along += step
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = ROAD_SHADER
	material.set_shader_parameter("cartway", preload("res://assets/noir/courtyard/cartway.png"))
	material.set_shader_parameter("earth_normal", preload("res://assets/noir_h3d/arena/ground/brown_mud_leaves_01_nor_gl_1k.jpg"))
	material.set_shader_parameter("earth", preload("res://assets/noir_h3d/arena/ground/brown_mud_leaves_01_diff_1k.jpg"))
	material.set_shader_parameter("wild", 1.0)
	material.set_shader_parameter("fade_from", TRAIL_LENGTH * 0.55 / 4.0)
	material.set_shader_parameter("fade_to", TRAIL_LENGTH / 4.0)
	var ribbon: MeshInstance3D = MeshInstance3D.new()
	ribbon.name = "Trail%d" % lane
	ribbon.mesh = tool.commit()
	ribbon.material_override = material
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_yard.add_child(ribbon)
	if crossing.is_finite():
		_build_log_bridge(crossing, trail)
	var end: Vector2 = trail[trail.size() - 1]
	var tail: Vector2 = (end - trail[trail.size() - 6]).normalized()
	var across: Vector2 = Vector2(-tail.y, tail.x)
	for index: int in 3:
		var spot: Vector2 = end - tail * (2.0 + index * 2.6) + across * (2.2 + index * 0.5) * (1.0 if index % 2 == 0 else -1.0)
		_dead_tree(Vector3(spot.x, 0.0, spot.y), 2.6 + index * 0.45, lane * 3 + index)
	var totem: Vector2 = trail[int(trail.size() * 0.62)] + across * 1.5
	_bone_totem(Vector3(totem.x, 0.0, totem.y))
	_trail_mist(Vector3(end.x, 0.0, end.y))


func _trail_vertex(point: Vector2) -> Vector3:
	return Vector3(point.x, -0.02, point.y)


## Где тропа пересекает ручей (INF — не пересекает).
func _stream_crossing(trail: PackedVector2Array) -> Vector2:
	var stream: PackedVector2Array = _world_stream()
	for index: int in trail.size() - 1:
		for k: int in stream.size() - 1:
			var hit: Variant = Geometry2D.segment_intersects_segment(trail[index], trail[index + 1], stream[k], stream[k + 1])
			if hit != null:
				var point: Vector2 = hit
				return point
	return Vector2.INF


## Кладки через ручей: брёвна вдоль тропы и поперечные бревна-лежни на берегах.
func _build_log_bridge(at: Vector2, trail: PackedVector2Array) -> void:
	var nearest: int = 0
	for index: int in trail.size():
		if trail[index].distance_to(at) < trail[nearest].distance_to(at):
			nearest = index
	var direction: Vector2 = (trail[mini(nearest + 1, trail.size() - 1)] - trail[maxi(nearest - 1, 0)]).normalized()
	var holder: Node3D = Node3D.new()
	holder.name = "LogBridge"
	holder.position = Vector3(at.x, 0.0, at.y)
	holder.rotation.y = atan2(direction.x, direction.y)
	_yard.add_child(holder)
	var wood: StandardMaterial3D = ArenaMaterials3D.solid(ArenaMaterials3D.WOOD.darkened(0.15))
	for index: int in 4:
		ArenaMaterials3D.part(holder, ArenaMaterials3D.cylinder(0.13, 0.12, 4.6, 7), wood,
				Vector3((index - 1.5) * 0.27, 0.16, 0.0), Vector3(PI * 0.5, 0.0, 0.0))
	for end: float in [-2.1, 2.1]:
		ArenaMaterials3D.part(holder, ArenaMaterials3D.cylinder(0.1, 0.1, 1.5, 6), wood,
				Vector3(0.0, 0.05, end), Vector3(0.0, 0.0, PI * 0.5))


## Сухое дерево (docs/37 SCN-8): чёрный ствол и голые ветви. seed — разброс ветвей.
func _dead_tree(at: Vector3, height: float, seed_value: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7001 + seed_value
	var holder: Node3D = Node3D.new()
	holder.position = at
	holder.rotation = Vector3(rng.randf_range(-0.08, 0.08), rng.randf() * TAU, rng.randf_range(-0.08, 0.08))
	_yard.add_child(holder)
	var bark: StandardMaterial3D = ArenaMaterials3D.solid(DEAD_WOOD, 0.95)
	ArenaMaterials3D.part(holder, ArenaMaterials3D.cylinder(0.17, 0.05, height, 7), bark, Vector3(0, height * 0.5, 0))
	for branch: int in 5:
		var rise: float = height * rng.randf_range(0.35, 0.85)
		var length: float = rng.randf_range(0.7, 1.4) * (1.0 - rise / height * 0.4)
		var yaw: float = TAU * branch / 5.0 + rng.randf_range(-0.4, 0.4)
		var tilt: float = rng.randf_range(0.6, 1.05)
		var limb: Node3D = Node3D.new()
		limb.position = Vector3(0, rise, 0)
		limb.rotation = Vector3(0.0, yaw, tilt)
		holder.add_child(limb)
		ArenaMaterials3D.part(limb, ArenaMaterials3D.cylinder(0.045, 0.012, length, 5), bark, Vector3(0, length * 0.5, 0))


## Костяной тотем у тропы: шест, перекладина и черепа.
func _bone_totem(at: Vector3) -> void:
	var holder: Node3D = Node3D.new()
	holder.position = at
	holder.rotation.y = 0.6
	_yard.add_child(holder)
	var pole: StandardMaterial3D = ArenaMaterials3D.solid(DEAD_WOOD.lightened(0.08), 0.95)
	var bone: StandardMaterial3D = ArenaMaterials3D.solid(BONE, 0.7)
	ArenaMaterials3D.part(holder, ArenaMaterials3D.cylinder(0.07, 0.05, 1.9, 6), pole, Vector3(0, 0.95, 0))
	ArenaMaterials3D.part(holder, ArenaMaterials3D.box(Vector3(0.8, 0.07, 0.07)), pole, Vector3(0, 1.55, 0))
	ArenaMaterials3D.part(holder, ArenaMaterials3D.sphere(0.15, 8, 5), bone, Vector3(0, 2.0, 0), Vector3.ZERO,
			Vector3(1.0, 1.15, 1.0))
	for side: float in [-0.34, 0.34]:
		ArenaMaterials3D.part(holder, ArenaMaterials3D.sphere(0.09, 6, 4), bone, Vector3(side, 1.38, 0))


## Туман в конце тропы: на ПК — объёмный, на телефоне его даёт общий слой дымки у земли.
func _trail_mist(at: Vector3) -> void:
	var world_env: WorldEnvironment = get_parent().get_node_or_null("Environment") as WorldEnvironment
	if world_env == null or not world_env.environment.volumetric_fog_enabled:
		return
	var fog: FogMaterial = FogMaterial.new()
	fog.density = 1.1
	fog.albedo = Color(0.6, 0.66, 0.68)
	fog.edge_fade = 0.7
	fog.height_falloff = 0.6
	var volume: FogVolume = FogVolume.new()
	volume.name = "TrailMist"
	volume.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	volume.size = Vector3(11.0, 3.2, 11.0)
	volume.position = at + Vector3(0, 0.9, 0)
	volume.material = fog
	_yard.add_child(volume)


## Южная (к камере) стена у открытой дороги ниже — частокол не прячет врага на въезде.
func _wall_height(center: Vector2, out: Vector2) -> float:
	if not _town or out.y <= 0.0:
		return WALL_SCALE
	for road: Vector2i in _roads_now:
		var middle: Vector3 = _layout.cell_center(road)
		if absf(middle.x - center.x) < 2.2 and center.y - middle.z > 0.0 and center.y - middle.z < 2.6:
			return WALL_SCALE * LOW_WALL
	return WALL_SCALE


## Жаровни снаружи — только у главных (западных) ворот: огней в кадре было ~12 при норме SCN-9 «≤ 3».
func _gate_bowls(gate: int) -> bool:
	return gate == 0


## На площади свет дают огни идолов (RitualIdols3D): факел и чаша посреди стены встали бы на их ряд.
func _wall_light_allowed(at: Vector2) -> bool:
	return not _cell_rect(PLAZA).grow(1.2).has_point(at)


func _cell_rect(cells: Rect2i) -> Rect2:
	return Rect2(Vector2(cells.position) * CELL + BOARD_MIN, Vector2(cells.size) * CELL)


## Урез пруда (мир x, z), отодвинутый наружу на grow м: эллипс с «шумом» радиуса.
## vary > 0 — ширина отступа гуляет по берегу (край мостовой не повторяет урез кольцом).
static func pond_contour(grow: float = 0.0, vary: float = 0.0) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in POND_STEPS:
		var angle: float = TAU * index / POND_STEPS
		var wobble: float = minf(1.09, 1.0 + 0.045 * sin(2.0 * angle + 0.7) + 0.035 * sin(3.0 * angle + 1.9)
				+ 0.02 * sin(5.0 * angle + 0.4))
		points.append(POND_CENTER + Vector2(cos(angle) * POND_RADII.x, sin(angle) * POND_RADII.y) * wobble)
	if grow != 0.0:
		var normals: PackedVector2Array = _outward(points)
		for index: int in points.size():
			var angle: float = TAU * index / POND_STEPS
			var swing: float = 1.0 + vary * (0.6 * sin(3.0 * angle + 2.3) + 0.4 * sin(7.0 * angle + 0.9))
			points[index] += normals[index] * grow * swing
	return points


## Нормали контура наружу (от середины пруда).
static func _outward(points: PackedVector2Array) -> PackedVector2Array:
	var normals: PackedVector2Array = PackedVector2Array()
	var count: int = points.size()
	for index: int in count:
		var tangent: Vector2 = points[(index + 1) % count] - points[(index - 1 + count) % count]
		var normal: Vector2 = Vector2(tangent.y, -tangent.x).normalized()
		if normal.dot(points[index] - POND_CENTER) < 0.0:
			normal = -normal
		normals.append(normal)
	return normals


## Мостовая обрывается за полосой земли у пруда (раньше плитка лежала под всей водой — «дно = брусчатка»).
func _paving_cut() -> PackedVector2Array:
	return _land_cut() if _town else PackedVector2Array()


## Край мостовой у пруда (урез + полоса земли неровной ширины).
func _land_cut() -> PackedVector2Array:
	if _land.is_empty():
		_land = pond_contour(POND_SHORE, 0.45)
	return _land


func _road_hidden(a: Vector3, b: Vector3) -> bool:
	var land: PackedVector2Array = _land_cut()
	return _road_over_water and Geometry2D.is_point_in_polygon(Vector2(a.x, a.z), land) 			and Geometry2D.is_point_in_polygon(Vector2(b.x, b.z), land)


## Пруд внутри подковы главной дороги: вода ручья (общий шейдер), берег-откос, чаша в земле.
func _build_pond() -> void:
	var shore: PackedVector2Array = pond_contour()
	var normals: PackedVector2Array = _outward(shore)
	var count: int = shore.size()
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring: int in POND_RINGS.size() - 1:
		for index: int in count:
			var next: int = (index + 1) % count
			for corner: Vector2i in [Vector2i(index, ring), Vector2i(next, ring), Vector2i(index, ring + 1),
					Vector2i(next, ring), Vector2i(next, ring + 1), Vector2i(index, ring + 1)]:
				var depth: float = POND_RINGS[corner.y]
				_pond_vertex(tool, shore[corner.x] - normals[corner.x] * depth, depth)
	var last: float = POND_RINGS[-1]
	for index: int in count:
		var next: int = (index + 1) % count
		_pond_vertex(tool, POND_CENTER, last)
		_pond_vertex(tool, shore[index] - normals[index] * last, last)
		_pond_vertex(tool, shore[next] - normals[next] * last, last)
	tool.generate_tangents()
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = POND_SHADER
	material.set_shader_parameter("bed", preload("res://assets/noir/courtyard/river_gravel.png"))
	material.set_shader_parameter("flow", 0.0)
	material.set_shader_parameter("moon_spot", POND_MOON)
	material.set_shader_parameter("moon_radius", 0.8)
	material.set_shader_parameter("water_specular", 0.1)
	var water: MeshInstance3D = MeshInstance3D.new()
	water.name = "Pond"
	water.mesh = tool.commit()
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_yard.add_child(water)
	_build_pond_banks(shore, normals)
	_build_pond_life(shore, normals)
	if _ground != null:
		_ground.set_shader_parameter("pond_center", POND_CENTER)
		_ground.set_shader_parameter("pond_radii", POND_RADII)
		_ground.set_shader_parameter("pond_depth", POND_DEPTH)


## Пруд как место (critique_2 п. 7-8): кладки проулка на сваях, мостки для рыбалки с лодкой,
## плетень кусками вдоль дорог, осока не выше 0,6 м и валуны у воды. Всё ниже 0,8 м, кроме перил
## кладок с дальней от камеры стороны. Только вид.
func _build_pond_life(shore: PackedVector2Array, normals: PackedVector2Array) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4242
	var gaps: Array[Vector2] = []
	for index: int in shortcut_layouts.size():
		if shortcut_levels[index] > _city_level:
			continue
		var span: PackedVector3Array = _deck_span(shortcut_layouts[index])
		if span.size() == 2:
			_build_boardwalk(span[0], span[1])
			gaps.append(Vector2(span[0].x, span[0].z))
			gaps.append(Vector2(span[1].x, span[1].z))
	var pier: int = _shore_index(shore, PIER_DIRECTION)
	_build_fishing_pier(shore[pier], normals[pier])
	gaps.append(shore[pier] + normals[pier] * POND_SHORE)
	_build_wattle(gaps, rng)
	_build_reeds(shore, normals, pier, rng)


## Где проулок идёт над прудом (по краю мостовой): начало и конец настила; пусто — не пересекает.
func _deck_span(road: ArenaLayout3D) -> PackedVector3Array:
	var land: PackedVector2Array = _land_cut()
	var first: float = -1.0
	var last: float = -1.0
	var length: float = 0.0
	var end: float = road.road_end_length()
	while length <= end:
		var at: Vector3 = road.road_point(length)
		if Geometry2D.is_point_in_polygon(Vector2(at.x, at.z), land):
			if first < 0.0:
				first = length
			last = length
		length += 0.2
	if first < 0.0:
		return PackedVector3Array()
	return PackedVector3Array([road.road_point(maxf(0.0, first - 0.5)), road.road_point(minf(end, last + 0.5))])


## Настил кладок: доски поперёк, два бруса, сваи парами; перила — с дальней от камеры стороны.
func _build_boardwalk(from: Vector3, to: Vector3) -> void:
	var holder: Node3D = Node3D.new()
	holder.name = "Boardwalk"
	var along: Vector3 = Vector3(to.x - from.x, 0.0, to.z - from.z)
	var length: float = along.length()
	holder.position = Vector3((from.x + to.x) * 0.5, DECK_Y, (from.z + to.z) * 0.5)
	holder.rotation.y = atan2(along.x, along.z)
	_yard.add_child(holder)
	var boards: Array[StandardMaterial3D] = [_deck_material(DECK_WOOD), _deck_material(DECK_WOOD.darkened(0.12))]
	var dark: StandardMaterial3D = ArenaMaterials3D.solid(DECK_WOOD.darkened(0.45))
	var count: int = ceili(length / 0.3)
	var step: float = length / count
	for index: int in count:
		var z: float = -length * 0.5 + step * (index + 0.5)
		ArenaMaterials3D.part(holder, ArenaMaterials3D.box(Vector3(2.1, 0.06, step - 0.035)), boards[index % 2],
				Vector3(sin(index * 1.7) * 0.04, sin(index * 2.3) * 0.008, z), Vector3(0.0, sin(index * 0.9) * 0.025, 0.0))
	for side: float in [-0.75, 0.75]:
		ArenaMaterials3D.part(holder, ArenaMaterials3D.box(Vector3(0.14, 0.12, length)), dark, Vector3(side, -0.09, 0.0))
	var piles: int = maxi(2, ceili(length / 1.6) + 1)
	for index: int in piles:
		var z: float = -length * 0.5 + length * index / (piles - 1)
		for side: float in [-0.95, 0.95]:
			ArenaMaterials3D.part(holder, ArenaMaterials3D.cylinder(0.09, 0.08, 0.7, 6), dark,
					Vector3(side, -0.35, z))
	# Перила с северной (дальней) стороны: камера с юга смотрит поверх них на настил.
	var far_side: float = 1.0 if sin(holder.rotation.y) >= 0.0 else -1.0
	for index: int in piles:
		var z: float = -length * 0.5 + length * index / (piles - 1)
		ArenaMaterials3D.part(holder, ArenaMaterials3D.cylinder(0.04, 0.035, 0.5, 5), dark, Vector3(far_side * 1.0, 0.25, z))
	ArenaMaterials3D.part(holder, ArenaMaterials3D.box(Vector3(0.06, 0.05, length)), dark, Vector3(far_side * 1.0, 0.48, 0.0))


## Доски чуть светятся ночью: настил — дорога врагов и должен быть светлее двора (docs/37 SCN-3).
static func _deck_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = ArenaMaterials3D.solid(color, 0.82)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.1
	return material


## Точка уреза, ближе всего лежащая в направлении direction от середины пруда.
static func _shore_index(shore: PackedVector2Array, direction: Vector2) -> int:
	var best: int = 0
	for index: int in shore.size():
		if (shore[index] - POND_CENTER).normalized().dot(direction) > (shore[best] - POND_CENTER).normalized().dot(direction):
			best = index
	return best


## Мостки для рыбалки: три доски на четырёх сваях с берега в воду, рядом долблёнка и ведро.
func _build_fishing_pier(at: Vector2, out: Vector2) -> void:
	var holder: Node3D = Node3D.new()
	holder.name = "FishingPier"
	var start: Vector2 = at + out * 0.9
	holder.position = Vector3(start.x, DECK_Y - 0.02, start.y)
	holder.rotation.y = atan2(-out.x, -out.y)
	_yard.add_child(holder)
	var wood: StandardMaterial3D = _deck_material(DECK_WOOD.darkened(0.05))
	var dark: StandardMaterial3D = ArenaMaterials3D.solid(DECK_WOOD.darkened(0.45))
	for board: int in 3:
		ArenaMaterials3D.part(holder, ArenaMaterials3D.box(Vector3(0.38, 0.05, 3.0)), wood,
				Vector3((board - 1) * 0.41, 0.0, 1.5), Vector3(0.0, (board - 1) * 0.015, 0.0))
	for corner: Vector2 in [Vector2(-0.55, 0.4), Vector2(0.55, 0.4), Vector2(-0.55, 2.8), Vector2(0.55, 2.8)]:
		ArenaMaterials3D.part(holder, ArenaMaterials3D.cylinder(0.08, 0.07, 0.8, 6), dark, Vector3(corner.x, -0.3, corner.y))
	# Долблёнка у мостков и ведро на досках.
	var boat: MeshInstance3D = ArenaMaterials3D.part(holder, ArenaMaterials3D.cylinder(0.32, 0.32, 2.6, 10),
			ArenaMaterials3D.solid(DECK_WOOD.darkened(0.3)), Vector3(1.05, -0.12, 1.9), Vector3(PI * 0.5, 0.0, 0.0),
			Vector3(1.0, 1.0, 0.55))
	boat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ArenaMaterials3D.part(holder, ArenaMaterials3D.cylinder(0.14, 0.11, 0.26, 8), dark, Vector3(-0.3, 0.16, 0.7))


## Плетень 0,55 м кусками вдоль края мостовой (не кольцом), с разрывами у кладок и мостков.
func _build_wattle(gaps: Array[Vector2], rng: RandomNumberGenerator) -> void:
	var line: PackedVector2Array = pond_contour(POND_SHORE * 0.8, 0.45)
	var wood: StandardMaterial3D = ArenaMaterials3D.solid(Color(0.36, 0.27, 0.18), 0.95)
	var count: int = line.size()
	for start: int in range(0, count, 24):
		for index: int in range(start, start + 11):
			var a: Vector2 = line[index % count]
			var b: Vector2 = line[(index + 1) % count]
			var middle: Vector2 = (a + b) * 0.5
			var blocked: bool = false
			for gap: Vector2 in gaps:
				blocked = blocked or middle.distance_to(gap) < 2.2
			if blocked:
				continue
			var along: Vector2 = b - a
			var yaw: float = atan2(along.x, along.y)
			ArenaMaterials3D.part(_yard, ArenaMaterials3D.cylinder(0.03, 0.025, 0.62, 5), wood,
					Vector3(a.x, 0.29, a.y), Vector3(rng.randf_range(-0.05, 0.05), 0.0, rng.randf_range(-0.05, 0.05)))
			for rod: int in 3:
				ArenaMaterials3D.part(_yard, ArenaMaterials3D.box(Vector3(0.035, 0.05, along.length() + 0.06)), wood,
						Vector3(middle.x, 0.14 + rod * 0.15, middle.y), Vector3(0.0, yaw, 0.0))


## Осока куртинами у воды (не выше 0,6 м; у северной дороги — только у самой воды) и валуны.
func _build_reeds(shore: PackedVector2Array, normals: PackedVector2Array, pier: int, rng: RandomNumberGenerator) -> void:
	var plants: Dictionary[String, Array] = {}
	var count: int = shore.size()
	for index: int in range(0, count, 3):
		if absi(index - pier) < 5 or absi(index - pier) > count - 5:
			continue
		if rng.randf() < 0.35:
			continue
		var north: bool = normals[index].y < -0.6
		var reach: float = rng.randf_range(0.05, 0.25) if north else rng.randf_range(0.1, 0.65)
		var at: Vector2 = shore[index] + normals[index] * reach
		super._collect(plants, "sedge" if rng.randf() < 0.7 else "seed_grass", at, rng.randf_range(0.42, 0.6))
	_build_collected(plants, _yard)
	for stone: int in 5:
		var index: int = (stone * 19 + 7) % count
		var at: Vector2 = shore[index] + normals[index] * rng.randf_range(0.15, 0.5)
		_place("rock_flat" if stone % 2 == 0 else "rock_boulder", Vector3(at.x, -0.05, at.y), rng.randf() * TAU,
				rng.randf_range(0.35, 0.55))


## UV.y воды пруда — расстояние до берега (0 на урезе, 0,5 глубже 1,1 м): мель по всему контуру.
static func _pond_vertex(tool: SurfaceTool, at: Vector2, depth: float) -> void:
	tool.set_normal(Vector3.UP)
	tool.set_uv(Vector2(0.0, minf(depth / 2.2, 0.5)))
	tool.add_vertex(Vector3(at.x, POND_WATER_Y, at.y))


## Берег пруда — профиль берега ручья: подводная ступень, урез чуть выше воды, гребень на уровне
## мостовой, дальше откос уходит под плитку. Гравий у воды, земля выше (тот же шейдер).
func _build_pond_banks(shore: PackedVector2Array, normals: PackedVector2Array) -> void:
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = shore.size()
	for index: int in count:
		var bar: float = smoothstep(0.05, 0.92, 0.5 + 0.5 * sin(index * 0.41 + 1.3))
		var ridge: float = -0.014 + 0.01 * sin(index * 0.77)
		for row: Vector3 in [Vector3(-0.7, -0.27, 0.0), Vector3(0.05 + bar * 0.12, POND_WATER_Y + 0.02, 0.22),
				Vector3(0.3 + bar * 0.4, ridge, 0.61), Vector3(1.1 + bar * 0.4, -0.05, 1.0)]:
			var at: Vector2 = shore[index] + normals[index] * row.x
			tool.set_uv(Vector2(float(index), row.z))
			tool.add_vertex(Vector3(at.x, row.y, at.y))
	for index: int in count:
		var next: int = (index + 1) % count
		for row: int in 3:
			var a: int = index * 4 + row
			var b: int = next * 4 + row
			for vertex: int in [a, a + 1, b, a + 1, b + 1, b]:
				tool.add_index(vertex)
	tool.generate_normals()
	var banks: MeshInstance3D = MeshInstance3D.new()
	banks.name = "PondBanks"
	banks.mesh = tool.commit()
	banks.material_override = _bank_material()
	_yard.add_child(banks)


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

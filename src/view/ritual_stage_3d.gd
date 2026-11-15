class_name RitualStage3D
extends ArenaStage3D
## Адаптер RitualField к актуальному PvP-рендеру. Состояние боя не меняет.

const UNIT_IDS: Dictionary[StringName, StringName] = {
	&"ratnik": &"basic", &"runner": &"fast", &"heavy": &"armored",
	&"warded": &"knight", &"banner": &"courier", &"voevoda": &"boss",
	# Нежить бесконечного забега — пока на моделях прежних врагов (автор заменит сам).
	&"mertvyak": &"basic", &"upyr": &"fast", &"kostyak": &"armored", &"navi_shield": &"knight",
	&"navi_banner": &"courier", &"koshchei_voevoda": &"boss", &"latnik": &"armored", &"volkodlak": &"fast"}
var _hero: Node3D
var _hero_model: String = "res://assets/noir_h3d/heroes/ilya.glb"
var _barrier: Node3D
var _barrier_progress: int = -1
var _barrier_lane: int = 0
## Дорога каждого входа: 0 — главная (она же layout), N — улица N.
var _lanes: Array[ArenaLayout3D] = []
## Края кадра по высоте двора (z мира): запас к открытым клеткам, как у прежнего кадра.
const FRAME_FAR_PAD: float = 1.0
const FRAME_NEAR_PAD: float = 2.0
## Камера: двор длинной стороной вдоль экрана — так он крупнее, чем по диагонали, как в PvP
## (поворот PvP с поправкой на лес был бы 0,65 — двор «ромбом» и на четверть мельче).
## Наклон круче PvP: при пологом взгляде мокрые лужи мостовой бликуют белым.
const CAMERA_PITCH_RITUAL: float = -0.85
const CAMERA_YAW_RITUAL: float = 0.3
## Наклон на 21:9 и при каком соотношении сторон места под карту он включается (плавно).
const CAMERA_PITCH_WIDE: float = -0.6
## Сколько логических пикселей кадр заходит под шапку на альбомном экране.
const HEADER_UNDER: float = 64.0
const WIDE_FROM: float = 1.9
const WIDE_TO: float = 2.9
const PORTRAIT_TURN: float = -PI * 0.5
## Враги забега мельче домов (решение автора 15 ноября: враг ~0,7 высоты дома тира I, дома x2).
## Читаемость держит плотная доска 17x14: камера ближе, чем на прежней 20x18.
const MOB_SCALE: float = 0.75
## Сторожка: центр на столько метров до конца главной дороги; герой — перед её проёмом и чуть к камере.
const GATEHOUSE_BACK: float = 2.2
const HERO_BEFORE_GATE: float = 0.65
const HERO_OFF_AXIS: float = 0.45
## Солнце, закат, ночь и тени облаков (ночь — свет PvP-двора).
var _daylight: RitualDaylight
var _catalogue_profile: bool = false
var _profile_ready: bool = false
## Идолы на площади (docs/37 §8) — только в забеге с участками; -1 — нет подсветки/выбора.
var _idols: RitualIdols3D
var idol_hovered: int = -1
var idol_selected: int = -1
## Сторожка и ворота входов (docs/37 SCN-7).
var _gates: RitualGates3D
## Завалы проулков (docs/37 ALY-1): узел на входе в проулок, пока он завален.
var _barricades: Array[Node3D] = []
## Подход нежити из леса (critique_2 п. 11-12, docs/37 SCN-8). По расписанию ночи (только чтение)
## вид ведёт «фантома» врага по лесной тропе так, чтобы в тик выхода он стоял в начале дороги, —
## там его сменяет настоящий враг. Логика, попадания и расписание не меняются.
## Враг без фантома (проулок выбран в момент выхода) проявляется за APPEAR_SECONDS.
const APPEAR_SECONDS: float = 0.45
## Последние метры тропы фантом проявляется из тумана.
const PHANTOM_FADE_M: float = 3.0
var _phantoms: Dictionary[String, ArenaUnit3D] = {}
var _phantom_spots: Dictionary[String, Vector3] = {}
## Путь подхода каждого входа: от конца тропы к началу дороги (мир) и длины вдоль него.
var _approach: Array[PackedVector3Array] = []
var _approach_lengths: Array[PackedFloat32Array] = []
## Сколько фантомов дошли до ворот входа в этом кадре — их сменят новые враги без проявления.
var _arrived: Dictionary[int, int] = {}
## Проявление врага у ворот: x — прошло секунд, y — полная непрозрачность (скрытный — полупрозрачен).
var _appear: Dictionary[int, Vector2] = {}
## Холодный контур врагов и фантомов ночью (critique_3 п. 34, VIS-3): один материал на всех,
## сила — по фазе суток. Только видимость: облик нежити ждёт моделей автора.
const ENEMY_RIM_SHADER: Shader = preload("res://assets/shaders/ritual_enemy_rim.gdshader")
const ENEMY_RIM_NIGHT: float = 0.85
const PAUSE_GRAY: float = 0.3
const RANGE_RING_SHADER: Shader = preload("res://assets/shaders/ritual_range_ring.gdshader")
const SELECTED_OUTLINE: Color = Color("ffe4a5")
var _ghost: Node3D
var _range_ring: MeshInstance3D
var _ghost_key: String = ""
var _pause_gray: float = 0.0
var _enemy_rim: ShaderMaterial


func _init() -> void:
	super()
	var post: ShaderMaterial = material as ShaderMaterial
	post.set_shader_parameter(&"clarity", RenderQuality.sharpen_amount())
	post.set_shader_parameter(&"clarity_radius", RenderQuality.SHARPEN_RADIUS)
	# Лес PvP повёрнут на −90° вокруг двора (ritual_arena_3d.gd) — луна вместе с ним.
	_camera.rotation = Vector3(CAMERA_PITCH_RITUAL, CAMERA_YAW_RITUAL, 0.0)
	for light_name: String in ["Moon", "WarmKey"]:
		var light: Node3D = _world.get_node(light_name) as Node3D
		light.basis = Basis(Vector3.UP, -PI * 0.5) * light.basis
	var arena: Node = _world.get_node("Arena")
	arena.set_script(preload("res://src/view/ritual_arena_3d.gd"))
	# Ресурс окружения принадлежит только этому экземпляру режима.
	var environment: WorldEnvironment = _world.get_node("Environment") as WorldEnvironment
	environment.environment = environment.environment.duplicate(true) as Environment
	environment.camera_attributes = environment.camera_attributes.duplicate(true) as CameraAttributes
	var clouds: CloudShadows3D = CloudShadows3D.new()
	clouds.name = "CloudShadows"
	clouds.center = Vector3(24.0, 0.0, -5.0)  # середина двора
	_world.add_child(clouds)
	_daylight = RitualDaylight.new(_world, clouds)
	_idols = RitualIdols3D.new(STYLE)
	_idols.visible = false
	_world.add_child(_idols)


func _exit_tree() -> void:
	RitualDaylight.reset_globals()


func show_field(field: FieldState, player_colors: Callable) -> void:
	if layout == null:
		var ritual: RitualField = field as RitualField
		for lane: int in ritual.lane_count():
			_lanes.append(RitualLayout3D.new(ritual.route(lane)))
		layout = _lanes[0]
		# Лес и трава обходят двор по настоящим клеткам — и будущие кварталы тоже: лес сажается
		# один раз (_build_platforms → build_for_layout), а улицу можно пристроить в любой момент.
		# Поэтому клетки записываются до _build_platforms: иначе луг садился на будущие улицы.
		var arena: RitualArena3D = _world.get_node("Arena") as RitualArena3D
		arena.lane_layouts = _lanes
		for street: int in range(1, ritual.settings.streets.size() + 1):
			var alley: Array[Vector2i] = ritual.alley_path(street)
			arena.alley_layouts.append(RitualLayout3D.new(alley) if not alley.is_empty() else null)
			for cell: Vector2i in alley:
				arena.yard_cells[cell] = true
		for cell: Vector2i in field.get_buildable_cells() + field.layout.path_cells:
			arena.yard_cells[cell] = true
		for region: Rect2i in ritual.settings.build_regions:
			for y: int in range(region.position.y, region.end.y):
				for x: int in range(region.position.x, region.end.x):
					arena.yard_cells[Vector2i(x, y)] = true
		for street: RitualStreetData in ritual.settings.streets:
			for cell: Vector2i in street.path_cells:
				arena.yard_cells[cell] = true
			for region: Rect2i in street.build_regions:
				for y: int in range(region.position.y, region.end.y):
					for x: int in range(region.position.x, region.end.x):
						arena.yard_cells[Vector2i(x, y)] = true
		# Проулки-срезки (docs/37 ALY-1): дорога рисуется, когда город дорос до проулка.
		for index: int in ritual.settings.alleys.size():
			var cells: Array[Vector2i] = ritual.alley_cells_with_ends(index)
			arena.shortcut_layouts.append(RitualLayout3D.new(cells))
			arena.shortcut_levels.append(ritual.settings.alleys[index].city_level)
			for cell: Vector2i in cells:
				arena.yard_cells[cell] = true
		_build_platforms()
	super.show_field(field, player_colors)
	if _hero == null:
		_spawn_hero()
	if _gates == null and (field as RitualField).settings.is_endless():
		_build_gates(field as RitualField)


func _tower_node(tower: TowerState) -> ArenaTower3D:
	if tower is RitualTower:
		return RitualTownHouse.new()
	return super(tower)


func _build_tower(tower: TowerState) -> ArenaTower3D:
	var node: ArenaTower3D = super(tower)
	if node is RitualTownHouse:
		(node as RitualTownHouse).face(_house_front(tower.anchor))
	if node is RitualTownHouse and tower.data.wind_length_milli > 0:
		(node as RitualTownHouse).aim_wind((_field as RitualField).wind_direction(tower))
	return node


## Куда смотрит фасад дома: к дороге южнее участка, иначе к дороге сбоку (любой, даже ещё закрытой).
func _house_front(cell: Vector2i) -> Vector2i:
	var field: RitualField = _field as RitualField
	var roads: Dictionary[Vector2i, bool] = {}
	for lane: int in field.lane_count():
		for road: Vector2i in field.route(lane):
			roads[road] = true
	for side: Vector2i in [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if roads.has(cell + side):
			return side
	return Vector2i.DOWN


func _sync_fog() -> void:
	var previous: int = _fog_key
	super()
	if previous != _fog_key:
		var field: RitualField = _field as RitualField
		for tower: TowerState in field.towers:
			var house: RitualTownHouse = _towers[tower.id] as RitualTownHouse if _towers.has(tower.id) else null
			if house != null and tower.data.wind_length_milli > 0:
				house.aim_wind(field.wind_direction(tower))


func house_cell_at(point: Vector2) -> Vector2i:
	var ray: Vector3 = _camera.project_ray_normal(point * _pixel_scale())
	var origin: Vector3 = _camera.project_ray_origin(point * _pixel_scale())
	var nearest: float = INF
	var picked_id: int = -1
	for id: int in _towers:
		var house: RitualTownHouse = _towers[id] as RitualTownHouse
		if house != null:
			var distance: float = house.pick_distance(origin, ray)
			if distance < nearest:
				nearest = distance
				picked_id = id
	return _field.get_tower(picked_id).anchor if picked_id >= 0 else cell_at(point)


func house_label(id: int) -> Vector2:
	var house: RitualTownHouse = _towers[id] as RitualTownHouse if _towers.has(id) else null
	return project(house.label_position()) if house != null else tower_top(id)


func _build_gates(ritual: RitualField) -> void:
	_gates = RitualGates3D.new()
	_gates.name = "RitualGates"
	_world.add_child(_gates)
	var end: float = layout.road_end_length()
	_gates.build_gatehouse(layout.road_point(end - GATEHOUSE_BACK), layout.road_direction(end - GATEHOUSE_BACK))
	var points: Array[Vector3] = [layout.road_point(0.4)]
	var outwards: Array[Vector3] = [-layout.road_direction(0.0)]
	for street: int in ritual.settings.streets.size():
		if not ritual.settings.streets[street].path_cells.is_empty():
			points.append(_lanes[street + 1].road_point(0.4))
			outwards.append(-_lanes[street + 1].road_direction(0.0))
	_gates.set_gates(points, outwards)


## Герой забега в сторожке — конец главной улицы, у крыльца терема, чуть в стороне от колеи.
func _spawn_hero() -> void:
	if _hero != null:
		_hero.queue_free()
	var scene: PackedScene = load(_hero_model) as PackedScene
	_hero = scene.instantiate() as Node3D
	_world.add_child(_hero)
	ArenaTower3D._tune_materials(_hero, STYLE.noir_model_glow, STYLE.noir_model_tone, STYLE.noir_model_rim)
	# Перед западным проёмом сторожки (critique_4 п. 10, 54): вне тени крыши — виден целиком с игровой
	# камеры; чуть к камере от оси, враги идут мимо, а не сквозь героя.
	var end: float = layout.road_end_length()
	var spot: float = end - GATEHOUSE_BACK - RitualGates3D.GATE_HALF_DEPTH - HERO_BEFORE_GATE
	var along: Vector3 = layout.road_direction(spot)
	_hero.position = layout.road_point(spot) + Vector3(along.z, 0.0, -along.x) * -HERO_OFF_AXIS
	_hero.rotation.y = PI * 0.5


func _sync_units(delta: float, interpolation: float) -> void:
	# Создаём модели по существующим PvP-ID, не подменяя данные мобов в sim.
	for mob: MobState in _field.mobs:
		if not _units.has(mob.id):
			var unit: ArenaUnit3D = _make_unit(mob.data)
			_units[mob.id] = unit
			# Пришёл фантом по тропе — враг сразу на месте; иначе проявляется у ворот.
			var lane: int = RitualField.lane_of(mob)
			if _arrived.get(lane, 0) > 0:
				_arrived[lane] -= 1
			else:
				var full: float = STYLE.stealth_alpha if mob.data.reveal_radius_milli > 0 else 1.0
				_appear[mob.id] = Vector2(0.0, full)
				unit.set_ghost(0.0)
	super._sync_units(delta, interpolation)
	_arrived.clear()
	for mob_id: int in _appear.keys():
		var unit: ArenaUnit3D = _units.get(mob_id)
		if unit == null:
			_appear.erase(mob_id)
			continue
		var state: Vector2 = _appear[mob_id] + Vector2(delta, 0.0)
		_appear[mob_id] = state
		var shown: float = clampf(state.x / APPEAR_SECONDS, 0.0, 1.0)
		unit.set_ghost(state.y * shown)
		if shown >= 1.0:
			_appear.erase(mob_id)


## Модель врага забега (и фантома подхода): PvP-модель по id, меньше домов (MOB_SCALE).
func _make_unit(data: MobData) -> ArenaUnit3D:
	var id: StringName = UNIT_IDS.get(data.id, &"basic")
	var unit: ArenaUnit3D = ArenaUnit3D.new()
	_world.add_child(unit)
	unit.build(STYLE.get_mob_model(id), STYLE.get_mob_tint(id), STYLE.get_mob_height(id) * MOB_SCALE,
		Color.TRANSPARENT, id)
	if _enemy_rim == null:
		_enemy_rim = ShaderMaterial.new()
		_enemy_rim.shader = ENEMY_RIM_SHADER
	for node: Node in unit.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_overlay = _enemy_rim
	if data.tags.has(&"banner"):
		ArenaMaterials3D.part(unit, ArenaMaterials3D.cylinder(0.025, 0.025, 1.6, 5),
			ArenaMaterials3D.solid(ArenaMaterials3D.WOOD), Vector3(0.3, 0.8, 0))
		ArenaMaterials3D.part(unit, ArenaMaterials3D.box(Vector3(0.5, 0.4, 0.03)),
			ArenaMaterials3D.glow(Color("9a71bd"), 0.7), Vector3(0.55, 1.35, 0))
	return unit


## Фантомы подхода: враги ближайших пачек, которым до выхода осталось меньше, чем идти по тропе.
func _sync_phantoms(trial: RitualTrial, delta: float) -> void:
	var arena: RitualArena3D = _world.get_node("Arena") as RitualArena3D
	if not trial.settings.is_endless() or trial.phase != RitualTrial.Phase.RUNNING or arena.trails.is_empty():
		_clear_phantoms()
		return
	if _approach.size() != arena.trails.size():
		_build_approach(arena)
	var meters_per_milli: float = layout.progress_to_length(1000.0) / 1000.0 - layout.progress_to_length(0.0) / 1000.0
	var tick: int = trial.tick_count
	var night: int = trial.settings.nights.night_index_at(tick)
	var open: int = 1 + trial.field.open_streets
	var wanted: Dictionary[String, bool] = {}
	for index: int in [night, night + 1]:
		if index < 1:
			continue
		for pack: RitualPack in trial.plan().packs(index):
			for slot: int in pack.members.size():
				var due: int = pack.at_tick + slot * pack.spacing
				var lane: int = trial.member_route(pack, slot)
				if lane < 0 or lane >= mini(open, _approach.size()):
					continue
				var key: String = "%d:%d:%d" % [pack.at_tick, lane, slot]
				if due <= tick:
					if _phantoms.has(key):
						_arrived[lane] = _arrived.get(lane, 0) + 1
					continue
				var data: MobData = trial.settings.enemies[pack.members[slot]]
				var left: float = (due - tick) * data.speed_milli_per_tick * meters_per_milli
				var lengths: PackedFloat32Array = _approach_lengths[lane]
				var total: float = lengths[lengths.size() - 1]
				if left >= total:
					continue
				wanted[key] = true
				var unit: ArenaUnit3D = _phantoms.get(key)
				if unit == null:
					unit = _make_unit(data)
					_phantoms[key] = unit
				var walked: float = total - left
				var point: Vector3 = _approach_point(lane, walked)
				var previous: Vector3 = _phantom_spots.get(key, point)
				var moved: Vector3 = point - previous
				_phantom_spots[key] = point
				unit.position = point
				if moved.length() > 0.002:
					unit.rotation.y = atan2(moved.x, moved.z)
				unit.animate(delta, moved.length() / maxf(delta, 0.001), STYLE.steps_per_meter)
				unit.set_ghost(clampf(walked / PHANTOM_FADE_M, 0.0, 1.0))
	for key: String in _phantoms.keys():
		if not wanted.has(key):
			_phantoms[key].queue_free()
			_phantoms.erase(key)
			_phantom_spots.erase(key)


func _clear_phantoms() -> void:
	for unit: ArenaUnit3D in _phantoms.values():
		unit.queue_free()
	_phantoms.clear()
	_phantom_spots.clear()


## Путь подхода входа: тропа от её конца к воротам и дальше до начала дороги (прогресс 0).
func _build_approach(arena: RitualArena3D) -> void:
	_approach.clear()
	_approach_lengths.clear()
	for lane: int in arena.trails.size():
		var trail: PackedVector2Array = arena.trails[lane]
		var points: PackedVector3Array = PackedVector3Array()
		for index: int in range(trail.size() - 1, -1, -1):
			points.append(Vector3(trail[index].x, 0.0, trail[index].y))
		var road: ArenaLayout3D = _lane_layout(lane)
		points.append(road.road_point(road.progress_to_length(0.0)))
		var lengths: PackedFloat32Array = PackedFloat32Array([0.0])
		for index: int in range(1, points.size()):
			lengths.append(lengths[index - 1] + points[index].distance_to(points[index - 1]))
		_approach.append(points)
		_approach_lengths.append(lengths)


func _approach_point(lane: int, walked: float) -> Vector3:
	var points: PackedVector3Array = _approach[lane]
	var lengths: PackedFloat32Array = _approach_lengths[lane]
	for index: int in range(1, points.size()):
		if lengths[index] >= walked:
			var span: float = maxf(0.0001, lengths[index] - lengths[index - 1])
			return points[index - 1].lerp(points[index], (walked - lengths[index - 1]) / span)
	return points[points.size() - 1]


## Враг идёт по дороге своего входа.
func _mob_world(mob: MobState, interpolation: float) -> Vector3:
	var lane: int = RitualField.lane_of(mob)
	if lane <= 0 or lane >= _lanes.size():
		return super._mob_world(mob, interpolation)
	var main: ArenaLayout3D = layout
	layout = _lanes[lane]
	var point: Vector3 = super._mob_world(mob, interpolation)
	layout = main
	return point


func _lane_layout(lane: int) -> ArenaLayout3D:
	return _lanes[lane] if lane >= 0 and lane < _lanes.size() else layout


func mob_head(mob: MobState, interpolation: float) -> Vector2:
	var id: StringName = UNIT_IDS.get(mob.data.id, &"basic")
	return project(_mob_world(mob, interpolation) + Vector3.UP * (STYLE.get_mob_height(id) * MOB_SCALE * 1.15 + 0.2))


func update_ritual(trial: RitualTrial, delta: float) -> void:
	var catalogue: bool = trial.settings.uses_plots()
	if not _profile_ready or catalogue != _catalogue_profile:
		_profile_ready = true
		_catalogue_profile = catalogue
		RenderQuality.setup_viewport(_viewport, catalogue)
		(material as ShaderMaterial).set_shader_parameter(&"clarity", RenderQuality.sharpen_amount(catalogue))
	var model: String = trial.hero().model if trial.hero() != null and not trial.hero().model.is_empty() \
			else "res://assets/noir_h3d/heroes/ilya.glb"
	if model != _hero_model:
		_hero_model = model
		if _hero != null:
			_spawn_hero()
	_daylight.camera_distance = _camera.position.distance_to((_frame_min + _frame_max) * 0.5)
	_daylight.apply(trial)
	if _enemy_rim != null:
		_enemy_rim.set_shader_parameter(&"strength", RitualDaylight.sun_phase(trial).y * ENEMY_RIM_NIGHT)
	_sync_phantoms(trial, delta)
	if _gates != null:
		var night: int = trial.current_night()
		var open: Array[bool] = [true]
		for street: int in trial.settings.streets.size():
			if not trial.settings.streets[street].path_cells.is_empty():
				open.append(street < trial.street_nights.size() and trial.street_nights[street] <= night)
		_gates.sync(trial, open, delta)
	_idols.visible = catalogue
	if catalogue:
		_idols.sync(trial.field.idols, idol_hovered, idol_selected)
		_sync_barricades(trial)
	if trial.palisade_progress != _barrier_progress or trial.palisade_lane != _barrier_lane:
		_barrier_progress = trial.palisade_progress
		_barrier_lane = trial.palisade_lane
		if _barrier != null:
			_barrier.queue_free()
			_barrier = null
		if _barrier_progress >= 0:
			_barrier = Node3D.new()
			_world.add_child(_barrier)
			var road: ArenaLayout3D = _lane_layout(_barrier_lane)
			var length: float = road.progress_to_length(_barrier_progress)
			_barrier.position = road.road_point(length)
			var direction: Vector3 = road.road_direction(length)
			_barrier.rotation.y = atan2(direction.x, direction.z)
			for index: int in 5:
				ArenaMaterials3D.part(_barrier, ArenaMaterials3D.cylinder(0.10, 0.02, 1.2, 5),
					ArenaMaterials3D.solid(ArenaMaterials3D.WOOD), Vector3((index - 2) * 0.36, 0.6, 0))
	if _barrier != null:
		_barrier.scale.y = 1.0 if trial.tick_count >= trial.palisade_ready else 0.4
	sync(delta, 1.0)


func _sync_barricades(trial: RitualTrial) -> void:
	var ritual: RitualField = trial.field
	while _barricades.size() < trial.barricades.size():
		_barricades.append(null)
	for index: int in trial.barricades.size():
		var closed: bool = trial.barricades[index]
		if closed == (_barricades[index] != null):
			continue
		if not closed:
			_barricades[index].queue_free()
			_barricades[index] = null
			continue
		var cells: Array[Vector2i] = ritual.alley_cells_with_ends(index)
		var road: ArenaLayout3D = RitualLayout3D.new(cells)
		var along: float = road.path_length_at(1) * 0.75
		var node: Node3D = Node3D.new()
		node.position = road.road_point(along)
		var direction: Vector3 = road.road_direction(along)
		node.rotation.y = atan2(direction.x, direction.z)
		for post: int in 5:
			ArenaMaterials3D.part(node, ArenaMaterials3D.cylinder(0.11, 0.03, 1.0, 5),
				ArenaMaterials3D.solid(ArenaMaterials3D.WOOD), Vector3((post - 2) * 0.34, 0.5, 0))
		ArenaMaterials3D.part(node, ArenaMaterials3D.box(Vector3(1.8, 0.12, 0.14)),
			ArenaMaterials3D.solid(ArenaMaterials3D.WOOD), Vector3(0, 0.55, 0.08), Vector3(0, 0, 0.35))
		_world.add_child(node)
		_barricades[index] = node


## Идол под точкой экрана (-1 — нет): круг вокруг середины фигуры.
func idol_at(point: Vector2) -> int:
	if not _idols.visible:
		return -1
	for index: int in _idols.shown():
		var center: Vector2 = project(RitualIdols3D.spot_at(index) + Vector3(0, 1.1, 0))
		var top: Vector2 = project(RitualIdols3D.spot_at(index) + Vector3(0, 2.6, 0))
		if point.distance_to(center) < maxf(18.0, center.distance_to(top) * 0.95):
			return index
	return -1


## Подножие идола на экране — сюда крепится окно идола.
func idol_screen(index: int, lift: float = 0.0) -> Vector2:
	return project(RitualIdols3D.spot_at(index) + Vector3(0, lift, 0))


func _update_frame_bounds() -> void:
	# Весь маршрут и терем; исходные PvP-отступы рассчитаны на другой конец пути.
	# Пристроили улицу — двор вырос по высоте, камера отъезжает.
	var far: float = -17.0
	var near: float = 8.0
	var left: float = 1.0
	var ritual: RitualField = _field as RitualField
	if ritual != null and layout != null:
		far = INF
		near = -INF
		left = INF
		for cell: Vector2i in ritual.get_buildable_cells() + ritual.open_road_cells():
			var corner: Vector2 = layout.corner_xz(Vector2(cell) * MILLI)
			far = minf(far, corner.y - FRAME_FAR_PAD)
			near = maxf(near, corner.y + layout.cell_m + FRAME_NEAR_PAD)
			left = minf(left, corner.x - FRAME_FAR_PAD)
	_frame_min = Vector3(left, 0.0, far)
	_frame_max = Vector3(49, 4.0, near)
	_frame_key = _open_key()


func _open_key() -> int:
	var ritual: RitualField = _field as RitualField
	return super._open_key() + (ritual.open_streets * 100000 if ritual != null else 0)


func _frame_perspective(target: Rect2, basis: Basis) -> void:
	# Широкий экран (critique_3 п. 2): камера положе — город вписывается по ширине, а не по высоте.
	# Портрет (п. 3): поворот на четверть круга — длинная сторона города вдоль экрана.
	var aspect: float = target.size.x / maxf(1.0, target.size.y)
	var pitch: float = lerpf(CAMERA_PITCH_RITUAL, CAMERA_PITCH_WIDE, smoothstep(WIDE_FROM, WIDE_TO, aspect))
	var yaw: float = CAMERA_YAW_RITUAL + (PORTRAIT_TURN if aspect < 0.9 else 0.0)
	if not is_equal_approx(_camera.rotation.x, pitch) or not is_equal_approx(_camera.rotation.y, yaw):
		_camera.rotation = Vector3(pitch, yaw, 0.0)
		basis = _camera.transform.basis
	# На альбомных экранах кадр заходит под шапку (она теперь островками по краям, critique_3 п. 43):
	# город крупнее по ширине (п. 2, SCN-1 0,65-0,75).
	if aspect > 1.5:
		# На 21:9 под шапку не заходим: там положе камера, а северные ворота ушли бы под разведку.
		var lift: float = HEADER_UNDER * smoothstep(1.5, 2.0, aspect) * (1.0 - smoothstep(2.4, 2.9, aspect))
		target = Rect2(target.position - Vector2(0.0, lift), target.size + Vector2(0.0, lift))
	# Кадр занимает выделенное место полностью, без прежнего запаса под PvP-шапку.
	var adjusted: Rect2 = Rect2(target.position - Vector2(0, target.size.y * SKY_SHARE / (1.0 - SKY_SHARE)),
		Vector2(target.size.x, target.size.y / (1.0 - SKY_SHARE)))
	super._frame_perspective(adjusted, basis)


## Пауза: картинка сцены обесцвечена на 30% (critique_3 п. 11); яркость не меняется.
func set_pause_look(paused: bool) -> void:
	var post: ShaderMaterial = material as ShaderMaterial
	var gray: float = PAUSE_GRAY if paused else 0.0
	if post != null and not is_equal_approx(_pause_gray, gray):
		_pause_gray = gray
		post.set_shader_parameter(&"pause_gray", gray)


## Контуры домов по их сетке (critique_3 п. 63): id дома → цвет; остальные без контура.
func set_house_outlines(marks: Dictionary[int, Color]) -> void:
	for id: int in _towers:
		var house: RitualTownHouse = _towers[id] as RitualTownHouse
		if house == null:
			continue
		var color: Color = marks.get(id, Color.TRANSPARENT)
		# Толщина в единицах модели (дом x2): 0,14 и 0,1 м в мире — 3-4 px с игровой камеры.
		house.set_outline(color, 0.07 if color == SELECTED_OUTLINE else 0.05)


## Износ видно домом (п. 64): копоть и пробоины, у молчащего — сильнее.
func sync_house_wear(field: RitualField, settings: RitualTrialConfig) -> void:
	for tower: TowerState in field.towers:
		var house: RitualTownHouse = _towers[tower.id] as RitualTownHouse if _towers.has(tower.id) else null
		if house == null or tower.durability < 0:
			continue
		var full: int = settings.max_durability(tower.level)
		var amount: float = 1.0 if tower.durability == 0 else (0.55 if tower.durability * 2 <= full else 0.0)
		house.set_wear(amount)


## Призрак дома и круг дальности на участке под курсором (п. 66); data == null — убрать.
func show_ghost(data: TowerData, cell: Vector2i, valid: bool, reach_milli: int) -> void:
	var key: String = "%s:%s:%s:%d" % [data.id if data != null else &"", cell, valid, reach_milli]
	if key == _ghost_key:
		return
	_ghost_key = key
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	if _range_ring != null:
		_range_ring.queue_free()
		_range_ring = null
	if data == null:
		return
	# Сюда нельзя — серый призрак и перечёркнутый круг на карте (critique_4 п. 27): красный был
	# неотличим от круга дальности «Жаровни Сварога». Круг дальности — только у допустимого места.
	var color: Color = GodSymbols.get_color(data.god)
	_ghost = Node3D.new()
	_ghost.name = "PlacementGhost"
	_world.add_child(_ghost)
	_ghost.position = _tower_position([cell])
	var model: Node3D = RitualTownHouse.ghost(data, color.lightened(0.25), not valid)
	model.rotation.y = atan2(float(_house_front(cell).x), float(_house_front(cell).y))
	_ghost.add_child(model)
	if reach_milli <= 0 or not valid:
		return
	var radius: float = float(reach_milli) / 1000.0 * layout.cell_m
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2.ONE * radius * 2.0
	var ring: ShaderMaterial = ShaderMaterial.new()
	ring.shader = RANGE_RING_SHADER
	ring.set_shader_parameter(&"color", color)
	ring.set_shader_parameter(&"fill", 0.02)
	_range_ring = MeshInstance3D.new()
	_range_ring.name = "RangeRing"
	_range_ring.mesh = plane
	_range_ring.material_override = ring
	_range_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_range_ring.position = _ghost.position + Vector3.UP * 0.12
	_world.add_child(_range_ring)

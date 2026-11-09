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
## Солнце, закат, ночь и тени облаков (ночь — свет PvP-двора).
var _daylight: RitualDaylight


func _init() -> void:
	super()
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


func _exit_tree() -> void:
	RitualDaylight.reset_globals()


func show_field(field: FieldState, player_colors: Callable) -> void:
	if layout == null:
		var ritual: RitualField = field as RitualField
		for lane: int in ritual.lane_count():
			_lanes.append(RitualLayout3D.new(ritual.route(lane)))
		layout = _lanes[0]
		_build_platforms()
		# Лес и трава обходят двор по настоящим клеткам (до постройки окружения) — и будущие
		# кварталы тоже: лес сажается один раз, а улицу можно пристроить в любой момент.
		var arena: RitualArena3D = _world.get_node("Arena") as RitualArena3D
		arena.lane_layouts = _lanes
		for street: int in range(1, ritual.settings.streets.size() + 1):
			var alley: Array[Vector2i] = ritual.alley_path(street)
			arena.alley_layouts.append(RitualLayout3D.new(alley) if not alley.is_empty() else null)
			for cell: Vector2i in alley:
				arena.yard_cells[cell] = true
		for cell: Vector2i in field.get_buildable_cells() + field.layout.path_cells:
			arena.yard_cells[cell] = true
		for street: RitualStreetData in ritual.settings.streets:
			for cell: Vector2i in street.path_cells:
				arena.yard_cells[cell] = true
			for region: Rect2i in street.build_regions:
				for y: int in range(region.position.y, region.end.y):
					for x: int in range(region.position.x, region.end.x):
						arena.yard_cells[Vector2i(x, y)] = true
	super.show_field(field, player_colors)
	if _hero == null:
		var scene: PackedScene = load("res://assets/noir_h3d/heroes/ilya.glb") as PackedScene
		_hero = scene.instantiate() as Node3D
		_world.add_child(_hero)
		ArenaTower3D._tune_materials(_hero, STYLE.noir_model_glow, STYLE.noir_model_tone, STYLE.noir_model_rim)
		# Сторожка — конец главной улицы, у крыльца терема; Илья чуть в стороне от колеи.
		_hero.position = layout.cell_center(field.layout.path_cells[-1]) + Vector3(0.2, 0, 1.1)
		_hero.rotation.y = PI * 0.5


func _sync_units(delta: float, interpolation: float) -> void:
	# Создаём модели по существующим PvP-ID, не подменяя данные мобов в sim.
	for mob: MobState in _field.mobs:
		if not _units.has(mob.id):
			var id: StringName = UNIT_IDS.get(mob.data.id, &"basic")
			var unit: ArenaUnit3D = ArenaUnit3D.new()
			_world.add_child(unit)
			unit.build(STYLE.get_mob_model(id), STYLE.get_mob_tint(id), STYLE.get_mob_height(id), Color.TRANSPARENT, id)
			if mob.data.tags.has(&"banner"):
				ArenaMaterials3D.part(unit, ArenaMaterials3D.cylinder(0.025, 0.025, 1.6, 5),
					ArenaMaterials3D.solid(ArenaMaterials3D.WOOD), Vector3(0.3, 0.8, 0))
				ArenaMaterials3D.part(unit, ArenaMaterials3D.box(Vector3(0.5, 0.4, 0.03)),
					ArenaMaterials3D.glow(Color("9a71bd"), 0.7), Vector3(0.55, 1.35, 0))
			_units[mob.id] = unit
	super._sync_units(delta, interpolation)


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
	return project(_mob_world(mob, interpolation) + Vector3.UP * (STYLE.get_mob_height(id) * 1.15 + 0.2))


func update_ritual(trial: RitualTrial, delta: float) -> void:
	_daylight.camera_distance = _camera.position.distance_to((_frame_min + _frame_max) * 0.5)
	_daylight.apply(trial)
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
	# Кадр занимает выделенное место полностью, без прежнего запаса под PvP-шапку.
	var adjusted: Rect2 = Rect2(target.position - Vector2(0, target.size.y * SKY_SHARE / (1.0 - SKY_SHARE)),
		Vector2(target.size.x, target.size.y / (1.0 - SKY_SHARE)))
	super._frame_perspective(adjusted, basis)

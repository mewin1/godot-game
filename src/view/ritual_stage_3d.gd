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
		layout = RitualLayout3D.new(field.layout)
		_build_platforms()
		# Лес и трава обходят двор по настоящим клеткам (до постройки окружения).
		var arena: RitualArena3D = _world.get_node("Arena") as RitualArena3D
		for cell: Vector2i in field.get_buildable_cells() + field.layout.path_cells:
			arena.yard_cells[cell] = true
	super.show_field(field, player_colors)
	if _hero == null:
		var scene: PackedScene = load("res://assets/noir_h3d/heroes/ilya.glb") as PackedScene
		_hero = scene.instantiate() as Node3D
		_world.add_child(_hero)
		ArenaTower3D._tune_materials(_hero, STYLE.noir_model_glow, STYLE.noir_model_tone, STYLE.noir_model_rim)
		_hero.position = layout.cell_center(Vector2i(18, 12)) + Vector3(0.2, 0, -0.7)
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


func mob_head(mob: MobState, interpolation: float) -> Vector2:
	var id: StringName = UNIT_IDS.get(mob.data.id, &"basic")
	return project(_mob_world(mob, interpolation) + Vector3.UP * (STYLE.get_mob_height(id) * 1.15 + 0.2))


func update_ritual(trial: RitualTrial, delta: float) -> void:
	_daylight.camera_distance = _camera.position.distance_to((_frame_min + _frame_max) * 0.5)
	_daylight.apply(trial)
	if trial.palisade_progress != _barrier_progress:
		_barrier_progress = trial.palisade_progress
		if _barrier != null:
			_barrier.queue_free()
			_barrier = null
		if _barrier_progress >= 0:
			_barrier = Node3D.new()
			_world.add_child(_barrier)
			var length: float = layout.progress_to_length(_barrier_progress)
			_barrier.position = layout.road_point(length)
			var direction: Vector3 = layout.road_direction(length)
			_barrier.rotation.y = atan2(direction.x, direction.z)
			for index: int in 5:
				ArenaMaterials3D.part(_barrier, ArenaMaterials3D.cylinder(0.10, 0.02, 1.2, 5),
					ArenaMaterials3D.solid(ArenaMaterials3D.WOOD), Vector3((index - 2) * 0.36, 0.6, 0))
	if _barrier != null:
		_barrier.scale.y = 1.0 if trial.tick_count >= trial.palisade_ready else 0.4
	sync(delta, 1.0)


func _update_frame_bounds() -> void:
	# Весь маршрут и терем; исходные PvP-отступы рассчитаны на другой конец пути.
	_frame_min = Vector3(1, 0.0, -17)
	_frame_max = Vector3(49, 4.0, 8)
	_frame_key = _open_key()


func _frame_perspective(target: Rect2, basis: Basis) -> void:
	# Кадр занимает выделенное место полностью, без прежнего запаса под PvP-шапку.
	var adjusted: Rect2 = Rect2(target.position - Vector2(0, target.size.y * SKY_SHARE / (1.0 - SKY_SHARE)),
		Vector2(target.size.x, target.size.y / (1.0 - SKY_SHARE)))
	super._frame_perspective(adjusted, basis)

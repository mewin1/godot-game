extends GutTest
## docs/37 P3: уровни города, входы с трёх сторон, проулок-срезка и баррикада.

var _settings: RitualTrialConfig
var _trial: RitualTrial


func before_each() -> void:
	_settings = load("res://data/ritual/endless.tres") as RitualTrialConfig
	_trial = RitualTrial.new(_settings, 0, 11)
	_trial.gold = 100000


func _grow(times: int) -> void:
	for index: int in times:
		assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.STREET)), "")


func _enemy(fast: bool) -> int:
	for index: int in _settings.enemies.size():
		var enemy: MobData = _settings.enemies[index]
		var quick: bool = enemy.speed_milli_per_tick >= _settings.alleys[0].fast_speed_milli
		if enemy.tags.is_empty() and quick == fast:
			return index
	return -1


func test_city_levels_open_plots_tiers_and_hero_hp() -> void:
	assert_eq(_trial.city_level(), 1)
	assert_eq(_trial.field.get_buildable_cells().size(), 10)
	var hp: int = _trial.max_hp()
	_grow(1)
	assert_eq(_trial.field.get_buildable_cells().size(), 16)
	_grow(1)
	assert_eq(_trial.field.get_buildable_cells().size(), 22)
	assert_eq(_trial.field.idols.size(), 3)
	_grow(1)
	assert_eq(_trial.city_level(), 4)
	assert_eq(_trial.field.get_buildable_cells().size(), 26)
	assert_eq(_trial.max_hp(), hp + 10, "Детинец прибавляет здоровья герою")
	assert_eq(_trial.field.idols.size(), 4, "Детинец ставит четвёртого идола")
	assert_false(_trial.can_grow())


## Входы с трёх сторон: запад (главная), север (верхний край поля), юг (нижний край).
func test_entrances_come_from_three_sides() -> void:
	var main: Array[Vector2i] = _trial.field.route(0)
	var north: Array[Vector2i] = _trial.field.route(1)
	var south: Array[Vector2i] = _trial.field.route(2)
	# Края считаются по городу 4-го уровня: доска шире города (площадь терема, лес).
	var top: int = 1000
	var left: int = 1000
	for road: Array[Vector2i] in [main, north, south]:
		for cell: Vector2i in road:
			top = mini(top, cell.y)
			left = mini(left, cell.x)
	assert_eq(main[0].x, left, "Главная дорога входит с запада")
	assert_eq(north[0].y, top, "Северная — сверху")
	assert_true(south[0].y >= _trial.field.layout.height - 1, "Южная — снизу")
	for road: Array[Vector2i] in [main, north, south]:
		assert_eq(road[road.size() - 1], main[main.size() - 1], "Все дороги сходятся у сторожки")
		var turns: int = 0
		for index: int in range(1, road.size() - 1):
			if road[index] - road[index - 1] != road[index + 1] - road[index]:
				turns += 1
		assert_true(turns >= 1, "На каждой дороге есть поворот внутри города")
	_grow(3)
	assert_eq(_trial.entrances(1000), 3, "Детинец не добавляет входа")


func test_new_entrance_opens_next_night() -> void:
	_grow(1)
	var opened: int = _trial.street_nights[0]
	assert_eq(_trial.entrances(opened - 1), 1, "До своей ночи вход закрыт")
	assert_eq(_trial.entrances(opened), 2, "С ближайшей ночи вход открыт")


## Срезка короче срезанного отрезка; быстрый враг идёт ею, медленный — по дороге.
func test_fast_enemies_take_open_alley_and_barricade_stops_them() -> void:
	var alley_lane: int = _trial.field.alley_route(0)
	assert_true(_trial.field.route(alley_lane).size() < _trial.field.route(0).size(), "Проулок короче дороги")
	var fast: int = _enemy(true)
	var slow: int = _enemy(false)
	assert_true(fast >= 0 and slow >= 0)
	assert_false(_trial.takes_alley(0, _settings.enemies[fast]), "На уровне 1 проулка ещё нет")
	assert_ne(_trial.execute(RitualCommand.new(RitualCommand.Action.BARRICADE, 0)), "")
	_grow(1)
	assert_true(_trial.takes_alley(0, _settings.enemies[fast]))
	assert_false(_trial.takes_alley(0, _settings.enemies[slow]))
	var gold: int = _trial.gold
	assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.BARRICADE, 0)), "")
	assert_eq(_trial.gold, gold - _settings.alleys[0].barricade_cost)
	assert_false(_trial.takes_alley(0, _settings.enemies[fast]), "Завал закрывает проулок")
	assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.BARRICADE, 0)), "")
	assert_true(_trial.takes_alley(0, _settings.enemies[fast]), "Завал разобран")
	assert_eq(_trial.gold, gold - _settings.alleys[0].barricade_cost, "Разбор бесплатный, без возврата")


## Медленный враг сворачивает в проулок, когда впереди на срезаемом отрезке частокол.
func test_slow_enemy_turns_into_alley_before_palisade() -> void:
	_grow(1)
	_trial.execute(RitualCommand.new(RitualCommand.Action.START))
	var slow: int = _enemy(false)
	var mob: RitualMob = _trial.field.spawn_mob(slow, 100, &"", 0)
	var fork: int = _trial.field.alley_fork(0)
	var join: int = _trial.field.alley_join(0)
	_trial.palisades = 1
	assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.PALISADE, 0, Vector2i.ZERO, 0, 0,
		(fork + join) / 2)), "")
	mob.progress = fork - 10
	_trial.tick()
	assert_eq(mob.lane, _trial.field.alley_route(0), "Частокол впереди — враг свернул в проулок")


func test_snapshot_keeps_barricade_and_fourth_idol() -> void:
	_grow(3)
	_trial.execute(RitualCommand.new(RitualCommand.Action.BARRICADE, 0))
	var restored: RitualTrial = RitualTrial.from_snapshot(_settings, _trial.snapshot())
	assert_not_null(restored)
	assert_true(restored.barricades[0])
	assert_eq(restored.field.idols.size(), 4)
	assert_eq(restored.state_hash(), _trial.state_hash())

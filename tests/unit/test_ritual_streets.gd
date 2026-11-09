extends GutTest
## «Городище» растёт улицами (docs/34 §3): за золото, места сразу, новый вход со следующей ночи,
## пачка целиком идёт через один вход, все маршруты сходятся у сторожки Ильи.

var _settings: RitualTrialConfig


func before_each() -> void:
	_settings = load("res://data/ritual/endless.tres") as RitualTrialConfig


func _trial(run_seed: int = 7, gold: int = 1000) -> RitualTrial:
	var trial: RitualTrial = RitualTrial.new(_settings, 0, run_seed)
	trial.gold = gold
	return trial


func _street(trial: RitualTrial) -> String:
	return trial.execute(RitualCommand.new(RitualCommand.Action.STREET))


func _until(trial: RitualTrial, tick: int) -> void:
	while trial.tick_count < tick and trial.phase == RitualTrial.Phase.RUNNING:
		trial.tick()


func test_streets_are_routes_from_own_entrance_to_ilya() -> void:
	var main_path: Array[Vector2i] = _settings.combat.board.path_cells
	assert_eq(_settings.streets.size(), 2, "Две улицы — всего три входа")
	var entrances: Dictionary[Vector2i, bool] = {main_path[0]: true}
	for street: RitualStreetData in _settings.streets:
		assert_eq(street.path_cells[-1], main_path[-1], "%s сходится у сторожки" % street.title)
		assert_false(entrances.has(street.path_cells[0]), "Свой вход у каждой улицы")
		entrances[street.path_cells[0]] = true
		for index: int in street.path_cells.size() - 1:
			var step: Vector2i = street.path_cells[index + 1] - street.path_cells[index]
			assert_eq(absi(step.x) + absi(step.y), 1, "Маршрут идёт по соседним клеткам")
		for region: Rect2i in street.build_regions:
			for cell: Vector2i in street.path_cells + main_path:
				assert_false(region.has_point(cell), "Места улицы не на дороге: %s" % cell)
			for old: Rect2i in _settings.build_regions:
				assert_false(region.intersects(old), "Квартал не залезает в старый двор")
		for cell: Vector2i in street.path_cells:
			assert_true(_settings.combat.board.is_inside(cell), "Улица внутри сетки поля: %s" % cell)
			for old: Rect2i in _settings.build_regions:
				assert_false(old.has_point(cell), "Дорога улицы не режет старые места: %s" % cell)


func test_street_costs_grow_and_last_one_greys_out() -> void:
	var trial: RitualTrial = _trial(7, 1000)
	assert_true(_settings.streets[1].cost > _settings.streets[0].cost, "Цена земли растёт")
	assert_eq(trial.street_cost(), _settings.streets[0].cost)
	assert_eq(_street(trial), "")
	assert_eq(trial.gold, 1000 - _settings.streets[0].cost)
	assert_eq(trial.street_cost(), _settings.streets[1].cost)
	assert_eq(_street(trial), "")
	assert_false(trial.can_grow())
	assert_eq(_street(trial), "Дальше — проклятая земля")
	var poor: RitualTrial = _trial(7, _settings.streets[0].cost - 1)
	assert_eq(_street(poor), "Не хватает золота")
	assert_eq(poor.street_nights.size(), 0)


func test_new_quarter_is_buildable_at_once() -> void:
	var trial: RitualTrial = _trial()
	var cell: Vector2i = _settings.streets[0].build_regions[0].position
	assert_false(trial.field.is_buildable(cell), "До покупки — не место")
	var before: int = trial.field.get_buildable_cells().size()
	assert_eq(_street(trial), "")
	assert_true(trial.field.is_buildable(cell), "Места квартала открыты сразу")
	assert_true(trial.field.get_buildable_cells().size() > before)
	var index: int = trial.offers[0]
	var error: String = trial.execute(RitualCommand.new(RitualCommand.Action.BUY, index, cell))
	assert_eq(error, "", "Дом ставится в новом квартале")


func test_entrance_opens_from_next_night_bought_in_evening_or_at_night() -> void:
	var nights: RitualNightRules = _settings.nights
	var evening: RitualTrial = _trial()
	assert_eq(_street(evening), "")
	assert_eq(evening.street_nights, [1] as Array[int], "Куплено вечером — вход с ближайшей ночи")
	assert_eq(evening.entrances(1), 2)
	var night: RitualTrial = _trial()
	_until(night, nights.night_start(1) + 5)
	assert_eq(_street(night), "")
	assert_eq(night.street_nights, [2] as Array[int], "Куплено ночью — вход со следующей")
	assert_eq(night.entrances(1), 1)
	assert_eq(night.entrances(2), 2)
	assert_true(night.field.is_buildable(_settings.streets[0].build_regions[0].position),
		"Места открыты сразу и ночью")


func test_packs_go_whole_through_one_entrance_and_use_all_open() -> void:
	var trial: RitualTrial = _trial(5)
	var plan: RitualNightPlan = trial.plan()
	for night: int in range(1, 8):
		for pack: RitualPack in plan.packs(night):
			assert_eq(trial.pack_lane(pack), 0, "Без улиц — один вход")
	assert_eq(_street(trial), "")
	assert_eq(_street(trial), "")
	var used: Dictionary[int, int] = {}
	for night: int in range(1, 12):
		for pack: RitualPack in plan.packs(night):
			var lane: int = trial.pack_lane(pack)
			assert_true(lane >= 0 and lane < 3)
			used[lane] = used.get(lane, 0) + 1
	assert_eq(used.size(), 3, "Пачки идут через все три входа")
	for lane: int in used:
		assert_true(used[lane] >= 5, "Входы получают пачки поровну, а не все в один")


func test_streets_do_not_change_night_composition() -> void:
	var plain: RitualNightPlan = RitualNightPlan.new(_settings, 9)
	var trial: RitualTrial = _trial(9)
	assert_eq(_street(trial), "")
	for night: int in range(1, 10):
		assert_eq(trial.plan().describe(night), plain.describe(night), "Состав ночи %d тот же" % night)


func test_mobs_walk_their_street_and_hit_ilya() -> void:
	var trial: RitualTrial = _trial(3)
	assert_eq(_street(trial), "")
	assert_eq(_street(trial), "")
	var field: RitualField = trial.field
	for lane: int in [1, 2]:
		var mob: RitualMob = field.spawn_mob(0, 100, &"", lane)
		assert_eq(field.get_mob_position(mob), field.lane_point(lane, 0), "Враг стоит у своего входа")
		assert_eq(field.get_mob_end_progress(mob), (_settings.streets[lane - 1].path_cells.size() - 1) * 1000)
	var hp: int = trial.hp
	_until(trial, trial.tick_count + 2000)
	assert_true(trial.hp < hp, "Враги с улиц дошли до сторожки и ударили Илью")
	var breaches: int = 0
	for record: Dictionary in trial.journal:
		if record.get("event", "") == "breach":
			breaches += 1
	assert_true(breaches >= 2)


func test_wind_reads_direction_of_own_route() -> void:
	var trial: RitualTrial = _trial()
	assert_eq(_street(trial), "")
	var mob: RitualMob = trial.field.spawn_mob(0, 100, &"", 1)
	var route: Array[Vector2i] = trial.field.route(1)
	assert_eq(trial.field.get_mob_step(mob), route[1] - route[0])
	mob.progress = (route.size() - 2) * 1000
	assert_eq(trial.field.get_mob_step(mob), route[-1] - route[-2])


func test_towers_aim_at_mob_closest_to_ilya_across_routes() -> void:
	var trial: RitualTrial = _trial()
	assert_eq(_street(trial), "")
	var field: RitualField = trial.field
	var main: RitualMob = field.spawn_mob(0, 100, &"", 0)
	var upper: RitualMob = field.spawn_mob(0, 100, &"", 1)
	main.progress = 12000
	upper.progress = 13000
	assert_true(field.route(1).size() > field.route(0).size(), "Улица длиннее стартовой")
	assert_true(field._remaining(main) < field._remaining(upper),
		"На короткой главной улице враг ближе к сторожке при меньшем прогрессе")


func test_hero_strike_and_palisade_work_on_street_road() -> void:
	var trial: RitualTrial = _trial()
	var street_cell: Vector2i = _settings.streets[0].path_cells[5]
	assert_eq(trial.field.locate_road(street_cell), Vector2i(-1, -1), "Улица не куплена — не дорога")
	assert_eq(_street(trial), "")
	var spot: Vector2i = trial.field.locate_road(street_cell)
	assert_eq(spot, Vector2i(1, 5000))
	var mob: RitualMob = trial.field.spawn_mob(0, 100, &"", 1)
	mob.progress = 5000
	trial.hero_ready = 0
	assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.SKILL, spot.x, Vector2i.ZERO, 0, 0, spot.y)), "")
	var hp: int = mob.hp
	_until(trial, trial.hero_due + 1)
	assert_true(mob.hp < hp, "Удар Ильи по точке улицы задел врага на ней")
	assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.SKILL, 2, Vector2i.ZERO, 0, 0, 1000)),
		"Илья не готов")


func test_palisade_on_main_road_ignores_routes_that_bypass_it() -> void:
	var trial: RitualTrial = _trial()
	assert_eq(_street(trial), "")
	assert_eq(_street(trial), "")
	var lower: Array[Vector2i] = trial.field.route(2)
	var shared: Vector2i = lower[-1]
	var main_index: int = trial.field.route(0).find(shared)
	# Последняя клетка — сама сторожка; частокол ставится на предпоследней клетке главной дороги.
	var cell: Vector2i = trial.field.route(0)[main_index - 1]
	var heavy: int = -1
	for index: int in _settings.enemies.size():
		if _settings.enemies[index].tags.has(_settings.heavy_tag):
			heavy = index
			break
	assert_true(heavy >= 0)
	trial.palisades = 1
	var spot: Vector2i = trial.field.locate_road(cell)
	assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.PALISADE, spot.x, Vector2i.ZERO, 0, 0, spot.y)), "")
	var on_main: RitualMob = trial.field.spawn_mob(heavy, 100, &"", 0)
	assert_eq(trial.palisade_at(on_main), spot.y)
	var on_lower: RitualMob = trial.field.spawn_mob(heavy, 100, &"", 2)
	assert_eq(trial.palisade_at(on_lower), -1, "Нижняя улица заходит к сторожке снизу, мимо частокола")
	var on_upper: RitualMob = trial.field.spawn_mob(heavy, 100, &"", 1)
	assert_eq(trial.palisade_at(on_upper), -1)
	on_main.progress = spot.y - 400
	trial.palisade_ready = 0
	_until(trial, trial.tick_count + 40)
	var stopped: bool = false
	for record: Dictionary in trial.journal:
		stopped = stopped or (record.get("event", "") == "palisade" and record["mob"] == on_main.id)
	assert_true(stopped, "Частокол остановил тяжёлого")


func test_spot_on_route_maps_shared_cells_between_routes() -> void:
	var trial: RitualTrial = _trial()
	assert_eq(_street(trial), "")
	var upper: Array[Vector2i] = trial.field.route(1)
	var mob: RitualMob = trial.field.spawn_mob(0, 100, &"", 1)
	var end_main: int = (trial.field.route(0).size() - 1) * 1000
	assert_eq(trial.spot_on_route(0, end_main, mob), (upper.size() - 1) * 1000,
		"Сторожка — одна точка для всех маршрутов")
	assert_eq(trial.spot_on_route(0, 0, mob), -1)


func test_streets_survive_snapshot_with_mob_lanes() -> void:
	var trial: RitualTrial = _trial(4)
	assert_eq(_street(trial), "")
	var lanes: Dictionary[int, bool] = {}
	for pack: RitualPack in trial.plan().packs(1):
		lanes[trial.pack_lane(pack)] = true
	assert_true(lanes.has(1), "В первую ночь часть пачек идёт новой улицей")
	_until(trial, _settings.nights.night_start(1) + 300)
	var copy: RitualTrial = RitualTrial.from_snapshot(_settings, trial.snapshot())
	assert_not_null(copy)
	assert_eq(copy.street_nights, trial.street_nights)
	assert_eq(copy.field.open_streets, 1)
	assert_true(copy.field.is_buildable(_settings.streets[0].build_regions[0].position))
	assert_eq(copy.state_hash(), trial.state_hash())
	for index: int in 400:
		trial.tick()
		copy.tick()
	assert_eq(copy.state_hash(), trial.state_hash(), "После снимка забег с улицами идёт бит-в-бит")


func test_alley_is_a_gap_from_start_that_nobody_can_build_on() -> void:
	var trial: RitualTrial = _trial()
	for street: RitualStreetData in _settings.streets:
		assert_false(street.alley_cells.is_empty(), "%s: проулок заложен" % street.title)
		for cell: Vector2i in street.alley_cells:
			assert_false(trial.field.is_buildable(cell), "Щель проулка не под дома: %s" % cell)
			assert_eq(trial.field.locate_road(cell), Vector2i(-1, -1), "До улицы проулок закрыт")
	assert_eq(_street(trial), "")
	assert_eq(_street(trial), "")
	for street: RitualStreetData in _settings.streets:
		for cell: Vector2i in street.alley_cells:
			assert_false(trial.field.is_buildable(cell), "И после пристройки в проулке не строят")
			assert_true(trial.field.locate_road(cell).x > 2, "Проулок стал дорогой ветки")


func test_branches_join_two_roads_and_end_at_ilya() -> void:
	var field: RitualField = _trial().field
	var ilya: Vector2i = _settings.combat.board.path_cells[-1]
	for street: int in [1, 2]:
		for entrance: int in [0, street]:
			var lane: int = field.branch_route(entrance, street)
			assert_true(lane > 2, "Ветка входа %d через проулок улицы %d" % [entrance, street])
			var cells: Array[Vector2i] = field.route(lane)
			assert_eq(cells[0], field.route(entrance)[0], "Ветка начинается у своего входа")
			assert_eq(cells[-1], ilya, "Ветка кончается у сторожки")
			for index: int in cells.size() - 1:
				var step: Vector2i = cells[index + 1] - cells[index]
				assert_eq(absi(step.x) + absi(step.y), 1)
			for cell: Vector2i in _settings.streets[street - 1].alley_cells:
				assert_true(cells.has(cell), "Ветка идёт через проулок")


func test_pack_splits_in_turn_between_straight_and_alley() -> void:
	var trial: RitualTrial = _trial(5)
	var plan: RitualNightPlan = trial.plan()
	var pack: RitualPack = plan.packs(1)[0]
	assert_eq(trial.pack_routes(pack).size(), 1, "Без улиц проулок закрыт — все прямо")
	assert_eq(_street(trial), "")
	var routes: Array[int] = trial.pack_routes(pack)
	assert_eq(routes.size(), 2, "Улица пристроена — пачка делится")
	assert_eq(trial.member_route(pack, 0), routes[0], "Первый — прямо")
	assert_eq(trial.member_route(pack, 1), routes[1], "Второй — в проулок")
	assert_eq(trial.member_route(pack, 2), routes[0])
	assert_eq(_street(trial), "")
	var main_pack: RitualPack = null
	for candidate: RitualPack in plan.packs(1):
		if trial.pack_lane(candidate) == 0:
			main_pack = candidate
	if main_pack != null:
		assert_eq(trial.pack_routes(main_pack).size(), 3, "С двумя улицами главная делится на три")


func test_split_mobs_really_walk_the_alley_and_survive_snapshot() -> void:
	var trial: RitualTrial = _trial(4)
	assert_eq(_street(trial), "")
	_until(trial, _settings.nights.night_start(1) + 200)
	var branches: int = 0
	for base: MobState in trial.field.mobs:
		branches += int((base as RitualMob).lane > 2)
	assert_true(branches > 0, "Кто-то из пачки свернул в проулок")
	var copy: RitualTrial = RitualTrial.from_snapshot(_settings, trial.snapshot())
	for index: int in 300:
		trial.tick()
		copy.tick()
	assert_eq(copy.state_hash(), trial.state_hash(), "С ветками забег после снимка бит-в-бит")


func _until_dawn(trial: RitualTrial, dawn: int) -> void:
	while trial.nights_survived() < dawn and trial.phase == RitualTrial.Phase.RUNNING:
		trial.tick()


func test_street_pays_tribute_each_dawn_after_its_entrance_night() -> void:
	# Домов нет — золото меняется только подачей (прорвавшиеся враги наград не дают).
	var trial: RitualTrial = _trial(5, 1000)
	trial.hp = 100000
	assert_eq(_street(trial), "", "Улица вечером — вход с 1-й ночи")
	var tribute: int = _settings.streets[0].tribute
	assert_true(tribute > 0, "У улицы есть подать")
	var gold: int = trial.gold
	_until_dawn(trial, 1)
	assert_eq(trial.gold - gold, tribute, "Первый рассвет после ночи с новым входом — подать")
	assert_eq(_street(trial), "", "Вторая улица днём — вход со 2-й ночи")
	gold = trial.gold
	_until_dawn(trial, 2)
	assert_eq(trial.gold - gold, tribute + _settings.streets[1].tribute, "Обе улицы платят")

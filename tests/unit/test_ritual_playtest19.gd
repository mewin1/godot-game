extends GutTest
## Плейтест автора 19 ноября: новая улица — вход после полного дня, частокол-заслон держит любого
## врага и ломается, частоколов несколько, проулок не заваливают (его держат дома у моста).

var _settings: RitualTrialConfig


func before_each() -> void:
	_settings = load("res://data/ritual/endless.tres") as RitualTrialConfig


func _trial(gold: int = 1000) -> RitualTrial:
	var trial: RitualTrial = RitualTrial.new(_settings, 0, 7)
	trial.gold = gold
	trial.hp = 100000
	return trial


func _until(trial: RitualTrial, tick: int) -> void:
	while trial.tick_count < tick and trial.phase == RitualTrial.Phase.RUNNING:
		if not trial.gift_choice.is_empty():
			trial.execute(RitualCommand.new(RitualCommand.Action.GIFT, trial.gift_choice[0]))
		trial.tick()


func _wall(trial: RitualTrial, progress: int, lane: int = 0) -> String:
	return trial.execute(RitualCommand.new(RitualCommand.Action.PALISADE, lane, Vector2i.ZERO, 0, 0, progress))


func test_street_bought_in_evening_opens_after_a_full_day() -> void:
	var trial: RitualTrial = _trial()
	assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.STREET)), "")
	assert_eq(trial.street_nights, [2] as Array[int], "Куплено вечером — вход только со 2-й ночи")
	assert_eq(trial.entrances(1), 1, "В ближайшую ночь нового входа нет")
	var day: RitualTrial = _trial()
	_until(day, _settings.nights.night_end(1) + 5)
	assert_false(_settings.is_night(day.tick_count))
	assert_eq(day.execute(RitualCommand.new(RitualCommand.Action.STREET)), "")
	assert_eq(day.street_nights, [3] as Array[int], "Куплено днём — вход через ночь, после полного дня")
	var night: RitualTrial = _trial()
	_until(night, _settings.nights.night_start(1) + 5)
	assert_eq(night.execute(RitualCommand.new(RitualCommand.Action.STREET)), "")
	assert_eq(night.street_nights, [2] as Array[int], "Куплено ночью — со следующей ночи (впереди целый день)")


func test_day_is_long_enough_to_read_and_build() -> void:
	var ticks: int = _settings.combat.ticks_per_second
	assert_true(_settings.nights.day_ticks >= 40 * ticks, "День не короче 40 с")


func test_wall_holds_any_first_enemy_then_breaks() -> void:
	var trial: RitualTrial = _trial()
	trial.palisades = 1
	assert_eq(_wall(trial, 5000), "")
	assert_eq(trial.palisades, 0)
	assert_eq(trial.wall_lanes.size(), 1)
	trial.tick_count = 100
	var mob: RitualMob = trial.field.spawn_mob(0)
	assert_false(mob.data.tags.has(_settings.heavy_tag), "Обычный мертвяк, не тяжёлый")
	mob.previous_progress = 4900
	mob.progress = 5100
	trial._resolve_palisade()
	assert_eq(mob.progress, 5000, "Мертвяк упёрся в частокол")
	assert_eq(trial.wall_break[0], 100 + _settings.palisade_hold_ticks)
	var second: RitualMob = trial.field.spawn_mob(1)
	second.previous_progress = 4950
	second.progress = 5300
	trial._resolve_palisade()
	assert_eq(second.progress, 5000, "Подошедший следом тоже стоит")
	trial.tick_count = 100 + _settings.palisade_hold_ticks
	trial._resolve_palisade()
	assert_true(trial.wall_lanes.is_empty(), "Через palisade_hold_ticks частокол сломан и исчез")
	mob.previous_progress = 5000
	mob.progress = 5200
	trial._resolve_palisade()
	assert_eq(mob.progress, 5200, "Сломанный частокол не держит")


func test_wall_not_ready_lets_enemies_pass() -> void:
	var trial: RitualTrial = _trial()
	trial.palisades = 1
	assert_eq(_wall(trial, 5000), "")
	var mob: RitualMob = trial.field.spawn_mob(0)
	mob.previous_progress = 4900
	mob.progress = 5100
	trial._resolve_palisade()
	assert_eq(mob.progress, 5100, "Пока частокол ставят, враги идут")


func test_several_walls_up_to_cap_and_stock_grows_at_dawn() -> void:
	var trial: RitualTrial = _trial()
	assert_true(_settings.palisade_active_cap >= 2)
	trial.palisades = _settings.palisade_active_cap + 1
	for index: int in _settings.palisade_active_cap:
		assert_eq(_wall(trial, 3000 + index * 4000), "", "Частокол %d" % index)
	assert_true(_wall(trial, 20000).begins_with("На дорогах уже"), "Больше предела не ставится")
	assert_ne(_wall(trial, 3000), "")
	var fresh: RitualTrial = _trial()
	assert_eq(fresh.palisades, 0)
	_until(fresh, _settings.nights.night_end(1) + 1)
	assert_true(fresh.palisades >= _settings.palisade_dawn_gain, "Рассвет приносит частокол")
	_until(fresh, _settings.nights.night_end(6) + 1)
	assert_true(fresh.palisades <= _settings.palisade_stock_cap + 1, "Запас не выше предела (+1 к ночи босса)")


func test_walls_survive_snapshot_and_hash() -> void:
	var trial: RitualTrial = _trial()
	trial.palisades = 2
	assert_eq(_wall(trial, 5000), "")
	var copy: RitualTrial = RitualTrial.from_snapshot(_settings, trial.snapshot())
	assert_not_null(copy)
	assert_eq(copy.wall_progress, trial.wall_progress)
	assert_eq(copy.state_hash(), trial.state_hash())


func test_alley_cannot_be_barricaded() -> void:
	var trial: RitualTrial = _trial()
	assert_eq(_settings.alleys[0].barricade_cost, 0)
	var error: String = trial.execute(RitualCommand.new(RitualCommand.Action.BARRICADE, 0))
	assert_ne(error, "")
	assert_true(trial.barricades.is_empty() or not trial.barricades[0])

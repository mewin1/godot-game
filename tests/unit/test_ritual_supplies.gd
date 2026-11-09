extends GutTest
## Припасы (docs/36 §4): рассвет приносит один случайный; смола замедляет участок,
## чаша мочит группу, оберег гасит прорывы.

var _settings: RitualTrialConfig


func before_each() -> void:
	_settings = load("res://data/ritual/endless.tres") as RitualTrialConfig


func _trial(run_seed: int = 2) -> RitualTrial:
	var trial: RitualTrial = RitualTrial.new(_settings, 0, run_seed)
	trial.hp = 100000
	return trial


func _mob(trial: RitualTrial, progress: int) -> RitualMob:
	var mob: RitualMob = trial.field.spawn_mob(0, 1000)
	mob.progress = progress
	mob.previous_progress = progress
	return mob


func _use(trial: RitualTrial, kind: int, progress: int = 5000) -> String:
	return trial.execute(RitualCommand.new(RitualCommand.Action.SUPPLY, 0, Vector2i.ZERO, kind, 0, progress))


func _total(trial: RitualTrial) -> int:
	var total: int = 0
	for count: int in trial.supplies:
		total += count
	return total


func test_dawn_brings_one_supply_up_to_cap() -> void:
	var trial: RitualTrial = _trial()
	assert_eq(_total(trial), 0, "В начале припасов нет")
	for dawn: int in range(1, 6):
		while trial.nights_survived() < dawn:
			trial.tick()
		assert_eq(_total(trial), mini(dawn, _settings.supply_cap), "Рассвет %d" % dawn)
	var again: RitualTrial = _trial()
	while again.nights_survived() < 3:
		again.tick()
	var first: RitualTrial = _trial()
	while first.nights_survived() < 3:
		first.tick()
	assert_eq(again.supplies, first.supplies, "Выдача зависит только от сида")


func test_tar_slows_mobs_on_its_stretch_until_it_dries() -> void:
	var trial: RitualTrial = _trial()
	trial.supplies[RitualTrial.Supply.TAR] = 1
	var inside: RitualMob = _mob(trial, 5000)
	var outside: RitualMob = _mob(trial, 9000)
	assert_eq(_use(trial, RitualTrial.Supply.TAR), "")
	assert_eq(trial.supplies[RitualTrial.Supply.TAR], 0, "Припас израсходован")
	var a: int = inside.progress
	var b: int = outside.progress
	trial.tick()
	assert_true(inside.progress - a < outside.progress - b, "В смоле враг медленнее")
	assert_eq(_use(trial, RitualTrial.Supply.TAR), "Припаса «Смоляная полоса» нет в запасе")
	for step: int in _settings.tar_ticks:
		trial.tick()
	assert_eq(trial.tar_progress, -1, "Смола высохла")


func test_rain_bowl_wets_the_group() -> void:
	var trial: RitualTrial = _trial()
	trial.supplies[RitualTrial.Supply.RAIN] = 1
	var near: RitualMob = _mob(trial, 5000)
	var near2: RitualMob = _mob(trial, 5600)
	var far: RitualMob = _mob(trial, 11000)
	assert_eq(_use(trial, RitualTrial.Supply.RAIN), "")
	assert_true(near.status_tags().has(&"wet") and near2.status_tags().has(&"wet"), "Группа мокрая")
	assert_false(far.status_tags().has(&"wet"), "Дальний сухой")


func test_charm_absorbs_next_breaches() -> void:
	var trial: RitualTrial = _trial()
	trial.hp = 30
	trial.supplies[RitualTrial.Supply.CHARM] = 1
	assert_eq(_use(trial, RitualTrial.Supply.CHARM), "", "Оберег без точки")
	for index: int in _settings.charm_blocks:
		trial.field.mob_breached.emit(_mob(trial, 0))
	assert_eq(trial.hp, 30, "Пять прорывов погашены")
	trial.field.mob_breached.emit(_mob(trial, 0))
	assert_true(trial.hp < 30, "Шестой ранит")


func test_supplies_survive_snapshot() -> void:
	var trial: RitualTrial = _trial()
	trial.supplies[RitualTrial.Supply.TAR] = 2
	_use(trial, RitualTrial.Supply.TAR)
	var copy: RitualTrial = RitualTrial.from_snapshot(_settings, trial.snapshot())
	assert_not_null(copy)
	assert_eq(copy.supplies, trial.supplies)
	assert_eq(copy.tar_until, trial.tar_until)
	assert_eq(copy.state_hash(), trial.state_hash())

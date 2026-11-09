extends GutTest
## Бесконечный «Обряд» (docs/34): календарь суток, генератор ночей с сидом, конец только при смерти.

var _settings: RitualTrialConfig
var _nights: RitualNightRules


func before_each() -> void:
	_settings = load("res://data/ritual/endless.tres") as RitualTrialConfig
	_nights = _settings.nights


func _trial(run_seed: int = 7) -> RitualTrial:
	return RitualTrial.new(_settings, 0, run_seed)


func _steps(trial: RitualTrial, count: int) -> void:
	for index: int in count:
		trial.tick()


func test_calendar_starts_in_evening_then_nights_grow_and_days_stay_short() -> void:
	assert_true(_nights.first_evening_ticks > 0, "Старт вечером: время на первые постройки")
	assert_eq(_nights.night_start(1), _nights.first_evening_ticks)
	assert_false(_nights.is_night(0))
	assert_false(_nights.is_night(_nights.first_evening_ticks - 1))
	assert_true(_nights.is_night(_nights.first_evening_ticks))
	for night: int in range(1, 30):
		assert_true(_nights.night_length(night + 1) >= _nights.night_length(night), "Ночь не короче прежней")
		var day: int = _nights.night_start(night + 1) - _nights.night_end(night)
		assert_eq(day, _nights.day_ticks, "День одинаково короткий")
		assert_true(day < _nights.night_length(night), "День короче ночи")
		assert_false(_nights.is_night(_nights.night_end(night)), "После ночи — день")
	assert_true(_nights.night_length(10) > _nights.night_length(1), "Ночи растут")
	assert_eq(_nights.night_length(500), _nights.night_max_ticks, "Длина ночи с пределом")


func test_night_index_points_to_current_or_upcoming_night() -> void:
	assert_eq(_nights.night_index_at(0), 1)
	assert_eq(_nights.night_index_at(_nights.night_end(1) - 1), 1)
	assert_eq(_nights.night_index_at(_nights.night_end(1)), 2)
	assert_eq(_nights.completed_nights(_nights.night_end(3)), 3)
	assert_eq(_nights.period_name(0), "Вечер")
	assert_eq(_nights.period_name(_nights.night_start(2)), "Ночь 2")
	assert_eq(_nights.period_name(_nights.night_end(1)), "День")


func test_generator_is_deterministic_and_depends_on_seed() -> void:
	var first: RitualNightPlan = RitualNightPlan.new(_settings, 11)
	var second: RitualNightPlan = RitualNightPlan.new(_settings, 11)
	var other: RitualNightPlan = RitualNightPlan.new(_settings, 12)
	var differs: bool = false
	for night: int in range(1, 16):
		assert_eq(first.describe(night), second.describe(night), "Один сид — одна ночь %d" % night)
		differs = differs or first.describe(night) != other.describe(night)
	assert_true(differs, "Другой сид даёт другие ночи")


func test_packs_fit_budget_unlocks_and_grow_denser() -> void:
	var plan: RitualNightPlan = RitualNightPlan.new(_settings, 3)
	var previous_count: int = 0
	for night: int in range(1, 25):
		var packs: Array[RitualPack] = plan.packs(night)
		var ordinary: int = 0
		for pack: RitualPack in packs:
			ordinary += 0 if pack.boss else 1
		assert_true(ordinary >= previous_count, "Обычных пачек не меньше, чем в прошлую ночь")
		previous_count = ordinary
		for pack: RitualPack in packs:
			assert_true(pack.at_tick >= _nights.night_start(night), "Пачка приходит ночью")
			assert_true(pack.at_tick < _nights.night_end(night), "Пачка начинается до рассвета")
			assert_true(pack.members.size() > 0)
			assert_true(pack.members.size() <= _nights.pack_max_size or pack.boss)
			for member: int in pack.members:
				if pack.boss and member == _nights.boss_enemy:
					continue
				var rule: RitualEnemyRule = _nights.rule_for(member)
				assert_not_null(rule, "Каждый враг пачки описан правилом")
				if rule != null:
					assert_true(rule.first_night <= night, "%s раньше своей ночи" % _settings.enemies[member].id)
	assert_true(plan.packs(20).size() > plan.packs(1).size(), "Поздние ночи плотнее")
	assert_true(plan.total_threat(20) > plan.total_threat(1) * 4, "Бюджет ночи растёт")


func test_boss_comes_every_fifth_night_with_elemental_resist() -> void:
	var plan: RitualNightPlan = RitualNightPlan.new(_settings, 5)
	for night: int in range(1, 21):
		var bosses: int = 0
		for pack: RitualPack in plan.packs(night):
			if pack.boss:
				bosses += 1
				assert_true(pack.members.has(_nights.boss_enemy))
				assert_true(_nights.boss_resist_gods.has(pack.resist), "Босс неуязвим к одной стихии")
		assert_eq(bosses, 1 if night % _nights.boss_every == 0 else 0, "Босс только в ночь %d" % night)


func test_difficulty_outgrows_any_possible_income() -> void:
	# Даже если всё золото всех прошлых ночей вложить в лучший урон за монету,
	# требуемый урон в секунду растёт быстрее: «всё на максимуме» недостижимо.
	var plan: RitualNightPlan = RitualNightPlan.new(_settings, 9)
	var best_dps_per_gold_milli: int = 0
	var tps: int = _settings.combat.ticks_per_second
	for index: int in _settings.combat.towers.size():
		var data: TowerData = _settings.combat.towers[index]
		if data.attacks and data.damage > 0:
			var dps_milli: int = data.damage * maxi(1, data.targets_per_shot) * tps * 1000 / data.cooldown_ticks
			best_dps_per_gold_milli = maxi(best_dps_per_gold_milli, dps_milli / _settings.costs[index])
	# Первые ~10 ночей игрок нарочно обгоняет (накопленное золото растёт быстрее) — лучший
	# отрезок забега. Дальше разрыв растёт. Окно 5 ночей сравнивает ночь босса с ночью босса,
	# а случайный состав пачек не даёт требовать рост в каждую отдельную ночь.
	var income: int = _settings.start_gold
	var ratios: Array[int] = [0]
	for night: int in range(1, 41):
		var need_dps_milli: int = plan.total_hp(night) * tps * 1000 / _nights.night_length(night)
		var can_dps_milli: int = income * best_dps_per_gold_milli
		ratios.append(need_dps_milli * 1000 / maxi(1, can_dps_milli))
		income += plan.total_gold(night)
	for night: int in range(15, 36):
		assert_true(ratios[night + 5] > ratios[night],
			"Ночь %d → %d: нужно больше урона на монету (%d‰ → %d‰)" % [night, night + 5, ratios[night], ratios[night + 5]])
	assert_true(ratios[40] > ratios[20] * 4, "За 20 ночей разрыв растёт в разы: %d‰ → %d‰" % [ratios[20], ratios[40]])
	assert_true(ratios[40] > 2000, "К 40-й ночи нужно вдвое больше урона, чем купить на всё золото: %d‰" % ratios[40])


func test_endless_run_starts_running_in_evening_without_start_button() -> void:
	var trial: RitualTrial = _trial()
	assert_eq(trial.phase, RitualTrial.Phase.RUNNING)
	assert_eq(trial.gold, _settings.start_gold)
	assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.START)), "Опыт уже запущен")
	_steps(trial, _nights.first_evening_ticks - 1)
	assert_eq(trial.field.mobs.size(), 0, "Вечером враги не приходят")


func test_spawns_follow_plan_only_at_night_and_day_is_quiet() -> void:
	var trial: RitualTrial = _trial(21)
	trial.hp = 1000000
	var plan: RitualNightPlan = RitualNightPlan.new(_settings, 21)
	var expected: int = 0
	for pack: RitualPack in plan.packs(1):
		expected += pack.members.size()
	_steps(trial, _nights.night_end(1) + 40)
	assert_eq(trial.field.battle_report.killed + trial.field.mobs.size() + _breach_count(trial), expected,
		"Пришли все враги первой ночи и никто лишний")
	var before_day: int = _spawn_count(trial)
	_steps(trial, _nights.day_ticks - 60)
	assert_eq(_spawn_count(trial), before_day, "Днём новых врагов нет")


func _spawn_count(trial: RitualTrial) -> int:
	return trial.field.counters()[1] - 1


func _breach_count(trial: RitualTrial) -> int:
	var count: int = 0
	for record: Dictionary in trial.journal:
		if record.get("event", "") == "breach":
			count += 1
	return count


func test_mob_health_grows_by_night() -> void:
	var plan: RitualNightPlan = RitualNightPlan.new(_settings, 1)
	assert_eq(plan.packs(1)[0].hp_percent, 100)
	assert_true(plan.packs(10)[0].hp_percent > 150)
	var trial: RitualTrial = _trial(1)
	var pack: RitualPack = plan.packs(1)[0]
	_steps(trial, pack.at_tick + 1)
	var mob: MobState = trial.field.mobs[0]
	assert_eq(mob.max_hp, _settings.enemies[pack.members[0]].hp * pack.hp_percent / 100)


func test_run_ends_only_on_death_and_counts_nights() -> void:
	var trial: RitualTrial = _trial(4)
	trial.hp = 1000000
	_steps(trial, _nights.night_end(2) + 5)
	assert_eq(trial.phase, RitualTrial.Phase.RUNNING, "Время само не заканчивает забег")
	assert_eq(trial.nights_survived(), 2)
	trial.hp = 1
	var guard: int = 0
	while trial.phase == RitualTrial.Phase.RUNNING and guard < 40000:
		trial.tick()
		guard += 1
	assert_eq(trial.phase, RitualTrial.Phase.OVER, "Без защиты забег кончается смертью")
	assert_false(trial.result.is_empty())


func test_boss_kill_is_counted() -> void:
	var trial: RitualTrial = _trial(2)
	var boss: RitualMob = trial.field.spawn_mob(_nights.boss_enemy)
	trial.field.deal_mob_damage(boss, boss.hp * 10)
	assert_eq(trial.bosses_killed, 1)


func test_snapshot_restores_seeded_run_bit_for_bit() -> void:
	var trial: RitualTrial = _trial(33)
	trial.hp = 1000000
	_steps(trial, _nights.night_start(1) + 200)
	var restored: RitualTrial = RitualTrial.from_snapshot(_settings, trial.snapshot())
	assert_not_null(restored)
	assert_eq(restored.run_seed, 33)
	_steps(trial, 400)
	_steps(restored, 400)
	assert_eq(restored.state_hash(), trial.state_hash())


func test_queue_lists_upcoming_packs_in_order() -> void:
	var plan: RitualNightPlan = RitualNightPlan.new(_settings, 8)
	var queue: Array[RitualPack] = plan.upcoming(0, 5)
	assert_eq(queue.size(), 5)
	for index: int in range(1, queue.size()):
		assert_true(queue[index].at_tick >= queue[index - 1].at_tick)
	var later: Array[RitualPack] = plan.upcoming(queue[0].at_tick + 1, 3)
	assert_eq(later[0].at_tick, queue[1].at_tick, "Начавшаяся пачка уходит из очереди")


func test_old_four_day_trial_is_unchanged() -> void:
	var old: RitualTrialConfig = load("res://data/ritual/trial.tres") as RitualTrialConfig
	assert_null(old.nights)
	var trial: RitualTrial = RitualTrial.new(old, 3)
	assert_eq(trial.phase, RitualTrial.Phase.PREP)
	assert_eq(old.period_name(old.night_tick), "Ночь")


func test_local_record_keeps_best_run() -> void:
	var path: String = "user://test_ritual_record.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	assert_eq(RitualRunRecord.best(path)["nights"], 0)
	assert_true(RitualRunRecord.submit(4, 0, path), "Первый забег — рекорд")
	assert_false(RitualRunRecord.submit(3, 5, path), "Меньше ночей — не рекорд")
	assert_true(RitualRunRecord.submit(4, 1, path), "Столько же ночей и больше боссов — рекорд")
	assert_eq(RitualRunRecord.best(path), {"nights": 4, "bosses": 1})
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

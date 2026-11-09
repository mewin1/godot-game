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


## До тика (ранний рассвет перематывает время — счёт шагов тут не годится).
func _until(trial: RitualTrial, tick: int) -> void:
	while trial.tick_count < tick and trial.phase == RitualTrial.Phase.RUNNING:
		trial.tick()


func test_calendar_starts_in_evening_then_nights_grow_and_days_stay_long() -> void:
	assert_true(_nights.first_evening_ticks > 0, "Старт вечером: время на первые постройки")
	assert_eq(_nights.night_start(1), _nights.first_evening_ticks)
	assert_false(_nights.is_night(0))
	assert_false(_nights.is_night(_nights.first_evening_ticks - 1))
	assert_true(_nights.is_night(_nights.first_evening_ticks))
	for night: int in range(1, 30):
		assert_true(_nights.night_length(night + 1) >= _nights.night_length(night), "Ночь не короче прежней")
		var day: int = _nights.night_start(night + 1) - _nights.night_end(night)
		assert_eq(day, _nights.day_ticks, "День одной длины")
		assert_true(day >= 20 * 20, "День — короткая передышка (плейтест: 25 с)")
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
	_until(trial, _nights.night_end(1) + 40)
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
	_until(trial, _nights.night_end(2) + 5)
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
	_until(trial, _nights.night_start(1) + 200)
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


# --- Шаг 2: очередь разведки ---


func test_queue_shows_whole_nearest_night() -> void:
	var trial: RitualTrial = _trial(8)
	var night_one: Array[RitualPack] = trial.plan().packs(1)
	assert_eq(trial.night_queue(), night_one, "Вечером видна вся первая ночь")
	trial.hp = 1000000
	_steps(trial, night_one[1].at_tick + 1)
	assert_eq(trial.night_queue(), night_one.slice(2), "Ночью — только ещё не вышедшие пачки этой ночи")
	_until(trial, _nights.night_end(1) + 5)
	assert_eq(trial.night_queue(), trial.plan().packs(2), "Днём — вся следующая ночь")


func test_boss_is_announced_ahead_of_the_queue() -> void:
	var trial: RitualTrial = _trial(5)
	trial.hp = 1000000
	assert_null(trial.boss_warning(), "В начале босс далеко")
	_until(trial, _nights.night_end(_nights.boss_every - _nights.warn_nights - 1) + 1)
	var warning: RitualPack = trial.boss_warning()
	assert_not_null(warning, "Босса видно за %d ночи" % _nights.warn_nights)
	if warning != null:
		assert_true(warning.boss and warning.night == _nights.boss_every)
	_until(trial, _nights.night_end(_nights.boss_every - 1) + 1)
	assert_null(trial.boss_warning(), "В ночь босса он уже в самой очереди")
	var has_boss: bool = false
	for pack: RitualPack in trial.night_queue():
		has_boss = has_boss or pack.boss
	assert_true(has_boss)


func test_first_pack_with_new_enemy_type_is_important() -> void:
	var plan: RitualNightPlan = RitualNightPlan.new(_settings, 6)
	var seen: Dictionary[int, bool] = {}
	var found_new: bool = false
	for night: int in range(1, 12):
		for pack: RitualPack in plan.packs(night):
			var has_new: bool = false
			for member: int in pack.members:
				has_new = has_new or (not seen.has(member) and _nights.rule_for(member) != null
						and _nights.rule_for(member).first_night > 1)
			assert_eq(plan.is_important(pack), has_new or pack.boss,
				"Ночь %d: важна пачка с новым (не стартовым) врагом или босс" % night)
			found_new = found_new or (has_new and night > 1)
			for member: int in pack.members:
				seen[member] = true
	assert_true(found_new, "Новые враги появляются по ходу забега")


func test_queue_is_time_ordered_and_skips_started_packs() -> void:
	var trial: RitualTrial = _trial(5)
	trial.hp = 1000000
	_until(trial, _nights.night_start(3) + 1)
	var queue: Array[RitualPack] = trial.night_queue()
	for index: int in queue.size():
		assert_true(queue[index].at_tick >= trial.tick_count, "Начавшиеся пачки не показываются")
		assert_eq(queue[index].night, 3)
		if index > 0:
			assert_true(queue[index].at_tick >= queue[index - 1].at_tick, "Очередь по времени")


func test_scout_tooltip_names_boss_resist_and_composition() -> void:
	var trial: RitualTrial = _trial(5)
	trial.hp = 1000000
	_until(trial, _nights.night_start(_nights.boss_every - _nights.warn_nights))
	var boss: RitualPack = trial.boss_warning()
	assert_not_null(boss, "Босс уже в очереди")
	if boss == null:
		return
	var text: String = RitualScoutQueue.describe(trial, boss)
	assert_string_contains(text, "БОСС: " + _settings.enemies[_nights.boss_enemy].display_name)
	assert_string_contains(text, "Неуязвим к стихии")
	assert_string_contains(text, "Состав (%d)" % boss.members.size())
	assert_string_contains(text, "Придёт в ночь %d" % _nights.boss_every)


# --- Шаг 3: лавка с азартом, без резерва и чар ---


func _offered(trial: RitualTrial) -> Array[int]:
	var result: Array[int] = []
	for index: int in trial.offers:
		if index >= 0:
			result.append(index)
	return result


func test_market_shows_few_random_cards_with_shooters_first() -> void:
	var trial: RitualTrial = _trial(3)
	assert_eq(trial.offers.size(), _settings.market_offers, "Мало карточек, а не все постройки")
	assert_true(_settings.market_offers < _settings.combat.towers.size())
	for slot: int in _settings.market_shooter_slots:
		var data: TowerData = _settings.combat.towers[trial.offers[slot]]
		assert_true(data.attacks and data.damage > 0, "Первые места — стреляющие постройки")


func test_buying_needs_card_in_market_and_empties_its_slot() -> void:
	var trial: RitualTrial = _trial(3)
	var missing: int = -1
	for index: int in _settings.combat.towers.size():
		if not trial.offers.has(index):
			missing = index
	if missing >= 0:
		assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.BUY, missing, Vector2i(8, 8))),
			"Этой постройки нет в лавке")
	var chosen: int = trial.offers[0]
	var before: int = _offered(trial).size()
	assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.BUY, chosen, Vector2i(8, 8))), "")
	assert_eq(_offered(trial).size(), before - 1, "Купленная карточка уходит с прилавка")
	assert_eq(trial.offers[0], -1, "Пустое место до обновления")


func test_reroll_is_paid_grows_within_day_and_is_seeded() -> void:
	var first: RitualTrial = _trial(12)
	var second: RitualTrial = _trial(12)
	first.gold = 100
	second.gold = 100
	var cost: int = first.reroll_cost()
	assert_eq(cost, _settings.reroll_cost)
	assert_eq(first.execute(RitualCommand.new(RitualCommand.Action.REROLL)), "")
	assert_eq(first.gold, 100 - cost)
	assert_eq(first.reroll_cost(), cost + _settings.reroll_cost_step, "Обновление дорожает в течение суток")
	assert_eq(second.execute(RitualCommand.new(RitualCommand.Action.REROLL)), "")
	assert_eq(first.offers, second.offers, "Один сид — одна лавка")
	first.gold = 0
	assert_eq(first.execute(RitualCommand.new(RitualCommand.Action.REROLL)), "Не хватает золота")


func test_dawn_brings_free_showcase_and_resets_reroll_price() -> void:
	var trial: RitualTrial = _trial(14)
	trial.hp = 1000000
	trial.gold = 100
	trial.execute(RitualCommand.new(RitualCommand.Action.BUY, trial.offers[0], Vector2i(8, 8)))
	trial.execute(RitualCommand.new(RitualCommand.Action.REROLL))
	trial.execute(RitualCommand.new(RitualCommand.Action.REROLL))
	var gold: int = trial.gold
	_until(trial, _nights.night_end(1) + 1)
	assert_eq(_offered(trial).size(), _settings.market_offers, "На рассвете прилавок полный")
	assert_eq(trial.reroll_cost(), _settings.reroll_cost, "Цена обновления сброшена")
	assert_true(trial.gold >= gold, "Новый прилавок на рассвете бесплатный")


func test_market_picks_every_element_equally() -> void:
	var trial: RitualTrial = _trial(77)
	var gods: Array[StringName] = trial.market_gods()
	assert_eq(gods.size(), 7, "В лавке все семь стихий режима, с Перуном и проклятием")
	var counts: Dictionary[StringName, int] = {}
	var rites: Dictionary[StringName, int] = {}
	for roll: int in 600:
		trial.gold = 1000
		trial.rerolls_today = 0
		trial.execute(RitualCommand.new(RitualCommand.Action.REROLL))
		for index: int in trial.offers:
			var god: StringName = _settings.combat.towers[index].god
			counts[god] = counts.get(god, 0) + 1
		for index: int in trial.rite_offers:
			rites[_settings.rites[index].god] = rites.get(_settings.rites[index].god, 0) + 1
	var mean: int = 600 * _settings.market_offers / gods.size()
	var rite_mean: int = 600 / gods.size()
	for god: StringName in gods:
		var built: int = counts.get(god, 0)
		var spoken: int = rites.get(god, 0)
		assert_true(absi(built - mean) < mean / 4, "%s: %d из ~%d" % [god, built, mean])
		assert_true(absi(spoken - rite_mean) < rite_mean / 3, "Заговор %s: %d из ~%d" % [god, spoken, rite_mean])


func test_rite_card_sits_in_market_and_is_bought_from_it() -> void:
	var trial: RitualTrial = _trial(3)
	assert_eq(trial.rite_offers.size(), _settings.market_rite_slots, "Крайняя карточка — заговор")
	var offered: int = trial.rite_offers[0]
	var missing: int = (offered + 1) % _settings.rites.size()
	trial.gold = 1000
	assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.RITE, missing)), "Этого заговора нет в лавке")
	assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.RITE, offered)), "")
	assert_eq(trial.rite_offers[0], -1, "Купленный заговор уходит с прилавка")


func test_night_cleared_early_brings_dawn_at_once() -> void:
	var trial: RitualTrial = _trial(8)
	var plan: RitualNightPlan = trial.plan()
	var last: int = 0
	for pack: RitualPack in plan.packs(1):
		last = maxi(last, pack.last_tick())
	_until(trial, last + 1)
	for base: MobState in trial.field.mobs:
		base.hp = 0
	trial.tick()
	trial.tick()
	assert_false(_settings.is_night(trial.tick_count), "Нежить отбита — сразу рассвет")
	assert_true(trial.tick_count >= _nights.night_end(1))
	assert_eq(trial.nights_survived(), 1)


func test_market_state_survives_snapshot() -> void:
	var trial: RitualTrial = _trial(21)
	trial.gold = 100
	trial.execute(RitualCommand.new(RitualCommand.Action.REROLL))
	var restored: RitualTrial = RitualTrial.from_snapshot(_settings, trial.snapshot())
	assert_eq(restored.offers, trial.offers)
	trial.execute(RitualCommand.new(RitualCommand.Action.REROLL))
	restored.execute(RitualCommand.new(RitualCommand.Action.REROLL))
	assert_eq(restored.offers, trial.offers, "Генератор лавки продолжается одинаково")
	assert_eq(restored.state_hash(), trial.state_hash())


func test_endless_mode_has_no_enchantments() -> void:
	var trial: RitualTrial = _trial(2)
	assert_true(_settings.enchants.is_empty(), "Чары на постройки убраны (выбор автора)")
	trial.execute(RitualCommand.new(RitualCommand.Action.BUY, trial.offers[0], Vector2i(8, 8)))
	assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.ENCHANT, 0, Vector2i.ZERO, 0, 1)),
		"В этом режиме чар нет")


func test_old_trial_keeps_full_shop_and_enchantments() -> void:
	var old: RitualTrialConfig = load("res://data/ritual/trial.tres") as RitualTrialConfig
	var trial: RitualTrial = RitualTrial.new(old, 3)
	assert_eq(old.market_offers, 0)
	assert_true(trial.offers.is_empty())
	assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.BUY, 4, Vector2i(7, 5))), "",
		"Прежний опыт покупает любую постройку")
	assert_false(old.enchants.is_empty())
	assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.REROLL)), "В этом режиме лавка не обновляется")


# --- Шаг 4: слияние до 4-го уровня, поведение по уровню ---


func _place(trial: RitualTrial, id: StringName, cell: Vector2i, level: int) -> TowerState:
	var data: TowerData = null
	for candidate: TowerData in _settings.combat.towers:
		if candidate.id == id:
			data = candidate
	var tower: TowerState = trial.field.add_tower(data, cell, 0)
	tower.level = level
	trial.field.mark_towers_changed()
	return tower


## Враги на верхней прямой дороги (y = 2), шаг 400 тысячных клетки; возвращает их.
func _crowd(trial: RitualTrial, enemy: int, count: int, start: int = 4200) -> Array[RitualMob]:
	var result: Array[RitualMob] = []
	for index: int in count:
		var mob: RitualMob = trial.field.spawn_mob(enemy, 1000)
		mob.progress = start + index * 400
		mob.previous_progress = mob.progress
		result.append(mob)
	return result


func _hurt(mobs: Array[RitualMob]) -> int:
	var count: int = 0
	for mob: RitualMob in mobs:
		count += int(mob.hp < mob.max_hp or mob.status_tags().size() > 0)
	return count


func test_white_stone_fourth_level_only_in_ritual() -> void:
	assert_eq(_settings.combat.max_tower_level, 4, "Белокаменный — 4-й уровень «Обряда»")
	var old: RitualTrialConfig = load("res://data/ritual/trial.tres") as RitualTrialConfig
	assert_eq(old.combat.max_tower_level, 3, "Прежний опыт — до 3")
	var pvp: GameConfig = load("res://data/game_config.tres") as GameConfig
	assert_eq(pvp.max_tower_level, 3, "PvP — до 3")
	assert_eq(_settings.level_names.size(), 4)
	assert_eq(_settings.level_names[3], "Белокаменный")


func test_merge_chain_reaches_white_stone() -> void:
	var trial: RitualTrial = _trial(1)
	var bolt: StringName = &"bolt"
	var cells: Array[Vector2i] = [Vector2i(13, 9), Vector2i(14, 9)]
	for level: int in range(1, 4):
		var first: TowerState = _place(trial, bolt, cells[0], level)
		var second: TowerState = _place(trial, bolt, cells[1], level)
		# MERGE: item — башня, которая растёт; tower_id — сливаемая копия.
		assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.MERGE, second.id, Vector2i.ZERO, 0, first.id)), "")
		assert_eq(second.level, level + 1)
		trial.field.remove_tower(second)
	var top: TowerState = _place(trial, bolt, cells[0], 4)
	var twin: TowerState = _place(trial, bolt, cells[1], 4)
	assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.MERGE, top.id, Vector2i.ZERO, 0, twin.id)),
		"Уровень уже максимальный")


func test_every_ritual_building_has_behavior_for_each_level() -> void:
	for data: TowerData in _settings.combat.towers:
		var levels: RitualBuildingLevels = _settings.levels_for(data)
		assert_not_null(levels, "%s: нет поведения по уровням" % data.id)
		if levels != null:
			assert_eq(levels.levels.size(), _settings.combat.max_tower_level, "%s: по поведению на уровень" % data.id)
			for behavior: RitualLevelBehavior in levels.levels:
				assert_false(behavior.note.is_empty(), "%s: у уровня есть описание" % data.id)


func test_water_house_wets_one_target_then_an_area() -> void:
	for level: int in [1, 2]:
		var trial: RitualTrial = _trial(1)
		_place(trial, &"water", Vector2i(9, 9), level)
		var mobs: Array[RitualMob] = _crowd(trial, 0, 3, 4600)
		trial.field.fire_trial_towers()
		var wet: int = 0
		for mob: RitualMob in mobs:
			wet += int(mob.status_tags().has(&"wet"))
		assert_eq(wet, 1 if level == 1 else 3, "Водяной дом %d-го уровня мочит %d" % [level, 1 if level == 1 else 3])


func test_bolt_second_level_shoots_two_targets() -> void:
	for level: int in [1, 2]:
		var trial: RitualTrial = _trial(1)
		_place(trial, &"bolt", Vector2i(10, 9), level)
		var mobs: Array[RitualMob] = _crowd(trial, 0, 3, 5000)
		trial.field.fire_trial_towers()
		assert_eq(_hurt(mobs), level, "Самострел %d-го уровня бьёт %d целей" % [level, level])


func test_level_damage_follows_behavior_percent() -> void:
	var trial: RitualTrial = _trial(1)
	var bolt: TowerData = _settings.combat.towers[0]
	for level: int in range(1, 5):
		var tower: TowerState = _place(trial, &"bolt", Vector2i(7 + level * 2, 12), level)
		var behavior: RitualLevelBehavior = _settings.levels_for(bolt).levels[level - 1]
		assert_eq(trial.field.get_tower_damage(tower), bolt.damage * behavior.damage_percent / 100 + behavior.damage_add)


func test_white_stone_bolt_pierces_armor() -> void:
	var latnik: int = 6
	assert_true(_settings.enemies[latnik].armor > 0)
	var damages: Array[int] = []
	for level: int in [3, 4]:
		var trial: RitualTrial = _trial(1)
		var tower: TowerState = _place(trial, &"bolt", Vector2i(10, 9), level)
		var mob: RitualMob = _crowd(trial, latnik, 1, 5000)[0]
		trial.field.fire_trial_towers()
		damages.append(mob.max_hp - mob.hp)
		var expected: int = trial.field.get_tower_damage(tower) - (_settings.enemies[latnik].armor if level == 3 else 0)
		assert_eq(mob.max_hp - mob.hp, expected, "Уровень %d: броня %s" % [level, "срезает" if level == 3 else "пробита"])


func test_old_trial_levels_are_unchanged() -> void:
	var old: RitualTrialConfig = load("res://data/ritual/trial.tres") as RitualTrialConfig
	var trial: RitualTrial = RitualTrial.new(old, 3)
	var tower: TowerState = trial.field.add_tower(old.combat.towers[0], Vector2i(10, 3), 0)
	tower.level = 2
	assert_null(old.levels_for(tower.data))
	assert_eq(trial.field.get_tower_damage(tower), old.combat.towers[0].damage * 2)


# --- Шаг 5: заговоры без предела с затуханием, скидка своей стихии ---


func _rite_index(id: StringName) -> int:
	for index: int in _settings.rites.size():
		if _settings.rites[index].id == id:
			return index
	return -1


func _buy_rite(trial: RitualTrial, id: StringName, times: int) -> void:
	for count: int in times:
		trial.gold = 100000
		# Заговор выпадает в лавке — кладём его на прилавок.
		trial.rite_offers.assign([_rite_index(id)])
		assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.RITE, _rite_index(id))), "",
			"Заговор %s №%d" % [id, count + 1])


func test_decay_formula_matches_doc_example() -> void:
	# docs/34 §6: предел +2 клетки, шаг 25% → +0,50 / +0,88 / +1,16 / … / +1,89 за 10.
	var values: Array[int] = []
	for n: int in [0, 1, 2, 3, 10]:
		values.append(RitualRiteCurve.decay(2000, 2500, n))
	assert_eq(values, [0, 500, 875, 1156, 1886])
	var previous: int = 0
	for n: int in range(1, 200):
		var value: int = RitualRiteCurve.decay(2000, 2500, n)
		assert_true(value >= previous and value < 2000, "Растёт и не достигает предела")
		previous = value


func test_rites_have_no_purchase_limit() -> void:
	var trial: RitualTrial = _trial(1)
	_buy_rite(trial, &"war_power", 12)
	assert_eq(trial.rite_count(_rite_index(&"war_power")), 12)


func test_damage_rite_is_linear_and_cost_grows_faster() -> void:
	var trial: RitualTrial = _trial(1)
	var tower: TowerState = _place(trial, &"bolt", Vector2i(10, 9), 1)
	var base: int = trial.field.get_tower_damage(tower)
	var index: int = _rite_index(&"war_power")
	var costs: Array[int] = []
	for n: int in 8:
		costs.append(trial.rite_cost(index))
		_buy_rite(trial, &"war_power", 1)
		trial.field.mark_towers_changed()
		assert_eq(trial.field.get_tower_damage(tower), base * (100 + 10 * (n + 1)) / 100, "Урон линейно +10%")
	for n: int in range(1, costs.size()):
		assert_true(costs[n] > costs[n - 1], "Цена урона растёт")
	assert_true(costs[7] - costs[6] > costs[1] - costs[0], "И растёт всё быстрее")


func test_range_rite_decays_toward_cap() -> void:
	var trial: RitualTrial = _trial(1)
	var tower: TowerState = _place(trial, &"bolt", Vector2i(10, 9), 1)
	var base: int = trial.field.get_tower_range(tower)
	var curve: RitualRiteCurve = _settings.rite_curve(&"war_range")
	assert_not_null(curve)
	_buy_rite(trial, &"war_range", 1)
	trial.field.mark_towers_changed()
	assert_eq(trial.field.get_tower_range(tower), base + 500, "Первый заговор дали — +0,5 клетки")
	_buy_rite(trial, &"war_range", 29)
	trial.field.mark_towers_changed()
	assert_true(trial.field.get_tower_range(tower) < base + curve.cap, "Дом никогда не бьёт на всю арену")
	assert_true(trial.field.get_tower_range(tower) > base + curve.cap * 95 / 100)


func test_targets_and_status_rites_decay_through_idol() -> void:
	var trial: RitualTrial = _trial(1)
	var tower: TowerState = _place(trial, &"bolt", Vector2i(10, 9), 1)
	_buy_rite(trial, &"war_volley", 2)
	assert_eq(trial.field.get_tower_targets(tower), 1, "Пол-цели и ещё треть — пока не целая цель")
	_buy_rite(trial, &"war_volley", 1)
	assert_eq(trial.field.get_tower_targets(tower), 2, "После трёх заговоров — вторая цель")
	_buy_rite(trial, &"war_volley", 40)
	assert_eq(trial.field.get_tower_targets(tower), 2, "Предел 2 цели не достигается")
	_buy_rite(trial, &"ice_cold", 30)
	var ice: IdolState = trial.field.get_idol(&"ice")
	assert_true(ice.status_ticks < _settings.rite_curve(&"ice_cold").cap, "Контроль с пределом")


func test_tempo_rite_shortens_cooldown_with_decay() -> void:
	var trial: RitualTrial = _trial(1)
	var tower: TowerState = _place(trial, &"rime", Vector2i(10, 9), 1)
	var base: int = trial.field.get_tower_cooldown(tower)
	_buy_rite(trial, &"ice_rhythm", 30)
	trial.field.mark_towers_changed()
	var fast: int = trial.field.get_tower_cooldown(tower)
	var cap: int = _settings.rite_curve(&"ice_rhythm").cap
	assert_true(fast < base, "Темп растёт")
	assert_true(fast >= base * 100 / (100 + cap), "Но не выше предела")


func test_own_element_discount_is_small_capped_and_applies_to_buying() -> void:
	var trial: RitualTrial = _trial(1)
	var bolt: int = 0
	var full: int = _settings.costs[bolt]
	assert_eq(trial.building_cost(bolt), full)
	_buy_rite(trial, &"war_power", 1)
	assert_eq(trial.building_cost(bolt), full * (10000 - RitualRiteCurve.decay(_settings.discount_cap_bp,
		_settings.discount_step_bp, 1)) / 10000)
	_buy_rite(trial, &"war_range", 40)
	var discounted: int = trial.building_cost(bolt)
	assert_true(discounted > full * (100 - _settings.discount_cap_bp / 100) / 100 - 1, "Скидка не больше предела")
	assert_true(discounted < full, "Скидка есть")
	assert_eq(trial.building_cost(1), _settings.costs[1], "Чужая стихия без скидки")
	trial.gold = 100
	trial.offers[0] = bolt
	assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.BUY, bolt, Vector2i(8, 8))), "")
	assert_eq(trial.gold, 100 - discounted, "Покупка по цене со скидкой")
	var tower: TowerState = trial.field.towers[0]
	assert_eq(tower.invested_total, discounted, "В доме учтено реально заплаченное")
	trial.execute(RitualCommand.new(RitualCommand.Action.SELL, 0, Vector2i.ZERO, 0, tower.id))
	assert_eq(trial.gold, 100 - discounted + discounted * _settings.sell_percent / 100, "Продажа — половина заплаченного")


func test_old_trial_rites_keep_their_limit() -> void:
	var old: RitualTrialConfig = load("res://data/ritual/trial.tres") as RitualTrialConfig
	var trial: RitualTrial = RitualTrial.new(old, 3)
	for count: int in old.rites[0].max_purchases:
		trial.gold = 1000
		assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.RITE, 0)), "")
	trial.gold = 1000
	assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.RITE, 0)), "Этот заговор уже усилен до предела")
	assert_eq(trial.building_cost(0), old.costs[0], "У прежнего опыта нет скидки стихии")


func test_rite_tooltip_shows_current_next_and_cap() -> void:
	var trial: RitualTrial = _trial(1)
	_buy_rite(trial, &"war_range", 1)
	var text: String = RitualShopPanel.rite_tooltip(trial, _rite_index(&"war_range"))
	assert_string_contains(text, "сейчас +0.50 клетки, со следующим +0.88 клетки (предел +2.00 клетки)")
	assert_string_contains(text, "Скидка на постройки этой стихии: −4%")
	var damage: String = RitualShopPanel.rite_tooltip(trial, _rite_index(&"war_power"))
	assert_string_contains(damage, "без предела")


# --- Шаг 6: износ домов от боя и ремонт ---


func _max_wear(level: int) -> int:
	return _settings.max_durability(level)


func test_new_house_has_full_durability_by_level() -> void:
	var trial: RitualTrial = _trial(1)
	trial.gold = 100
	assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.BUY, trial.offers[0], Vector2i(8, 8))), "")
	assert_eq(trial.field.towers[0].durability, _max_wear(1))
	assert_eq(_max_wear(2), _max_wear(1) * 2, "Прочность растёт как число копий")


func test_house_wears_by_time_in_battle_not_per_shot() -> void:
	var trial: RitualTrial = _trial(1)
	var tower: TowerState = _place(trial, &"bolt", Vector2i(10, 9), 1)
	tower.durability = _max_wear(1)
	trial.field.fire_trial_towers()
	assert_eq(tower.durability, _max_wear(1), "Без врагов дом не изнашивается")
	_crowd(trial, 0, 1, 5000)
	trial.field.fire_trial_towers()
	assert_eq(tower.durability, _max_wear(1) - trial.field.get_tower_cooldown(tower),
		"Выстрел списывает время до следующего — быстрые дома не наказаны")


func test_worn_house_is_weaker_then_silent_but_stays() -> void:
	var trial: RitualTrial = _trial(1)
	var tower: TowerState = _place(trial, &"bolt", Vector2i(10, 9), 1)
	tower.durability = _max_wear(1) / 2 + 1
	var full: int = trial.field.get_tower_damage(tower)
	tower.durability = _max_wear(1) / 2
	assert_eq(trial.field.get_tower_damage(tower), full * _settings.worn_damage_percent / 100, "Ниже половины — слабее")
	tower.durability = 0
	var mob: RitualMob = _crowd(trial, 0, 1, 5000)[0]
	trial.field.fire_trial_towers()
	assert_eq(mob.hp, mob.max_hp, "На нуле дом молчит")
	assert_eq(trial.field.towers.size(), 1, "…но стоит")


func test_splash_does_not_wear_other_houses() -> void:
	var trial: RitualTrial = _trial(1)
	var brazier: TowerState = _place(trial, &"brazier", Vector2i(9, 9), 2)
	var idle: TowerState = _place(trial, &"wind", Vector2i(13, 12), 1)
	brazier.durability = _max_wear(2)
	idle.durability = _max_wear(1)
	_crowd(trial, 0, 3, 4600)
	trial.field.fire_trial_towers()
	assert_true(brazier.durability < _max_wear(2))
	assert_eq(idle.durability, _max_wear(1), "Область и бой не трогают другие дома")


func test_repair_is_cheaper_than_new_and_repair_all_sums() -> void:
	var trial: RitualTrial = _trial(1)
	var first: TowerState = _place(trial, &"bolt", Vector2i(10, 9), 1)
	var second: TowerState = _place(trial, &"bolt", Vector2i(14, 9), 1)
	first.durability = 0
	second.durability = _max_wear(1) / 2
	var one: int = trial.repair_cost(first)
	assert_true(one > 0 and one < _settings.costs[0], "Полный ремонт дешевле новой постройки")
	var total: int = trial.repair_all_cost()
	assert_eq(total, one + trial.repair_cost(second))
	trial.gold = total
	assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.REPAIR_HOUSE, 0, Vector2i.ZERO, 0, 0)), "")
	assert_eq(trial.gold, 0)
	assert_eq(first.durability, _max_wear(1))
	assert_eq(second.durability, _max_wear(1))
	assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.REPAIR_HOUSE, 0, Vector2i.ZERO, 0, first.id)),
		"Дом цел")


func test_repair_gets_own_element_discount() -> void:
	var trial: RitualTrial = _trial(1)
	var tower: TowerState = _place(trial, &"bolt", Vector2i(10, 9), 1)
	tower.durability = 0
	var full: int = trial.repair_cost(tower)
	_buy_rite(trial, &"war_range", 8)
	assert_true(trial.repair_cost(tower) < full, "Ремонт своей стихии дешевле")


func test_merge_adds_durability_and_rescales() -> void:
	var trial: RitualTrial = _trial(1)
	var first: TowerState = _place(trial, &"bolt", Vector2i(13, 9), 1)
	var second: TowerState = _place(trial, &"bolt", Vector2i(14, 9), 1)
	first.durability = 300
	second.durability = 500
	assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.MERGE, second.id, Vector2i.ZERO, 0, first.id)), "")
	assert_eq(second.durability, 800, "Прочность складывается — слияние не бесплатный ремонт")
	assert_eq(second.level, 2)


func test_old_trial_has_no_wear() -> void:
	var old: RitualTrialConfig = load("res://data/ritual/trial.tres") as RitualTrialConfig
	var trial: RitualTrial = RitualTrial.new(old, 0)
	for tower: TowerState in trial.field.towers:
		assert_eq(tower.durability, -1)


# --- Шаг 7: сторожка Ильи ---


func test_breach_hurts_ilya_and_enemy_vanishes() -> void:
	var trial: RitualTrial = _trial(1)
	var mob: RitualMob = trial.field.spawn_mob(0)
	mob.progress = trial.field.get_path_end_progress() - 10
	mob.previous_progress = mob.progress
	trial.tick()
	assert_eq(trial.hp, _settings.hero_hp - _settings.enemies[0].breach_damage, "Враг дошёл — Илья теряет HP")
	assert_false(mob.is_alive(), "Враг исчез: его убил Илья")


func test_ilya_death_is_immediate_defeat() -> void:
	var trial: RitualTrial = _trial(1)
	trial.hp = 1
	var mob: RitualMob = trial.field.spawn_mob(0)
	mob.progress = trial.field.get_path_end_progress() - 10
	trial.tick()
	assert_eq(trial.phase, RitualTrial.Phase.OVER)
	assert_eq(trial.result, "Илья пал")


func test_old_terem_repair_heals_ilya() -> void:
	var trial: RitualTrial = _trial(1)
	trial.hp = 30
	trial.gold = 100
	assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.REPAIR)), "")
	assert_eq(trial.hp, 30 + _settings.repair_hp)
	trial.hp = _settings.hero_hp
	assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.REPAIR)), "Илья здоров")


# --- Шаг 8: дары за боссов ---


func _kill_boss(trial: RitualTrial) -> void:
	var boss: RitualMob = trial.field.spawn_mob(_nights.boss_enemy)
	trial.field.deal_mob_damage(boss, boss.hp * 10)


func _gift_index(effect: RitualGiftData.Effect, god: StringName = &"") -> int:
	for index: int in _settings.gifts.size():
		var gift: RitualGiftData = _settings.gifts[index]
		if gift.effect == effect and (god == &"" or gift.god == god):
			return index
	return -1


func _take(trial: RitualTrial, gift: int) -> void:
	trial.gift_choice = [gift]
	assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.GIFT, gift)), "")


func test_gift_set_is_data_with_eight_to_fourteen_gifts() -> void:
	assert_true(_settings.gifts.size() >= 8 and _settings.gifts.size() <= 14)
	for gift: RitualGiftData in _settings.gifts:
		assert_false(gift.display_name.is_empty() or gift.description.is_empty())


func test_boss_kill_pauses_with_three_distinct_seeded_gifts() -> void:
	var first: RitualTrial = _trial(31)
	var second: RitualTrial = _trial(31)
	_kill_boss(first)
	_kill_boss(second)
	assert_eq(first.gift_choice.size(), 3)
	assert_eq(first.gift_choice, second.gift_choice, "Один сид — те же дары")
	var unique: Dictionary[int, bool] = {}
	for gift: int in first.gift_choice:
		unique[gift] = true
	assert_eq(unique.size(), 3, "Без повторов")
	var tick: int = first.tick_count
	first.tick()
	assert_eq(first.tick_count, tick, "Пока дар не выбран — игра на паузе")
	assert_eq(first.execute(RitualCommand.new(RitualCommand.Action.GIFT, 999)), "Этого дара нет в выборе")
	var chosen: int = first.gift_choice[1]
	assert_eq(first.execute(RitualCommand.new(RitualCommand.Action.GIFT, chosen)), "")
	assert_true(first.gift_choice.is_empty())
	assert_true(first.gifts_taken.has(chosen))
	first.tick()
	assert_eq(first.tick_count, tick + 1, "После выбора игра идёт")
	_kill_boss(first)
	assert_false(first.gift_choice.has(chosen), "Взятый дар больше не предлагается")


func test_gift_damage_all_and_god_fury() -> void:
	var trial: RitualTrial = _trial(1)
	var bolt: TowerState = _place(trial, &"bolt", Vector2i(10, 9), 1)
	var fire: TowerState = _place(trial, &"brazier", Vector2i(14, 9), 1)
	var bolt_base: int = trial.field.get_tower_damage(bolt)
	var fire_base: int = trial.field.get_tower_damage(fire)
	_take(trial, _gift_index(RitualGiftData.Effect.DAMAGE_ALL))
	assert_eq(trial.field.get_tower_damage(bolt), bolt_base * 150 / 100, "Урон всех ×1,5")
	_take(trial, _gift_index(RitualGiftData.Effect.DAMAGE_GOD, &"svarog"))
	assert_eq(trial.field.get_tower_damage(fire), fire_base * 250 / 100, "Гнев стихии складывается с общим")
	assert_eq(trial.field.get_tower_damage(bolt), bolt_base * 150 / 100)


func test_gift_water_houses_hit_an_area() -> void:
	var trial: RitualTrial = _trial(1)
	_take(trial, _gift_index(RitualGiftData.Effect.SPLASH_GOD, &"water"))
	_place(trial, &"water", Vector2i(9, 9), 1)
	var mobs: Array[RitualMob] = _crowd(trial, 0, 3, 4600)
	trial.field.fire_trial_towers()
	var wet: int = 0
	for mob: RitualMob in mobs:
		wet += int(mob.status_tags().has(&"wet"))
	assert_eq(wet, 3, "С даром водяной дом 1-го уровня мочит область")


func test_gift_ilya_strikes_twice() -> void:
	var single: RitualTrial = _trial(1)
	var double: RitualTrial = _trial(1)
	_take(double, _gift_index(RitualGiftData.Effect.HERO_TWICE))
	var hurt: Array[int] = []
	for trial: RitualTrial in [single, double]:
		var mob: RitualMob = _crowd(trial, 2, 1, 5000)[0]
		trial.tick_count = trial.hero_ready
		assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.SKILL, 0, Vector2i.ZERO, 0, 0, 5000)), "")
		trial.hp = 1000000
		for step: int in _settings.hero_warning + 1:
			trial.tick()
		hurt.append(mob.max_hp - mob.hp)
	assert_true(hurt[1] > hurt[0] * 3 / 2, "Илья бьёт дважды: %s" % str(hurt))


func test_gift_free_repair_lasts_two_nights_and_double_discount() -> void:
	var trial: RitualTrial = _trial(1)
	var tower: TowerState = _place(trial, &"bolt", Vector2i(10, 9), 1)
	tower.durability = 0
	_buy_rite(trial, &"war_range", 4)
	var discount: int = trial.discount_bp(&"war")
	_take(trial, _gift_index(RitualGiftData.Effect.DOUBLE_DISCOUNT))
	assert_eq(trial.discount_bp(&"war"), discount * 2, "Скидка стихии удвоена")
	_take(trial, _gift_index(RitualGiftData.Effect.FREE_REPAIR))
	assert_eq(trial.repair_cost(tower), 0, "Ремонт бесплатен")
	trial.tick_count = _nights.night_end(trial.current_night() + 1) - 1
	assert_eq(trial.repair_cost(tower), 0, "…ещё в следующую ночь")
	trial.tick_count = _nights.night_end(trial.current_night()) + 1
	assert_true(trial.repair_cost(tower) > 0, "…а потом снова платный")


func test_gifts_survive_snapshot() -> void:
	var trial: RitualTrial = _trial(1)
	var tower: TowerState = _place(trial, &"bolt", Vector2i(10, 9), 1)
	_take(trial, _gift_index(RitualGiftData.Effect.DAMAGE_ALL))
	var restored: RitualTrial = RitualTrial.from_snapshot(_settings, trial.snapshot())
	assert_eq(restored.field.get_tower_damage(restored.field.get_tower(tower.id)), trial.field.get_tower_damage(tower))


func test_boss_health_grows_per_appearance_not_per_night() -> void:
	assert_eq(_nights.boss_hp_percent(_nights.boss_every), 100, "Первый босс — базовое здоровье")
	assert_eq(_nights.boss_hp_percent(_nights.boss_every * 2), 100 + _nights.boss_hp_growth_percent)
	var trial: RitualTrial = _trial(5)
	for pack: RitualPack in trial.plan().packs(_nights.boss_every):
		if pack.boss:
			assert_eq(pack.hp_for(_nights.boss_enemy, _nights.boss_enemy), 100)
			assert_true(pack.hp_for(pack.members[0], _nights.boss_enemy) > 100, "Свита растёт по ночам")


# --- Плейтест 9 ноября: ночная стройка дороже и дольше, перенос ночью дольше ---


func _at_night(trial: RitualTrial) -> void:
	trial.hp = 1000000
	while not _settings.is_night(trial.tick_count):
		trial.tick()
	trial.field.mobs.clear()


func test_night_building_costs_more_and_installs_longer() -> void:
	var day: RitualTrial = _trial(3)
	var night: RitualTrial = _trial(3)
	_at_night(night)
	night.offers = day.offers.duplicate()
	var index: int = day.offers[0]
	assert_eq(night.building_cost(index), day.building_cost(index) * _settings.night_cost_percent / 100,
		"Ночью дороже")
	assert_true(_settings.night_cost_percent > 100)
	day.gold = 100
	night.gold = 100
	assert_eq(day.execute(RitualCommand.new(RitualCommand.Action.BUY, index, Vector2i(8, 8))), "")
	assert_eq(night.execute(RitualCommand.new(RitualCommand.Action.BUY, index, Vector2i(8, 8))), "")
	assert_eq(day.field.towers[0].action_lock_ticks, _settings.install_ticks)
	assert_eq(night.field.towers[0].action_lock_ticks, _settings.night_install_ticks, "Ночью ставится дольше")
	assert_true(_settings.night_install_ticks > _settings.install_ticks * 2)


func test_night_move_takes_much_longer() -> void:
	var trial: RitualTrial = _trial(3)
	var tower: TowerState = _place(trial, &"bolt", Vector2i(10, 9), 1)
	assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.MOVE, 0, Vector2i(12, 9), 0, tower.id)), "")
	assert_eq(tower.action_lock_ticks, _settings.install_ticks, "Днём перенос быстрый")
	_at_night(trial)
	assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.MOVE, 0, Vector2i(14, 9), 0, tower.id)), "")
	assert_eq(tower.action_lock_ticks, _settings.night_move_ticks, "Ночью перенос значительно дольше")
	assert_true(_settings.night_move_ticks >= _settings.install_ticks * 5)


func test_packs_are_big_and_mixed_from_first_night() -> void:
	for seed_value: int in range(1, 9):
		var plan: RitualNightPlan = RitualNightPlan.new(_settings, seed_value)
		for pack: RitualPack in plan.packs(1):
			assert_true(pack.members.size() >= 8, "Сид %d: пачка первой ночи не мелкая (%d)" % [seed_value, pack.members.size()])
			var kinds: Dictionary[int, bool] = {}
			for member: int in pack.members:
				kinds[member] = true
			assert_true(kinds.size() >= 2, "Сид %d: в пачке разные враги" % seed_value)


func test_days_and_nights_are_long_enough_to_play() -> void:
	assert_true(_nights.night_length(1) >= 20 * 50, "Первая ночь не короче 50 с")
	assert_true(_nights.day_ticks >= 20 * 20, "День — передышка на стройку")
	assert_true(_nights.first_evening_ticks >= 20 * 25)


func test_perun_and_curse_houses_fight_in_the_run() -> void:
	for id: StringName in [&"spark", &"thunder", &"hex", &"plague"]:
		var data: TowerData = null
		for candidate: TowerData in _settings.combat.towers:
			if candidate.id == id:
				data = candidate
		assert_not_null(data, "%s в наборе забега" % id)
		var levels: RitualBuildingLevels = _settings.levels_for(data)
		assert_not_null(levels, "Уровни для %s" % id)
		assert_eq(levels.levels.size(), 4, "%s: деревянный → белокаменный" % id)
	# Молния: по мокрым цепь почти всегда задевает второго.
	var trial: RitualTrial = _trial(1)
	var spark: TowerState = _place(trial, &"spark", Vector2i(9, 9), 1)
	var wet: Array[RitualMob] = _crowd(trial, 2, 2, 4600)
	for shot: int in 5:
		for mob: RitualMob in wet:
			mob.wet_ticks_left = 200
		spark.cooldown_left = 0
		trial.field.fire_trial_towers()
	assert_eq(_hurt(wet), 2, "Искровик цепью бьёт и вторую мокрую цель")
	# Чёрная метка 3-го уровня метит трёх сразу, метка взрывается.
	var cursed: RitualTrial = _trial(1)
	_place(cursed, &"hex", Vector2i(9, 9), 3)
	var mobs: Array[RitualMob] = _crowd(cursed, 2, 3, 4600)
	cursed.field.fire_trial_towers()
	var marked: int = 0
	for mob: RitualMob in mobs:
		marked += int(mob.status_tags().has(&"curse"))
	assert_eq(marked, 3, "Три метки на 3-м уровне")
	var before: int = mobs[0].hp
	for step: int in 70:
		cursed.field.finish_tick()
	assert_true(mobs[0].hp < before, "Метка взорвалась уроном")


func test_perun_and_curse_rites_strengthen_their_idol() -> void:
	var trial: RitualTrial = _trial(1)
	_buy_rite(trial, &"perun_charge", 2)
	_buy_rite(trial, &"curse_mark", 4)
	var perun: IdolState = trial.field.get_idol(&"perun")
	var curse: IdolState = trial.field.get_idol(&"curse")
	assert_true(perun.chain_chance_bonus > 0 and perun.chain_chance_bonus < 40, "Шанс цепи растёт с затуханием")
	assert_true(curse.extra_targets >= 1 and curse.extra_targets < 2, "Метка берёт больше целей, не до предела")

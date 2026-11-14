extends GutTest
## docs/37: усиления на рассвете (D4), бонус за чистую ночь (ECO-3), рост удара Ильи (HER-3),
## дары по городу (BOS-2), покупка припасов днём (SUP-2).

var _settings: RitualTrialConfig
var _trial: RitualTrial


func before_each() -> void:
	_settings = load("res://data/ritual/endless.tres") as RitualTrialConfig
	_trial = RitualTrial.new(_settings, 0, 7)
	_trial.hp = 100000


func _to_dawn(dawn: int) -> void:
	var night: RitualNightRules = _settings.nights
	while _trial.nights_survived() < dawn and _trial.phase == RitualTrial.Phase.RUNNING:
		if not _trial.gift_choice.is_empty():
			_trial.execute(RitualCommand.new(RitualCommand.Action.GIFT, _trial.gift_choice[0]))
		_trial.tick()
	assert_eq(_trial.nights_survived(), dawn)
	assert_false(night.is_night(_trial.tick_count))


func test_dawn_offers_boons_that_expire_at_night() -> void:
	assert_false(_settings.boons.is_empty())
	_to_dawn(1)
	assert_eq(_trial.boon_choice.size(), _settings.boon_choices, "На рассвете — выбор усилений")
	var offered: Array[int] = _trial.boon_choice.duplicate()
	var tick: int = _trial.tick_count
	_trial.tick()
	assert_eq(_trial.tick_count, tick + 1, "Выбор не останавливает день")
	while not _settings.is_night(_trial.tick_count):
		_trial.tick()
	_trial.tick()
	assert_true(_trial.boon_choice.is_empty(), "Невыбранное сгорает к ночи")
	assert_ne(_trial.execute(RitualCommand.new(RitualCommand.Action.BOON, offered[0])), "")


func test_taking_a_boon_applies_it_once() -> void:
	_to_dawn(1)
	var index: int = _trial.boon_choice[0]
	var gold: int = _trial.gold
	assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.BOON, index)), "")
	assert_eq(_trial.boons_taken, [index])
	assert_true(_trial.boon_choice.is_empty(), "Одно усиление за рассвет")
	assert_ne(_trial.execute(RitualCommand.new(RitualCommand.Action.BOON, index)), "")
	assert_true(_trial.gold >= gold)


func test_god_boons_only_for_owned_buildings() -> void:
	for dawn: int in range(1, 6):
		_to_dawn(dawn)
		for index: int in _trial.boon_choice:
			var boon: RitualGiftData = _settings.boons[index]
			if boon.effect in [RitualGiftData.Effect.DAMAGE_GOD, RitualGiftData.Effect.SPLASH_GOD]:
				var owned: bool = false
				for tower: TowerState in _trial.field.towers:
					owned = owned or tower.data.god == boon.god
				assert_true(owned, "Усиление %s без своих домов" % boon.id)


func test_clean_night_pays_bonus_and_leak_cancels_it() -> void:
	assert_true(_settings.clean_night_gold > 0)
	_to_dawn(1)
	var expected: int = _settings.clean_night_gold + _settings.clean_night_gold_per_night * 1
	assert_eq(_trial.last_clean_bonus, expected if _trial.night_leaks_last == 0 else 0)
	var mob: RitualMob = _trial.field.spawn_mob(0, 100)
	mob.progress = _trial.field.get_mob_end_progress(mob)
	while not _settings.is_night(_trial.tick_count):
		_trial.tick()
	_to_dawn(2)
	assert_true(_trial.night_leaks_last > 0 or _trial.last_clean_bonus > 0)


func test_ilya_strike_cap_grows_with_nights() -> void:
	var ilya: RitualHeroData = _trial.hero()
	assert_true(ilya.cap_growth_percent > 0)
	var first: int = _trial.hero_cap()
	_to_dawn(5)
	assert_true(_trial.hero_cap() > first * 3 / 2, "К пятой ночи предел удара заметно выше")


func test_supplies_can_be_bought_by_day_only() -> void:
	assert_eq(_settings.supply_costs.size(), 3)
	_trial.gold = 1000
	_trial.supplies = [0, 0, 0]
	assert_eq(_trial.execute(RitualCommand.new(RitualCommand.Action.BUY_SUPPLY, RitualTrial.Supply.TAR)), "")
	assert_eq(_trial.supplies[RitualTrial.Supply.TAR], 1)
	assert_eq(_trial.gold, 1000 - _settings.supply_costs[0])
	while not _settings.is_night(_trial.tick_count):
		_trial.tick()
	assert_ne(_trial.execute(RitualCommand.new(RitualCommand.Action.BUY_SUPPLY, RitualTrial.Supply.TAR)), "",
		"Ночью мастера спят")


func test_god_gifts_follow_the_city() -> void:
	_trial.gold = 10000
	var cells: Array[Vector2i] = _trial.field.get_buildable_cells()
	_trial.execute(RitualCommand.new(RitualCommand.Action.BUY, 0, cells[0]))
	_trial.execute(RitualCommand.new(RitualCommand.Action.BUY, 0, cells[1]))
	var god: StringName = _settings.combat.towers[0].god
	var seen_own: int = 0
	for attempt: int in 12:
		_trial.offer_gifts_now()
		assert_eq(_trial.gift_choice.size(), _settings.gift_choices)
		for index: int in _trial.gift_choice:
			var gift: RitualGiftData = _settings.gifts[index]
			if gift.effect in [RitualGiftData.Effect.DAMAGE_GOD, RitualGiftData.Effect.SPLASH_GOD]:
				assert_eq(gift.god, god, "Дар стихии — только той, что есть в городе")
				seen_own += 1
	assert_true(seen_own > 0, "Дар своей стихии хоть раз предложен")


func test_snapshot_keeps_boon_state() -> void:
	_to_dawn(1)
	var restored: RitualTrial = RitualTrial.from_snapshot(_settings, _trial.snapshot())
	assert_eq(restored.boon_choice, _trial.boon_choice)
	assert_eq(restored.state_hash(), _trial.state_hash())

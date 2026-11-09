extends GutTest
## Герои бесконечного «Обряда» (docs/36 §1): выбор перед забегом, своё HP, навык и пассивка.

const ILYA: int = 0
const SOLOVEY: int = 1
const YAGA: int = 2

var _settings: RitualTrialConfig


func before_each() -> void:
	_settings = load("res://data/ritual/endless.tres") as RitualTrialConfig


func _trial(hero: int, run_seed: int = 3) -> RitualTrial:
	return RitualTrial.new(_settings, 0, run_seed, hero)


func _until(trial: RitualTrial, tick: int) -> void:
	while trial.tick_count < tick and trial.phase == RitualTrial.Phase.RUNNING:
		trial.tick()


func _mob(trial: RitualTrial, enemy: int, progress: int) -> RitualMob:
	var mob: RitualMob = trial.field.spawn_mob(enemy, 1000)
	mob.progress = progress
	mob.previous_progress = progress
	return mob


func test_three_heroes_with_own_health_and_names() -> void:
	assert_eq(_settings.heroes.size(), 3)
	var ilya: RitualTrial = _trial(ILYA)
	var yaga: RitualTrial = _trial(YAGA)
	assert_eq(ilya.hero().id, &"ilya", "По умолчанию — Илья")
	assert_eq(ilya.hp, 50)
	assert_eq(yaga.hp, 40, "У Яги своё здоровье")
	assert_eq(yaga.max_hp(), 40, "Лечение не выше её предела")
	yaga.hp = 1
	yaga.field.mob_breached.emit(_mob(yaga, 0, 0))
	assert_eq(yaga.result, "Баба-Яга пала")


func test_solovey_whistle_pushes_back_and_stuns_boss_half() -> void:
	var trial: RitualTrial = _trial(SOLOVEY)
	trial.hp = 100000
	trial.tick_count = _settings.nights.night_start(1)
	var hero: RitualHeroData = trial.hero()
	var mob: RitualMob = _mob(trial, 0, 6000)
	var boss: RitualMob = _mob(trial, _settings.nights.boss_enemy, 6200)
	var hp: int = mob.hp
	assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.SKILL, 0, Vector2i.ZERO, 0, 0, 6000)), "")
	# Замах: warning_ticks тиков враги ещё идут, свист — на следующем тике.
	for step: int in hero.warning_ticks:
		trial.tick()
	var before: int = mob.progress
	var boss_before: int = boss.progress
	trial.tick()
	assert_true(mob.progress <= before - hero.knockback_milli + 100, "Отброшен на 3 клетки: %d → %d" % [before, mob.progress])
	assert_true(boss.progress > boss_before - hero.knockback_milli, "Босс отлетает ближе")
	assert_true(mob.stun_ticks_left > 0, "Оглушён")
	assert_eq(mob.hp, hp, "Свист не ранит")
	var stunned_at: int = mob.progress
	trial.tick()
	assert_eq(mob.progress, stunned_at, "Оглушённый стоит")


func test_solovey_gets_palisade_each_dawn_up_to_two() -> void:
	var trial: RitualTrial = _trial(SOLOVEY)
	trial.hp = 100000
	var start: int = trial.palisades
	_until(trial, _settings.nights.night_end(1) + 1)
	assert_true(trial.palisades >= start + 1, "Засека на рассвете")
	_until(trial, _settings.nights.night_end(3) + 1)
	assert_true(trial.palisades <= 2 or _settings.nights.is_boss_night(4), "Запас засек не больше двух")
	var ilya: RitualTrial = _trial(ILYA)
	ilya.hp = 100000
	_until(ilya, _settings.nights.night_end(1) + 1)
	assert_eq(ilya.palisades, 0, "У Ильи засек нет")


func test_yaga_rerolls_twice_a_day_for_free() -> void:
	var trial: RitualTrial = _trial(YAGA)
	var gold: int = trial.gold
	for free: int in 2:
		assert_eq(trial.reroll_cost(), 0)
		assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.REROLL)), "")
	assert_eq(trial.gold, gold, "Два обновления бесплатно")
	assert_eq(trial.reroll_cost(), _settings.reroll_cost, "Третье — по обычной цене")
	assert_eq(_trial(ILYA).reroll_cost(), _settings.reroll_cost, "У Ильи бесплатных нет")


func test_yaga_brew_makes_next_building_stone() -> void:
	var trial: RitualTrial = _trial(YAGA)
	trial.gold = 1000
	assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.SKILL)), "", "Варево без точки дороги")
	assert_eq(trial.brew_charges, 1)
	assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.SKILL)), "Варево ещё не готово")
	assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.BUY, trial.offers[0], Vector2i(8, 8))), "")
	assert_eq(trial.field.towers[0].level, 2, "Первая после варева — каменная")
	assert_eq(trial.brew_charges, 0)
	assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.BUY, trial.offers[1], Vector2i(13, 8))), "")
	assert_eq(trial.field.towers[1].level, 1, "Следующая — обычная")


func test_hero_survives_snapshot() -> void:
	var trial: RitualTrial = _trial(YAGA)
	trial.execute(RitualCommand.new(RitualCommand.Action.SKILL))
	var copy: RitualTrial = RitualTrial.from_snapshot(_settings, trial.snapshot())
	assert_not_null(copy)
	assert_eq(copy.hero().id, &"baba_yaga")
	assert_eq(copy.brew_charges, 1)
	assert_eq(copy.state_hash(), trial.state_hash())

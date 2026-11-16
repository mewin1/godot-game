extends GutTest
## Кривая давления бесконечного "Обряда" (docs/37 ECO-1, ECO-5, ECO-6, ECO-8): ночи растут ровно,
## награда за ночь не падает, примета меняет состав, а не силу ночи.

const SEEDS: Array[int] = [1, 2, 3, 4, 5]
const NIGHTS: int = 30
var _settings: RitualTrialConfig
var _rules: RitualNightRules


func before_each() -> void:
	_settings = load("res://data/ritual/endless.tres") as RitualTrialConfig
	_rules = _settings.nights


func test_endless_curve_is_smooth() -> void:
	for seed_value: int in SEEDS:
		var plan: RitualNightPlan = RitualNightPlan.new(_settings, seed_value)
		var health: Array[int] = [0]
		var gold: Array[int] = [0]
		for night: int in range(1, NIGHTS + 1):
			health.append(plan.total_ehp(night))
			gold.append(plan.total_gold(night))
		for night: int in range(2, NIGHTS + 1):
			var place: String = "сид %d, ночь %d" % [seed_value, night]
			assert_true(gold[night] >= gold[night - 1], "Награда за ночь не падает: " + place)
			var ratio: int = health[night] * 100 / health[night - 1]
			if _rules.is_boss_night(night):
				assert_between(ratio, 125, 160, "Ночь босса - не больше x1,60 к прошлой: " + place)
			elif _rules.is_boss_night(night - 1):
				# После босса сравнение через ночь: босс поднимает одну ночь, а не кривую.
				assert_between(health[night] * 100 / health[night - 2], 156, 196, "Две ночи после босса: " + place)
			else:
				# Плейтест 19 ноября: «слишком легко» — давление x1,36 за ночь (было x1,29, цель docs/37 x1,10-1,30).
				assert_between(ratio, 125, 145, "Ночь к ночи x1,25-x1,45: " + place)


func test_omen_changes_composition_not_strength() -> void:
	var plan: RitualNightPlan = RitualNightPlan.new(_settings, 915701)
	for night: int in range(1, NIGHTS + 1):
		if _rules.is_boss_night(night):
			continue
		var target: int = _rules.pressure(night)
		assert_between(plan.total_ehp(night), target * 9 / 10, target * 11 / 10,
			"Ночь %d (%s) в пределах 10%% кривой" % [night, plan.omen(night).title if plan.omen(night) != null else "без приметы"])


func test_full_packs_turn_extra_budget_into_packs_then_elites() -> void:
	var plan: RitualNightPlan = RitualNightPlan.new(_settings, 1)
	var night: int = NIGHTS
	var packs: Array[RitualPack] = plan.packs(night)
	var ordinary: int = 0
	for pack: RitualPack in packs:
		ordinary += int(not pack.boss)
	assert_eq(ordinary, _rules.packs_max + (plan.omen(night).packs_add if plan.omen(night) != null else 0),
		"Сначала пачек больше, до предела ночи")
	var elites: int = 0
	for pack: RitualPack in packs:
		assert_true(pack.members.size() <= _rules.pack_max_size + int(pack.boss), "Сам босс - сверх полной пачки")
		assert_eq(pack.elite.size(), pack.members.size())
		for rank: int in pack.elite:
			elites += int(rank > 0)
	assert_true(elites > 0, "Бюджет сверх полных пачек - элита, а не скрытое здоровье")


func test_elite_spawns_with_more_health_and_bounty() -> void:
	var plan: RitualNightPlan = RitualNightPlan.new(_settings, 1)
	var pack: RitualPack = null
	var slot: int = -1
	for candidate: RitualPack in plan.packs(NIGHTS):
		slot = candidate.elite.find(1)
		if slot >= 0 and not candidate.boss:
			pack = candidate
			break
	assert_not_null(pack, "К 30-й ночи есть элита")
	var plain: int = pack.elite.find(0)
	if plain >= 0 and pack.members[plain] == pack.members[slot]:
		assert_eq(pack.hp_at(slot, _rules.boss_enemy), pack.hp_at(plain, _rules.boss_enemy) * 3)
	assert_true(pack.bounties[slot] > 0)
	var trial: RitualTrial = RitualTrial.new(_settings, 0, 1)
	var mob: RitualMob = trial.spawn_from_pack(pack, slot)
	assert_eq(mob.elite_rank, 1, "Элиту видно на враге (корона)")
	assert_eq(mob.kill_reward, pack.bounties[slot])


func test_endless_ward_takes_damage_from_spark_and_rime() -> void:
	_assert_ward_damage(&"spark", 20)
	_assert_ward_damage(&"rime", 10)


func test_endless_ward_keeps_fire_and_accepts_physical_and_other_elements() -> void:
	_assert_ward_damage(&"brazier", 80)
	_assert_ward_damage(&"bolt", 40)
	_assert_ward_damage(&"wind", 10)
	_assert_ward_damage(&"water", 10)
	_assert_ward_damage(&"hex", 10)
	_assert_ward_damage(&"plague", 10)


func test_scout_explains_ward_damage_and_counts_elite_members() -> void:
	var trial: RitualTrial = RitualTrial.new(_settings, 0, 1)
	var pack: RitualPack = RitualPack.new()
	pack.members = [3, 3, 3]
	pack.leader = 3
	pack.elite = [0, 1, 1]
	var tip: String = RitualScoutQueue.describe(trial, pack)
	assert_string_contains(tip, "Обереги: 3 (огонь 200%, физика 100%, молния 50%, прочее 25%)")
	assert_string_contains(tip, "Элита: 2 (здоровье и награда x3)")
	pack.elite = [0, 0, 0]
	assert_false(RitualScoutQueue.describe(trial, pack).contains("Элита:"))


func test_trial_ward_keeps_original_percentages() -> void:
	var settings: RitualTrialConfig = load("res://data/ritual/trial.tres") as RitualTrialConfig
	assert_eq(settings.ward_physical_percent, 25)
	assert_eq(settings.ward_lightning_percent, 0)
	assert_eq(settings.ward_other_percent, 0)
	var trial: RitualTrial = RitualTrial.new(settings, 0, 1)
	var mob: RitualMob = trial.field.spawn_mob(3)
	for data: TowerData in _settings.combat.towers:
		if data.id in [&"spark", &"rime"]:
			trial.field._hit(mob, 40, data)
	assert_eq(mob.ward_hp, settings.ward_hp, "В прежнем опыте Искра и Иней не ранят оберег")


func _assert_ward_damage(tower_id: StringName, expected: int) -> void:
	var trial: RitualTrial = RitualTrial.new(_settings, 0, 1)
	var warded: int = -1
	for index: int in _settings.enemies.size():
		if _settings.enemies[index].tags.has(_settings.ward_tag):
			warded = index
			break
	assert_true(warded >= 0, "В активных правилах есть враг с оберегом")
	if warded < 0:
		return
	var mob: RitualMob = trial.field.spawn_mob(warded)
	var body_hp: int = mob.hp
	var ward_hp: int = mob.ward_hp
	var data: TowerData = null
	for candidate: TowerData in _settings.combat.towers:
		if candidate.id == tower_id:
			data = candidate
			break
	assert_not_null(data, "Постройка есть в активном каталоге: " + tower_id)
	if data == null:
		return
	trial.field._hit(mob, 40, data)
	assert_eq(ward_hp - mob.ward_hp, expected, "Урон оберегу: " + tower_id)
	assert_eq(mob.hp, body_hp, "Оберег защищает тело: " + tower_id)
	assert_eq(mob.burn_ticks_left + mob.cold_ticks_left + mob.charge_ticks_left
		+ mob.wet_ticks_left + mob.curse_ticks_left, 0, "Оберег блокирует статусы: " + tower_id)

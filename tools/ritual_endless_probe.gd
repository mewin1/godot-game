extends SceneTree
## Темп бесконечного «Обряда» (docs/34 §14, шаг 9): сколько живут простые политики игрока.
## Боты — только ориентир; баланс проверяет автор живой игрой.
## Запуск: godot --headless --path . -s res://tools/ritual_endless_probe.gd [-- --seeds=1,2,3]

## Копия правил: аргументы `-- --pressure=29 --budget=14 --boss=1800` меняют рост давления/бюджета ночей
## и здоровье босса; `--base`, `--gold`, `--spread`, `--kill=150` (награда в процентах), `--escort` (свита босса,
## % бюджета ночи) — тоже только в этом прогоне.
## Бот покупает улицы (ключ `--streets`): днём, со 2-й ночи, если останется запас.
var _streets: bool = false
## `--trace`: кто ранил героя по ночам (вид врага → урон).
var _trace: bool = false
var _record: bool = false
## docs/37 P7: строка BALANCE с показателями таблицы целей §3 (ключ --report).
var _report: bool = false
## Политика «реакции»: дом, дающий реакцию с соседом в досягаемости, ценится выше (A/B к «разумным»).
var _aware: bool = false
## --nights=N завершает технический прогон после N рассветов, без изменения правил.
var _night_limit: int = 0
var SETTINGS: RitualTrialConfig = (load("res://data/ritual/endless.tres") as RitualTrialConfig).duplicate(true)
const TPS: int = 20
const LIMIT_TICKS: int = 20 * 60 * 90


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var seeds: Array[int] = [1, 2, 3]
	var only: String = ""
	var heroes: Array[int] = [0]
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--pressure="):
			SETTINGS.nights.pressure_growth_percent = argument.trim_prefix("--pressure=").to_int()
		if argument.begins_with("--budget="):
			SETTINGS.nights.budget_growth_percent = argument.trim_prefix("--budget=").to_int()
		if argument.begins_with("--packs="):
			SETTINGS.nights.packs_growth_every = argument.trim_prefix("--packs=").to_int()
		if argument.begins_with("--base="):
			SETTINGS.nights.budget_base = argument.trim_prefix("--base=").to_int()
		if argument.begins_with("--boss="):
			SETTINGS.enemies[SETTINGS.nights.boss_enemy].hp = argument.trim_prefix("--boss=").to_int()
		if argument.begins_with("--gold="):
			SETTINGS.start_gold = argument.trim_prefix("--gold=").to_int()
		if argument.begins_with("--spread="):
			SETTINGS.nights.spread_percent = argument.trim_prefix("--spread=").to_int()
		if argument.begins_with("--kill="):
			for enemy: MobData in SETTINGS.enemies:
				enemy.kill_reward = maxi(1, enemy.kill_reward * argument.trim_prefix("--kill=").to_int() / 100)
		if argument.begins_with("--heroes="):
			heroes.clear()
			for part: String in argument.trim_prefix("--heroes=").split(","):
				heroes.append(part.to_int())
		if argument.begins_with("--escort="):
			SETTINGS.nights.boss_escort_percent = argument.trim_prefix("--escort=").to_int()
		if argument == "--trace":
			_trace = true
		if argument == "--record":
			_record = true
		if argument == "--report":
			_report = true
		if argument.begins_with("--nights="):
			_night_limit = maxi(0, argument.trim_prefix("--nights=").to_int())
		if argument == "--streets":
			_streets = true
		if argument.begins_with("--only="):
			only = argument.trim_prefix("--only=")
		if argument.begins_with("--seeds="):
			seeds.clear()
			for part: String in argument.trim_prefix("--seeds=").split(","):
				seeds.append(part.to_int())
	print("ENDLESS: рост давления %d%%, бюджета %d%% от %d, пачка +1 за %d ночи, босс %d HP" % [
		SETTINGS.nights.pressure_growth_percent, SETTINGS.nights.budget_growth_percent, SETTINGS.nights.budget_base,
		SETTINGS.nights.packs_growth_every, SETTINGS.enemies[SETTINGS.nights.boss_enemy].hp])
	if _report:
		_print_curve()
	for policy: String in ["ничего", "разумные траты", "реакции"]:
		if not only.is_empty() and not policy.contains(only):
			continue
		for hero: int in heroes:
			for seed_value: int in seeds:
				_play(policy, seed_value, hero)
	quit()


func _play(policy: String, seed_value: int, hero: int = 0) -> void:
	var trial: RitualTrial = RitualTrial.new(SETTINGS, 0, seed_value, hero)
	_aware = policy == "реакции"
	var stats: RitualRunStats = RitualRunStats.new()
	stats.watch(trial.field)
	var houses_15: int = -1
	var earned_before: int = 0
	var unspent: Array[int] = []
	var first_leak: int = -1
	var hp_before: int = trial.hp
	var timeline: PackedStringArray = []
	var last_night: int = 0
	var reactions_before: int = 0
	var rates: PackedStringArray = []
	while trial.phase == RitualTrial.Phase.RUNNING and trial.tick_count < LIMIT_TICKS \
			and (_night_limit == 0 or trial.nights_survived() < _night_limit):
		if not trial.gift_choice.is_empty():
			trial.execute(RitualCommand.new(RitualCommand.Action.GIFT, trial.gift_choice[0]))
		if policy != "ничего" and not trial.boon_choice.is_empty():
			trial.execute(RitualCommand.new(RitualCommand.Action.BOON, trial.boon_choice[0]))
		if policy != "ничего" and trial.tick_count % 10 == 0:
			_spend(trial)
			_cast(trial)
			_palisade(trial)
			_use_supplies(trial)
		if trial.nights_survived() > last_night:
			last_night = trial.nights_survived()
			if last_night == 15:
				houses_15 = trial.field.towers.size()
			var income: int = trial.earned - earned_before
			earned_before = trial.earned
			if last_night >= 3 and income > 0:
				unspent.append(trial.gold * 100 / income)
			if first_leak < 0 and (hp_before - trial.hp) * 10 >= trial.max_hp():
				first_leak = last_night
			hp_before = trial.hp
			# Реакций в секунду за ночь (docs/37 P4: поздние ночи — не больше 4 в среднем).
			var total: int = 0
			for id: StringName in trial.field.reaction_counts:
				total += trial.field.reaction_counts[id]
			var night_seconds: float = float(SETTINGS.nights.night_length(last_night)) / TPS
			rates.append("н%d %.1f" % [last_night, (total - reactions_before) / night_seconds])
			reactions_before = total
			timeline.append("н%d %d:%02d ♥%d з%d д%d в%d" % [last_night, trial.tick_count / TPS / 60,
				trial.tick_count / TPS % 60, trial.hp, trial.gold, trial.field.towers.size(),
				_enemies(trial, last_night)])
		trial.tick()
	var seconds: int = trial.tick_count / TPS
	print("ENDLESS: %s, %s, сид %d — ночей %d, %d:%02d, %s, добыто %d, домов %d, боссов %d, даров %d" % [
		policy, trial.hero_name(), seed_value, trial.nights_survived(), seconds / 60, seconds % 60,
		trial.result if not trial.result.is_empty() else "жив к пределу", trial.earned,
		trial.field.towers.size(), trial.bosses_killed, trial.gifts_taken.size()])
	print("ENDLESS:    " + " | ".join(timeline))
	if _report:
		var mean: int = 0
		var worst: int = 0
		for value: int in unspent:
			mean += value
			worst = maxi(worst, value)
		mean /= maxi(1, unspent.size())
		var lethal: int = trial.nights_survived() + 1
		var top: PackedStringArray = stats.top_damage(1)
		print("BALANCE: %s | %s | сид %d | ночей %d | домов к 15-й %s | запас на рассвете %d%% (худший %d%%) | от прорыва до гибели %s | лучший дом %s" % [
			policy, trial.hero_name(), seed_value, trial.nights_survived(),
			str(houses_15) if houses_15 >= 0 else "-", mean, worst,
			str(lethal - first_leak) if first_leak > 0 and trial.phase == RitualTrial.Phase.OVER else "-",
			top[0] if not top.is_empty() else "-"])
	print("REACTIONS/с: " + " | ".join(rates))
	if SETTINGS.uses_plots():
		var upgrades: int = 0
		var branches: int = 0
		for command: Dictionary in trial.commands:
			var action: int = RitualStateCodec.integer(command["action"])
			upgrades += int(action == RitualCommand.Action.UPGRADE)
			branches += int(action == RitualCommand.Action.SPECIALISE)
		print("CATALOGUE: город %d, улучшений %d, специализаций %d" % [trial.city_level(), upgrades, branches])
	if _record:
		print("ENDLESS RECORD: " + RitualTrialRecord.save_result(trial))
	if _trace:
		var hurt: Dictionary[int, Dictionary] = {}
		for record: Dictionary in trial.journal:
			if record.get("event", "") == "breach":
				var tick: int = record["tick"]
				var damage: int = record["damage"]
				var night: int = SETTINGS.nights.night_index_at(tick)
				var by_kind: Dictionary = hurt.get(night, {})
				var before: int = by_kind.get(record["kind"], 0)
				by_kind[record["kind"]] = before + damage
				hurt[night] = by_kind
		for night: int in hurt:
			print("ENDLESS:    прорывы н%d: %s" % [night, str(hurt[night])])


func _enemies(trial: RitualTrial, night: int) -> int:
	var count: int = 0
	for pack: RitualPack in trial.plan().packs(night):
		count += pack.members.size()
	return count


## Разумные траты: лечение Ильи, ремонт, слияние, покупка стрелка с прилавка, заговор урона,
## обновление прилавка, если покупать нечего.
func _spend(trial: RitualTrial) -> void:
	if trial.hp <= trial.max_hp() - 15:
		trial.execute(RitualCommand.new(RitualCommand.Action.REPAIR))
	var needs_repair: bool = not SETTINGS.uses_plots()
	for tower: TowerState in trial.field.towers:
		needs_repair = needs_repair or (tower.durability >= 0 \
			and tower.durability * 2 <= SETTINGS.max_durability(tower.level))
	if needs_repair and trial.repair_all_cost() > 0 and trial.repair_all_cost() * 3 <= trial.gold:
		trial.execute(RitualCommand.new(RitualCommand.Action.REPAIR_HOUSE))
	if SETTINGS.uses_plots():
		_spend_catalogue(trial)
		return
	# Ночью стройка дороже и дольше — бот строит днём, ночью только чинит, сливает и копит.
	if SETTINGS.is_night(trial.tick_count):
		var rite_at_night: int = _main_rite(trial)
		if rite_at_night >= 0 and trial.gold >= trial.rite_cost(rite_at_night) + 60:
			trial.execute(RitualCommand.new(RitualCommand.Action.RITE, rite_at_night))
		return
	if _streets and trial.can_grow() and trial.current_night() >= 2 \
			and trial.gold >= trial.street_cost() + 25:
		trial.execute(RitualCommand.new(RitualCommand.Action.STREET))
	if _merge(trial):
		return
	var bought: bool = false
	for slot: int in trial.offers.size():
		var index: int = trial.offers[slot]
		if index >= 0 and SETTINGS.combat.towers[index].damage > 0 and _buy_best(trial, index):
			bought = true
			break
	if bought:
		return
	var rite: int = _main_rite(trial)
	if rite >= 0 and trial.gold >= trial.rite_cost(rite) + 20:
		trial.execute(RitualCommand.new(RitualCommand.Action.RITE, rite))
		return
	if trial.gold >= trial.reroll_cost() + 15:
		trial.execute(RitualCommand.new(RitualCommand.Action.REROLL))


func _merge(trial: RitualTrial) -> bool:
	for tower: TowerState in trial.field.towers:
		for other: TowerState in trial.field.towers:
			if other != tower and other.data == tower.data and other.level == tower.level \
					and tower.level < SETTINGS.combat.max_tower_level \
					and not tower.is_action_blocked() and not other.is_action_blocked():
				return trial.execute(RitualCommand.new(RitualCommand.Action.MERGE, other.id,
					Vector2i.ZERO, 0, tower.id)).is_empty()
	return false


func _spend_catalogue(trial: RitualTrial) -> void:
	var want_growth: bool = trial.can_grow() and trial.field.towers.size() >= 8 \
		and trial.current_night() >= 5 * trial.city_level()
	if SETTINGS.is_night(trial.tick_count):
		if want_growth:
			return
		var rite: int = _main_rite(trial)
		if rite >= 0 and trial.gold >= trial.rite_cost(rite) + 60:
			trial.execute(RitualCommand.new(RitualCommand.Action.RITE, rite))
		return
	var free: Array[Vector2i] = []
	for cell: Vector2i in trial.field.get_buildable_cells():
		if trial.field.get_tower_at(cell) == null:
			free.append(cell)
	var grow: bool = free.is_empty() or want_growth
	if (grow or want_growth) and trial.can_grow():
		if trial.gold >= trial.street_cost() + 20:
			trial.execute(RitualCommand.new(RitualCommand.Action.STREET))
		return
	var choice: RitualCommand = null
	var best: int = 0
	for index: int in SETTINGS.combat.towers.size():
		if not trial.building_unlock_error(index).is_empty() or trial.building_cost(index) > trial.gold:
			continue
		for cell: Vector2i in free:
			var candidate: RitualTower = RitualTower.new()
			candidate.data = SETTINGS.combat.towers[index]
			candidate.anchor = cell
			var value: int = _catalogue_value(trial, candidate) * 1000 / maxi(1, trial.building_cost(index))
			# Участков мало — важнее урон на участок: дорогой дом весит больше (корень из цены).
			if free.size() <= 2:
				value = int(value * sqrt(float(trial.building_cost(index)) / 12.0))
			var same: int = 0
			for tower: TowerState in trial.field.towers:
				same += int(tower.data.god == candidate.data.god)
			value = value * 4 / (4 + same)
			if value > best:
				best = value
				choice = RitualCommand.new(RitualCommand.Action.BUY, index, cell)
	for tower: TowerState in trial.field.towers:
		var branch: int = (1 if tower.data.damage == 0 else 0) if tower.level == 2 else -1
		if not trial.upgrade_error(tower, branch).is_empty():
			continue
		var preview: RitualTower = trial.upgrade_preview(tower, branch)
		var value: int = (_catalogue_value(trial, preview) - _catalogue_value(trial, tower)) \
			* 1000 / maxi(1, trial.upgrade_cost(tower))
		if value > best:
			best = value
			choice = RitualCommand.new(RitualCommand.Action.SPECIALISE if branch >= 0 \
				else RitualCommand.Action.UPGRADE, branch, Vector2i.ZERO, 0, tower.id)
	if choice != null:
		trial.execute(choice)
		return
	var rite: int = _main_rite(trial)
	if rite >= 0 and trial.gold >= trial.rite_cost(rite):
		trial.execute(RitualCommand.new(RitualCommand.Action.RITE, rite))


func _catalogue_value(trial: RitualTrial, tower: TowerState) -> int:
	var dps: int = trial.field.get_tower_damage(tower) * SETTINGS.combat.ticks_per_second \
		* trial.field.get_tower_targets(tower) / maxi(1, trial.field.get_tower_cooldown(tower))
	var behavior: RitualLevelBehavior = SETTINGS.level_behavior(tower)
	if tower.data.damage == 0:
		dps = 20 * behavior.support_percent / 100
	elif tower.data.cold_ticks > 0:
		dps = dps * 140 / 100
	elif tower.data.burn_percent > 0:
		dps = dps * (100 + tower.data.burn_percent) / 100
	elif tower.data.charge_ticks > 0 or tower.data.curse_ticks > 0:
		dps = dps * 125 / 100
	var value: int = dps * maxi(1, trial.field.count_path_cells_in_range(tower.cells(),
		trial.field.get_tower_range(tower)))
	if _aware:
		for other: TowerState in trial.field.towers:
			if other.id == tower.id:
				continue
			var gap: Vector2 = Vector2(other.center_milli() - tower.center_milli())
			if gap.length() <= trial.field.get_tower_range(tower) + trial.field.get_tower_range(other) \
					and RitualBoard.reaction_between(tower.data, other.data, SETTINGS.combat.reactions) != null:
				value = value * 140 / 100
				break
	return value


## Сила ночей по плану: отношение соседних ночей (цель §3: 1,10-1,30, ночь босса до 1,45).
func _print_curve() -> void:
	var plan: RitualNightPlan = RitualNightPlan.new(SETTINGS, 1)
	var low: float = 99.0
	var high: float = 0.0
	var boss_high: float = 0.0
	for night: int in range(2, 31):
		var ratio: float = float(plan.total_ehp(night)) / maxf(1.0, float(plan.total_ehp(night - 1)))
		if SETTINGS.nights.is_boss_night(night):
			boss_high = maxf(boss_high, ratio)
		elif not SETTINGS.nights.is_boss_night(night - 1):
			low = minf(low, ratio)
			high = maxf(high, ratio)
	print("BALANCE CURVE: обычные ночи x%.2f..x%.2f, ночь босса до x%.2f" % [low, high, boss_high])


## Заговор (с прилавка, если заговоры выпадают в лавке) для бога, у которого больше всего домов.
func _main_rite(trial: RitualTrial) -> int:
	var counts: Dictionary[StringName, int] = {}
	for tower: TowerState in trial.field.towers:
		counts[tower.data.god] = counts.get(tower.data.god, 0) + (1 << (tower.level - 1))
	var best: int = -1
	var best_count: int = 0
	for index: int in SETTINGS.rites.size():
		if SETTINGS.market_rite_slots > 0 and not trial.rite_offers.has(index):
			continue
		var rite: RiteData = SETTINGS.rites[index]
		if SETTINGS.market_rite_slots > 0 and not trial.has_idol_for(index):
			continue
		var count: int = counts.get(rite.god, 0)
		var useful: bool = rite.effect == RiteData.Effect.DAMAGE or SETTINGS.market_rite_slots > 0
		if useful and count > best_count:
			best = index
			best_count = count
	return best


func _buy_best(trial: RitualTrial, index: int) -> bool:
	if trial.gold < trial.building_cost(index):
		return false
	var data: TowerData = SETTINGS.combat.towers[index]
	var best_score: int = -1
	var best_cell: Vector2i = Vector2i.ZERO
	var best_rotation: int = 0
	for cell: Vector2i in trial.field.get_buildable_cells():
		for rotation: int in TowerState.ROTATIONS:
			if not trial.field.can_place_tower_data(data, cell, rotation):
				continue
			var cells: Array[Vector2i] = TowerState.shape_cells_at(data.shape, cell, rotation)
			var score: int = trial.field.count_path_cells_in_range(cells, data.range_milli)
			if score > best_score:
				best_score = score
				best_cell = cell
				best_rotation = rotation
	if best_score < 0:
		return false
	return trial.execute(RitualCommand.new(RitualCommand.Action.BUY, index, best_cell, best_rotation)).is_empty()


## Удар Ильи туда, где прогноз урона больше всего (не меньше 150).
func _cast(trial: RitualTrial) -> void:
	if trial.tick_count < trial.hero_ready or trial.hero_due >= 0:
		return
	var hero: RitualHeroData = trial.hero()
	if hero != null and hero.skill == RitualHeroData.Skill.BREW:
		# Варево днём, когда есть деньги на постройку.
		if not SETTINGS.is_night(trial.tick_count) and trial.gold >= 12:
			trial.execute(RitualCommand.new(RitualCommand.Action.SKILL))
		return
	if hero != null and hero.skill == RitualHeroData.Skill.WHISTLE:
		_whistle(trial)
		return
	var best: int = 0
	var best_progress: int = -1
	for progress: int in range(0, trial.field.get_path_end_progress(), 500):
		var point: Vector2i = trial.field.get_path_point(progress)
		var total: int = 0
		for mob: MobState in trial.field.mobs:
			if mob.is_alive() and trial.field._is_in_range(point, trial.field.get_mob_position(mob), trial.skill_radius()):
				total += trial.hero_damage(mob as RitualMob)
		if total > best:
			best = total
			best_progress = progress
	if best >= 150:
		trial.execute(RitualCommand.new(RitualCommand.Action.SKILL, 0, Vector2i.ZERO, 0, 0, best_progress))


## Свист Соловья: когда враги в последней трети пути — туда, где их больше всего (не меньше 3).
func _whistle(trial: RitualTrial) -> void:
	var end: int = trial.field.get_path_end_progress()
	var best: int = 0
	var best_progress: int = -1
	for progress: int in range(end / 2, end, 500):
		var point: Vector2i = trial.field.get_path_point(progress)
		var count: int = 0
		for mob: MobState in trial.field.mobs:
			if mob.is_alive() and trial.field._is_in_range(point, trial.field.get_mob_position(mob), trial.skill_radius()):
				count += 1
		if count > best:
			best = count
			best_progress = progress
	if best >= 3:
		trial.execute(RitualCommand.new(RitualCommand.Action.SKILL, 0, Vector2i.ZERO, 0, 0, best_progress))


## Частокол перед самым дальним тяжёлым врагом (или боссом) во второй половине пути.
func _palisade(trial: RitualTrial) -> void:
	if trial.palisades <= 0 or trial.palisade_progress >= 0:
		return
	var end: int = trial.field.get_path_end_progress()
	for mob: MobState in trial.field.mobs:
		if mob.is_alive() and trial.eligible_for_palisade(mob) and (mob as RitualMob).lane == 0 \
				and mob.progress > end / 2 and mob.progress + 1500 < end:
			if trial.execute(RitualCommand.new(RitualCommand.Action.PALISADE, 0, Vector2i.ZERO, 0, 0,
					mob.progress + 1500)).is_empty():
				return


## Припасы: оберег — когда герой ранен вдвое; смола и чаша — в гущу врагов (не меньше 4).
func _use_supplies(trial: RitualTrial) -> void:
	if trial.supplies[RitualTrial.Supply.CHARM] > 0 and trial.charm_left == 0 and trial.hp * 2 <= trial.max_hp():
		trial.execute(RitualCommand.new(RitualCommand.Action.SUPPLY, 0, Vector2i.ZERO, RitualTrial.Supply.CHARM))
	for kind: int in [RitualTrial.Supply.TAR, RitualTrial.Supply.RAIN]:
		if trial.supplies[kind] <= 0 or (kind == RitualTrial.Supply.TAR and trial.tar_until > trial.tick_count):
			continue
		var end: int = trial.field.get_path_end_progress()
		var best: int = 0
		var best_progress: int = -1
		for progress: int in range(end / 3, end, 500):
			var point: Vector2i = trial.field.get_path_point(progress)
			var count: int = 0
			for mob: MobState in trial.field.mobs:
				if mob.is_alive() and trial.field._is_in_range(point, trial.field.get_mob_position(mob), trial.supply_radius(kind)):
					count += 1
			if count > best:
				best = count
				best_progress = progress
		if best >= 4:
			trial.execute(RitualCommand.new(RitualCommand.Action.SUPPLY, 0, Vector2i.ZERO, kind, 0, best_progress))

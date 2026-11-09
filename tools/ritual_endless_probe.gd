extends SceneTree
## Темп бесконечного «Обряда» (docs/34 §14, шаг 9): сколько живут простые политики игрока.
## Боты — только ориентир; баланс проверяет автор живой игрой.
## Запуск: godot --headless --path . -s res://tools/ritual_endless_probe.gd [-- --seeds=1,2,3]

## Копия правил: аргументы `-- --hp=9 --budget=14 --boss=1800` меняют рост здоровья/бюджета ночей
## и здоровье босса; `--base`, `--gold`, `--spread`, `--kill=150` (награда в процентах) — тоже только в этом прогоне.
var SETTINGS: RitualTrialConfig = (load("res://data/ritual/endless.tres") as RitualTrialConfig).duplicate(true)
const TPS: int = 20
const LIMIT_TICKS: int = 20 * 60 * 90


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var seeds: Array[int] = [1, 2, 3]
	var only: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hp="):
			SETTINGS.nights.hp_growth_percent = argument.trim_prefix("--hp=").to_int()
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
		if argument.begins_with("--only="):
			only = argument.trim_prefix("--only=")
		if argument.begins_with("--seeds="):
			seeds.clear()
			for part: String in argument.trim_prefix("--seeds=").split(","):
				seeds.append(part.to_int())
	print("ENDLESS: рост здоровья %d%%, бюджета %d%% от %d, пачка +1 за %d ночи, босс %d HP" % [
		SETTINGS.nights.hp_growth_percent, SETTINGS.nights.budget_growth_percent, SETTINGS.nights.budget_base,
		SETTINGS.nights.packs_growth_every, SETTINGS.enemies[SETTINGS.nights.boss_enemy].hp])
	for policy: String in ["ничего", "разумные траты"]:
		if not only.is_empty() and not policy.contains(only):
			continue
		for seed_value: int in seeds:
			_play(policy, seed_value)
	quit()


func _play(policy: String, seed_value: int) -> void:
	var trial: RitualTrial = RitualTrial.new(SETTINGS, 0, seed_value)
	var timeline: PackedStringArray = []
	var last_night: int = 0
	while trial.phase == RitualTrial.Phase.RUNNING and trial.tick_count < LIMIT_TICKS:
		if not trial.gift_choice.is_empty():
			trial.execute(RitualCommand.new(RitualCommand.Action.GIFT, trial.gift_choice[0]))
		if policy != "ничего" and trial.tick_count % 10 == 0:
			_spend(trial)
			_cast(trial)
		if trial.nights_survived() > last_night:
			last_night = trial.nights_survived()
			timeline.append("н%d %d:%02d Илья%d з%d д%d в%d" % [last_night, trial.tick_count / TPS / 60,
				trial.tick_count / TPS % 60, trial.hp, trial.gold, trial.field.towers.size(),
				_enemies(trial, last_night)])
		trial.tick()
	var seconds: int = trial.tick_count / TPS
	print("ENDLESS: %s, сид %d — ночей %d, %d:%02d, %s, добыто %d, домов %d, боссов %d, даров %d" % [
		policy, seed_value, trial.nights_survived(), seconds / 60, seconds % 60,
		trial.result if not trial.result.is_empty() else "жив к пределу", trial.earned,
		trial.field.towers.size(), trial.bosses_killed, trial.gifts_taken.size()])
	print("ENDLESS:    " + " | ".join(timeline))


func _enemies(trial: RitualTrial, night: int) -> int:
	var count: int = 0
	for pack: RitualPack in trial.plan().packs(night):
		count += pack.members.size()
	return count


## Разумные траты: лечение Ильи, ремонт, слияние, покупка стрелка с прилавка, заговор урона,
## обновление прилавка, если покупать нечего.
func _spend(trial: RitualTrial) -> void:
	if trial.hp <= SETTINGS.hero_hp - 15:
		trial.execute(RitualCommand.new(RitualCommand.Action.REPAIR))
	if trial.repair_all_cost() > 0 and trial.repair_all_cost() * 3 <= trial.gold:
		trial.execute(RitualCommand.new(RitualCommand.Action.REPAIR_HOUSE))
	# Ночью стройка дороже и дольше — бот строит днём, ночью только чинит, сливает и копит.
	if SETTINGS.is_night(trial.tick_count):
		var rite_at_night: int = _main_rite(trial)
		if rite_at_night >= 0 and trial.gold >= trial.rite_cost(rite_at_night) + 60:
			trial.execute(RitualCommand.new(RitualCommand.Action.RITE, rite_at_night))
		return
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
	var best: int = 0
	var best_progress: int = -1
	for progress: int in range(0, trial.field.get_path_end_progress(), 500):
		var point: Vector2i = trial.field.get_path_point(progress)
		var total: int = 0
		for mob: MobState in trial.field.mobs:
			if mob.is_alive() and trial.field._is_in_range(point, trial.field.get_mob_position(mob), SETTINGS.hero_radius):
				total += trial.hero_damage(mob as RitualMob)
		if total > best:
			best = total
			best_progress = progress
	if best >= 150:
		trial.execute(RitualCommand.new(RitualCommand.Action.SKILL, 0, Vector2i.ZERO, 0, 0, best_progress))

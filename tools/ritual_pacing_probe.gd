extends SceneTree
## Разбор темпа «Обряда»: простые политики игрока, пустые паузы и лишнее золото.
## Политики нарочно простые: это ориентир для плейтеста, не оценка баланса.

const SETTINGS: RitualTrialConfig = preload("res://data/ritual/trial.tres")
const TPS: int = 20


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# `-- --hp=100,120,140,170` — проверить другой рост здоровья врагов по суткам.
	var rules: RitualTrialConfig = SETTINGS
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hp="):
			var percents: Array[int] = []
			for part: String in argument.trim_prefix("--hp=").split(","):
				percents.append(part.to_int())
			rules.cycle_hp_percent = percents
	print("PACE: здоровье по суткам %s" % str(rules.cycle_hp_percent))
	_play("А, без команд", 0, false, false, [])
	_play("А + Илья и частокол", 0, true, false, [])
	_play("А + Илья + траты", 0, true, true, [])
	_play("А + траты без Ильи", 0, false, true, [])
	_play("Б, без команд", 1, false, false, [])
	_play("Б + Илья + траты", 1, true, true, [])
	_play("7 самострелов, без команд", 3, false, false, [0, 0, 0, 0, 0, 0, 0])
	_play("4 горнила + Сварог, без команд", 3, false, false, [2, 2, 2, 2])
	_play("Свободная: 4 горнила + Илья + траты", 3, true, true, [2, 2, 2, 2])
	quit()


func _play(label: String, loadout: int, active: bool, greedy: bool, free_build: Array[int]) -> void:
	# `-- --only=текст` — прогнать только политики с этим текстом в названии.
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--only=") and not label.contains(argument.trim_prefix("--only=")):
			return
	var trial: RitualTrial = RitualTrial.new(SETTINGS, loadout)
	for index: int in free_build:
		_buy_best(trial, index)
	if free_build.has(2):
		trial.execute(RitualCommand.new(RitualCommand.Action.RITE, 1))
	trial.execute(RitualCommand.new(RitualCommand.Action.RITE, 0))
	trial.execute(RitualCommand.new(RitualCommand.Action.START))
	var empty_ticks: int = 0
	var idle_gold_ticks: int = 0
	var max_gold: int = 0
	var full_at: int = -1
	var skills: int = 0
	var buys: int = 0
	var timeline: PackedStringArray = []
	while trial.phase == RitualTrial.Phase.RUNNING:
		if active:
			if _cast(trial):
				skills += 1
			_palisade(trial)
		if greedy and _spend(trial):
			buys += 1
		if SETTINGS.tower_limit > 0 and trial.field.towers.size() >= SETTINGS.tower_limit and full_at < 0:
			full_at = trial.tick_count
		if trial.field.count_alive_mobs() == 0 and trial.next_spawn < SETTINGS.spawns.size():
			empty_ticks += 1
		if trial.gold >= 30:
			idle_gold_ticks += 1
		max_gold = maxi(max_gold, trial.gold)
		if trial.tick_count % (30 * TPS) == 0:
			timeline.append("%3dс hp%2d з%3d в%2d" % [trial.tick_count / TPS, trial.hp, trial.gold,
				trial.field.count_alive_mobs()])
		trial.tick()
	var last_kill: int = 0
	var breaches: Dictionary[String, int] = {}
	for record: Dictionary in trial.journal:
		var kind: String = record.get("event", "")
		if kind in ["killed", "breach"]:
			var at: int = record["tick"]
			last_kill = at
		if kind == "breach":
			var who: String = record.get("kind", "")
			breaches[who] = breaches.get(who, 0) + 1
	print("PACE: %s — %s, HP %d, добыча %d, золото в конце %d, макс. запас %d" % [label,
		trial.result, trial.hp, trial.earned, trial.gold, max_gold])
	print("PACE:    пустое поле %d с; лимит башен с %s; запас ≥30 золота %d с; ударов Ильи %d; трат %d; последний враг ушёл на %d с, конец на %d с" % [
		empty_ticks / TPS, "%d с" % (full_at / TPS) if full_at >= 0 else "—",
		idle_gold_ticks / TPS, skills, buys, last_kill / TPS, trial.tick_count / TPS])
	print("PACE:    прорвались: %s" % str(breaches))
	print("PACE:    " + " | ".join(timeline))


## Простая жадная трата: починка, заговор своего бога, слияние, чара, новая башня.
## Главная башня — с самым сильным ударом из имеющихся (горнило у А, самострел у Б).
func _spend(trial: RitualTrial) -> bool:
	if trial.hp <= SETTINGS.hero_hp - 15 and trial.execute(RitualCommand.new(RitualCommand.Action.REPAIR)).is_empty():
		return true
	var main: int = 0
	for tower: TowerState in trial.field.towers:
		var index: int = SETTINGS.combat.towers.find(tower.data)
		if tower.data.attacks and tower.data.damage > SETTINGS.combat.towers[main].damage:
			main = index
	for index: int in SETTINGS.rites.size():
		var idol: IdolState = trial.field.get_idol(SETTINGS.rites[index].god)
		if idol != null and trial.rite_count(index) < SETTINGS.rites[index].max_purchases \
				and trial.gold >= trial.rite_cost(index) and trial.rite_count(index) < 3:
			return trial.execute(RitualCommand.new(RitualCommand.Action.RITE, index)).is_empty()
	var data: TowerData = SETTINGS.combat.towers[main]
	for level: int in [2, 1]:
		var pair: Array[TowerState] = []
		for tower: TowerState in trial.field.towers:
			if tower.data == data and tower.level == level and not tower.is_action_blocked():
				pair.append(tower)
		if pair.size() >= 2:
			return trial.execute(RitualCommand.new(RitualCommand.Action.MERGE, pair[1].id,
				Vector2i.ZERO, 0, pair[0].id)).is_empty()
	for tower: TowerState in trial.field.towers:
		if tower.data == data and tower.level >= 2 and trial.gold >= SETTINGS.enchant_costs[0] \
				and trial.enchant_error(0, tower.id).is_empty():
			return trial.execute(RitualCommand.new(RitualCommand.Action.ENCHANT, 0,
				Vector2i.ZERO, 0, tower.id)).is_empty()
	return _buy_best(trial, main)


## Ставит постройку туда, где она достаёт больше всего клеток дороги.
func _buy_best(trial: RitualTrial, index: int) -> bool:
	if trial.gold < SETTINGS.costs[index]:
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


## Удар Ильи туда, где сумма прогнозного урона больше всего (не меньше 150).
func _cast(trial: RitualTrial) -> bool:
	if trial.tick_count < trial.hero_ready or trial.hero_due >= 0:
		return false
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
	if best < 150:
		return false
	return trial.execute(RitualCommand.new(RitualCommand.Action.SKILL, 0, Vector2i.ZERO, 0, 0, best_progress)).is_empty()


## Частокол — перед воеводой, как только тот появился.
func _palisade(trial: RitualTrial) -> void:
	if trial.palisades <= 0:
		return
	for mob: MobState in trial.field.mobs:
		if mob.is_alive() and mob.data.tags.has(SETTINGS.boss_tag) and mob.progress < 20000:
			trial.execute(RitualCommand.new(RitualCommand.Action.PALISADE, 0, Vector2i.ZERO, 0, 0, 22000))
			return

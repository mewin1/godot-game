class_name RitualNightPlan
extends RefCounted
## Генератор ночей бесконечного «Обряда»: ночь — чистая функция (сид, номер ночи).
## Поэтому план не хранит изменяемого состояния и одинаков после снимка; кэш — только ускорение.

var settings: RitualTrialConfig
var rules: RitualNightRules
var run_seed: int = 0
var _cache: Dictionary[int, Array] = {}
var _seen: Dictionary[int, Dictionary] = {}


func _init(trial_settings: RitualTrialConfig, seed_value: int) -> void:
	settings = trial_settings
	rules = trial_settings.nights
	run_seed = seed_value


func packs(night: int) -> Array[RitualPack]:
	if not _cache.has(night):
		_cache[night] = _generate(night)
	var result: Array[RitualPack] = []
	result.assign(_cache[night])
	return result


## Пачки, у которых в этот тик выходит очередной враг. Хвост пачки может зайти в день.
func spawns_at(tick: int) -> Array[RitualPack]:
	var result: Array[RitualPack] = []
	var night: int = rules.night_index_at(tick)
	for index: int in [night - 1, night]:
		if index < 1:
			continue
		for pack: RitualPack in packs(index):
			if pack.member_at(tick) >= 0:
				result.append(pack)
	return result


## Очередь разведки: ближайшие ещё не начавшиеся пачки по времени.
func upcoming(tick: int, count: int) -> Array[RitualPack]:
	var result: Array[RitualPack] = []
	var night: int = rules.night_index_at(tick)
	var last_night: int = night + 50
	while result.size() < count and night <= last_night:
		for pack: RitualPack in packs(night):
			if pack.at_tick >= tick and result.size() < count:
				result.append(pack)
		night += 1
	return result


## Очередь разведки: count ближайших пачек и, сверх них, важные угрозы ближайших warn_nights ночей —
## чтобы контрмеру успели накопить (docs/34 §9).
func scout(tick: int, count: int, warn_nights: int) -> Array[RitualPack]:
	var queue: Array[RitualPack] = upcoming(tick, count)
	var night: int = rules.night_index_at(tick)
	for index: int in range(night, night + warn_nights + 1):
		for pack: RitualPack in packs(index):
			if pack.at_tick >= tick and not queue.has(pack) and is_important(pack):
				queue.append(pack)
	queue.sort_custom(func(first: RitualPack, second: RitualPack) -> bool:
		return first.at_tick < second.at_tick or (first.at_tick == second.at_tick and second.boss and not first.boss))
	return queue


## Важная угроза: босс или пачка с врагом, которого в забеге ещё не было
## (кроме стартовых врагов первой ночи — они не требуют контрмеры).
func is_important(pack: RitualPack) -> bool:
	if pack.boss:
		return true
	for member: int in new_types(pack):
		var rule: RitualEnemyRule = rules.rule_for(member)
		if rule != null and rule.first_night > 1:
			return true
	return false


## Враги пачки, впервые появившиеся в этом забеге.
func new_types(pack: RitualPack) -> Array[int]:
	var seen: Dictionary[int, bool] = _seen_through(pack.night - 1).duplicate()
	for earlier: RitualPack in packs(pack.night):
		if earlier == pack:
			break
		for member: int in earlier.members:
			seen[member] = true
	var result: Array[int] = []
	for member: int in pack.members:
		if not seen.has(member) and not result.has(member):
			result.append(member)
	return result


## Все враги, появлявшиеся до конца ночи night включительно (кэш по ночам — тоже только ускорение).
func _seen_through(night: int) -> Dictionary[int, bool]:
	if night < 1:
		return {}
	if not _seen.has(night):
		var seen: Dictionary[int, bool] = _seen_through(night - 1).duplicate()
		for pack: RitualPack in packs(night):
			for member: int in pack.members:
				seen[member] = true
		_seen[night] = seen
	return _seen[night]


func total_hp(night: int) -> int:
	var total: int = 0
	for pack: RitualPack in packs(night):
		for member: int in pack.members:
			total += settings.enemies[member].hp * pack.hp_percent / 100
	return total


func total_gold(night: int) -> int:
	var total: int = 0
	for pack: RitualPack in packs(night):
		for member: int in pack.members:
			total += settings.enemies[member].kill_reward
	return total


func total_threat(night: int) -> int:
	var total: int = 0
	for pack: RitualPack in packs(night):
		for member: int in pack.members:
			var rule: RitualEnemyRule = rules.rule_for(member)
			total += rule.threat if rule != null else 0
	return total


## Текстовый отпечаток ночи — для тестов детерминизма и отладки.
func describe(night: int) -> String:
	var parts: PackedStringArray = []
	for pack: RitualPack in packs(night):
		parts.append("%d:%s:%s:%d" % [pack.at_tick, str(pack.members), pack.resist, pack.hp_percent])
	return "|".join(parts)


func _generate(night: int) -> Array[RitualPack]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = run_seed * 1000003 + night * 7919
	var count: int = rules.pack_count(night)
	var budget: int = rules.budget(night)
	var start: int = rules.night_start(night)
	var window: int = rules.night_length(night) * rules.spread_percent / 100
	var result: Array[RitualPack] = []
	for index: int in count:
		var share: int = budget / count + (budget % count if index == count - 1 else 0)
		var pack: RitualPack = _compose(rng, night, share)
		pack.at_tick = start + window * index / count
		result.append(pack)
	if rules.is_boss_night(night):
		_insert_boss(rng, night, budget, start + window / 2, result)
	return result


func _compose(rng: RandomNumberGenerator, night: int, budget: int) -> RitualPack:
	var pack: RitualPack = RitualPack.new()
	pack.night = night
	pack.spacing = maxi(1, rules.pack_spacing_ticks)
	pack.hp_percent = rules.hp_percent(night)
	var remaining: int = budget
	var leader: RitualEnemyRule = _pick(rng, night, budget * rules.leader_budget_percent / 100, true)
	if leader != null:
		remaining -= leader.threat
	var room: int = rules.pack_max_size - (1 if leader != null else 0)
	var spent: int = budget - remaining
	while pack.members.size() < room:
		var rule: RitualEnemyRule = _pick(rng, night, remaining, false)
		if rule == null:
			break
		pack.members.append(rule.enemy_index)
		remaining -= rule.threat
		spent += rule.threat
	if pack.members.is_empty() and leader == null:
		var cheapest: RitualEnemyRule = _pick(rng, night, 2147483647, false, true)
		pack.members.append(cheapest.enemy_index)
		spent = cheapest.threat
		remaining = 0
	if leader != null:
		pack.members.insert(pack.members.size() / 2, leader.enemy_index)
	# Бюджет, на который не нашлось места в пачке, становится здоровьем: ночь не слабеет.
	if remaining > 0 and spent > 0:
		pack.hp_percent += pack.hp_percent * remaining / spent
	pack.leader = _strongest(pack.members)
	return pack


func _insert_boss(rng: RandomNumberGenerator, night: int, budget: int, at_tick: int,
		result: Array[RitualPack]) -> void:
	var pack: RitualPack = _compose(rng, night, budget * rules.boss_escort_percent / 100)
	pack.members.append(rules.boss_enemy)
	pack.leader = rules.boss_enemy
	pack.boss = true
	pack.at_tick = at_tick
	if not rules.boss_resist_gods.is_empty():
		pack.resist = rules.boss_resist_gods[rng.randi_range(0, rules.boss_resist_gods.size() - 1)]
	var position: int = result.size()
	for index: int in result.size():
		if result[index].at_tick > at_tick:
			position = index
			break
	result.insert(position, pack)


## Взвешенный выбор среди открытых к этой ночи врагов, которые влезают в бюджет.
func _pick(rng: RandomNumberGenerator, night: int, budget: int, lead: bool,
		cheapest: bool = false) -> RitualEnemyRule:
	var candidates: Array[RitualEnemyRule] = []
	var total: int = 0
	for rule: RitualEnemyRule in rules.enemies:
		if rule.weight(lead) > 0 and rule.first_night <= night and rule.threat <= budget:
			candidates.append(rule)
			total += rule.weight(lead)
	if candidates.is_empty():
		return null
	if cheapest:
		var best: RitualEnemyRule = candidates[0]
		for rule: RitualEnemyRule in candidates:
			if rule.threat < best.threat:
				best = rule
		return best
	var roll: int = rng.randi_range(0, total - 1)
	for rule: RitualEnemyRule in candidates:
		roll -= rule.weight(lead)
		if roll < 0:
			return rule
	return candidates[candidates.size() - 1]


func _strongest(members: Array[int]) -> int:
	var best: int = -1
	var best_threat: int = -1
	for member: int in members:
		var rule: RitualEnemyRule = rules.rule_for(member)
		var threat: int = rule.threat if rule != null else 0
		if threat > best_threat:
			best = member
			best_threat = threat
	return best

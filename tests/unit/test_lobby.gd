extends GutTest
## Лобби из 5: пары на раунд, призрак, осада лидера, награды осады, места 1–5.

const SEED: int = 4242
const PLAYERS: int = 5
const MAX_TICKS: int = 2_000_000

var _config: GameConfig


func before_each() -> void:
	_config = SimFixtures.make_config()


func test_five_players_two_duels_and_one_ghost() -> void:
	var sim: MatchSim = _make_lobby()
	var ghosts: int = 0
	for i: int in PLAYERS:
		var opponent: int = sim.opponent_of[i]
		if opponent == MatchSim.GHOST:
			ghosts += 1
		else:
			assert_eq(sim.opponent_of[opponent], i, "пары взаимные")
	assert_eq(ghosts, 1)


func test_four_players_no_ghost() -> void:
	var sim: MatchSim = MatchSim.new(_config, SEED, 4, 0)
	sim.start()
	for i: int in 4:
		assert_ne(sim.opponent_of[i], MatchSim.GHOST)


func test_ghost_is_copy_of_another_player() -> void:
	var sim: MatchSim = _make_lobby()
	var lonely: int = sim.opponent_of.find(MatchSim.GHOST)
	assert_eq(sim.ghost_target, lonely)
	assert_ne(sim.ghost_source, lonely)
	assert_true(sim.ghost_source >= 0)
	_skip_prep(sim)
	var source: PlayerState = sim.players[sim.ghost_source]
	assert_not_null(sim.ghost_field)
	assert_eq(sim.ghost_field.towers.size(), source.field.towers.size(), "башни скопированы")
	assert_eq(sim.ghost_field.path_length, source.field.path_length)


func test_ghost_fight_both_ways() -> void:
	var sim: MatchSim = _make_lobby()
	var lonely: int = sim.ghost_target
	var source: PlayerState = sim.players[sim.ghost_source]
	_skip_prep(sim)
	# Запоминаем размеры армий сейчас: в следующей подготовке боты их прокачают.
	var ghost_army_size: int = source.army.get_unit_count()
	var my_army_size: int = sim.players[lonely].army.get_unit_count()
	var ghost_army: Dictionary[int, bool] = {}
	var my_army: Dictionary[int, bool] = {}
	while sim.phase == MatchSim.Phase.WAVE:
		for mob: MobState in sim.players[lonely].field.mobs:
			# Детёныши колобка появляются при смерти — это не новые юниты армии.
			if mob.data.id == &"kolobok_small":
				continue
			if mob.sender_index == MatchSim.GHOST and mob.data != _config.wave_mob:
				ghost_army[mob.id] = true
		for mob: MobState in sim.ghost_field.mobs:
			if mob.sender_index == lonely and mob.data.id != &"kolobok_small":
				my_army[mob.id] = true
		sim.tick()
	assert_eq(ghost_army.size(), ghost_army_size, "армия призрака идёт ко мне")
	assert_eq(my_army.size(), my_army_size, "моя — к призраку")


func test_siege_round_every_five_rounds() -> void:
	var sim: MatchSim = _make_lobby()
	assert_false(sim.is_siege_round(4))
	assert_true(sim.is_siege_round(5))
	assert_true(sim.is_siege_round(10))


func test_no_siege_with_two_players() -> void:
	var sim: MatchSim = MatchSim.new(_config, SEED, 2, 0)
	sim.start()
	assert_false(sim.is_siege_round(5))


func test_siege_picks_leader_and_two_weakest() -> void:
	var sim: MatchSim = _make_lobby()
	var hp_values: Array[int] = [30, 40, 12, 25, 10]
	for i: int in PLAYERS:
		sim.players[i].hero_hp = hp_values[i]
	sim.round_number = 4
	_finish_round_now(sim)
	assert_eq(sim.round_number, 5)
	assert_eq(sim.siege_leader, 1)
	assert_true(sim.siege_attackers.has(4))
	assert_true(sim.siege_attackers.has(2))
	assert_eq(sim.opponent_of[4], 1)
	assert_eq(sim.opponent_of[2], 1)
	assert_eq(sim.opponent_of[0], 3, "остальные — обычная дуэль")


func test_leader_army_goes_to_both_attackers() -> void:
	var sim: MatchSim = _make_siege_round()
	var leader: int = sim.siege_leader
	# Запоминаем сейчас: после волны начнётся новый раунд и осада сбросится.
	var attackers: Array[int] = sim.siege_attackers.duplicate()
	assert_eq(attackers.size(), 2)
	_skip_prep(sim)
	var army_size: int = sim.players[leader].army.get_unit_count()
	var seen: Dictionary[int, Dictionary] = {}
	for attacker_index: int in attackers:
		seen[attacker_index] = {}
	while sim.phase == MatchSim.Phase.WAVE and sim.round_number == 5:
		for attacker_index: int in attackers:
			for mob: MobState in sim.players[attacker_index].field.mobs:
				if mob.sender_index == leader:
					seen[attacker_index][mob.id] = true
		sim.tick()
	for attacker_index: int in attackers:
		assert_eq(seen[attacker_index].size(), army_size, "армия лидера у атакующего %d" % attacker_index)


func test_leader_gets_bonus_when_siege_held() -> void:
	var sim: MatchSim = _make_siege_round()
	_disable_bots(sim)
	var leader: PlayerState = sim.players[sim.siege_leader]
	_remove_all_waves(sim)
	var gold_before: int = leader.gold
	_finish_round_now(sim)
	assert_eq(leader.gold, gold_before + _config.siege_leader_bonus + leader.get_total_income())


func test_attackers_paid_for_damage_and_breach_bonus() -> void:
	var sim: MatchSim = _make_siege_round()
	_disable_bots(sim)
	var attacker: PlayerState = sim.players[sim.siege_attackers[0]]
	var leader: PlayerState = sim.players[sim.siege_leader]
	_remove_all_waves(sim)
	var gold_before: int = attacker.gold
	# Урон по лидеру в осаде уменьшен — прорывов нужно больше, чтобы снять порог.
	var breach_damage: int = _config.siege_breach_threshold
	var breaches: int = ceili(breach_damage * 100.0 / _config.siege_leader_damage_percent)
	_add_breaches(sim, leader, breaches, attacker.index)
	sim._collect_field_results(leader)
	_finish_round_now(sim)
	# Общая награда армии за урон + награда осады за урон + бонус за прорыв порога.
	var gold_per_hp: int = _config.army_gold_per_hp + _config.siege_gold_per_hp
	var expected: int = breach_damage * gold_per_hp + _config.siege_attacker_bonus
	assert_eq(attacker.gold, gold_before + expected + attacker.get_total_income())


## Баг из живого матча: трое пали в одном раунде, а места раздали по остатку HP —
## «победил» тот, кто пал раньше, но с меньшим минусом. Теперь выше тот, кто продержался дольше.
func test_same_round_deaths_ranked_by_who_fell_later() -> void:
	var sim: MatchSim = _make_lobby()
	_disable_bots(sim)
	_remove_all_waves(sim)
	var early: PlayerState = sim.players[1]
	var late: PlayerState = sim.players[2]
	early.hero_hp = 3
	late.hero_hp = 3
	sim.tick_count = 100
	_add_breaches(sim, early, 5, -1)
	sim._collect_field_results(early)
	sim.tick_count = 200
	_add_breaches(sim, late, 23, -1)
	sim._collect_field_results(late)
	assert_lt(late.hero_hp, early.hero_hp, "у павшего позже минус больше")
	_finish_round_now(sim)
	assert_false(early.is_alive)
	assert_false(late.is_alive)
	assert_lt(late.place, early.place, "кто пал позже — выше место")


## Осада — выравнивание, а не добивание: каждая армия атакующих бьёт лидера слабее,
## чтобы две армии вместе снимали примерно как одна в дуэли.
func test_siege_leader_takes_reduced_damage_from_attackers() -> void:
	var sim: MatchSim = _make_siege_round()
	_disable_bots(sim)
	_remove_all_waves(sim)
	var leader: PlayerState = sim.players[sim.siege_leader]
	var hp_before: int = leader.hero_hp
	var breaches: int = 10
	_add_breaches(sim, leader, breaches, sim.siege_attackers[0])
	sim._collect_field_results(leader)
	var full_damage: int = breaches * _config.army_mob.breach_damage \
			* _config.get_breach_multiplier(sim.round_number)
	var expected: int = full_damage * _config.siege_leader_damage_percent / 100
	assert_lt(_config.siege_leader_damage_percent, 100)
	assert_eq(hp_before - leader.hero_hp, expected)
	assert_eq(sim.players[sim.siege_attackers[0]].army_damage_dealt, expected,
			"урон армии в раунде считается по фактически снятому HP")


func test_bot_lobby_gives_unique_places() -> void:
	var sim: MatchSim = _make_lobby()
	var guard: int = 0
	while sim.phase != MatchSim.Phase.OVER and guard < MAX_TICKS:
		sim.tick()
		guard += 1
	assert_eq(sim.phase, MatchSim.Phase.OVER)
	var places: Array[int] = []
	for player: PlayerState in sim.players:
		places.append(player.place)
	places.sort()
	assert_eq(places, [1, 2, 3, 4, 5] as Array[int])


func test_lobby_is_deterministic() -> void:
	assert_eq(_lobby_hash(SEED), _lobby_hash(SEED))


func _lobby_hash(seed_value: int) -> int:
	var sim: MatchSim = MatchSim.new(_config, seed_value, PLAYERS, 0)
	sim.start()
	var guard: int = 0
	while sim.phase != MatchSim.Phase.OVER and guard < MAX_TICKS:
		sim.tick()
		guard += 1
	return sim.state_hash()


## Прорывы на поле игрока: sender_index — чья армия (-1 — базовая волна).
func _add_breaches(sim: MatchSim, player: PlayerState, count: int, sender_index: int) -> void:
	var mob_data: MobData = sim.config.army_mob if sender_index >= 0 else sim.config.wave_mob
	for i: int in count:
		var mob: MobState = MobState.create(mob_data)
		mob.sender_index = sender_index
		player.field.pending_breaches.append(mob)


func _make_lobby() -> MatchSim:
	var sim: MatchSim = MatchSim.new(_config, SEED, PLAYERS, 0)
	sim.start()
	return sim


## Лобби, переведённое в начало раунда осады (5-го).
func _make_siege_round() -> MatchSim:
	var sim: MatchSim = _make_lobby()
	sim.round_number = 4
	_finish_round_now(sim)
	return sim


## Конец текущего раунда прямо сейчас (через волну без мобов).
func _finish_round_now(sim: MatchSim) -> void:
	_skip_prep(sim)
	_remove_all_waves(sim)
	sim.tick()


## Боты тратят золото в начале раунда — для проверки наград их выключаем.
func _disable_bots(sim: MatchSim) -> void:
	for player: PlayerState in sim.players:
		player.is_bot = false


func _remove_all_waves(sim: MatchSim) -> void:
	if sim.phase == MatchSim.Phase.PREP:
		_skip_prep(sim)
	for player: PlayerState in sim.players:
		player.field.mobs.clear()
		player.field._spawn_queue.clear()
	if sim.ghost_field != null:
		sim.ghost_field.mobs.clear()
		sim.ghost_field._spawn_queue.clear()


func _skip_prep(sim: MatchSim) -> void:
	if sim.phase != MatchSim.Phase.PREP:
		return
	for i: int in sim.config.prep_ticks:
		if sim.phase != MatchSim.Phase.PREP:
			return
		sim.tick()

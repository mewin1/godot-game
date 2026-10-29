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


func test_ghost_sends_pack_to_lonely_player() -> void:
	var sim: MatchSim = _make_lobby()
	var lonely: int = sim.opponent_of.find(MatchSim.GHOST)
	var field: FieldState = sim.players[lonely].field
	var seen: Dictionary[int, bool] = {}
	_skip_prep(sim)
	while sim.phase == MatchSim.Phase.WAVE:
		sim.tick()
		for mob: MobState in field.mobs:
			if mob.data == _config.send_mob:
				seen[mob.id] = true
	assert_eq(seen.size(), _config.send_pack_size)


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


func test_leader_send_copied_to_both_attackers() -> void:
	var sim: MatchSim = _make_siege_round()
	var leader: int = sim.siege_leader
	sim.players[leader].gold = 100
	assert_eq(sim.execute_command(leader, SendUnitsCommand.new()), "")
	_skip_prep(sim)
	for attacker_index: int in sim.siege_attackers:
		var seen: Dictionary[int, bool] = {}
		var field: FieldState = sim.players[attacker_index].field
		while sim.phase == MatchSim.Phase.WAVE and seen.size() < _config.send_pack_size:
			sim.tick()
			for mob: MobState in field.mobs:
				if mob.sender_index == leader:
					seen[mob.id] = true
		assert_eq(seen.size(), _config.send_pack_size, "копия пачки у атакующего %d" % attacker_index)


func test_leader_gets_bonus_when_siege_held() -> void:
	var sim: MatchSim = _make_siege_round()
	_disable_bots(sim)
	var leader: PlayerState = sim.players[sim.siege_leader]
	_remove_all_waves(sim)
	var gold_before: int = leader.gold
	_finish_round_now(sim)
	assert_eq(leader.gold, gold_before + _config.siege_leader_bonus + leader.income)


func test_attackers_paid_for_damage_and_breach_bonus() -> void:
	var sim: MatchSim = _make_siege_round()
	_disable_bots(sim)
	var attacker: PlayerState = sim.players[sim.siege_attackers[0]]
	var leader: PlayerState = sim.players[sim.siege_leader]
	_remove_all_waves(sim)
	var gold_before: int = attacker.gold
	var breach_damage: int = _config.siege_breach_threshold
	for i: int in breach_damage:
		var mob: MobState = MobState.create(_config.send_mob)
		mob.sender_index = attacker.index
		leader.field.pending_breaches.append(mob)
	sim._collect_field_results(leader)
	_finish_round_now(sim)
	var expected: int = breach_damage * _config.siege_gold_per_hp + _config.siege_attacker_bonus
	assert_eq(attacker.gold, gold_before + expected + attacker.income)


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


func _skip_prep(sim: MatchSim) -> void:
	if sim.phase != MatchSim.Phase.PREP:
		return
	for i: int in sim.config.prep_ticks:
		if sim.phase != MatchSim.Phase.PREP:
			return
		sim.tick()

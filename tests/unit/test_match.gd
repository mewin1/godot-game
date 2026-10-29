extends GutTest
## Матч: фазы раунда, команды, скилл отправки, бафы, урон прорыва, конец матча, детерминизм.

const SEED: int = 777
## Предел тиков для прогона матча в тестах (защита от бесконечного цикла).
const MAX_TICKS: int = 400_000

var _config: GameConfig


func before_each() -> void:
	_config = SimFixtures.make_config()


func test_start_begins_round_one_prep() -> void:
	var sim: MatchSim = _make_match()
	assert_eq(sim.round_number, 1)
	assert_eq(sim.phase, MatchSim.Phase.PREP)
	assert_eq(sim.players[0].shop.offers.size(), 3)
	assert_eq(sim.opponent_of[0], 1)


func test_ready_command_starts_wave_next_tick() -> void:
	var sim: MatchSim = _make_match()
	sim.queue_command(0, ReadyCommand.new())
	sim.tick()
	assert_eq(sim.phase, MatchSim.Phase.WAVE)


func test_prep_ends_by_timer() -> void:
	var sim: MatchSim = _make_match()
	for i: int in _config.prep_ticks:
		sim.tick()
	assert_eq(sim.phase, MatchSim.Phase.WAVE)


func test_queued_command_applies_on_tick() -> void:
	var sim: MatchSim = _make_match()
	sim.queue_command(0, RerollShopCommand.new())
	assert_eq(sim.players[0].gold, _config.start_gold, "до тика ещё не выполнена")
	sim.tick()
	assert_eq(sim.players[0].gold, _config.start_gold - _config.reroll_cost)


func test_command_during_wave_fails_with_signal() -> void:
	var sim: MatchSim = _make_match()
	_skip_prep(sim)
	watch_signals(sim)
	sim.queue_command(0, RerollShopCommand.new())
	sim.tick()
	assert_signal_emitted(sim, "command_failed")


func test_send_costs_by_round_formula() -> void:
	assert_eq(_config.get_send_cost(1), 5)
	assert_eq(_config.get_send_cost(5), 13)
	assert_eq(_config.get_send_cost(10), 23)


func test_send_raises_income_and_only_once_per_round() -> void:
	var sim: MatchSim = _make_match()
	var player: PlayerState = sim.players[0]
	assert_eq(sim.execute_command(0, SendUnitsCommand.new()), "")
	assert_eq(player.gold, _config.start_gold - 5)
	assert_eq(player.income, _config.base_income + 1)
	assert_ne(sim.execute_command(0, SendUnitsCommand.new()), "", "второй раз нельзя")


func test_send_pack_arrives_on_opponent_field() -> void:
	var sim: MatchSim = _make_match()
	sim.execute_command(0, SendUnitsCommand.new())
	_skip_prep(sim)
	var seen_ids: Dictionary[int, bool] = {}
	var opponent_field: FieldState = sim.players[1].field
	while sim.phase == MatchSim.Phase.WAVE:
		sim.tick()
		for mob: MobState in opponent_field.mobs:
			if mob.sender_index == 0:
				seen_ids[mob.id] = true
	assert_eq(seen_ids.size(), _config.send_pack_size)


func test_send_pack_reward_is_quarter_of_cost() -> void:
	var army: SendArmy = SendArmy.new(_config)
	var pack: Array[MobState] = army.build_pack(0, 13, 1)
	var total: int = 0
	for mob: MobState in pack:
		total += mob.kill_reward
	assert_eq(total, 13 * _config.send_reward_percent / 100)


func test_buffs_change_pack() -> void:
	var army: SendArmy = SendArmy.new(_config)
	army.add_buff(SimFixtures.find_buff(_config, &"units_small"))
	army.add_buff(SimFixtures.find_buff(_config, &"add_fast"))
	army.add_buff(SimFixtures.find_buff(_config, &"hp_small"))
	var pack: Array[MobState] = army.build_pack(0, 5, 1)
	assert_eq(pack.size(), _config.send_pack_size + 2)
	assert_eq(pack[0].max_hp, _config.send_mob.hp * 115 / 100)


func test_discount_buff_lowers_send_cost() -> void:
	var army: SendArmy = SendArmy.new(_config)
	army.add_buff(SimFixtures.find_buff(_config, &"discount"))
	assert_eq(army.get_send_cost(1), 4)


func test_buff_offers_appear_after_first_battle() -> void:
	var sim: MatchSim = _make_match()
	assert_true(sim.players[0].buff_offers.is_empty(), "в первом раунде бафов нет")
	_play_until_round(sim, 2)
	assert_eq(sim.players[0].buff_offers.size(), _config.buff_offer_count)


func test_buff_offers_are_common_on_shop_level_one() -> void:
	var army: SendArmy = SendArmy.new(_config)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for i: int in 20:
		for buff: SendBuffData in army.roll_buff_offers(1, rng):
			assert_false(buff.is_rare)


func test_unchosen_buff_is_picked_automatically() -> void:
	var sim: MatchSim = _make_match()
	_play_until_round(sim, 2)
	_skip_prep(sim)
	assert_eq(sim.players[0].army.buffs.size(), 1)


func test_round_end_pays_income() -> void:
	var sim: MatchSim = _make_match()
	var player: PlayerState = sim.players[0]
	_play_until_round(sim, 2)
	assert_true(player.gold >= _config.start_gold + _config.base_income, "доход начислен")


func test_breach_damages_hero() -> void:
	var sim: MatchSim = _make_match()
	_play_until_round(sim, 2)
	var wave_size: int = _config.wave_base_count
	assert_eq(sim.players[0].hero_hp, _config.hero_hp - wave_size, "без башен прорвались все")


func test_breach_multiplier_grows_late() -> void:
	assert_eq(_config.get_breach_multiplier(9), 1)
	assert_eq(_config.get_breach_multiplier(10), 2)
	assert_eq(_config.get_breach_multiplier(15), 3)


func test_match_ends_when_hero_dies() -> void:
	var sim: MatchSim = _make_match()
	sim.players[0].hero_hp = 1
	watch_signals(sim)
	_play_until_round(sim, 2)
	assert_eq(sim.phase, MatchSim.Phase.OVER)
	assert_signal_emitted(sim, "match_finished")
	assert_eq(sim.players[0].place, 2)
	assert_eq(sim.get_winner(), sim.players[1])


func test_bot_buys_towers_in_first_round() -> void:
	var sim: MatchSim = _make_match()
	assert_gt(sim.players[1].field.towers.size(), 0)
	assert_lt(sim.players[1].gold, _config.tower_cost)


func test_bot_match_finishes() -> void:
	var sim: MatchSim = MatchSim.new(_config, SEED, 2, 0)
	sim.start()
	_run_to_end(sim)
	assert_eq(sim.phase, MatchSim.Phase.OVER)
	assert_not_null(sim.get_winner())


func test_same_seed_same_commands_same_hash() -> void:
	assert_eq(_scripted_match_hash(SEED), _scripted_match_hash(SEED))


func test_different_seed_gives_different_hash() -> void:
	assert_ne(_scripted_match_hash(SEED), _scripted_match_hash(SEED + 1))


## Матч бот против бота плюс команды «человека» по тикам — прогон до конца, хэш итога.
func _scripted_match_hash(seed_value: int) -> int:
	var sim: MatchSim = MatchSim.new(_config, seed_value, 2, 1)
	sim.start()
	var guard: int = 0
	while sim.phase != MatchSim.Phase.OVER and guard < MAX_TICKS:
		if sim.phase == MatchSim.Phase.PREP and sim.phase_tick == 1:
			sim.queue_command(0, SendUnitsCommand.new())
			sim.queue_command(0, BuyTowerCommand.new(0, Vector2i(2, 2 + sim.round_number % 6), 1))
			sim.queue_command(0, ChooseBuffCommand.new(1))
		if sim.phase == MatchSim.Phase.PREP and sim.phase_tick == 5:
			sim.queue_command(0, ReadyCommand.new())
		sim.tick()
		guard += 1
	return sim.state_hash()


func _make_match() -> MatchSim:
	var sim: MatchSim = MatchSim.new(_config, SEED, 2, 1)
	sim.start()
	return sim


func _skip_prep(sim: MatchSim) -> void:
	sim.queue_command(0, ReadyCommand.new())
	sim.tick()


func _play_until_round(sim: MatchSim, target_round: int) -> void:
	var guard: int = 0
	while sim.round_number < target_round and sim.phase != MatchSim.Phase.OVER and guard < MAX_TICKS:
		if sim.phase == MatchSim.Phase.PREP:
			sim.queue_command(0, ReadyCommand.new())
		sim.tick()
		guard += 1


func _run_to_end(sim: MatchSim) -> void:
	var guard: int = 0
	while sim.phase != MatchSim.Phase.OVER and guard < MAX_TICKS:
		sim.tick()
		guard += 1

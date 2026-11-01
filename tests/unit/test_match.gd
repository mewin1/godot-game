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


func test_army_goes_to_opponent_every_round_for_free() -> void:
	var sim: MatchSim = _make_match()
	var gold_before: int = sim.players[0].gold
	_skip_prep(sim)
	assert_eq(sim.players[0].gold, gold_before, "армия бесплатная")
	var seen_ids: Dictionary[int, bool] = {}
	var opponent_field: FieldState = sim.players[1].field
	while sim.phase == MatchSim.Phase.WAVE:
		sim.tick()
		for mob: MobState in opponent_field.mobs:
			if mob.sender_index == 0:
				seen_ids[mob.id] = true
	assert_eq(seen_ids.size(), _config.army_base_units)


func test_army_upgrade_costs_gold_raises_income_and_price() -> void:
	var sim: MatchSim = _make_match()
	var player: PlayerState = sim.players[0]
	var cost: int = player.army.get_upgrade_cost(0)
	assert_eq(sim.execute_command(0, BuyArmyUpgradeCommand.new(0)), "")
	assert_eq(player.gold, _config.start_gold - cost)
	assert_eq(player.income, _config.base_income + 1)
	assert_eq(player.army.get_upgrade_cost(0), cost + _config.army_upgrades[0].cost_step)


func test_army_upgrade_extra_unit_grows_army() -> void:
	var army: ArmyState = ArmyState.new(_config)
	army.apply_upgrade(_upgrade_index(&"army_units"))
	assert_eq(army.build_pack(0, 1).size(), _config.army_base_units + 1)


func test_army_upgrade_locked_by_shop_level() -> void:
	var player: PlayerState = PlayerState.new(_config, 0, 1)
	player.gold = 1000
	assert_ne(player.buy_army_upgrade(_upgrade_index(&"army_boss")), "", "босс — с 3-го уровня")
	player.upgrade_shop()
	player.upgrade_shop()
	assert_eq(player.buy_army_upgrade(_upgrade_index(&"army_boss")), "")


func test_army_upgrade_respects_max_purchases() -> void:
	var player: PlayerState = PlayerState.new(_config, 0, 1)
	player.gold = 10000
	var index: int = _upgrade_index(&"army_speed")
	var max_purchases: int = _config.army_upgrades[index].max_purchases
	for i: int in max_purchases:
		assert_eq(player.buy_army_upgrade(index), "")
	assert_ne(player.buy_army_upgrade(index), "")


func test_army_upgrade_without_gold_fails() -> void:
	var player: PlayerState = PlayerState.new(_config, 0, 1)
	player.gold = 0
	assert_ne(player.buy_army_upgrade(0), "")
	assert_eq(player.income, _config.base_income)


func test_army_units_give_kill_reward_from_data() -> void:
	var army: ArmyState = ArmyState.new(_config)
	var pack: Array[MobState] = army.build_pack(0, 1)
	assert_eq(pack[0].kill_reward, _config.army_mob.kill_reward)


func test_army_hp_grows_with_rounds() -> void:
	var army: ArmyState = ArmyState.new(_config)
	assert_gt(army.build_pack(0, 10)[0].max_hp, army.build_pack(0, 1)[0].max_hp)


func test_buffs_change_pack() -> void:
	var army: ArmyState = ArmyState.new(_config)
	army.add_buff(SimFixtures.find_buff(_config, &"units_small"))
	army.add_buff(SimFixtures.find_buff(_config, &"add_fast"))
	army.add_buff(SimFixtures.find_buff(_config, &"hp_small"))
	var pack: Array[MobState] = army.build_pack(0, 1)
	assert_eq(pack.size(), _config.army_base_units + 2)
	assert_eq(pack[0].max_hp, _config.army_mob.hp * 115 / 100)


func test_discount_buff_lowers_upgrade_cost() -> void:
	var army: ArmyState = ArmyState.new(_config)
	var cost: int = army.get_upgrade_cost(0)
	army.add_buff(SimFixtures.find_buff(_config, &"discount"))
	assert_eq(army.get_upgrade_cost(0), cost - 1)


func test_income_buff_adds_income_per_upgrade() -> void:
	var army: ArmyState = ArmyState.new(_config)
	army.add_buff(SimFixtures.find_buff(_config, &"income"))
	var from_cost: int = maxi(1, _config.army_upgrades[0].base_cost * _config.army_income_percent / 100)
	assert_eq(army.get_upgrade_income(0), from_cost + 1)


func test_buff_offers_appear_after_first_battle() -> void:
	var sim: MatchSim = _make_match()
	assert_true(sim.players[0].buff_offers.is_empty(), "в первом раунде бафов нет")
	_play_until_round(sim, 2)
	assert_eq(sim.players[0].buff_offers.size(), _config.buff_offer_count)


func test_buff_offers_are_common_on_shop_level_one() -> void:
	var army: ArmyState = ArmyState.new(_config)
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
	var enemy_army: int = sim.players[1].army.get_unit_count()
	_play_until_round(sim, 2)
	var leaked: int = _config.wave_base_count + enemy_army
	assert_eq(sim.players[0].hero_hp, _config.hero_hp - leaked, "без башен прорвались волна и армия")


## Цифры раундов — из конфига (их подбирают по логам), проверяем саму ступеньку.
func test_breach_multiplier_grows_late() -> void:
	var first: int = _config.breach_multiplier_start_rounds[0]
	var second: int = _config.breach_multiplier_start_rounds[1]
	assert_eq(_config.get_breach_multiplier(first - 1), 1)
	assert_eq(_config.get_breach_multiplier(first), _config.breach_multipliers[0])
	assert_eq(_config.get_breach_multiplier(second), _config.breach_multipliers[1])


## Время волны вышло — мобы не засчитываются прорвавшимися разом, а впадают в ярость (бегут
## быстрее мимо башен). Прорыв всех оставшихся — только после дополнительного времени.
func test_wave_timeout_enrages_mobs_before_forced_breach() -> void:
	var sim: MatchSim = _make_match()
	_skip_prep(sim)
	var field: FieldState = sim.players[0].field
	var stuck: MobState = MobState.create(_config.wave_mob)
	stuck.speed = 0
	field.schedule_spawn(stuck, field.wave_tick)
	while sim.phase_tick < _config.wave_max_ticks:
		sim.tick()
	sim.tick()
	assert_true(field.is_enraged, "ярость после таймера")
	assert_false(stuck.is_breached, "мобы ещё бегут, а не прорвались разом")
	while sim.phase == MatchSim.Phase.WAVE and sim.round_number == 1:
		sim.tick()
	assert_true(stuck.is_breached, "после доп. времени — прорыв оставшихся")
	assert_false(field.is_enraged, "в новом раунде ярости нет")


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
			sim.queue_command(0, BuyArmyUpgradeCommand.new(sim.round_number % 3))
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


func _upgrade_index(upgrade_id: StringName) -> int:
	for i: int in _config.army_upgrades.size():
		if _config.army_upgrades[i].id == upgrade_id:
			return i
	return -1


func test_army_breach_gives_gold_to_owner() -> void:
	var sim: MatchSim = _make_match()
	_skip_prep(sim)
	var owner: PlayerState = sim.players[0]
	var victim: PlayerState = sim.players[1]
	var gold_before: int = owner.gold
	var mob: MobState = MobState.create(_config.army_mob)
	mob.sender_index = owner.index
	victim.field.pending_breaches.append(mob)
	sim._collect_field_results(victim)
	assert_eq(owner.gold, gold_before + mob.breach_damage * _config.army_gold_per_hp)


## Урон сверх оставшегося HP сохраняет тай-брейк, но не создаёт золото и урон армии.
func test_breach_rewards_only_for_remaining_hp() -> void:
	var sim: MatchSim = _make_match()
	var defender: PlayerState = sim.players[0]
	var sender: PlayerState = sim.players[1]
	defender.hero_hp = 2
	var gold_before: int = sender.gold
	var data: MobData = _config.army_mob.duplicate() as MobData
	data.breach_gold_to_sender = 7
	for i: int in 3:
		var mob: MobState = MobState.create(data)
		mob.breach_damage = 3
		mob.sender_index = 1
		defender.field.pending_breaches.append(mob)
	sim._collect_field_results(defender)
	assert_eq(sender.army_damage_dealt, 2)
	assert_eq(sender.gold - gold_before, 2 * _config.army_gold_per_hp + 7)
	assert_eq(defender.hero_hp, 0, "HP не уходит в минус")
	assert_eq(defender.breach_overkill, 7, "перелёт сохранён для тай-брейка")
	var fell_tick: int = defender.fell_tick
	var late: MobState = MobState.create(data)
	late.sender_index = 1
	defender.field.pending_breaches.append(late)
	sim.tick_count += 10
	sim._collect_field_results(defender)
	assert_eq(sender.army_damage_dealt, 2)
	assert_eq(sender.gold - gold_before, 2 * _config.army_gold_per_hp + 7)
	assert_eq(defender.fell_tick, fell_tick)


func test_round_breach_limit_is_shared_and_does_not_pay_for_excess() -> void:
	_config.breach_limits = [4, 8, 12, 16, 20]
	_config.breach_multiplier_start_rounds = []
	var sim: MatchSim = _make_match()
	var defender: PlayerState = sim.players[0]
	var sender: PlayerState = sim.players[1]
	var gold_before: int = sender.gold
	watch_signals(defender.field)
	for i: int in 3:
		var mob: MobState = MobState.create(_config.army_mob)
		mob.breach_damage = 3
		mob.sender_index = -1 if i == 0 else 1
		defender.field.pending_breaches.append(mob)
		sim._collect_field_results(defender)
	assert_eq(defender.hero_hp, _config.hero_hp - 4)
	assert_eq(defender.hp_lost_this_round, 4)
	assert_eq(defender.raw_breach_damage, 9)
	assert_eq(sender.army_damage_dealt, 1)
	assert_eq(sender.gold - gold_before, _config.army_gold_per_hp)
	assert_signal_emit_count(defender.field, "breach_resolved", 3)
	sim._start_round(2)
	assert_eq(defender.limited_breach_damage, 0)
	assert_eq(defender.raw_breach_damage, 0)


func test_breach_limit_progression_and_legacy_unlimited() -> void:
	assert_eq(_config.get_breach_limit(20), 0)
	_config.breach_limits = [4, 8, 12, 16, 20]
	for number: int in [1, 4, 5, 8, 9, 12, 13, 16, 17, 40]:
		assert_eq(_config.get_breach_limit(number), mini(20, 4 * ((number - 1) / 4 + 1)))


func test_siege_round_uses_one_limit_for_both_attackers() -> void:
	_config.breach_limits = [4]
	var sim: MatchSim = MatchSim.new(_config, SEED, 3, 3)
	sim.start()
	sim.siege_leader = 0
	sim.siege_attackers = [1, 2]
	sim._siege_damage_by_attacker = {1: 0, 2: 0}
	var defender: PlayerState = sim.players[0]
	for sender: int in [1, 2]:
		var mob: MobState = MobState.create(_config.army_mob)
		mob.sender_index = sender
		mob.breach_damage = 6
		defender.field.pending_breaches.append(mob)
		sim._collect_field_results(defender)
	assert_eq(defender.hp_lost_this_round, 4)
	assert_eq(defender.raw_breach_damage, 6, "осадное снижение до общего предела")
	assert_eq(sim.players[1].army_damage_dealt, 3)
	assert_eq(sim.players[2].army_damage_dealt, 1)
	assert_eq(sim._siege_leader_hp_lost, 4)


func test_limit_usage_changes_hash_and_future_damage_even_with_same_hp() -> void:
	_config.breach_limits = [4]
	var first: MatchSim = _make_match()
	var second: MatchSim = _make_match()
	first.players[0].limited_breach_damage = 2
	assert_ne(first.state_hash(), second.state_hash())
	for sim: MatchSim in [first, second]:
		var mob: MobState = MobState.create(_config.army_mob)
		mob.breach_damage = 4
		sim.players[0].field.pending_breaches.append(mob)
		sim._collect_field_results(sim.players[0])
	assert_eq(first.players[0].hero_hp - second.players[0].hero_hp, 2)


func test_incoming_preview_matches_spawned_army_without_consuming_rng() -> void:
	var sim: MatchSim = _make_match()
	var before: int = sim.state_hash()
	var preview: Array[MobState] = sim.build_incoming_armies(0)
	assert_eq(sim.state_hash(), before)
	_skip_prep(sim)
	var actual: Array[MobState] = []
	for entry: SpawnEntry in sim.players[0].field._spawn_queue:
		if entry.mob.sender_index == 1:
			actual.append(entry.mob)
	assert_eq(preview.size(), actual.size())
	for i: int in preview.size():
		assert_eq(preview[i].max_hp, actual[i].max_hp)
		assert_eq(preview[i].speed, actual[i].speed)


func test_player_rng_changes_hash_before_future_shop_roll() -> void:
	var first: MatchSim = _make_match()
	var second: MatchSim = _make_match()
	assert_eq(first.state_hash(), second.state_hash())
	# Видимая витрина пока та же; следующий бросок уже зависит от другого состояния.
	second.players[0].rng.state += 1
	assert_ne(first.state_hash(), second.state_hash(),
			"хэш должен обнаружить расхождение до следующей случайной покупки/витрины")

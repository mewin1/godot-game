extends GutTest
## Купленный резерв, снимки маршрутов, призрак и единый темп основного матча.


func _make(players: int = 6) -> MatchSim:
	var config: GameConfig = SimFixtures.make_config()
	config.active_battle = ActiveBattleConfig.new()
	config.active_battle.reserve_deadline_ticks = 20
	config.active_battle.bot_release_ticks = 10
	config.battle_real_ticks = 80
	config.army_first_round = 1
	config.wave_base_count = 0
	config.wave_count_per_round = 0
	config.prep_requires_ready = true
	var sim: MatchSim = MatchSim.new(config, 1401, players, players)
	sim.start()
	for player: PlayerState in sim.players:
		player.army.added_mobs.append(config.army_mob)
		player.army.added_mobs.append(config.army_mob)
		assert_eq(sim.execute_command(player.index,
				PlanReserveCommand.new(config.army_mob.id, config.army_mob.resist, 2)), "")
	return sim


func _start(sim: MatchSim) -> void:
	for player: PlayerState in sim.get_alive_players():
		assert_eq(sim.execute_command(player.index, ReadyCommand.new()), "")
	sim.tick()
	assert_eq(sim.phase, MatchSim.Phase.WAVE)


func test_plan_only_uses_purchased_units_and_preserves_resist() -> void:
	var sim: MatchSim = _make()
	var army: ArmyState = sim.players[0].army
	assert_eq(army.reserve_indices(), [army.base_units, army.base_units + 1])
	assert_ne(army.set_reserve(sim.config.army_mob.id, sim.config.army_mob.resist, 3), "")
	assert_ne(army.set_reserve(sim.config.army_mob.id, &"unknown", 1), "")
	assert_eq(army.reserve_count, 2, "Отказ сохраняет предыдущий план")
	assert_eq(army.get_unit_count(), army.base_units + 2)


func test_release_once_without_gold_and_no_duplicate_composition() -> void:
	var sim: MatchSim = _make()
	_start(sim)
	var gold: int = sim.players[0].gold
	var target: FieldState = sim.players[sim.opponent_of[0]].field
	assert_eq(target.count_remaining_mobs(), sim.players[0].army.base_units)
	assert_eq(sim.execute_command(0, ReleaseReserveCommand.new()), "")
	assert_eq(target.count_remaining_mobs(), sim.players[0].army.get_unit_count())
	assert_eq(sim.players[0].gold, gold)
	assert_ne(sim.execute_command(0, ReleaseReserveCommand.new()), "")
	assert_ne(sim.execute_command(0, PlanReserveCommand.new()), "")


func test_empty_fields_wait_for_reserve_then_auto_release() -> void:
	var sim: MatchSim = _make()
	for player: PlayerState in sim.players:
		player.army.base_units = 0
	_start(sim)
	for i: int in 19:
		sim.tick()
	assert_eq(sim.phase, MatchSim.Phase.WAVE)
	assert_eq(sim.battle_reserves.pending_count(0), 2)
	sim.tick()
	assert_eq(sim.battle_reserves.pending_count(0), 0)
	for dispatch: BattleReserves.Dispatch in sim.battle_reserves.dispatches:
		assert_true(dispatch.automatic)
		assert_eq(dispatch.released_tick, 20)


func test_siege_single_order_releases_independent_copies() -> void:
	var sim: MatchSim = _make()
	sim._start_round(sim.config.siege_every_rounds)
	_start(sim)
	var leader: int = sim.siege_leader
	assert_gte(leader, 0)
	assert_eq(sim.execute_command(leader, ReleaseReserveCommand.new()), "")
	var copies: Array[BattleReserves.Dispatch] = []
	for dispatch: BattleReserves.Dispatch in sim.battle_reserves.dispatches:
		if dispatch.sender == leader:
			copies.append(dispatch)
	assert_eq(copies.size(), 2)
	assert_eq(copies[0].released_tick, copies[1].released_tick)
	assert_false(copies[0].pack[0] == copies[1].pack[0])
	assert_eq(copies[0].pack.size(), 2)


func test_ghost_release_is_independent_of_live_source() -> void:
	var sim: MatchSim = _make(5)
	_start(sim)
	assert_gte(sim.ghost_source, 0)
	assert_eq(sim.execute_command(sim.ghost_source, ReleaseReserveCommand.new()), "")
	assert_eq(sim.battle_reserves.pending_count(MatchSim.GHOST), 2)
	for i: int in 10:
		sim.tick()
	assert_eq(sim.battle_reserves.pending_count(MatchSim.GHOST), 0)
	assert_eq(sim.battle_reserves.pending_count(sim.ghost_target), 2)


func test_snapshot_and_hash_include_plan_and_held_stats() -> void:
	var first: MatchSim = _make()
	var second: MatchSim = _make()
	assert_eq(first.state_hash(), second.state_hash())
	assert_eq(second.execute_command(0, PlanReserveCommand.new()), "")
	assert_ne(first.state_hash(), second.state_hash())
	_start(first)
	var held: MobState = first.battle_reserves.dispatches[0].pack[0]
	var hp: int = held.hp
	first.players[0].army.hp_percent += 100
	assert_eq(held.hp, hp, "Купленные свойства фиксируются в начале волны")
	var hash_before: int = first.state_hash()
	held.hp -= 1
	assert_ne(first.state_hash(), hash_before)


func test_same_orders_same_hash_and_fixed_speed() -> void:
	var first: MatchSim = _make()
	var second: MatchSim = _make()
	_start(first)
	_start(second)
	for i: int in 30:
		if i == 5:
			assert_eq(first.execute_command(0, ReleaseReserveCommand.new()), "")
			assert_eq(second.execute_command(0, ReleaseReserveCommand.new()), "")
		first.tick()
		second.tick()
		assert_eq(first.state_hash(), second.state_hash())
		assert_eq(first.get_battle_speed(), 1)


func test_timeout_retreats_without_breach_damage() -> void:
	var sim: MatchSim = _make()
	sim.config.battle_real_ticks = 2
	_start(sim)
	var hp: int = sim.players[0].hero_hp
	sim.tick()
	sim.tick()
	assert_ne(sim.phase, MatchSim.Phase.WAVE)
	assert_eq(sim.players[0].hero_hp, hp)
	assert_gt(sim.players[0].field.battle_report.retreated, 0)

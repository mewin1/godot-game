extends GutTest
## Герои: выбор из трёх, пассивки, навыки (команда, цена, раз за раунд), детерминизм.

const MAX_TICKS: int = 400_000

var _config: GameConfig


func before_each() -> void:
	_config = SimFixtures.make_config()


func test_config_has_ten_heroes_with_unique_ids() -> void:
	var ids: Dictionary[StringName, bool] = {}
	for hero: HeroData in _config.heroes:
		ids[hero.id] = true
	assert_eq(_config.heroes.size(), 10)
	assert_eq(ids.size(), 10)


func test_hero_select_gives_three_different_offers() -> void:
	var sim: MatchSim = MatchSim.new(_config, 5, 5, 1)
	sim.start_with_hero_select()
	assert_eq(sim.phase, MatchSim.Phase.HERO_SELECT)
	var offers: Array[HeroData] = sim.players[0].hero_offers
	assert_eq(offers.size(), 3)
	assert_ne(offers[0], offers[1])
	assert_ne(offers[1], offers[2])
	assert_ne(offers[0], offers[2])


func test_bots_pick_heroes_at_once() -> void:
	var sim: MatchSim = MatchSim.new(_config, 5, 5, 1)
	sim.start_with_hero_select()
	for i: int in range(1, 5):
		assert_not_null(sim.players[i].hero, "бот %d выбрал" % i)
	assert_null(sim.players[0].hero)


func test_round_starts_after_human_chooses() -> void:
	var sim: MatchSim = MatchSim.new(_config, 5, 2, 1)
	sim.start_with_hero_select()
	sim.tick()
	assert_eq(sim.phase, MatchSim.Phase.HERO_SELECT)
	var hero: HeroData = sim.players[0].hero_offers[1]
	sim.queue_command(0, ChooseHeroCommand.new(1))
	sim.tick()
	sim.tick()
	assert_eq(sim.phase, MatchSim.Phase.PREP)
	assert_eq(sim.round_number, 1)
	assert_eq(sim.players[0].hero, hero)
	assert_eq(sim.players[0].hero_hp, hero.hp)


func test_hero_select_timeout_picks_first_offer() -> void:
	var sim: MatchSim = MatchSim.new(_config, 5, 2, 1)
	sim.start_with_hero_select()
	var first: HeroData = sim.players[0].hero_offers[0]
	for i: int in _config.hero_select_ticks:
		sim.tick()
	assert_eq(sim.players[0].hero, first)
	assert_eq(sim.phase, MatchSim.Phase.PREP)


func test_tower_commands_rejected_during_hero_select() -> void:
	var sim: MatchSim = MatchSim.new(_config, 5, 2, 1)
	sim.start_with_hero_select()
	assert_eq(sim.execute_command(0, RerollShopCommand.new()), "Сначала выберите героя")


func test_baba_yaga_first_reroll_each_round_is_free() -> void:
	var sim: MatchSim = SimFixtures.make_hero_match(_config, &"baba_yaga")
	var player: PlayerState = sim.players[0]
	var gold: int = player.gold
	assert_eq(sim.execute_command(0, RerollShopCommand.new()), "")
	assert_eq(player.gold, gold, "первый бесплатно")
	assert_eq(sim.execute_command(0, RerollShopCommand.new()), "")
	assert_eq(player.gold, gold - _config.reroll_cost, "второй платный")


func test_baba_yaga_brew_makes_next_tower_level_two() -> void:
	var sim: MatchSim = SimFixtures.make_hero_match(_config, &"baba_yaga")
	var player: PlayerState = sim.players[0]
	player.gold = 50
	assert_eq(sim.execute_command(0, UseHeroSkillCommand.new()), "")
	assert_eq(player.gold, 50 - player.hero.skill.cost)
	var placed: TowerState = _buy_first_offer_anywhere(sim, player)
	assert_eq(placed.level, 2)
	var second: TowerState = _buy_first_offer_anywhere(sim, player)
	assert_eq(second.level, 1, "варево разовое")


func test_skill_only_once_per_round() -> void:
	var sim: MatchSim = SimFixtures.make_hero_match(_config, &"skomorokh")
	sim.players[0].gold = 50
	assert_eq(sim.execute_command(0, UseHeroSkillCommand.new()), "")
	assert_eq(sim.execute_command(0, UseHeroSkillCommand.new()), "Навык уже был в этом раунде")


func test_skill_cost_grows_after_use() -> void:
	var sim: MatchSim = SimFixtures.make_hero_match(_config, &"skomorokh")
	var player: PlayerState = sim.players[0]
	var first_cost: int = player.get_skill_cost()
	player.gold = 50
	sim.execute_command(0, UseHeroSkillCommand.new())
	assert_eq(player.get_skill_cost(), first_cost + player.hero.skill.cost_step)


func test_skill_not_enough_gold() -> void:
	var sim: MatchSim = SimFixtures.make_hero_match(_config, &"baba_yaga")
	sim.players[0].gold = 0
	assert_eq(sim.execute_command(0, UseHeroSkillCommand.new()), "Не хватает золота")


func test_domovoy_extra_gold_and_full_refund() -> void:
	var sim: MatchSim = SimFixtures.make_hero_match(_config, &"domovoy")
	var player: PlayerState = sim.players[0]
	assert_eq(player.gold, _config.start_gold + 14)
	var tower: TowerState = _buy_first_offer_anywhere(sim, player)
	player.end_prep()
	assert_eq(player.get_sell_price(tower), _config.tower_cost, "через раунд — всё равно 100%")


func test_cosmonaut_shop_upgrade_is_cheaper() -> void:
	var sim: MatchSim = SimFixtures.make_hero_match(_config, &"cosmonaut")
	var player: PlayerState = sim.players[0]
	assert_eq(player.get_shop_upgrade_price(), player.shop.upgrade_cost - 3)
	player.gold = 100
	var gold: int = player.gold
	var price: int = player.get_shop_upgrade_price()
	assert_eq(sim.execute_command(0, UpgradeShopCommand.new()), "")
	assert_eq(player.gold, gold - price)


func test_ilya_has_more_hp_and_strike_only_in_wave() -> void:
	var sim: MatchSim = SimFixtures.make_hero_match(_config, &"ilya")
	var player: PlayerState = sim.players[0]
	assert_eq(player.hero_hp, 50)
	player.gold = 50
	assert_eq(sim.execute_command(0, UseHeroSkillCommand.new()), "Навык — только в волну")
	_skip_to_wave_with_mobs(sim)
	var hp_before: Array[int] = []
	for mob: MobState in player.field.mobs:
		hp_before.append(mob.hp)
	assert_eq(sim.execute_command(0, UseHeroSkillCommand.new()), "")
	for i: int in player.field.mobs.size():
		var expected: int = hp_before[i] - hp_before[i] * 45 / 100
		assert_eq(player.field.mobs[i].hp, expected)


func test_leshy_knocks_mob_back_once_at_half_path() -> void:
	var field: FieldState = FieldState.new(_config)
	field.knockback_milli = 2000
	var mob: MobState = MobState.create(SimFixtures.find_mob(&"basic"))
	field.schedule_spawn(mob, 0)
	field.start_wave()
	var half: int = field.get_path_end_progress() / 2
	var knocked_at: int = -1
	for i: int in 400:
		var before: int = mob.progress
		field.tick()
		if mob.progress < before:
			assert_eq(knocked_at, -1, "отбросило только раз")
			knocked_at = before
		if not mob.is_alive():
			break
	assert_true(knocked_at >= half - mob.speed, "отброшен на середине")
	assert_true(mob.was_knocked_back)


func test_babushka_slows_enemy_army_not_base_wave() -> void:
	var field: FieldState = FieldState.new(_config)
	field.enemy_army_slow_percent = 20
	var unit: MobState = MobState.create(_config.army_mob)
	unit.sender_index = 1
	var base: MobState = MobState.create(_config.wave_mob)
	var unit_speed: int = unit.speed
	var base_speed: int = base.speed
	field.schedule_spawn(unit, 0)
	field.schedule_spawn(base, 0)
	field.start_wave()
	field.tick()
	assert_eq(unit.speed, unit_speed * 80 / 100)
	assert_eq(base.speed, base_speed)


func test_babushka_heal_is_capped_at_start_hp() -> void:
	var sim: MatchSim = SimFixtures.make_hero_match(_config, &"babushka")
	var player: PlayerState = sim.players[0]
	player.gold = 50
	assert_eq(sim.execute_command(0, UseHeroSkillCommand.new()), "Терем и так цел")
	player.hero_hp = player.hero_max_hp - 1
	assert_eq(sim.execute_command(0, UseHeroSkillCommand.new()), "")
	assert_eq(player.hero_hp, player.hero_max_hp)


func test_solovey_army_faster_and_gang_only_this_round() -> void:
	var sim: MatchSim = SimFixtures.make_hero_match(_config, &"solovey")
	var player: PlayerState = sim.players[0]
	assert_eq(player.army.speed_percent, 15)
	player.gold = 50
	var units: int = player.army.build_pack(0, 1).size()
	assert_eq(sim.execute_command(0, UseHeroSkillCommand.new()), "")
	assert_eq(player.army.build_pack(0, 1).size(), units + 3)
	_finish_round(sim)
	assert_eq(player.army.build_pack(0, 2).size(), units, "ватага — на один раунд")


func test_robber_breach_gives_sender_extra_gold() -> void:
	var robber: MobData = SimFixtures.find_mob(&"robber")
	assert_eq(robber.breach_gold_to_sender, 3)


func test_gorynych_silences_opponent_towers() -> void:
	var sim: MatchSim = SimFixtures.make_hero_match(_config, &"gorynych")
	var player: PlayerState = sim.players[0]
	player.gold = 50
	_skip_to_wave_with_mobs(sim)
	assert_eq(sim.execute_command(0, UseHeroSkillCommand.new()), "")
	var target: FieldState = sim.players[sim.opponent_of[0]].field
	assert_eq(target.silence_ticks_left, 140)
	assert_eq(player.field.silence_ticks_left, 0, "своё поле не трогает")


func test_silenced_field_towers_do_not_fire() -> void:
	var field: FieldState = FieldState.new(_config)
	var data: TowerData = SimFixtures.find_tower(_config, &"mech_1")
	field.add_tower(data, Vector2i(2, 4), 0)
	var mob: MobState = MobState.create(_config.wave_mob)
	field.schedule_spawn(mob, 0)
	field.start_wave()
	field.silence_towers(1000)
	for i: int in 200:
		field.tick()
	assert_eq(mob.hp, mob.max_hp)


func test_koschei_breaks_chest_below_half_hp() -> void:
	var sim: MatchSim = SimFixtures.make_hero_match(_config, &"koschei")
	var player: PlayerState = sim.players[0]
	player.gold = 100
	var cheap: TowerState = _buy_first_offer_anywhere(sim, player)
	var expensive: TowerState = _buy_first_offer_anywhere(sim, player)
	expensive.invested_total = 30
	player.hero_hp = player.hero_max_hp / 2 - 1
	player.notify_hp_lost(sim)
	assert_true(player.is_hero_triggered)
	assert_null(player.field.get_tower(expensive.id), "дорогая рухнула")
	assert_eq(cheap.level, 2, "остальные +1")
	player.notify_hp_lost(sim)
	assert_eq(cheap.level, 2, "срабатывает один раз")


func test_skomorokh_wheel_changes_something_or_nothing() -> void:
	var sim: MatchSim = SimFixtures.make_hero_match(_config, &"skomorokh")
	var player: PlayerState = sim.players[0]
	player.gold = 50
	assert_eq(sim.execute_command(0, UseHeroSkillCommand.new()), "")
	assert_true(player.hero_message.begins_with("Ярмарка"))


func test_hero_match_is_deterministic() -> void:
	assert_eq(_run_bot_match(4242), _run_bot_match(4242))


func test_bot_hero_match_finishes() -> void:
	var sim: MatchSim = MatchSim.new(_config, 31, 5, 0)
	sim.start_with_hero_select()
	var guard: int = 0
	while sim.phase != MatchSim.Phase.OVER and guard < MAX_TICKS:
		sim.tick()
		guard += 1
	assert_eq(sim.phase, MatchSim.Phase.OVER)


func _run_bot_match(seed_value: int) -> int:
	var sim: MatchSim = MatchSim.new(_config, seed_value, 5, 0)
	sim.start_with_hero_select()
	var guard: int = 0
	while sim.phase != MatchSim.Phase.OVER and guard < MAX_TICKS:
		sim.tick()
		guard += 1
	return sim.state_hash()


## Покупает первое предложение на первое подходящее место. Возвращает башню.
func _buy_first_offer_anywhere(sim: MatchSim, player: PlayerState) -> TowerState:
	player.shop.offers[0] = SimFixtures.find_tower(_config, &"ice_1")
	for cell: Vector2i in player.field.get_buildable_cells():
		if player.field.can_place_tower_data(player.shop.offers[0], cell, 0):
			assert_eq(sim.execute_command(0, BuyTowerCommand.new(0, cell, 0)), "")
			return player.field.get_tower_at(cell)
	fail_test("нет места")
	return null


func _skip_to_wave_with_mobs(sim: MatchSim) -> void:
	sim.queue_command(0, ReadyCommand.new())
	for i: int in 120:
		sim.tick()


func _finish_round(sim: MatchSim) -> void:
	var round_number: int = sim.round_number
	sim.queue_command(0, ReadyCommand.new())
	var guard: int = 0
	while sim.round_number == round_number and guard < 10000:
		sim.tick()
		guard += 1

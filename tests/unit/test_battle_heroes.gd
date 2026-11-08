extends GutTest
## Все 11 приёмов, ответ оберегом и отсутствие повторных наград.


func _make(hero: StringName) -> MatchSim:
	var config: GameConfig = SimFixtures.make_config()
	config.active_battle = load("res://data/active_battle.tres") as ActiveBattleConfig
	config.prep_requires_ready = true
	config.wave_base_count = 0
	config.wave_count_per_round = 0
	config.army_first_round = 1
	var sim: MatchSim = MatchSim.new(config, 771, 2, 2)
	sim.start()
	sim.players[0].pick_hero(load("res://data/heroes/%s.tres" % hero) as HeroData)
	sim.players[1].pick_hero(load("res://data/heroes/vasilisa.tres") as HeroData)
	for player: PlayerState in sim.players:
		player.field.set_shop_level(4)
		player.army.base_units = 0
		for i: int in 3:
			var spot: Vector3i = BotBrain.new(0).find_best_spot(player.field, config.towers[0])
			player.field.add_tower(config.towers[0], Vector2i(spot.x, spot.y), spot.z)
	sim.battle_heroes.prepare(sim)
	for player: PlayerState in sim.players:
		sim.execute_command(player.index, ReadyCommand.new())
	sim.tick()
	return sim


func _mob(sim: MatchSim, field_index: int, sender: int) -> MobState:
	var mob: MobState = MobState.create(sim.config.army_mob)
	mob.id = 100 + sim.players[field_index].field.mobs.size()
	mob.max_hp = 1000
	mob.hp = 1000
	mob.speed = 0
	mob.sender_index = sender
	sim.players[field_index].field.mobs.append(mob)
	return mob


func _advance_effect(sim: MatchSim, count: int) -> void:
	for i: int in count:
		sim.phase_tick += 1
		sim.battle_heroes.tick(sim)
		for player: PlayerState in sim.players:
			player.field.tick(false)


func test_all_catalog_heroes_have_unique_free_orders() -> void:
	var config: GameConfig = load("res://data/game_config.tres") as GameConfig
	assert_not_null(config.active_battle, "Основной ресурс действительно включает новый бой")
	var settings: ActiveBattleConfig = load("res://data/active_battle.tres") as ActiveBattleConfig
	assert_eq(settings.skills.size(), config.heroes.size())
	for hero: HeroData in config.heroes:
		assert_not_null(settings.skill_for(hero.id), String(hero.id))


func test_yaga_moves_selected_tower_after_lock() -> void:
	var sim: MatchSim = _make(&"baba_yaga")
	var order: BattleHeroOrder = sim.battle_heroes.get_order(0)
	var tower: TowerState = sim.players[0].field.get_tower(order.tower_id)
	var before: Vector2i = tower.anchor
	assert_eq(sim.execute_command(0, UseHeroSkillCommand.new()), "")
	assert_true(tower.is_action_blocked())
	_advance_effect(sim, order.skill.duration_ticks - 1)
	assert_eq(tower.anchor, before)
	_advance_effect(sim, 1)
	assert_eq(tower.anchor, order.cell)
	assert_ne(tower.anchor, before)


func test_domovoy_swaps_two_selected_towers() -> void:
	var sim: MatchSim = _make(&"domovoy")
	var order: BattleHeroOrder = sim.battle_heroes.get_order(0)
	var field: FieldState = sim.players[0].field
	var first: TowerState = field.get_tower(order.tower_id)
	var second: TowerState = field.get_tower(order.second_id)
	var first_cell: Vector2i = first.anchor
	var second_cell: Vector2i = second.anchor
	assert_eq(sim.execute_command(0, UseHeroSkillCommand.new()), "")
	_advance_effect(sim, order.skill.duration_ticks)
	assert_eq(first.anchor, second_cell)
	assert_eq(second.anchor, first_cell)


func test_warning_then_suppression_and_ward_counter() -> void:
	var sim: MatchSim = _make(&"gorynych")
	var target: TowerState = sim.players[1].field.towers[0]
	assert_eq(sim.execute_command(0, AimHeroCommand.new(1, target.anchor)), "")
	assert_eq(sim.execute_command(0, UseHeroSkillCommand.new()), "")
	_advance_effect(sim, 23)
	assert_eq(target.suppressed_ticks, 0)
	_advance_effect(sim, 1)
	assert_gt(target.suppressed_ticks, 0)
	assert_eq(sim.execute_command(1, AimHeroCommand.new(1, target.anchor)), "")
	assert_eq(sim.execute_command(1, UseHeroSkillCommand.new()), "")
	_advance_effect(sim, 1)
	assert_eq(target.suppressed_ticks, 0)
	assert_gt(target.ward_ticks, 0)
	target.action_lock_ticks = 10
	assert_true(target.is_action_blocked(), "Оберег не снимает собственную зарядку")


func test_ilya_only_hits_circle_after_warning_and_respects_cap() -> void:
	var sim: MatchSim = _make(&"ilya")
	var mob: MobState = _mob(sim, 0, 1)
	var field: FieldState = sim.players[0].field
	sim.execute_command(0, AimHeroCommand.new(0, field.layout.path_cells[0]))
	assert_eq(sim.execute_command(0, UseHeroSkillCommand.new()), "")
	_advance_effect(sim, 19)
	assert_eq(mob.hp, 1000)
	_advance_effect(sim, 1)
	assert_eq(mob.hp, 550)


func test_leshy_trap_catches_each_mob_once() -> void:
	var sim: MatchSim = _make(&"leshy")
	var mob: MobState = _mob(sim, 0, 1)
	var field: FieldState = sim.players[0].field
	mob.progress = 3000
	mob.was_knocked_back = true
	sim.execute_command(0, AimHeroCommand.new(0, field.layout.path_cells[3]))
	assert_eq(sim.execute_command(0, UseHeroSkillCommand.new()), "")
	_advance_effect(sim, 1)
	assert_eq(mob.progress, 0)
	mob.progress = 3000
	_advance_effect(sim, 1)
	assert_eq(mob.progress, 3000)
	assert_true(mob.was_knocked_back)


func test_solovey_only_boosts_own_spawned_army() -> void:
	var sim: MatchSim = _make(&"solovey")
	var own: MobState = _mob(sim, 1, 0)
	var base: MobState = _mob(sim, 1, -1)
	own.speed = 20
	assert_eq(sim.execute_command(0, UseHeroSkillCommand.new()), "")
	_advance_effect(sim, 1)
	assert_eq(own.current_speed(), 30)
	assert_eq(base.rush_ticks, 0)
	assert_eq(_mob(sim, 1, 0).rush_ticks, 0, "Позднее подкрепление не получает разгон")


func test_koschei_revives_only_first_death_and_no_double_reward() -> void:
	var sim: MatchSim = _make(&"koschei")
	var first: MobState = _mob(sim, 1, 0)
	var second: MobState = _mob(sim, 1, 0)
	var field: FieldState = sim.players[1].field
	assert_eq(sim.execute_command(0, UseHeroSkillCommand.new()), "")
	_advance_effect(sim, 1)
	field.deal_mob_damage(first, 10000)
	assert_eq(first.hp, 400)
	assert_eq(field.pending_kill_gold, 0)
	field.deal_mob_damage(second, 10000)
	assert_false(second.is_alive())
	field.deal_mob_damage(first, 10000)
	assert_false(first.is_alive())
	assert_eq(field.pending_kill_gold, first.kill_reward + second.kill_reward)


func test_babushka_heals_own_army_without_exceeding_maximum() -> void:
	var sim: MatchSim = _make(&"babushka")
	var own: MobState = _mob(sim, 1, 0)
	var base: MobState = _mob(sim, 1, -1)
	own.hp = 800
	base.hp = 500
	assert_eq(sim.execute_command(0, UseHeroSkillCommand.new()), "")
	_advance_effect(sim, 1)
	assert_eq(own.hp, 1000)
	assert_eq(base.hp, 500)


func test_skomorokh_decoy_has_no_reward_or_wave_hold() -> void:
	var sim: MatchSim = _make(&"skomorokh")
	assert_eq(sim.execute_command(0, UseHeroSkillCommand.new()), "")
	_advance_effect(sim, 20)
	var field: FieldState = sim.players[1].field
	assert_eq(field.mobs.size(), 1)
	var decoy: MobState = field.mobs[0]
	assert_true(decoy.is_decoy)
	assert_true(field.is_wave_done())
	field.deal_mob_damage(decoy, 10000)
	assert_eq(field.pending_kill_gold, 0)
	assert_eq(field.battle_report.killed, 0)


func test_cosmonaut_charge_then_temporary_haste() -> void:
	var sim: MatchSim = _make(&"cosmonaut")
	var order: BattleHeroOrder = sim.battle_heroes.get_order(0)
	var tower: TowerState = sim.players[0].field.get_tower(order.tower_id)
	assert_eq(sim.execute_command(0, UseHeroSkillCommand.new()), "")
	assert_true(tower.is_action_blocked())
	_advance_effect(sim, 40)
	assert_false(tower.is_action_blocked())
	assert_gt(tower.haste_ticks, 0)
	_advance_effect(sim, 120)
	assert_eq(tower.haste_ticks, 0)


func test_free_one_use_and_target_rejection() -> void:
	var sim: MatchSim = _make(&"gorynych")
	var gold: int = sim.players[0].gold
	assert_ne(sim.execute_command(0, AimHeroCommand.new(0, Vector2i.ZERO)), "")
	assert_eq(sim.execute_command(0, UseHeroSkillCommand.new()), "")
	assert_eq(sim.players[0].gold, gold)
	assert_ne(sim.execute_command(0, UseHeroSkillCommand.new()), "")
	assert_ne(sim.execute_command(0, AimHeroCommand.new(1, Vector2i.ZERO)), "")

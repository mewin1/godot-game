extends GutTest
## Регрессии новой сборки: настоящий конфиг, транзакции резерва, заговоры и взаимодействия.

var _config: GameConfig
var _player: PlayerState


func before_each() -> void:
	_config = (load("res://data/game_config.tres") as GameConfig).duplicate() as GameConfig
	_player = PlayerState.new(_config, 0, 741)
	_player.start_prep(false)
	_player.gold = 1000


func _tower(id_value: StringName) -> TowerData:
	for data: TowerData in _config.towers:
		if data.id == id_value:
			return data
	return null


func _offer(data: TowerData) -> void:
	_player.shop.offers[0] = data
	_player.shop.rite_offers[0] = null


func _rite(id_value: StringName) -> RiteData:
	for data: RiteData in _config.rites:
		if data.id == id_value:
			return data
	return null


func _offer_rite(id_value: StringName) -> void:
	_player.shop.offers[2] = null
	_player.shop.rite_offers[2] = _rite(id_value)


func _mob(at_progress: int = 3000) -> MobState:
	var mob: MobState = MobState.create(_config.army_mob)
	mob.id = _player.field.mobs.size() + 1
	mob.hp = 1000
	mob.max_hp = 1000
	mob.progress = at_progress
	_player.field.mobs.append(mob)
	return mob


func test_current_content_preserves_army_and_three_empty_idols() -> void:
	assert_eq(_config.towers.size(), 21)
	assert_eq(_config.army_base_units, 5)
	assert_true(_config.school_bonuses.is_empty())
	assert_eq(_player.field.idols.size(), 3)
	for idol: IdolState in _player.field.idols:
		assert_eq(idol.god, &"")


func test_first_two_shop_slots_are_attackers_even_with_rites() -> void:
	for i: int in 30:
		_player.shop.roll(_player.rng)
		assert_not_null(_player.shop.offers[0])
		assert_not_null(_player.shop.offers[1])
		assert_true(_player.shop.offers[0].attacks)
		assert_true(_player.shop.offers[1].attacks)


func test_reserve_purchase_pays_without_occupying_field() -> void:
	_offer(_tower(&"spark"))
	assert_eq(_player.buy_to_reserve(0), "")
	assert_eq(_player.gold, 994)
	assert_eq(_player.reserve.size(), 1)
	assert_eq(_player.field.towers.size(), 0)
	assert_null(_player.shop.get_offer(0))


func test_full_reserve_keeps_gold_and_offer() -> void:
	for i: int in _player.get_reserve_capacity():
		_offer(_tower(&"spark"))
		_player.buy_to_reserve(0)
	_offer(_tower(&"brazier"))
	var before: int = _player.gold
	assert_ne(_player.buy_to_reserve(0), "")
	assert_eq(_player.gold, before)
	assert_not_null(_player.shop.get_offer(0))


func test_transfer_keeps_identity_level_and_paid_cost() -> void:
	_offer(_tower(&"spark"))
	_player.buy_to_reserve(0)
	var tower: TowerState = _player.reserve[0]
	tower.level = 2
	tower.enchantment = RiteData.Effect.ENCHANT_DAMAGE
	assert_eq(_player.place_from_reserve(tower.id, Vector2i(2, 4), 0), "")
	assert_eq(_player.store_tower(tower.id), "")
	assert_same(_player.reserve[0], tower)
	assert_eq(tower.level, 2)
	assert_eq(tower.enchantment, int(RiteData.Effect.ENCHANT_DAMAGE))
	assert_eq(_player.get_sell_price(tower), 6)
	_player.end_prep()
	assert_eq(_player.get_sell_price(tower), 2)


func test_bad_reserve_placement_is_atomic() -> void:
	_offer(_tower(&"spark"))
	_player.buy_to_reserve(0)
	var tower: TowerState = _player.reserve[0]
	assert_ne(_player.place_from_reserve(tower.id, Vector2i(1, 4), 0), "")
	assert_eq(_player.reserve.size(), 1)
	assert_eq(_player.field.towers.size(), 0)


func test_merging_across_reserve_and_field_preserves_enchantment() -> void:
	var data: TowerData = _tower(&"spark")
	var target: TowerState = _player.field.add_tower(data, Vector2i(2, 4), 0)
	_offer(data)
	_player.buy_to_reserve(0)
	var source: TowerState = _player.reserve[0]
	source.enchantment = RiteData.Effect.ENCHANT_RATE
	assert_eq(_player.merge_towers(source.id, target.id), "")
	assert_true(_player.reserve.is_empty())
	assert_eq(target.level, 2)
	assert_eq(target.enchantment, int(RiteData.Effect.ENCHANT_RATE))


func test_idol_rite_dedicates_once_and_rejects_other_god() -> void:
	_offer_rite(&"perun_charge")
	assert_eq(_player.buy_rite(2, 0), "")
	assert_eq(_player.field.idols[0].god, &"perun")
	assert_eq(_player.field.idols[0].chain_chance_bonus, 10)
	_offer_rite(&"svarog_burn")
	var before: int = _player.gold
	assert_ne(_player.buy_rite(2, 0), "")
	assert_eq(_player.gold, before)
	assert_not_null(_player.shop.get_rite(2))


func test_same_god_cannot_occupy_second_idol() -> void:
	_offer_rite(&"perun_charge")
	_player.buy_rite(2, 0)
	_offer_rite(&"perun_power")
	assert_ne(_player.buy_rite(2, 1), "")
	assert_eq(_player.field.idols[1].god, &"")


func test_idol_chance_cannot_be_bought_past_cap() -> void:
	for i: int in 2:
		_offer_rite(&"perun_charge")
		assert_eq(_player.buy_rite(2, 0), "")
	_offer_rite(&"perun_charge")
	assert_ne(_player.buy_rite(2, 0), "")
	assert_eq(_player.field.idols[0].chain_chance_bonus, 20)


func test_tower_rite_can_enchant_reserved_tower_only_once() -> void:
	_offer(_tower(&"spark"))
	_player.buy_to_reserve(0)
	var tower: TowerState = _player.reserve[0]
	_offer_rite(&"enchant_damage")
	assert_eq(_player.buy_rite(2, tower.id), "")
	assert_eq(tower.invested_total, 12)
	_offer_rite(&"enchant_rate")
	assert_ne(_player.buy_rite(2, tower.id), "")
	assert_eq(tower.enchantment, int(RiteData.Effect.ENCHANT_DAMAGE))


func test_awakening_requires_max_level_and_existing_enchantment() -> void:
	var tower: TowerState = _player.field.add_tower(_tower(&"spark"), Vector2i(2, 4), 0)
	_offer_rite(&"awaken_focus")
	assert_ne(_player.buy_rite(2, tower.id), "")
	tower.level = 3
	tower.enchantment = RiteData.Effect.ENCHANT_DAMAGE
	assert_eq(_player.buy_rite(2, tower.id), "")
	_offer_rite(&"awaken_wide")
	assert_ne(_player.buy_rite(2, tower.id), "")


func test_legacy_perun_three_hits_chain_once_without_recursion() -> void:
	_config.chain_chance_percent = -1
	var tower: TowerState = _player.field.add_tower(_tower(&"spark"), Vector2i(2, 4), 0)
	var first: MobState = _mob(3000)
	var next: MobState = _mob(3500)
	for i: int in 2:
		DivineCombat.hit(_player.field, tower, first, 10)
	assert_eq(next.hp, 1000)
	DivineCombat.hit(_player.field, tower, first, 10)
	assert_eq(next.hp, 996)
	assert_eq(next.charges, 0)


func test_perun_idol_increases_dry_and_wet_chances() -> void:
	_offer_rite(&"perun_charge")
	_player.buy_rite(2, 0)
	var mob: MobState = _mob(3000)
	assert_eq(DivineCombat.chain_chance(_player.field, mob), 30)
	mob.wet_ticks_left = 1
	assert_eq(DivineCombat.chain_chance(_player.field, mob), 90)


func test_wind_against_path_slows_and_along_path_speeds() -> void:
	var tower: TowerState = _player.field.add_tower(_tower(&"wind"), Vector2i(2, 4), 0)
	var mob: MobState = _mob(2000)
	# Путь идёт вверх; башня выше моба дует вниз навстречу.
	tower.rotation = 2
	DivineCombat.apply_wind(_player.field, mob)
	assert_gt(mob.wind_slow_percent, 0)
	assert_lt(mob.current_speed(), mob.speed)
	# Башня ниже моба дует вверх вслед за ним.
	tower.anchor = Vector2i(2, 8)
	tower.rotation = 0
	DivineCombat.apply_wind(_player.field, mob)
	assert_gt(mob.wind_boost_percent, 0)
	assert_gt(mob.current_speed(), mob.speed)


func test_wind_does_not_stack_with_same_direction() -> void:
	_player.field.add_tower(_tower(&"wind"), Vector2i(2, 4), 2)
	_player.field.add_tower(_tower(&"wind"), Vector2i(2, 3), 2)
	var mob: MobState = _mob(2000)
	DivineCombat.apply_wind(_player.field, mob)
	assert_lte(mob.wind_slow_percent, 30)


func test_fire_persists_and_wind_increases_periodic_damage() -> void:
	var tower: TowerState = _player.field.add_tower(_tower(&"brazier"), Vector2i(2, 4), 0)
	var mob: MobState = _mob()
	DivineCombat.hit(_player.field, tower, mob, 8)
	assert_gt(mob.burn_damage, 0)
	mob.is_in_wind = true
	var before: int = mob.hp
	DivineCombat.tick_effects(_player.field, mob)
	assert_eq(before - mob.hp, mob.burn_damage * 125 / 100)


func test_ghost_copies_idols_and_enchantments_independently() -> void:
	_offer_rite(&"perun_charge")
	_player.buy_rite(2, 0)
	var tower: TowerState = _player.field.add_tower(_tower(&"spark"), Vector2i(2, 4), 0)
	tower.enchantment = RiteData.Effect.ENCHANT_RATE
	var ghost: FieldState = FieldState.new(_config)
	ghost.copy_towers_from(_player.field)
	assert_eq(ghost.towers[0].enchantment, int(RiteData.Effect.ENCHANT_RATE))
	assert_eq(ghost.idols[0].chain_chance_bonus, 10)
	ghost.idols[0].chain_chance_bonus = 0
	assert_eq(_player.field.idols[0].chain_chance_bonus, 10)


func test_path_and_space_grow_only_with_shop_upgrade() -> void:
	var before: int = _player.field.path_length
	_player.upgrade_shop()
	assert_gt(_player.field.path_length, before)
	assert_eq(_player.get_reserve_capacity(), 10)


func test_preparation_30_seconds_then_60_seconds() -> void:
	var sim: MatchSim = MatchSim.new(_config, 42, 2, 1)
	sim.start()
	assert_eq(sim.get_prep_ticks(), 600)
	sim.round_number = 3
	assert_eq(sim.get_prep_ticks(), 1200)


func test_armies_start_identical_and_have_five_units() -> void:
	var other: PlayerState = PlayerState.new(_config, 1, 451)
	assert_eq(_player.army.get_unit_count(), 5)
	assert_eq(other.army.get_unit_count(), 5)
	assert_eq(_player.army.build_pack(0, 2)[0].hp, other.army.build_pack(1, 2)[0].hp)


func test_retreat_does_not_give_kill_gold_or_damage() -> void:
	_mob()
	_player.field.schedule_spawn(MobState.create(_config.army_mob), 999)
	_player.field.retreat_remaining()
	assert_true(_player.field.is_wave_done())
	assert_eq(_player.field.pending_kill_gold, 0)
	assert_true(_player.field.pending_breaches.is_empty())


func test_same_commands_with_reserve_and_idols_keep_same_hash() -> void:
	var other: PlayerState = PlayerState.new(_config, 0, 741)
	other.start_prep(false)
	other.gold = 1000
	_offer(_tower(&"spark"))
	other.shop.offers[0] = _tower(&"spark")
	other.shop.rite_offers[0] = null
	_player.buy_to_reserve(0)
	other.buy_to_reserve(0)
	_offer_rite(&"perun_charge")
	other.shop.offers[2] = null
	other.shop.rite_offers[2] = _rite(&"perun_charge")
	_player.buy_rite(2, 0)
	other.buy_rite(2, 0)
	var first_hash: StateHasher = StateHasher.new()
	var second_hash: StateHasher = StateHasher.new()
	_player.add_to_hash(first_hash)
	other.add_to_hash(second_hash)
	assert_eq(first_hash.value, second_hash.value)


func test_shared_battle_stops_at_40_seconds_without_forced_breach() -> void:
	var sim: MatchSim = MatchSim.new(_config, 89, 2, 2)
	sim.start()
	for player: PlayerState in sim.players:
		player.is_ready = true
	sim.tick()
	assert_eq(sim.phase, MatchSim.Phase.WAVE)
	for player: PlayerState in sim.players:
		var tank: MobState = MobState.create(_config.army_mob)
		tank.max_hp = 1000000
		tank.hp = tank.max_hp
		tank.speed = 1
		player.field.schedule_spawn(tank, 0)
	for i: int in _config.battle_real_ticks:
		sim.tick()
	assert_eq(sim.phase, MatchSim.Phase.PREP)
	assert_eq(sim.round_number, 2)
	for player: PlayerState in sim.players:
		assert_eq(player.hero_hp, _config.hero_hp - _config.wave_base_count)


func test_two_early_attackers_can_hold_first_wave() -> void:
	var field: FieldState = _player.field
	field.add_tower(_tower(&"spark"), Vector2i(2, 6), 0)
	field.add_tower(_tower(&"brazier"), Vector2i(2, 4), 0)
	field.start_wave()
	WaveBuilder.schedule_wave(_config, field, 1, [])
	for i: int in 400:
		field.tick()
	assert_true(field.is_wave_done())
	assert_true(field.pending_breaches.is_empty())


func test_reserve_commands_rejected_during_combat() -> void:
	var sim: MatchSim = MatchSim.new(_config, 91, 2, 2)
	sim.start()
	for player: PlayerState in sim.players:
		player.is_ready = true
	sim.tick()
	var before: int = sim.players[0].gold
	assert_ne(sim.execute_command(0, ReserveCommand.new(ReserveCommand.Action.BUY, 0)), "")
	assert_eq(sim.players[0].gold, before)


func test_large_army_is_fully_spawned_within_window() -> void:
	var field: FieldState = _player.field
	var pack: Array[MobState] = []
	for i: int in 60:
		pack.append(MobState.create(_config.army_mob))
	field.start_wave()
	WaveBuilder.schedule_wave(_config, field, 1, pack)
	for i: int in _config.spawn_window_ticks + 1:
		field.tick()
	assert_eq(field.mobs.size() + field.pending_breaches.size(),
			60 + _config.wave_base_count)


func test_gift_can_merge_directly_into_field_without_extra_placement() -> void:
	var data: TowerData = _tower(&"spark")
	var target: TowerState = _player.field.add_tower(data, Vector2i(2, 4), 0)
	_player.gift_towers.append(data)
	var has_direct_merge: bool = _player.has_method("gift_into")
	assert_true(has_direct_merge, "Подарок должен сливаться без промежуточной установки")
	if not has_direct_merge:
		return
	assert_eq(_player.gift_into(0, target.id), "")
	assert_eq(target.level, 2)
	assert_true(_player.gift_towers.is_empty())
	assert_eq(_player.field.towers.size(), 1)


func test_gift_can_merge_into_full_reserve_without_new_slot() -> void:
	var data: TowerData = _tower(&"spark")
	for i: int in _player.get_reserve_capacity():
		_offer(data)
		_player.buy_to_reserve(0)
	_player.gift_towers.append(data)
	var target: TowerState = _player.reserve[0]
	var has_direct_merge: bool = _player.has_method("gift_into")
	assert_true(has_direct_merge)
	if not has_direct_merge:
		return
	assert_eq(_player.gift_into(0, target.id), "")
	assert_eq(target.level, 2)
	assert_eq(_player.reserve.size(), _player.get_reserve_capacity())


func test_invalid_gift_merge_keeps_reward_and_target() -> void:
	var target: TowerState = _player.field.add_tower(_tower(&"spark"), Vector2i(2, 4), 0)
	_player.gift_towers.append(_tower(&"brazier"))
	assert_ne(_player.gift_into(0, target.id), "")
	assert_eq(target.level, 1)
	assert_eq(_player.gift_towers.size(), 1)


func test_gift_sale_equals_sale_after_placement() -> void:
	_player.gift_towers.append(_tower(&"spark"))
	var before: int = _player.gold
	assert_eq(_player.sell_gift(0), "")
	assert_eq(_player.gold - before, _config.tower_cost / _config.sell_divisor)
	assert_true(_player.gift_towers.is_empty())


func test_rounds_never_expand_unupgraded_field() -> void:
	_config.prep_ticks = 1
	_config.start_gold = 1000
	_config.hero_hp = 1000
	_config.army_first_round = 99
	_config.wave_base_count = 1
	_config.wave_count_per_round = 0
	var sim: MatchSim = MatchSim.new(_config, 96, 2, 2)
	sim.start()
	var original_length: int = sim.players[0].field.path_length
	var original_space: int = sim.players[0].field.get_buildable_cells().size()
	var guard: int = 0
	while sim.round_number < 5 and guard < 2000:
		if sim.phase == MatchSim.Phase.PREP:
			for player: PlayerState in sim.players:
				assert_eq(sim.execute_command(player.index, ReadyCommand.new()), "")
		sim.tick()
		guard += 1
	assert_eq(sim.round_number, 5)
	assert_eq(sim.players[0].field.path_length, original_length)
	assert_eq(sim.players[0].field.get_buildable_cells().size(), original_space)
	assert_eq(sim.execute_command(0, UpgradeShopCommand.new()), "")
	assert_gt(sim.players[0].field.path_length, original_length)


func test_visual_interpolation_spans_all_accelerated_substeps() -> void:
	var field: FieldState = _player.field
	var mob: MobState = _mob(1000)
	var before: int = mob.progress
	field.begin_visual_step()
	for i: int in 5:
		field.tick()
	field.end_visual_step()
	assert_eq(mob.previous_progress, before)
	assert_eq(mob.progress, before + 5 * mob.speed)


func test_wind_levels_strengthen_control_without_direct_damage() -> void:
	var wind: TowerState = _player.field.add_tower(_tower(&"wind"), Vector2i(2, 4), 2)
	var mob: MobState = _mob(2000)
	for level: int in range(1, 4):
		wind.level = level
		DivineCombat.apply_wind(_player.field, mob)
		assert_eq(mob.wind_slow_percent, 30 + 5 * (level - 1))
		assert_eq(DivineCombat.wind_length(_player.field, wind), 5000 + 1000 * (level - 1))
	var gale: TowerState = TowerState.new()
	gale.data = _tower(&"gale")
	gale.level = 3
	assert_eq(DivineCombat.wind_length(_player.field, gale), 5000)
	assert_eq(_player.field.get_tower_damage(gale), 0)


func test_upgraded_wind_keeps_control_after_reserve_merge_and_caps_power() -> void:
	_offer(_tower(&"wind"))
	assert_eq(_player.buy_to_reserve(0), "")
	var wind: TowerState = _player.reserve[0]
	_offer(_tower(&"wind"))
	assert_eq(_player.buy_tower_into(0, wind.id), "")
	assert_eq(wind.level, 2)
	assert_eq(_player.place_from_reserve(wind.id, Vector2i(2, 4), 2), "")
	var mob: MobState = _mob(2000)
	DivineCombat.apply_wind(_player.field, mob)
	assert_eq(mob.wind_slow_percent, 35)
	var idol: IdolState = _player.field.idols[0]
	idol.god = &"stribog"
	idol.wind_power = 100
	DivineCombat.apply_wind(_player.field, mob)
	assert_eq(mob.wind_slow_percent, _config.max_wind_slow_percent)

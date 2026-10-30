extends GutTest
## Вода, независимый RNG боя, вероятность и границы цепи на настоящем конфиге.

var _config: GameConfig
var _field: FieldState


func before_each() -> void:
	_config = (load("res://data/game_config.tres") as GameConfig).duplicate() as GameConfig
	_field = FieldState.new(_config, 3, 407)


func _tower(id_value: StringName) -> TowerState:
	for data: TowerData in _config.towers:
		if data.id == id_value:
			return _field.add_tower(data, Vector2i(2, 4), 0)
	return null


func _mob(progress: int = 3000) -> MobState:
	var mob: MobState = MobState.create(_config.army_mob)
	mob.id = _field.mobs.size() + 1
	mob.max_hp = 1000000
	mob.hp = mob.max_hp
	mob.progress = progress
	_field.mobs.append(mob)
	return mob


func test_water_splash_wets_group_and_levels_extend_duration() -> void:
	var water: TowerState = _tower(&"water")
	water.level = 2
	var first: MobState = _mob(3000)
	var second: MobState = _mob(3500)
	_field._shoot(water, first)
	assert_eq(first.wet_ticks_left, 80)
	assert_eq(second.wet_ticks_left, 80)
	var idol: IdolState = _field.idols[0]
	idol.apply_rite(load("res://data/rites/water_duration.tres") as RiteData)
	water.level = 3
	DivineCombat.hit(_field, water, first, 4)
	assert_eq(first.wet_ticks_left, 120)


func test_wetness_expires_and_refresh_never_shortens_it() -> void:
	var water: TowerState = _tower(&"water")
	var mob: MobState = _mob()
	mob.wet_ticks_left = 100
	DivineCombat.hit(_field, water, mob, 4)
	assert_eq(mob.wet_ticks_left, 100)
	mob.wet_ticks_left = 1
	assert_eq(DivineCombat.chain_chance(_field, mob), 80)
	DivineCombat.tick_effects(_field, mob)
	assert_eq(DivineCombat.chain_chance(_field, mob), 20)


func test_guaranteed_chain_hits_extra_targets_once_without_secondary_rolls() -> void:
	_config.chain_chance_percent = 100
	var tower: TowerState = _tower(&"spark")
	var first: MobState = _mob()
	var second: MobState = _mob(3500)
	var third: MobState = _mob(4000)
	third.wet_ticks_left = 100
	DivineCombat.hit(_field, tower, first, 10)
	assert_eq(first.hp, first.max_hp - 10)
	assert_eq(second.hp, second.max_hp - 4)
	assert_eq(third.hp, third.max_hp)
	assert_eq(second.charges, 0)
	var idol: IdolState = _field.idols[0]
	idol.god = &"perun"
	idol.chain_targets = 1
	DivineCombat.hit(_field, tower, first, 10)
	assert_eq(second.hp, second.max_hp - 8)
	assert_eq(third.hp, third.max_hp - 4)


func test_zero_chance_and_shield_block_chain_and_shield_blocks_wetting() -> void:
	var tower: TowerState = _tower(&"spark")
	var first: MobState = _mob()
	var second: MobState = _mob(3500)
	_config.chain_chance_percent = 0
	DivineCombat.hit(_field, tower, first, 10)
	assert_eq(second.hp, second.max_hp)
	_config.chain_chance_percent = 100
	first.shield_left = 1
	DivineCombat.hit(_field, tower, first, 10)
	assert_eq(second.hp, second.max_hp)
	assert_eq(first.shield_left, 0)
	var water: TowerState = _tower(&"water")
	first.shield_left = 1
	DivineCombat.hit(_field, water, first, 4)
	assert_eq(first.wet_ticks_left, 0)


func test_killing_primary_can_chain_but_never_pays_twice_for_dead_target() -> void:
	_config.chain_chance_percent = 100
	var tower: TowerState = _tower(&"spark")
	var first: MobState = _mob()
	var second: MobState = _mob(3500)
	first.hp = 1
	DivineCombat.hit(_field, tower, first, 10)
	var reward: int = _field.pending_kill_gold
	DivineCombat.hit(_field, tower, first, 10)
	assert_eq(_field.pending_kill_gold, reward)
	assert_eq(second.hp, second.max_hp - 4)


func test_rng_is_repeatable_and_wet_targets_trigger_more_chains() -> void:
	var dry: int = _chain_count(false)
	var wet: int = _chain_count(true)
	assert_eq(dry, _chain_count(false))
	assert_eq(wet, _chain_count(true))
	assert_between(dry, 150, 250)
	assert_between(wet, 750, 850)
	assert_gt(wet, dry * 2)


func _chain_count(wet: bool) -> int:
	_field = FieldState.new(_config, 3, 407)
	var tower: TowerState = _tower(&"spark")
	var first: MobState = _mob()
	var second: MobState = _mob(3500)
	first.wet_ticks_left = 100 if wet else 0
	for i: int in 1000:
		DivineCombat.hit(_field, tower, first, 10)
	return (second.max_hp - second.hp) / 4


func test_ghost_copies_rng_and_idol_without_sharing_mutable_state() -> void:
	_field.roll_chance(20)
	var ghost: FieldState = FieldState.new(_config, 3, 999)
	ghost.copy_towers_from(_field)
	for i: int in 32:
		assert_eq(_field.roll_chance(37), ghost.roll_chance(37))
	var before: StateHasher = StateHasher.new()
	_field.add_to_hash(before)
	_field.roll_chance(37)
	var after: StateHasher = StateHasher.new()
	_field.add_to_hash(after)
	assert_ne(before.value, after.value)


func test_probability_cap_and_armor_on_secondary_target() -> void:
	var tower: TowerState = _tower(&"spark")
	var first: MobState = _mob()
	var second: MobState = _mob(3500)
	first.wet_ticks_left = 100
	var idol: IdolState = _field.idols[0]
	idol.god = &"perun"
	idol.chain_chance_bonus = 100
	assert_eq(DivineCombat.chain_chance(_field, first), 100)
	second.armor = 100
	DivineCombat.hit(_field, tower, first, 10)
	assert_eq(second.hp, second.max_hp - 1)
	assert_false(_field.roll_chance(0))
	assert_true(_field.roll_chance(100))


func test_water_reserve_merge_keeps_rite_and_strengthens_wetting() -> void:
	var player: PlayerState = PlayerState.new(_config, 0, 407)
	player.gold = 100
	player.start_prep(false)
	var water_data: TowerData = _tower(&"water").data
	for i: int in 2:
		player.shop.offers[0] = water_data
		player.shop.rite_offers[0] = null
		if i == 0:
			assert_eq(player.buy_to_reserve(0), "")
		else:
			assert_eq(player.buy_tower_into(0, player.reserve[0].id), "")
	var tower: TowerState = player.reserve[0]
	tower.enchantment = RiteData.Effect.ENCHANT_RANGE
	assert_eq(player.place_from_reserve(tower.id, Vector2i(2, 4), 0), "")
	var mob: MobState = _mob()
	DivineCombat.hit(player.field, tower, mob, 4)
	assert_eq(mob.wet_ticks_left, 80)
	assert_eq(tower.enchantment, int(RiteData.Effect.ENCHANT_RANGE))


func test_wetness_changes_hash_and_wide_awakening_reaches_another_target() -> void:
	var water: TowerState = _tower(&"water")
	var first: MobState = _mob()
	var distant: MobState = _mob(4400)
	var before: StateHasher = StateHasher.new()
	_field.add_to_hash(before)
	first.wet_ticks_left = 1
	var after: StateHasher = StateHasher.new()
	_field.add_to_hash(after)
	assert_ne(before.value, after.value)
	_field._shoot(water, first)
	assert_eq(distant.wet_ticks_left, 0)
	water.awakening = RiteData.Effect.AWAKEN_WIDE
	_field._shoot(water, first)
	assert_gt(distant.wet_ticks_left, 0)


func test_bot_uses_water_in_support_of_perun_and_buys_merge_copy() -> void:
	var sim: MatchSim = MatchSim.new(_config, 407, 2, 2)
	sim.start()
	var player: PlayerState = sim.players[0]
	player.gold = _config.tower_cost
	var water_data: TowerData = _tower(&"water").data
	var spark: TowerData = _tower(&"spark").data
	var brain: BotBrain = BotBrain.new(0)
	assert_false(brain._wants_tower(player, water_data))
	player.field.add_tower(spark, Vector2i(2, 4), 0)
	player.field.add_tower(spark, Vector2i(3, 4), 0)
	player.shop.offers.fill(null)
	player.shop.rite_offers.fill(null)
	player.shop.offers[0] = water_data
	brain._buy_towers(sim, player)
	var found: TowerState = null
	for tower: TowerState in player.field.towers:
		if tower.data == water_data:
			found = tower
	assert_not_null(found)
	assert_true(brain._wants_tower(player, water_data), "копия нужна для слияния")
	if found != null:
		found.level = 2
	assert_false(brain._wants_tower(player, water_data), "одной воды хватает двум Искровикам")


func test_ghost_keeps_remaining_shot_cooldown() -> void:
	var tower: TowerState = _tower(&"spark")
	tower.cooldown_left = 7
	var ghost: FieldState = FieldState.new(_config, 3)
	ghost.copy_towers_from(_field)
	assert_eq(ghost.towers[0].cooldown_left, 7,
			"копия не должна получать бесплатный выстрел в начале боя")

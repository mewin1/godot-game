extends GutTest
## Нетопырь и Колобок включены в армию активного конфига; лёт обходит наземный осадный станок.

var _config: GameConfig


func before_each() -> void:
	_config = (load("res://data/game_config.tres") as GameConfig).duplicate() as GameConfig


func _upgrade_index(id_value: StringName) -> int:
	for i: int in _config.army_upgrades.size():
		if _config.army_upgrades[i].id == id_value:
			return i
	return -1


func _tower(id_value: StringName) -> TowerData:
	for data: TowerData in _config.towers:
		if data.id == id_value:
			return data
	return null


func _spawn(field: FieldState, data: MobData) -> MobState:
	var mob: MobState = MobState.create(data)
	field.schedule_spawn(mob, 0)
	field.start_wave()
	return mob


func _tick(field: FieldState, ticks: int) -> void:
	for i: int in ticks:
		field.tick()


func test_army_upgrades_are_only_concrete_units() -> void:
	assert_eq(_config.army_upgrades.size(), 9)
	assert_true(_upgrade_index(&"army_bat") >= 0, "нетопырь есть в лавке армии")
	assert_true(_upgrade_index(&"army_kolobok") >= 0, "колобок есть в лавке армии")
	assert_true(_upgrade_index(&"army_spirit") >= 0, "дух есть в лавке армии")
	assert_eq(_upgrade_index(&"army_hp"), -1, "стат-баф HP убран из лавки армии")
	assert_eq(_upgrade_index(&"army_speed"), -1, "стат-баф скорости убран")
	assert_eq(_upgrade_index(&"army_units"), -1, "стат-баф юнитов убран")


func test_army_casino_offers_subset_of_unlocked_units() -> void:
	var army: ArmyState = ArmyState.new(_config)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	army.roll_offers(2, rng)
	assert_eq(army.offers.size(), _config.army_offer_count, "показывается ровно army_offer_count юнитов")
	for index: int in army.offers:
		assert_eq(army.check_upgrade_available(index, 2), "", "предложен только открытый юнит")
	var again: ArmyState = ArmyState.new(_config)
	var rng2: RandomNumberGenerator = RandomNumberGenerator.new()
	rng2.seed = 7
	again.roll_offers(2, rng2)
	assert_eq(army.offers, again.offers, "одинаковый сид даёт ту же витрину армии")


func test_build_pack_includes_flying_bat_and_splitting_kolobok() -> void:
	var army: ArmyState = ArmyState.new(_config)
	army.apply_upgrade(_upgrade_index(&"army_bat"))
	army.apply_upgrade(_upgrade_index(&"army_kolobok"))
	var pack: Array[MobState] = army.build_pack(0, 2)
	var has_bat: bool = false
	var has_kolobok: bool = false
	for mob: MobState in pack:
		if mob.data.id == &"bat":
			has_bat = true
			assert_true(mob.data.is_flying, "нетопырь летает")
		if mob.data.id == &"kolobok":
			has_kolobok = true
			assert_true(mob.data.split_into != null, "колобок делится")
	assert_true(has_bat)
	assert_true(has_kolobok)


func test_spirit_gets_resist_to_chosen_element() -> void:
	var army: ArmyState = ArmyState.new(_config)
	army.apply_upgrade(_upgrade_index(&"army_spirit"), &"svarog")
	var pack: Array[MobState] = army.build_pack(0, 2)
	var has_spirit: bool = false
	for mob: MobState in pack:
		if mob.data.id == &"spirit":
			has_spirit = true
			assert_eq(mob.resist, &"svarog", "дух резистит выбранную стихию")
	assert_true(has_spirit)


func test_resist_reduces_damage_from_matching_god() -> void:
	var field: FieldState = FieldState.new(_config)
	var tower: TowerState = field.add_tower(_tower(&"brazier"), Vector2i(2, 8), 0)
	var resistant: MobState = MobState.create(SimFixtures.find_mob(&"spirit"))
	resistant.hp = 1000
	resistant.max_hp = 1000
	resistant.resist = &"svarog"
	field.mobs.append(resistant)
	DivineCombat.hit(field, tower, resistant, 100)
	var reduced: int = 1000 - resistant.hp
	var normal: MobState = MobState.create(SimFixtures.find_mob(&"spirit"))
	normal.hp = 1000
	normal.max_hp = 1000
	field.mobs.append(normal)
	DivineCombat.hit(field, tower, normal, 100)
	var full: int = 1000 - normal.hp
	assert_lt(reduced, full, "резист снижает урон от своей стихии")
	assert_eq(reduced, 70, "урон снижается на resist_percent")


func test_spirit_rejects_inactive_element_without_spending() -> void:
	var player: PlayerState = PlayerState.new(_config, 0, 123)
	player.shop.level = 2
	player.shop.active_gods.assign([&"svarog", &"perun"])
	player.army.offers.assign([_upgrade_index(&"army_spirit")])
	player.gold = 100
	var income: int = player.income
	assert_ne(player.buy_army_upgrade(_upgrade_index(&"army_spirit"), &"ice"), "")
	assert_eq(player.gold, 100)
	assert_eq(player.income, income)
	assert_eq(player.army.get_total_upgrades(), 0)


func test_pending_spirit_element_changes_field_hash() -> void:
	var fire: FieldState = FieldState.new(_config)
	var ice: FieldState = FieldState.new(_config)
	var fire_spirit: MobState = MobState.create(SimFixtures.find_mob(&"spirit"))
	var ice_spirit: MobState = MobState.create(SimFixtures.find_mob(&"spirit"))
	fire_spirit.resist = &"svarog"
	ice_spirit.resist = &"ice"
	fire.schedule_spawn(fire_spirit, 10)
	ice.schedule_spawn(ice_spirit, 10)
	var fire_hash: StateHasher = StateHasher.new()
	var ice_hash: StateHasher = StateHasher.new()
	fire.add_to_hash(fire_hash)
	ice.add_to_hash(ice_hash)
	assert_ne(fire_hash.value, ice_hash.value, "выбор стихии влияет ещё до выхода духа")


func test_spirit_command_log_contains_selected_element() -> void:
	var sim: MatchSim = MatchSim.new(_config, 123, 2, 2)
	var command: BuyArmyUpgradeCommand = BuyArmyUpgradeCommand.new(
			_upgrade_index(&"army_spirit"), sim.active_gods[1])
	var element: String = command.to_log(sim, sim.players[0]).get("element", "")
	assert_eq(element, String(sim.active_gods[1]))


func test_command_rejects_army_upgrade_outside_offers_without_mutation() -> void:
	var sim: MatchSim = MatchSim.new(_config, 123, 2, 2)
	sim.start()
	var player: PlayerState = sim.players[0]
	player.shop.level = 2
	player.gold = 100
	player.army.offers.assign([0])
	var before: int = sim.state_hash()
	var rng_before: int = player.rng.state
	var error: String = sim.execute_command(0, BuyArmyUpgradeCommand.new(
			_upgrade_index(&"army_spirit"), sim.active_gods[0]))
	assert_ne(error, "", "скрытого юнита купить нельзя")
	assert_eq(sim.state_hash(), before, "отказ не меняет состояние или золото")
	assert_eq(player.rng.state, rng_before, "отказ не расходует RNG")


func test_legacy_all_open_army_does_not_require_offers() -> void:
	_config.army_offer_count = 0
	var player: PlayerState = PlayerState.new(_config, 0, 123)
	player.shop.level = 2
	player.gold = 100
	player.shop.active_gods.assign([&"svarog"])
	assert_true(player.army.offers.is_empty())
	assert_eq(player.buy_army_upgrade(_upgrade_index(&"army_spirit"), &"svarog"), "")


func test_bot_purchases_spirit_with_active_element_deterministically() -> void:
	for seed_value: int in 8:
		var first: MatchSim = _bot_spirit_purchase(seed_value)
		var second: MatchSim = _bot_spirit_purchase(seed_value)
		assert_eq(first.players[0].army.added_mobs.size(), 1)
		assert_true(first.active_gods.has(first.players[0].army.added_mobs[0].resist))
		assert_eq(first.state_hash(), second.state_hash(), "тот же сид и действия дают тот же хэш")


func test_spirit_purchases_keep_independent_elements_and_original_resource() -> void:
	var army: ArmyState = ArmyState.new(_config)
	var index: int = _upgrade_index(&"army_spirit")
	army.apply_upgrade(index, &"svarog")
	army.apply_upgrade(index, &"ice")
	assert_eq(army.get_upgrade(index).mob.resist, &"", "общий ресурс не меняется")
	var pack: Array[MobState] = army.build_pack(1, 5)
	assert_eq(pack[pack.size() - 2].resist, &"svarog")
	assert_eq(pack[pack.size() - 1].resist, &"ice")
	assert_eq(pack[pack.size() - 1].sender_index, 1)
	var first_hash: StateHasher = StateHasher.new()
	army.add_to_hash(first_hash)
	army.added_mobs[1].resist = &"perun"
	var second_hash: StateHasher = StateHasher.new()
	army.add_to_hash(second_hash)
	assert_ne(first_hash.value, second_hash.value, "стихия учитывается в хэше армии")


func test_resist_keeps_reactions_and_statuses_and_other_elements_full_damage() -> void:
	var field: FieldState = FieldState.new(_config)
	var tower: TowerState = field.add_tower(_tower(&"brazier"), Vector2i(2, 8), 0)
	var resistant: MobState = MobState.create(SimFixtures.find_mob(&"spirit"))
	resistant.hp = 1000
	resistant.max_hp = 1000
	resistant.resist = &"ice"
	DivineCombat.hit(field, tower, resistant, 100)
	assert_eq(resistant.hp, 900, "другая стихия не снижает урон")
	assert_gt(resistant.burn_ticks_left, 0, "резист не блокирует метки")
	resistant.resist = &"svarog"
	resistant.burn_ticks_left = 0
	resistant.wet_ticks_left = 30
	DivineCombat.hit(field, tower, resistant, 100)
	assert_gt(field.reaction_counts.size(), 0, "резист не блокирует реакцию")
	assert_eq(resistant.wet_ticks_left, 0, "реакция расходует метку как обычно")


func _bot_spirit_purchase(seed_value: int) -> MatchSim:
	var sim: MatchSim = MatchSim.new(_config, seed_value, 2, 2)
	sim.start()
	var player: PlayerState = sim.players[0]
	player.shop.level = 2
	player.army.offers.assign([_upgrade_index(&"army_spirit")])
	player.gold = player.army.get_upgrade_cost(_upgrade_index(&"army_spirit"))
	var bot: BotBrain = BotBrain.new(100)
	bot._buy_army_with_budget(sim, player, player.gold)
	return sim


func test_war_engine_does_not_hit_flying() -> void:
	assert_false(_tower(&"war_engine").can_hit_flying, "осадный станок наземный")
	var field: FieldState = FieldState.new(_config)
	field.add_tower(_tower(&"war_engine"), Vector2i(2, 8), 0)
	var bat: MobState = _spawn(field, SimFixtures.find_mob(&"bat"))
	_tick(field, 60)
	assert_eq(bat.hp, bat.max_hp, "осадный станок не бьёт летающих")


func test_war_engine_hits_ground_and_bolt_hits_flying() -> void:
	var field: FieldState = FieldState.new(_config)
	field.add_tower(_tower(&"war_engine"), Vector2i(2, 8), 0)
	var ground: MobState = _spawn(field, _config.army_mob)
	_tick(field, 60)
	assert_true(ground.hp < ground.max_hp, "осадный станок бьёт наземных")

	var bolt_field: FieldState = FieldState.new(_config)
	bolt_field.add_tower(_tower(&"bolt"), Vector2i(2, 8), 0)
	var bat: MobState = _spawn(bolt_field, SimFixtures.find_mob(&"bat"))
	_tick(bolt_field, 60)
	assert_true(bat.hp < bat.max_hp, "самострел бьёт летающих")


func test_threat_preview_separates_spirits_with_different_defenses() -> void:
	var sim: MatchSim = MatchSim.new(_config, 77, 2, 2)
	sim.start()
	sim.round_number = 2
	var index: int = _upgrade_index(&"army_spirit")
	var sender: PlayerState = sim.players[sim.opponent_of[0]]
	sender.army.apply_upgrade(index, &"svarog")
	sender.army.apply_upgrade(index, &"water")
	var details: String = ArmyPreview.describe(sim, 0)[1]
	assert_true(details.contains("Дух (Огонь · Сварог) ×1"))
	assert_true(details.contains("Дух (Вода) ×1"))

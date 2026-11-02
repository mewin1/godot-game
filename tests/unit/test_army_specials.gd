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

extends GutTest
## Новые идолы остаются тремя основами; эффекты получают только башни своего бога.

var _config: GameConfig
var _field: FieldState


func before_each() -> void:
	_config = load("res://data/game_config.tres") as GameConfig
	_field = FieldState.new(_config, 3, 311)


func _tower(id_value: String) -> TowerState:
	return _field.add_tower(load("res://data/towers/%s.tres" % id_value) as TowerData,
			Vector2i(2, 4), 0)


func _rite(id_value: String) -> RiteData:
	return load("res://data/rites/%s.tres" % id_value) as RiteData


func test_new_gods_damage_and_extra_targets_are_scoped_to_god() -> void:
	var ids: Array[String] = ["ice", "curse", "war"]
	var towers: Array[TowerState] = [_tower("rime"), _tower("hex"), _tower("bolt")]
	for i: int in 3:
		var base_damage: int = _field.get_tower_damage(towers[i])
		_field.idols[i].apply_rite(_rite(ids[i] + "_power"))
		_field.idols[i].apply_rite(_rite(ids[i] + "_targets"))
		assert_eq(_field.get_tower_damage(towers[i]), base_damage * 110 / 100)
		assert_eq(_field.get_tower_targets(towers[i]), 2)
	assert_eq(_field.get_tower_targets(_tower("spark")), 1)
	assert_eq(_field.idols.size(), 3)


func test_duration_and_targets_survive_independent_ghost_snapshot() -> void:
	_field.idols[0].apply_rite(_rite("ice_duration"))
	_field.idols[0].apply_rite(_rite("ice_targets"))
	var ghost: FieldState = FieldState.new(_config, 3)
	ghost.copy_towers_from(_field)
	assert_eq(ghost.idols[0].status_ticks, 20)
	assert_eq(ghost.idols[0].extra_targets, 1)
	_field.idols[0].apply_rite(_rite("ice_duration"))
	assert_eq(ghost.idols[0].status_ticks, 20)
	var mob: MobState = MobState.create(_config.army_mob)
	mob.hp = 1000
	DivineCombat.hit(_field, _tower("rime"), mob, 8)
	assert_eq(mob.cold_ticks_left, 100)


func test_new_rite_limits_and_hash_include_effects() -> void:
	var idol: IdolState = _field.idols[0]
	var before: StateHasher = StateHasher.new()
	idol.add_to_hash(before)
	idol.apply_rite(_rite("war_targets"))
	assert_ne(idol.check_rite(_rite("war_targets")), "")
	assert_ne(idol.check_rite(_rite("ice_power")), "")
	var after: StateHasher = StateHasher.new()
	idol.add_to_hash(after)
	assert_ne(before.value, after.value)
	assert_eq(idol.duplicate_state().extra_targets, 1)


func test_physical_finisher_consumes_both_marks() -> void:
	var mob: MobState = MobState.create(_config.army_mob)
	mob.hp = 1000
	mob.charge_ticks_left = 60
	mob.curse_ticks_left = 60
	mob.curse_damage = 20
	DivineCombat.hit(_field, _tower("bolt"), mob, 100)
	assert_eq(mob.hp, 860)
	assert_eq(mob.status_tags().size(), 0)
	assert_eq(mob.curse_damage, 0)


func test_wet_lightning_increases_damage_before_chain_armor() -> void:
	var mob: MobState = MobState.create(_config.army_mob)
	mob.hp = 1000
	mob.wet_ticks_left = 60
	DivineCombat.hit(_field, _tower("spark"), mob, 100)
	assert_eq(mob.hp, 890)

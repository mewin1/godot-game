extends GutTest
## Личный резист Духа: поддержка стихий и независимый урон переходов Цепи.

var _config: GameConfig
var _field: FieldState


func before_each() -> void:
	_config = (load("res://data/game_config.tres") as GameConfig).duplicate() as GameConfig
	_field = FieldState.new(_config)


func _tower(id_value: StringName) -> TowerState:
	for data: TowerData in _config.towers:
		if data.id == id_value:
			return _field.add_tower(data, Vector2i(2, 4), 0)
	return null


func _mob(progress: int, element: StringName = &"") -> MobState:
	var mob: MobState = MobState.create(SimFixtures.find_mob(&"spirit"))
	mob.hp = 10000
	mob.max_hp = 10000
	mob.progress = progress
	mob.resist = element
	_field.mobs.append(mob)
	return mob


func test_water_resist_shortens_wetness_with_idol_and_level_bonuses() -> void:
	var water: TowerState = _tower(&"water")
	water.level = 2
	_field.idols[0].apply_rite(load("res://data/rites/water_duration.tres") as RiteData)
	var normal: MobState = _mob(3000)
	var spirit: MobState = _mob(3500, &"water")
	DivineCombat.hit(_field, water, normal, 0)
	DivineCombat.hit(_field, water, spirit, 0)
	assert_eq(spirit.wet_ticks_left,
			normal.wet_ticks_left * (100 - _config.resist_percent) / 100)
	assert_gt(spirit.wet_ticks_left, 0, "мокрота остаётся для реакций")


func test_wind_spread_uses_recipient_water_resist_and_keeps_reaction() -> void:
	var source: MobState = _mob(3000)
	source.wet_ticks_left = 60
	source.is_in_wind = true
	var spirit: MobState = _mob(4000, &"water")
	WindReactions.apply(_field, source)
	assert_eq(spirit.wet_ticks_left, 30 * (100 - _config.resist_percent) / 100)
	assert_eq(source.progress, 2600, "откат продолжает срабатывать")
	var reactions: int = _field.reaction_counts.get(&"surge", 0)
	assert_eq(reactions, 1)


func test_wind_resist_reduces_counterflow_and_tailwind_without_losing_geometry() -> void:
	var wind: TowerState = _tower(&"wind")
	wind.rotation = 2
	var normal: MobState = _mob(2000)
	var spirit: MobState = _mob(2000, &"stribog")
	DivineCombat.apply_wind(_field, normal)
	DivineCombat.apply_wind(_field, spirit)
	assert_eq(spirit.wind_slow_percent,
			normal.wind_slow_percent * (100 - _config.resist_percent) / 100)
	assert_true(spirit.is_in_wind, "геометрия потока сохранена")
	wind.anchor = Vector2i(2, 8)
	wind.rotation = 0
	DivineCombat.apply_wind(_field, normal)
	DivineCombat.apply_wind(_field, spirit)
	assert_eq(spirit.wind_boost_percent,
			normal.wind_boost_percent * (100 - _config.resist_percent) / 100)
	assert_gt(spirit.wind_boost_percent, 0, "попутный поток по-прежнему ускоряет")


func test_primary_resist_does_not_reduce_chain_damage_to_another_mob() -> void:
	_config.chain_chance_percent = 100
	var spark: TowerState = _tower(&"spark")
	var primary: MobState = _mob(3000, &"perun")
	var secondary: MobState = _mob(3500)
	DivineCombat.hit(_field, spark, primary, 100)
	assert_eq(10000 - primary.hp, 100 - _config.resist_percent)
	assert_eq(10000 - secondary.hp, _config.chain_percent,
			"цепь рассчитывается до личного резиста основной цели")


func test_secondary_resist_reduces_only_its_own_chain_damage() -> void:
	_config.chain_chance_percent = 100
	var spark: TowerState = _tower(&"spark")
	var primary: MobState = _mob(3000)
	var secondary: MobState = _mob(3500, &"perun")
	DivineCombat.hit(_field, spark, primary, 100)
	assert_eq(10000 - primary.hp, 100)
	assert_eq(10000 - secondary.hp,
			_config.chain_percent * (100 - _config.resist_percent) / 100)

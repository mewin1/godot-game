extends GutTest
## Контроль на неподвижной цели: реакция не должна уничтожать вложенный урон проклятия.


func test_execution_does_not_reduce_total_damage_of_strong_curse_build() -> void:
	var normal: int = _damage_over_fixed_window(false)
	var reactive: int = _damage_over_fixed_window(true)
	assert_gte(reactive, normal,
			"Добивание должно усиливать билд, а не терять накопленный взрыв")


func _damage_over_fixed_window(with_execution: bool) -> int:
	var config: GameConfig = (load("res://data/game_config.tres") as GameConfig).duplicate() as GameConfig
	if not with_execution:
		var rules: Array[ReactionData] = []
		for rule: ReactionData in config.reactions:
			if rule.id != &"execute":
				rules.append(rule)
		config.reactions = rules
	var field: FieldState = FieldState.new(config, 3, 611)
	for id_value: String in ["doom", "spark", "bolt"]:
		var tower: TowerState = field.add_tower(
				load("res://data/towers/%s.tres" % id_value) as TowerData, Vector2i(2, 4), 0)
		tower.level = 3 if id_value == "doom" else 1
	var mob: MobState = MobState.create(config.wave_mob)
	mob.hp = 100000
	mob.max_hp = 100000
	field.mobs.append(mob)
	for tick_index: int in 240:
		DivineCombat.tick_effects(field, mob)
		for tower: TowerState in field.towers:
			if tick_index % tower.data.cooldown_ticks == 0:
				DivineCombat.hit(field, tower, mob, field.get_tower_damage(tower))
	return mob.max_hp - mob.hp



func test_execution_converts_pending_burn_ticks_and_curse_without_double_explosion() -> void:
	var config: GameConfig = load("res://data/game_config.tres") as GameConfig
	var field: FieldState = FieldState.new(config, 3, 611)
	var tower: TowerState = field.add_tower(
			load("res://data/towers/bolt.tres") as TowerData, Vector2i(2, 4), 0)
	var mob: MobState = MobState.create(config.wave_mob)
	mob.hp = 1000
	mob.burn_ticks_left = 41
	mob.burn_cooldown = 1
	mob.burn_damage = 10
	mob.curse_ticks_left = 60
	mob.curse_damage = 80
	assert_eq(mob.get_stored_damage(20), 110)
	DivineCombat.hit(field, tower, mob, 100)
	assert_eq(mob.hp, 750)
	assert_eq(mob.status_tags().size(), 0)
	for i: int in 100:
		DivineCombat.tick_effects(field, mob)
	assert_eq(mob.hp, 750)


func test_shield_preserves_payload_and_unreached_burn_tick_is_not_stored() -> void:
	var config: GameConfig = load("res://data/game_config.tres") as GameConfig
	var field: FieldState = FieldState.new(config, 3, 611)
	var tower: TowerState = field.add_tower(
			load("res://data/towers/bolt.tres") as TowerData, Vector2i(2, 4), 0)
	var mob: MobState = MobState.create(config.wave_mob)
	mob.hp = 1000
	mob.charge_ticks_left = 60
	mob.curse_ticks_left = 60
	mob.curse_damage = 80
	mob.shield_left = 1
	DivineCombat.hit(field, tower, mob, 100)
	assert_eq(mob.hp, 1000)
	assert_eq(mob.curse_damage, 80)
	assert_eq(mob.status_tags().size(), 2)
	mob.remove_status(&"curse")
	mob.burn_ticks_left = 5
	mob.burn_cooldown = 20
	mob.burn_damage = 100
	assert_eq(mob.get_stored_damage(20), 0)

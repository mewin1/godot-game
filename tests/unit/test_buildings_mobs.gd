extends GutTest
## Новые постройки (соседство, ловушка, пульс, много целей, лавка) и мобы
## (летает, лечит, делится, щит, невидимка, рывок, особые в волне).

var _config: GameConfig


func before_each() -> void:
	_config = SimFixtures.make_config()


func test_forge_boosts_only_edge_neighbors() -> void:
	var field: FieldState = FieldState.new(_config)
	var forge: TowerState = field.add_tower(_tower(&"forge"), Vector2i(2, 5), 0)
	var near: TowerState = field.add_tower(_tower(&"ice_1"), Vector2i(4, 5), 0)
	var diagonal: TowerState = field.add_tower(_tower(&"ice_1"), Vector2i(4, 6), 0)
	field.refresh_bonuses()
	assert_eq(near.bonus_damage_percent, 30)
	assert_eq(diagonal.bonus_damage_percent, 0, "по диагонали — не сосед")
	assert_eq(field.get_tower_damage(near), _tower(&"ice_1").damage * 130 / 100)
	assert_eq(forge.bonus_damage_percent, 0)


func test_support_bonus_grows_with_level() -> void:
	var field: FieldState = FieldState.new(_config)
	var samovar: TowerState = field.add_tower(_tower(&"samovar"), Vector2i(2, 5), 0)
	var shooter: TowerState = field.add_tower(_tower(&"mech_1"), Vector2i(2, 6), 0)
	samovar.level = 2
	field.mark_towers_changed()
	field.refresh_bonuses()
	assert_eq(shooter.bonus_fire_rate_percent, 50)
	assert_true(field.get_tower_cooldown(shooter) < _tower(&"mech_1").cooldown_ticks)


func test_watchtower_adds_range_and_moving_away_removes_it() -> void:
	var field: FieldState = FieldState.new(_config)
	field.add_tower(_tower(&"watchtower"), Vector2i(2, 5), 0)
	var shooter: TowerState = field.add_tower(_tower(&"ice_1"), Vector2i(2, 6), 0)
	field.refresh_bonuses()
	assert_eq(field.get_tower_range(shooter), _tower(&"ice_1").range_milli + 1000)
	field.move_tower(shooter, Vector2i(3, 8), 0)
	field.refresh_bonuses()
	assert_eq(shooter.bonus_range_milli, 0)


func test_supports_do_not_shoot() -> void:
	var field: FieldState = FieldState.new(_config)
	field.add_tower(_tower(&"forge"), Vector2i(2, 5), 0)
	var mob: MobState = _spawn(field, _config.wave_mob)
	_tick(field, 100)
	assert_eq(mob.hp, mob.max_hp)


func test_stall_gives_income_scaled_by_level() -> void:
	var field: FieldState = FieldState.new(_config)
	var stall: TowerState = field.add_tower(_tower(&"stall"), Vector2i(2, 5), 0)
	assert_eq(field.get_round_income(), 2)
	stall.level = 2
	assert_eq(field.get_round_income(), 4)


func test_trap_does_not_catch_flying() -> void:
	var field: FieldState = FieldState.new(_config)
	field.add_tower(_tower(&"trap"), Vector2i(2, 8), 0)
	var bat: MobState = _spawn(field, SimFixtures.find_mob(&"bat"))
	_tick(field, 60)
	assert_eq(bat.hp, bat.max_hp)


func test_trap_holds_ground_mob() -> void:
	var field: FieldState = FieldState.new(_config)
	field.add_tower(_tower(&"trap"), Vector2i(2, 8), 0)
	var mob: MobState = _spawn(field, _config.army_mob)
	var guard: int = 0
	while mob.hp == mob.max_hp and guard < 100:
		field.tick()
		guard += 1
	assert_true(mob.hp < mob.max_hp)
	assert_eq(mob.slow_percent, 100)


func test_banya_hits_all_mobs_in_range() -> void:
	var field: FieldState = FieldState.new(_config)
	field.add_tower(_tower(&"banya"), Vector2i(2, 7), 0)
	var first: MobState = _spawn(field, _config.army_mob)
	var second: MobState = _spawn(field, _config.army_mob)
	watch_signals(field)
	_tick(field, 50)
	assert_true(first.hp < first.max_hp and second.hp < second.max_hp)
	assert_signal_emitted(field, "tower_pulsed")


func test_panelka_shoots_three_targets() -> void:
	var field: FieldState = FieldState.new(_config)
	field.add_tower(_tower(&"panelka"), Vector2i(2, 7), 0)
	var mobs: Array[MobState] = []
	for i: int in 4:
		mobs.append(_spawn(field, _config.army_mob))
	_tick(field, 3)
	var hit: int = 0
	for mob: MobState in mobs:
		if mob.hp < mob.max_hp:
			hit += 1
	assert_eq(hit, 3)


func test_knight_shield_blocks_first_hit() -> void:
	var knight: MobState = MobState.create(SimFixtures.find_mob(&"knight"))
	assert_false(knight.take_damage(1000))
	assert_eq(knight.hp, knight.max_hp)
	assert_true(knight.take_damage(1000))


func test_stealth_seen_only_close() -> void:
	var field: FieldState = FieldState.new(_config)
	var tower: TowerState = field.add_tower(_tower(&"mech_2"), Vector2i(4, 2), 0)
	var ghost: MobState = _spawn(field, SimFixtures.find_mob(&"stealth"))
	field.tick()
	assert_eq(ghost.hp, ghost.max_hp, "у входа далеко — невидим")
	assert_true(field.get_tower_range(tower) > ghost.data.reveal_radius_milli)


func test_kolobok_splits_into_two_on_death() -> void:
	var field: FieldState = FieldState.new(_config)
	var kolobok: MobState = _spawn(field, SimFixtures.find_mob(&"kolobok"))
	field.tick()
	field.damage_all_by_percent(0)
	kolobok.hp = 1
	field.add_tower(_tower(&"mech_1"), Vector2i(2, 8), 0)
	_tick(field, 2)
	var small: int = 0
	for mob: MobState in field.mobs:
		if mob.data.id == &"kolobok_small":
			small += 1
			assert_eq(mob.max_hp, kolobok.max_hp * 35 / 100)
	assert_eq(small, 2)


func test_healer_heals_neighbors() -> void:
	var field: FieldState = FieldState.new(_config)
	var healer: MobState = _spawn(field, SimFixtures.find_mob(&"healer"))
	var hurt: MobState = _spawn(field, _config.army_mob)
	field.tick()
	hurt.hp = 10
	_tick(field, 21)
	assert_true(hurt.hp > 10)
	assert_true(healer.is_alive())


func test_courier_sprints_at_end_of_path() -> void:
	var courier: MobState = MobState.create(SimFixtures.find_mob(&"courier"))
	var field: FieldState = FieldState.new(_config)
	field.schedule_spawn(courier, 0)
	field.start_wave()
	field.tick()
	var early_step: int = courier.progress
	courier.progress = field.get_path_end_progress() * 80 / 100
	var before: int = courier.progress
	field.tick()
	assert_eq(courier.progress - before, early_step * 2)


func test_base_wave_adds_specials_from_their_round() -> void:
	var early: Array[MobState] = WaveBuilder.build_base_wave(_config, 2)
	var later: Array[MobState] = WaveBuilder.build_base_wave(_config, 10)
	assert_false(_has_mob(early, &"kolobok"))
	assert_true(_has_mob(later, &"kolobok"))
	assert_true(_has_mob(later, &"courier"))


func test_army_can_buy_specific_mob() -> void:
	var army: ArmyState = ArmyState.new(_config)
	var index: int = -1
	for i: int in _config.army_upgrades.size():
		if _config.army_upgrades[i].id == &"army_kolobok":
			index = i
	assert_true(index >= 0)
	army.apply_upgrade(index)
	assert_true(_has_mob(army.build_pack(0, 1), &"kolobok"))


func _tower(tower_id: StringName) -> TowerData:
	return SimFixtures.find_tower(_config, tower_id)


func _spawn(field: FieldState, data: MobData) -> MobState:
	var mob: MobState = MobState.create(data)
	field.schedule_spawn(mob, 0)
	field.start_wave()
	return mob


func _tick(field: FieldState, ticks: int) -> void:
	for i: int in ticks:
		field.tick()


func _has_mob(mobs: Array[MobState], mob_id: StringName) -> bool:
	for mob: MobState in mobs:
		if mob.data.id == mob_id:
			return true
	return false

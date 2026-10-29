extends GutTest
## Поле: путь по уровням магазина, сетка, установка башен, движение мобов, стрельба, прорыв.

var _config: GameConfig


func before_each() -> void:
	_config = SimFixtures.make_config()


func test_config_loads_with_content() -> void:
	assert_not_null(_config.board, "площадка")
	assert_eq(_config.towers.size(), 6, "башен-заглушек")
	assert_not_null(_config.wave_mob, "моб волны")
	assert_true(_config.send_buffs.size() >= 6, "бафы отправки")


func test_path_level_one_is_straight_line() -> void:
	var field: FieldState = FieldState.new(_config, 1)
	var path: Array[Vector2i] = field.get_active_path()
	assert_eq(path.size(), 10)
	for cell: Vector2i in path:
		assert_eq(cell.x, path[0].x, "все клетки в одном столбце")


func test_path_is_continuous_for_all_levels() -> void:
	var cells: Array[Vector2i] = _config.board.path_cells
	for i: int in range(1, cells.size()):
		var step: Vector2i = cells[i] - cells[i - 1]
		assert_eq(absi(step.x) + absi(step.y), 1, "клетки %d и %d соседние" % [i - 1, i])


func test_path_grows_with_shop_level_and_keeps_old_start() -> void:
	var previous: Array[Vector2i] = []
	for level: int in range(1, 5):
		var field: FieldState = FieldState.new(_config, level)
		var path: Array[Vector2i] = field.get_active_path()
		assert_gt(path.size(), previous.size(), "уровень %d длиннее" % level)
		assert_eq(path.slice(0, previous.size()), previous, "новый путь продолжает старый")
		previous = path


func test_buildable_cells_never_on_any_path_cell() -> void:
	var field: FieldState = FieldState.new(_config, 1)
	for cell: Vector2i in _config.board.path_cells:
		assert_false(field.is_buildable(cell), "клетка пути %s" % cell)


func test_buildable_cells_grow_with_shop_level() -> void:
	var small: int = FieldState.new(_config, 1).get_buildable_cells().size()
	var big: int = FieldState.new(_config, 3).get_buildable_cells().size()
	assert_gt(small, 0)
	assert_gt(big, small)


func test_rotated_shape_four_turns_returns_same() -> void:
	var shape: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]
	assert_eq(TowerState.rotated_shape(shape, 4), shape)


func test_rotated_domino_one_turn_is_vertical() -> void:
	var shape: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	var rotated: Array[Vector2i] = TowerState.rotated_shape(shape, 1)
	assert_eq(rotated, [Vector2i(0, 0), Vector2i(0, 1)] as Array[Vector2i])


func test_can_place_on_occupied_cell_returns_false() -> void:
	var field: FieldState = FieldState.new(_config, 1)
	var data: TowerData = SimFixtures.find_tower(_config, &"ice_1")
	var cell: Vector2i = Vector2i(0, 5)
	assert_true(field.can_place_tower_data(data, cell, 0))
	field.add_tower(data, cell, 0)
	assert_false(field.can_place_tower_data(data, cell, 0))


func test_can_place_on_path_returns_false() -> void:
	var field: FieldState = FieldState.new(_config, 1)
	var data: TowerData = SimFixtures.find_tower(_config, &"ice_1")
	assert_false(field.can_place_tower_data(data, Vector2i(1, 5), 0))


func test_move_tower_frees_old_cells() -> void:
	var field: FieldState = FieldState.new(_config, 1)
	var data: TowerData = SimFixtures.find_tower(_config, &"ice_1")
	var tower: TowerState = field.add_tower(data, Vector2i(0, 5), 0)
	assert_true(field.move_tower(tower, Vector2i(2, 5), 0))
	assert_null(field.get_tower_at(Vector2i(0, 5)))
	assert_eq(field.get_tower_at(Vector2i(2, 5)), tower)


func test_mob_moves_by_speed_each_tick() -> void:
	var field: FieldState = FieldState.new(_config, 1)
	var mob: MobState = MobState.create(_config.wave_mob)
	field.schedule_spawn(mob, 0)
	field.tick()
	field.tick()
	assert_eq(mob.progress, _config.wave_mob.speed_milli_per_tick * 2)


func test_mob_reaching_end_breaches_and_is_removed() -> void:
	var field: FieldState = FieldState.new(_config, 1)
	field.schedule_spawn(MobState.create(_config.wave_mob), 0)
	_run_until_done(field)
	assert_eq(field.pending_breaches.size(), 1)
	assert_true(field.mobs.is_empty())


func test_tower_in_range_kills_mob_and_gives_gold() -> void:
	var field: FieldState = FieldState.new(_config, 1)
	field.add_tower(SimFixtures.find_tower(_config, &"mech_1"), Vector2i(2, 4), 0)
	field.schedule_spawn(MobState.create(_config.wave_mob), 0)
	_run_until_done(field)
	assert_eq(field.pending_breaches.size(), 0, "моб не прорвался")
	assert_eq(field.pending_kill_gold, _config.wave_mob.kill_reward)


func test_tower_out_of_range_does_not_fire() -> void:
	var config: GameConfig = SimFixtures.make_config()
	config.build_radius = 9
	var field: FieldState = FieldState.new(config, 1)
	var data: TowerData = SimFixtures.find_tower(config, &"ice_1")
	var tower: TowerState = field.add_tower(data, Vector2i(8, 9), 0)
	watch_signals(field)
	field.schedule_spawn(MobState.create(config.wave_mob), 0)
	for i: int in 20:
		field.tick()
	assert_signal_not_emitted(field, "tower_fired")
	assert_eq(tower.cooldown_left, 0)


func test_slow_reduces_mob_speed() -> void:
	var mob: MobState = MobState.create(_config.wave_mob)
	mob.apply_slow(50, 10)
	assert_eq(mob.current_speed(), _config.wave_mob.speed_milli_per_tick / 2)


func test_slow_ends_after_its_ticks() -> void:
	var mob: MobState = MobState.create(_config.wave_mob)
	mob.apply_slow(50, 2)
	mob.advance()
	mob.advance()
	assert_eq(mob.slow_percent, 0)


func test_armor_reduces_damage_but_not_below_one() -> void:
	var mob: MobState = MobState.create(_config.wave_mob)
	mob.armor = 10
	var hp_before: int = mob.hp
	mob.take_damage(3)
	assert_eq(mob.hp, hp_before - 1)


func test_tower_fires_once_per_cooldown() -> void:
	var field: FieldState = FieldState.new(_config, 1)
	var data: TowerData = SimFixtures.find_tower(_config, &"ice_1")
	field.add_tower(data, Vector2i(0, 8), 0)
	var tough: MobState = MobState.create(_config.wave_mob, 10000)
	tough.speed = 0
	field.schedule_spawn(tough, 0)
	watch_signals(field)
	for i: int in data.cooldown_ticks * 3:
		field.tick()
	assert_signal_emit_count(field, "tower_fired", 3)


func test_same_setup_gives_same_hash() -> void:
	assert_eq(_simulate_field_hash(), _simulate_field_hash())


func _simulate_field_hash() -> int:
	var field: FieldState = FieldState.new(_config, 2)
	field.add_tower(SimFixtures.find_tower(_config, &"fire_1"), Vector2i(2, 3), 1)
	field.add_tower(SimFixtures.find_tower(_config, &"ice_1"), Vector2i(0, 6), 0)
	for i: int in 8:
		field.schedule_spawn(MobState.create(_config.wave_mob, i * 10), i * 15)
	_run_until_done(field)
	var hasher: StateHasher = StateHasher.new()
	field.add_to_hash(hasher)
	hasher.add(field.pending_kill_gold)
	hasher.add(field.pending_breaches.size())
	return hasher.value


func _run_until_done(field: FieldState) -> void:
	var guard: int = 0
	while not field.is_wave_done() and guard < 5000:
		field.tick()
		guard += 1

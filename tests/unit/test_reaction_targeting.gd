extends GutTest
## Финишер видит подготовленную цель; обычные стрелки сохраняют приоритет прорыва.

var _config: GameConfig
var _field: FieldState


func before_each() -> void:
	_config = load("res://data/game_config.tres") as GameConfig
	_field = FieldState.new(_config, 3, 441)
	for index: int in 3:
		var mob: MobState = MobState.create(_config.wave_mob)
		mob.id = index + 1
		mob.hp = 1000
		mob.progress = [5000, 4000, 3500][index]
		_field.mobs.append(mob)
	_field.mobs[1].charge_ticks_left = 60
	_field.mobs[1].curse_ticks_left = 60
	_field.mobs[2].freeze_ticks_left = 30


func test_war_finisher_prefers_two_marked_targets_over_unmarked_leader() -> void:
	var tower: TowerState = _field.add_tower(
			load("res://data/towers/war_engine.tres") as TowerData, Vector2i(2, 4), 0)
	var targets: Array[MobState] = _field._find_targets(tower, tower.center_milli(), 3000)
	assert_eq(targets[0].id, 2)
	assert_eq(targets[1].id, 3)


func test_shield_does_not_falsely_promise_reaction_and_basic_shooter_stays_front() -> void:
	_field.mobs[1].shield_left = 1
	var tower: TowerState = _field.add_tower(
			load("res://data/towers/war_engine.tres") as TowerData, Vector2i(2, 4), 0)
	var targets: Array[MobState] = _field._find_targets(tower, tower.center_milli(), 3000)
	assert_eq(targets[0].id, 3)
	assert_eq(targets[1].id, 1)
	var basic: TowerState = _field.add_tower(
			load("res://data/towers/bolt.tres") as TowerData, Vector2i(2, 5), 0)
	var basic_targets: Array[MobState] = _field._find_targets(basic, basic.center_milli(), 3000)
	assert_eq(basic_targets[0].id, 1)


func test_finisher_saves_imminent_breach_before_chasing_reaction() -> void:
	_field.mobs[0].progress = _field.get_path_end_progress() - 500
	_field.mobs[1].progress = _field.get_path_end_progress() - 2500
	var tower: TowerState = _field.add_tower(
			load("res://data/towers/war_rocket.tres") as TowerData, Vector2i(2, 8), 0)
	var targets: Array[MobState] = _field._find_targets(tower, tower.center_milli(), 3200)
	assert_eq(targets[0].id, 1, "Последняя клетка важнее красивого сочетания позади")

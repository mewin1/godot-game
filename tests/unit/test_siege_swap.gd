extends GutTest
## Подготовка обмена, цена ошибки и сохранность состояния башен.

var _settings: SiegeTrialConfig
var _trial: SiegeTrial


func before_each() -> void:
	_settings = (load("res://data/siege_trial.tres") as SiegeTrialConfig).duplicate() as SiegeTrialConfig
	_settings.bot_domovoy_chance = 0
	_settings.bot_defenses = []
	_trial = SiegeTrial.new(_settings, SiegeTrial.DOMOVOY)
	_trial.bot_enabled = false


func test_swap_stops_both_towers_then_moves_them_once() -> void:
	var side: SiegeTrialSide = _trial.sides[0]
	var first: TowerState = side.walking_tower()
	var second: TowerState = side.field.get_tower(side.swap_tower_id)
	var origin: Vector2i = first.anchor
	var destination: Vector2i = second.anchor
	_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.START))
	assert_eq(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.SKILL)), "")
	for tick: int in _settings.swap_ticks - 1:
		_trial.tick()
	assert_eq(first.anchor, origin)
	assert_eq(second.anchor, destination)
	_trial.tick()
	assert_eq(first.anchor, destination)
	assert_eq(second.anchor, origin)
	assert_eq(side.swap_left, 0)
	var first_damage: int = side.field.battle_report.damage_by_tower.get(first.id, 0)
	var second_damage: int = side.field.battle_report.damage_by_tower.get(second.id, 0)
	assert_eq(first_damage, 0)
	assert_eq(second_damage, 0)
	assert_same(side.field.get_tower_at(origin), second)
	assert_same(side.field.get_tower_at(destination), first)
	assert_ne(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.SKILL)), "")


func test_swap_preserves_identity_stats_and_firing_order() -> void:
	var field: FieldState = _trial.sides[0].field
	var order: Array[TowerState] = field.towers.duplicate()
	var first: TowerState = order[0]
	var second: TowerState = order[1]
	first.cooldown_left = 7
	second.cooldown_left = 11
	SiegeTowerSwap.apply(field, first, second)
	assert_eq(field.towers, order)
	assert_eq(first.level, _settings.levels[0])
	assert_eq(second.level, _settings.levels[1])
	assert_eq(first.cooldown_left, 7)
	assert_eq(second.cooldown_left, 11)
	for tower: TowerState in field.towers:
		for cell: Vector2i in tower.cells():
			assert_same(field.get_tower_at(cell), tower)


func test_swap_rejects_same_tower_empty_cell_and_shape_crossing_road() -> void:
	var side: SiegeTrialSide = _trial.sides[0]
	var before: int = _trial.state_hash()
	for cell: Vector2i in [side.walk_origin, Vector2i(5, 7), _settings.positions[2]]:
		assert_ne(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.TARGET, 0, cell)), "")
		assert_eq(_trial.state_hash(), before)


func test_swap_can_exchange_different_shapes_when_both_fit() -> void:
	var side: SiegeTrialSide = _trial.sides[0]
	var water: TowerState = side.field.towers[2]
	var spark: TowerState = side.field.towers[1]
	assert_eq(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.HUT, 0, Vector2i.ZERO, water.id)), "")
	assert_eq(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.TARGET, 0, spark.anchor)), "")
	var before: Vector2i = spark.anchor
	_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.START))
	assert_ne(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.TARGET, 0, _settings.positions[3])), "")
	_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.SKILL))
	for tick: int in _settings.swap_ticks:
		_trial.tick()
	assert_eq(water.anchor, before)
	for cell: Vector2i in water.cells():
		assert_same(side.field.get_tower_at(cell), water)


func test_swap_timing_changes_defense_with_same_pair_and_seed() -> void:
	var hp_after: Array[int] = []
	for use_at: int in [0, 160]:
		var duel: SiegeTrial = SiegeTrial.new(_settings, SiegeTrial.DOMOVOY)
		duel.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.TARGET, 0, _settings.positions[3]))
		duel.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.START))
		for tick: int in _settings.max_ticks:
			if tick == use_at:
				duel.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.SKILL))
			if tick == 180:
				duel.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.RELEASE))
			duel.tick()
		hp_after.append(duel.sides[0].hp)
	assert_gt(hp_after[1], hp_after[0], "Момент обмена должен менять исход обороны")


func test_bot_domovoy_waits_then_saves_stronger_tower_from_announced_raid() -> void:
	_settings.bot_domovoy_chance = 100
	_trial = SiegeTrial.new(_settings, SiegeTrial.GORYNYCH)
	assert_eq(_trial.sides[1].hero, SiegeTrial.DOMOVOY)
	_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.TARGET, 0, _settings.positions[0]))
	_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.START))
	for tick: int in _settings.bot_reaction_ticks + 1:
		_trial.tick()
	assert_false(_trial.sides[1].skill_used, "Прицел не является приказом")
	_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.SKILL))
	for tick: int in _settings.bot_reaction_ticks:
		_trial.tick()
	assert_false(_trial.sides[1].skill_used)
	_trial.tick()
	assert_gt(_trial.sides[1].swap_left, 0)
	for tick: int in _settings.swap_ticks:
		_trial.tick()
	assert_false(_trial.in_fire_zone(0, _trial.sides[1].walking_tower()))


func test_bot_domovoy_does_not_swap_two_towers_inside_same_raid() -> void:
	_settings.bot_domovoy_chance = 100
	_settings.fire_radius_milli = 20000
	_trial = SiegeTrial.new(_settings, SiegeTrial.GORYNYCH)
	_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.START))
	_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.SKILL))
	for tick: int in _settings.bot_reaction_ticks + 1:
		_trial.tick()
	assert_false(_trial.sides[1].skill_used)


func test_bot_domovoy_swaps_on_observed_army_and_finishes_deterministically() -> void:
	_settings.bot_domovoy_chance = 100
	var first: SiegeTrial = SiegeTrial.new(_settings)
	var second: SiegeTrial = SiegeTrial.new(_settings)
	for trial: SiegeTrial in [first, second]:
		trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.START))
	for tick: int in _settings.max_ticks:
		first.tick()
		second.tick()
		assert_eq(first.state_hash(), second.state_hash())
	assert_true(first.sides[1].skill_used)
	assert_eq(first.phase, SiegeTrial.Phase.OVER)

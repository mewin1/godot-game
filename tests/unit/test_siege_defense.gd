extends GutTest

var _settings: SiegeTrialConfig


func before_each() -> void:
	_settings = load("res://data/siege_trial.tres") as SiegeTrialConfig


func _fixed_defense(index: int) -> SiegeTrialConfig:
	var config: SiegeTrialConfig = _settings.duplicate() as SiegeTrialConfig
	config.bot_defenses = [_settings.bot_defenses[index]]
	return config


func test_all_defenses_preserve_tower_power_and_have_valid_cells() -> void:
	for index: int in _settings.bot_defenses.size():
		var duel: SiegeTrial = SiegeTrial.new(_fixed_defense(index))
		var field: FieldState = duel.sides[1].field
		assert_eq(field.towers.size(), _settings.towers.size())
		for slot: int in field.towers.size():
			var tower: TowerState = field.towers[slot]
			assert_same(tower.data, _settings.towers[slot])
			assert_eq(tower.level, _settings.levels[slot])
			assert_eq(duel.sides[0].field.towers[slot].anchor, _settings.positions[slot])
			for cell: Vector2i in tower.cells():
				assert_true(field.is_buildable(cell))
				assert_same(field.get_tower_at(cell), tower)


func test_spread_defense_reduces_towers_in_the_default_raid_zone() -> void:
	var covered: Array[int] = []
	for index: int in _settings.bot_defenses.size():
		var duel: SiegeTrial = SiegeTrial.new(_fixed_defense(index), SiegeTrial.GORYNYCH)
		var count: int = 0
		for tower: TowerState in duel.sides[1].field.towers:
			if duel.in_fire_zone(0, tower):
				count += 1
		covered.append(count)
	assert_gt(covered[0], covered[1], "Выбор центра должен учитывать расстановку")


func test_each_defense_supports_both_defensive_heroes_and_reaches_end() -> void:
	for index: int in _settings.bot_defenses.size():
		for chance: int in [0, 100]:
			var config: SiegeTrialConfig = _fixed_defense(index)
			config.bot_domovoy_chance = chance
			var duel: SiegeTrial = SiegeTrial.new(config, SiegeTrial.GORYNYCH)
			var bot: SiegeTrialSide = duel.sides[1]
			assert_eq(bot.walk_origin, bot.walking_tower().anchor)
			if bot.hero == SiegeTrial.YAGA:
				assert_true(bot.field.can_place_tower_data(bot.walking_tower().data, bot.destination, 0))
			else:
				assert_true(SiegeTowerSwap.can_swap(bot.field, bot.walking_tower(), bot.field.get_tower(bot.swap_tower_id)))
			duel.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.START))
			for tick: int in config.max_ticks:
				duel.tick()
			assert_eq(duel.phase, SiegeTrial.Phase.OVER)

extends GutTest
## Проверяем два приказа, завершение без подвисаний и повторяемость дуэли.

var _settings: SiegeTrialConfig
var _trial: SiegeTrial


func before_each() -> void:
	_settings = (load("res://data/siege_trial.tres") as SiegeTrialConfig).duplicate() as SiegeTrialConfig
	_settings.bot_domovoy_chance = 0
	_settings.bot_defenses = []
	_trial = SiegeTrial.new(_settings)
	_trial.bot_enabled = false


func _start() -> void:
	assert_eq(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.START)), "")


func _step(count: int) -> void:
	for index: int in count:
		_trial.tick()


func test_held_reserve_keeps_empty_battle_open_and_auto_releases_once() -> void:
	_start()
	for side: SiegeTrialSide in _trial.sides:
		side.field.retreat_remaining()
	_step(_settings.reserve_deadline)
	assert_eq(_trial.phase, SiegeTrial.Phase.BATTLE)
	assert_false(_trial.sides[0].released)
	_step(1)
	assert_true(_trial.sides[0].released)
	assert_eq(_trial.sides[0].released_tick, _settings.reserve_deadline)
	assert_true(_trial.sides[0].released_automatically)
	assert_eq(_trial.sides[1].field.count_remaining_mobs(), _settings.reserve_plans[0].order.size())
	assert_ne(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.RELEASE)), "")
	assert_eq(_trial.sides[1].field.count_remaining_mobs(), _settings.reserve_plans[0].order.size())


func test_yaga_stops_firing_then_arrives_and_cannot_walk_again() -> void:
	_start()
	assert_eq(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.SKILL)), "")
	_step(_settings.walk_ticks - 1)
	var me: SiegeTrialSide = _trial.sides[0]
	assert_eq(me.field.towers[0].anchor, _settings.positions[0])
	var damage: int = me.field.battle_report.damage_by_tower.get(me.field.towers[0].id, 0)
	assert_eq(damage, 0)
	_step(1)
	assert_eq(me.field.towers[0].anchor, _settings.walk_destination)
	assert_eq(me.walk_left, 0)
	assert_ne(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.SKILL)), "")


func test_invalid_walk_position_does_not_change_destination() -> void:
	for cell: Vector2i in [Vector2i(-1, -1), Vector2i(1, 7), _settings.positions[1]]:
		assert_ne(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.TARGET, 0, cell)), "")
	assert_eq(_trial.sides[0].destination, _settings.walk_destination)
	_start()
	assert_ne(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.TARGET, 0, Vector2i(0, 4))), "")


func test_gorynych_warns_then_suppresses_only_zone_and_recovers() -> void:
	_trial = SiegeTrial.new(_settings, SiegeTrial.GORYNYCH)
	_trial.bot_enabled = false
	assert_eq(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.TARGET, 0, _settings.positions[0])), "")
	_start()
	assert_eq(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.SKILL)), "")
	assert_eq(_trial.sides[0].fire_left, 0)
	_step(_settings.fire_warning_ticks)
	assert_eq(_trial.sides[0].fire_left, _settings.fire_ticks)
	var target: FieldState = _trial.sides[1].field
	var tower: TowerState = target.towers[0]
	assert_true(_trial.in_fire_zone(0, tower))
	assert_false(_trial.in_fire_zone(0, target.towers[3]))
	var before: int = target.battle_report.damage_by_tower.get(tower.id, 0)
	_step(_settings.fire_ticks)
	var during: int = target.battle_report.damage_by_tower.get(tower.id, 0)
	assert_eq(during, before)
	assert_eq(_trial.sides[0].fire_left, 0)
	target.schedule_spawn(MobState.create(_settings.main_mob), target.wave_tick)
	_step(20)
	var after: int = target.battle_report.damage_by_tower.get(tower.id, 0)
	assert_gt(after, before)


func test_commands_validate_phase_and_side_without_spending_skill() -> void:
	assert_ne(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.RELEASE)), "")
	assert_ne(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.SKILL)), "")
	assert_ne(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.SKILL, -1)), "")
	assert_false(_trial.sides[0].skill_used)
	_start()
	assert_ne(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.RESERVE, 0, Vector2i.ZERO, 1)), "")


func test_same_seed_commands_and_bot_produce_identical_state_every_tick() -> void:
	for hero: StringName in [SiegeTrial.YAGA, SiegeTrial.GORYNYCH, SiegeTrial.DOMOVOY]:
		var first: SiegeTrial = SiegeTrial.new(_settings, hero, 145)
		var second: SiegeTrial = SiegeTrial.new(_settings, hero, 145)
		for duel: SiegeTrial in [first, second]:
			duel.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.RESERVE, 0, Vector2i.ZERO, 3))
			if hero == SiegeTrial.YAGA:
				duel.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.HUT, 0, Vector2i.ZERO, duel.sides[0].field.towers[1].id))
			duel.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.START))
		for tick: int in _settings.max_ticks + 1:
			if tick == 130 or tick == 190:
				var action: SiegeTrialCommand.Action = SiegeTrialCommand.Action.RELEASE if tick == 130 else SiegeTrialCommand.Action.SKILL
				for duel: SiegeTrial in [first, second]:
					duel.execute(SiegeTrialCommand.new(action))
			first.tick()
			second.tick()
			assert_eq(first.state_hash(), second.state_hash(), "tick %d" % tick)
		assert_eq(first.phase, SiegeTrial.Phase.OVER)
		assert_eq(first.journal, second.journal)


func test_timeout_counts_remaining_and_rejects_late_commands() -> void:
	var short: SiegeTrialConfig = _settings.duplicate() as SiegeTrialConfig
	short.max_ticks = 1
	_trial = SiegeTrial.new(short)
	_trial.bot_enabled = false
	_start()
	_step(1)
	assert_eq(_trial.phase, SiegeTrial.Phase.OVER)
	assert_lt(_trial.sides[0].hp, short.hero_hp)
	var before: int = _trial.state_hash()
	assert_ne(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.SKILL)), "")
	_step(50)
	assert_eq(_trial.state_hash(), before)


func test_playing_does_not_modify_shared_game_resources() -> void:
	var hp: int = _settings.main_mob.hp
	var speed: int = _settings.reserves[0].speed_milli_per_tick
	_start()
	_step(_settings.max_ticks)
	assert_eq(_settings.main_mob.hp, hp)
	assert_eq(_settings.reserves[0].speed_milli_per_tick, speed)
	var fresh: SiegeTrial = SiegeTrial.new(_settings)
	assert_eq(fresh.sides[0].field.towers[0].anchor, _settings.positions[0])
	assert_false(fresh.sides[0].released)


func test_gorynych_timing_changes_outcome_on_the_same_prepared_board() -> void:
	var hp_after: Array[int] = []
	for use_at: int in [0, 240]:
		var duel: SiegeTrial = SiegeTrial.new(_settings, SiegeTrial.GORYNYCH)
		duel.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.START))
		for tick: int in _settings.max_ticks:
			if tick == use_at:
				duel.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.SKILL))
			if tick == 180:
				duel.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.RELEASE))
			duel.tick()
		hp_after.append(duel.sides[1].hp)
	assert_gt(hp_after[0], hp_after[1], "Точный налёт должен пробивать лучше пустого раннего")


func test_target_outside_board_rejected_without_changing_spell() -> void:
	_trial = SiegeTrial.new(_settings, SiegeTrial.GORYNYCH)
	assert_ne(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.TARGET, 0, Vector2i(-1, 4))), "")
	assert_eq(_trial.sides[0].target, _settings.fire_target)


func test_bot_yaga_evades_announced_raid_after_reaction_delay() -> void:
	_trial = SiegeTrial.new(_settings, SiegeTrial.GORYNYCH)
	_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.TARGET, 0, _settings.positions[0]))
	_start()
	_step(_settings.bot_reaction_ticks + 1)
	assert_false(_trial.sides[1].skill_used, "Прицел сам по себе не выдаёт будущий приказ")
	_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.SKILL))
	_step(_settings.bot_reaction_ticks)
	assert_false(_trial.sides[1].skill_used, "Бот не отвечает мгновенно")
	_step(1)
	assert_true(_trial.sides[1].skill_used)
	assert_eq(_trial.sides[1].skill_tick - _trial.sides[0].skill_tick, _settings.bot_reaction_ticks)
	_step(_settings.walk_ticks)
	assert_false(_trial.in_fire_zone(0, _trial.sides[1].field.towers[0]))
	assert_gt(_trial.sides[0].fire_left, 0, "Избушка уходит, пока налёт ещё действует")


func test_bot_yaga_does_not_evade_raid_away_from_hut() -> void:
	_trial = SiegeTrial.new(_settings, SiegeTrial.GORYNYCH)
	_start()
	_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.SKILL))
	_step(_settings.bot_reaction_ticks + 1)
	assert_false(_trial.sides[1].skill_used)


func test_bot_yaga_does_not_evade_into_the_same_raid() -> void:
	_trial = SiegeTrial.new(_settings, SiegeTrial.GORYNYCH)
	assert_eq(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.TARGET, 1, Vector2i(0, 6))), "")
	_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.TARGET, 0, _settings.positions[0]))
	_start()
	_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.SKILL))
	_step(_settings.bot_reaction_ticks + 1)
	assert_false(_trial.sides[1].skill_used, "Перенос внутри зоны не спасает от налёта")


func test_bot_reserve_reacts_to_walk_with_delay() -> void:
	_trial.bot_enabled = true
	_start()
	_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.SKILL))
	_step(_settings.bot_reaction_ticks)
	assert_false(_trial.sides[1].released)
	_step(1)
	assert_eq(_trial.sides[1].released_tick, _settings.bot_reaction_ticks)


func test_breach_report_counts_timeout_once_and_enters_state_hash() -> void:
	var short: SiegeTrialConfig = _settings.duplicate() as SiegeTrialConfig
	short.max_ticks = 1
	_trial = SiegeTrial.new(short)
	_trial.bot_enabled = false
	_start()
	_step(1)
	assert_eq(_trial.sides[0].breached_count, short.main_count)
	_step(2)
	assert_eq(_trial.sides[0].breached_count, short.main_count)
	var before: int = _trial.state_hash()
	_trial.sides[0].breached_count += 1
	assert_ne(_trial.state_hash(), before)


func test_mixed_reserve_spawns_in_declared_order_with_own_stats() -> void:
	for choice: int in [2, 3]:
		_trial = SiegeTrial.new(_settings)
		_trial.bot_enabled = false
		assert_eq(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.RESERVE, 0, Vector2i.ZERO, choice)), "")
		_start()
		var target: FieldState = _trial.sides[1].field
		target.retreat_remaining()
		target.towers.clear()
		target.mark_towers_changed()
		_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.RELEASE))
		assert_false(_trial.sides[0].released_automatically)
		var order: PackedInt32Array = _settings.reserve_plans[choice].order
		for slot: int in order.size():
			_step(1 if slot == 0 else _settings.spawn_interval)
			assert_eq(target.mobs.size(), slot + 1, "Отряд выходит по одному, а не мгновенно")
			var mob: MobState = target.mobs[slot]
			assert_same(mob.data, _settings.reserves[order[slot]])
			assert_eq(mob.max_hp, _settings.reserve_hp[order[slot]])
			assert_eq(mob.speed, _settings.reserve_speed[order[slot]])
			assert_eq(mob.sender_index, 0)


func test_reserve_plan_rejects_invalid_or_mid_battle_changes() -> void:
	assert_eq(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.RESERVE, 0, Vector2i.ZERO, 3)), "")
	for choice: int in [-1, _settings.reserve_plans.size()]:
		assert_ne(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.RESERVE, 0, Vector2i.ZERO, choice)), "")
		assert_eq(_trial.sides[0].reserve_kind, 3)
	_start()
	assert_ne(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.RESERVE, 0, Vector2i.ZERO, 2)), "")
	assert_eq(_trial.sides[0].reserve_kind, 3)


func test_same_mixed_roster_in_different_order_changes_battle() -> void:
	var hp_after: Array[int] = []
	for choice: int in [2, 3]:
		var duel: SiegeTrial = SiegeTrial.new(_settings)
		duel.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.RESERVE, 0, Vector2i.ZERO, choice))
		duel.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.START))
		duel.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.RELEASE))
		for tick: int in _settings.max_ticks:
			if tick == 180:
				duel.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.SKILL))
			duel.tick()
		hp_after.append(duel.sides[1].hp)
	var first: PackedInt32Array = _settings.reserve_plans[2].order.duplicate()
	var second: PackedInt32Array = _settings.reserve_plans[3].order.duplicate()
	first.sort()
	second.sort()
	assert_eq(first, second, "Меняется только порядок, а не сила/состав армии")
	assert_ne(hp_after[0], hp_after[1], "Порядок должен иметь наблюдаемое последствие")


func test_yaga_moves_selected_tower_and_only_it_stops_firing() -> void:
	var side: SiegeTrialSide = _trial.sides[0]
	var tower: TowerState = side.field.towers[1]
	var first: TowerState = side.field.towers[0]
	assert_eq(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.HUT, 0, Vector2i.ZERO, tower.id)), "")
	assert_eq(side.walk_origin, tower.anchor)
	_start()
	_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.SKILL))
	_step(_settings.walk_ticks)
	assert_eq(tower.anchor, side.destination)
	assert_eq(first.anchor, _settings.positions[0])
	var selected_damage: int = side.field.battle_report.damage_by_tower.get(tower.id, 0)
	var first_damage: int = side.field.battle_report.damage_by_tower.get(first.id, 0)
	assert_eq(selected_damage, 0)
	assert_gt(first_damage, 0)
	assert_same(side.field.get_tower_at(side.destination), tower)
	assert_null(side.field.get_tower_at(side.walk_origin))


func test_yaga_selecting_wide_tower_finds_destination_for_entire_shape() -> void:
	var side: SiegeTrialSide = _trial.sides[0]
	var tower: TowerState = side.field.towers[2]
	assert_eq(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.TARGET, 0, Vector2i(0, 6))), "")
	assert_eq(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.HUT, 0, Vector2i.ZERO, tower.id)), "")
	assert_true(side.field.can_place_tower_data(tower.data, side.destination, 0))
	assert_ne(side.destination, Vector2i(0, 6))
	var valid: Vector2i = side.destination
	assert_ne(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.TARGET, 0, Vector2i(side.field.layout.width - 1, 7))), "")
	assert_eq(side.destination, valid, "Нельзя обрезать вторую клетку башни краем поля")
	_start()
	_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.SKILL))
	_step(_settings.walk_ticks)
	for cell: Vector2i in tower.cells():
		assert_same(side.field.get_tower_at(cell), tower)


func test_hut_selection_rejects_wrong_hero_invalid_id_and_battle() -> void:
	var before: int = _trial.state_hash()
	assert_ne(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.HUT, 0, Vector2i.ZERO, -1)), "")
	assert_ne(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.HUT, 1, Vector2i.ZERO, 1)), "")
	assert_eq(_trial.state_hash(), before)
	_start()
	before = _trial.state_hash()
	assert_ne(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.HUT, 0, Vector2i.ZERO, 2)), "")
	assert_eq(_trial.state_hash(), before)

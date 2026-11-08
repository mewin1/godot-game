extends GutTest
## Разделение существующего состава на авангард и удержанный отряд.

var _settings: SiegeTrialConfig
var _trial: SiegeTrial


func before_each() -> void:
	_settings = load("res://data/siege_trial.tres") as SiegeTrialConfig
	_trial = SiegeTrial.new(_settings)
	_trial.bot_enabled = false


func _choose(plan: int) -> void:
	assert_eq(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.RESERVE, 0, Vector2i.ZERO, plan)), "")
	assert_eq(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.START)), "")


func test_opening_leads_main_army_and_reserve_is_not_duplicated() -> void:
	for choice: int in [4, 5]:
		_trial = SiegeTrial.new(_settings)
		_trial.bot_enabled = false
		_choose(choice)
		var plan: SiegeReservePlan = _settings.reserve_plans[choice]
		var field: FieldState = _trial.sides[1].field
		field.towers.clear()
		field.mark_towers_changed()
		assert_eq(field.count_remaining_mobs(), _settings.main_count + plan.opening_count)
		_trial.tick()
		assert_same(field.mobs[0].data, _settings.reserves[plan.order[0]])
		for tick: int in plan.opening_count * _settings.spawn_interval:
			_trial.tick()
		assert_same(field.mobs[plan.opening_count].data, _settings.main_mob)
		assert_eq(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.RELEASE)), "")
		assert_eq(field.count_remaining_mobs(), _settings.main_count + plan.order.size())
		assert_ne(_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.RELEASE)), "")
		assert_eq(field.count_remaining_mobs(), _settings.main_count + plan.order.size())


func test_deadline_releases_only_held_group_after_opening_was_destroyed() -> void:
	_choose(4)
	var field: FieldState = _trial.sides[1].field
	field.retreat_remaining()
	for tick: int in _settings.reserve_deadline + 1:
		_trial.tick()
	assert_true(_trial.sides[0].released_automatically)
	assert_eq(field.count_remaining_mobs(), _settings.reserve_plans[4].held_count())
	assert_same(field.mobs[0].data, _settings.reserves[0])


func test_split_plans_preserve_roster_and_leave_nonempty_reserve() -> void:
	for choice: int in [4, 5]:
		var split: SiegeReservePlan = _settings.reserve_plans[choice]
		var together: SiegeReservePlan = _settings.reserve_plans[choice - 2]
		assert_eq(split.order, together.order)
		assert_gt(split.opening_count, 0)
		assert_gt(split.held_count(), 0)
	for plan: SiegeReservePlan in _settings.reserve_plans:
		assert_gte(plan.opening_count, 0)
		assert_gt(plan.held_count(), 0)
		for kind: int in plan.order:
			assert_between(kind, 0, _settings.reserves.size() - 1)


func test_attack_groups_account_for_scheduled_units_at_timeout() -> void:
	var short: SiegeTrialConfig = _settings.duplicate() as SiegeTrialConfig
	short.max_ticks = 1
	_trial = SiegeTrial.new(short)
	_trial.bot_enabled = false
	_choose(4)
	_trial.execute(SiegeTrialCommand.new(SiegeTrialCommand.Action.RELEASE))
	_trial.tick()
	var attack: SiegeAttackLedger = _trial.sides[0].attack
	assert_eq(attack.breaches(false), short.main_count + short.reserve_plans[4].opening_count)
	assert_eq(attack.breaches(true), short.reserve_plans[4].held_count())
	assert_eq(attack.breaches(false) + attack.breaches(true), _trial.sides[1].breached_count)


func test_unreleased_reserve_is_not_counted_as_breached() -> void:
	var short: SiegeTrialConfig = _settings.duplicate() as SiegeTrialConfig
	short.max_ticks = 1
	_trial = SiegeTrial.new(short)
	_trial.bot_enabled = false
	_choose(5)
	_trial.tick()
	assert_eq(_trial.sides[0].attack.breaches(true), 0)
	assert_eq(_trial.sides[0].attack.breaches(false), short.main_count + short.reserve_plans[5].opening_count)

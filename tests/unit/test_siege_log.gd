extends GutTest

var _settings: SiegeTrialConfig


func before_each() -> void:
	_settings = load("res://data/siege_trial.tres") as SiegeTrialConfig


func _send(trial: SiegeTrial, log: SiegeTrialLog, command: SiegeTrialCommand) -> void:
	assert_eq(trial.execute(command), "")
	log.record(command, trial.tick_count)


func _play(hero: StringName) -> Dictionary:
	var trial: SiegeTrial = SiegeTrial.new(_settings, hero, 9007199254740993)
	var log: SiegeTrialLog = SiegeTrialLog.new()
	_send(trial, log, SiegeTrialCommand.new(SiegeTrialCommand.Action.RESERVE, 0, Vector2i.ZERO, 5))
	if hero == SiegeTrial.GORYNYCH:
		_send(trial, log, SiegeTrialCommand.new(SiegeTrialCommand.Action.TARGET, 0, _settings.positions[0]))
	else:
		_send(trial, log, SiegeTrialCommand.new(SiegeTrialCommand.Action.HUT, 0, Vector2i.ZERO, trial.sides[0].field.towers[1].id))
	_send(trial, log, SiegeTrialCommand.new(SiegeTrialCommand.Action.START))
	for tick: int in _settings.max_ticks:
		if tick == 120:
			_send(trial, log, SiegeTrialCommand.new(SiegeTrialCommand.Action.RELEASE))
		if tick == 180:
			_send(trial, log, SiegeTrialCommand.new(SiegeTrialCommand.Action.SKILL))
		trial.tick()
	var data: Dictionary = JSON.parse_string(JSON.stringify(log.report(trial)))
	return data


func test_json_round_trip_replays_all_heroes_with_exact_seed_and_final_state() -> void:
	for hero: StringName in [SiegeTrial.YAGA, SiegeTrial.GORYNYCH, SiegeTrial.DOMOVOY]:
		var data: Dictionary = _play(hero)
		var replay: SiegeTrial = SiegeTrialLog.replay(data, _settings)
		assert_not_null(replay)
		if replay == null:
			continue
		assert_eq(replay.seed_value, 9007199254740993, "JSON не должен округлять 64-битный сид")
		assert_eq(replay.phase, SiegeTrial.Phase.OVER)
		var expected: int = data.final_hash
		assert_eq(replay.state_hash(), expected)
		var expected_journal: Array = data.journal
		assert_eq(Array(replay.journal), expected_journal)


func test_replay_rejects_changed_config_invalid_order_and_wrong_result() -> void:
	var data: Dictionary = _play(SiegeTrial.YAGA)
	for key: String in ["config_sha256", "format", "final_hash"]:
		var altered: Dictionary = data.duplicate(true)
		altered[key] = "changed" if key == "config_sha256" else -1
		assert_null(SiegeTrialLog.replay(altered, _settings))
	for key: String in ["tick", "action", "side"]:
		var altered: Dictionary = data.duplicate(true)
		altered.orders[0][key] = -1
		assert_null(SiegeTrialLog.replay(altered, _settings))


func test_record_copies_command_values_before_caller_changes_them() -> void:
	var log: SiegeTrialLog = SiegeTrialLog.new()
	var command: SiegeTrialCommand = SiegeTrialCommand.new(SiegeTrialCommand.Action.RESERVE, 0, Vector2i.ZERO, 2)
	log.record(command, 0)
	command.value = 3
	var recorded: int = log.orders[0].value
	assert_eq(recorded, 2)

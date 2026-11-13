extends GutTest
## Хеш состояния и повтор записи забега (docs/37 BUG-20, P0): одно состояние - один хеш,
## запись забега проигрывается заново до того же хеша.

var _settings: RitualTrialConfig


func before_each() -> void:
	_settings = load("res://data/ritual/endless.tres") as RitualTrialConfig


func test_whatif_can_advance_after_boss_gift_pause_without_adding_a_gift() -> void:
	var script: GDScript = load("res://tools/ritual_whatif.gd") as GDScript
	assert_true(script.has_method("advance_without_gifts"))
	if not script.has_method("advance_without_gifts"):
		return
	var trial: RitualTrial = RitualTrial.new(_settings, 0, 1)
	trial.gift_choice.assign([0])
	script.call("advance_without_gifts", trial, 2)
	assert_eq(trial.tick_count, 2, "Развилка продолжает счет времени после победы над боссом")
	assert_true(trial.gift_choice.is_empty())
	assert_true(trial.gifts_taken.is_empty(), "Сравнение вариантов не добавляет случайного усиления")


func test_hash_of_string_name_keys_does_not_depend_on_creation_order() -> void:
	# Ключи впервые создаются здесь, в двух порядках: StringName сравниваются по адресу в памяти,
	# и хотя бы в одном наборе этот порядок расходится с алфавитом.
	var forward: Array[StringName] = []
	for code: int in range(10):
		forward.append(StringName("replay_test_up_%02d" % code))
	var backward: Array[StringName] = []
	for code: int in range(9, -1, -1):
		backward.append(StringName("replay_test_down_%02d" % code))
	backward.reverse()
	for keys: Array[StringName] in [forward, backward]:
		var data: Dictionary = {}
		for index: int in keys.size():
			data[keys[index]] = index
		var actual: StateHasher = StateHasher.new()
		RitualStateCodec.hash_value(actual, data)
		var expected: StateHasher = StateHasher.new()
		expected.add(TYPE_DICTIONARY)
		expected.add(keys.size())
		for key: StringName in keys:
			RitualStateCodec.hash_value(expected, key)
			RitualStateCodec.hash_value(expected, data[key])
		assert_eq(actual.value, expected.value, "Ключи сортируются по тексту, а не по адресу в памяти")


func test_hash_keeps_numeric_order_of_int_keys() -> void:
	var data: Dictionary = {10: 1, 9: 2}
	var actual: StateHasher = StateHasher.new()
	RitualStateCodec.hash_value(actual, data)
	var expected: StateHasher = StateHasher.new()
	expected.add(TYPE_DICTIONARY)
	expected.add(2)
	for key: int in [9, 10]:
		RitualStateCodec.hash_value(expected, key)
		RitualStateCodec.hash_value(expected, data[key])
	assert_eq(actual.value, expected.value)


func test_record_replays_to_the_same_hash() -> void:
	var trial: RitualTrial = RitualTrial.new(_settings, 0, 11, 1)
	assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.BUY, 0,
		trial.field.get_buildable_cells()[0])), "")
	while trial.tick_count < _settings.nights.night_start(2) and trial.phase == RitualTrial.Phase.RUNNING:
		trial.tick()
	var report: Dictionary = JSON.parse_string(JSON.stringify(RitualTrialRecord.build_report(trial)))
	assert_eq(RitualTrialRecord.number(report["hero_index"]), 1, "Герой записан: без него повтор идет другим героем")
	var replay: RitualTrial = RitualTrialRecord.replay(report, _settings)
	assert_not_null(replay)
	assert_eq(replay.tick_count, trial.tick_count)
	assert_eq(replay.state_hash(), trial.state_hash())


func test_cli_hash_check_accepts_matching_record() -> void:
	var result: CliResult = _run_cli(_interim_report(5), ["--hash"])
	var output: String = result.output
	assert_eq(result.code, 0, output)
	assert_string_contains(output, "Хеш:")
	assert_string_contains(output, "(совпал)")


func test_cli_hash_check_rejects_changed_hash() -> void:
	var report: Dictionary = _interim_report(5)
	report["hash"] = RitualTrialRecord.number(report["hash"]) + 1
	var result: CliResult = _run_cli(report, ["--hash"])
	var output: String = result.output
	assert_eq(result.code, 1, output)
	assert_string_contains(output, "Хеш:")
	assert_string_contains(output, "РАЗНЫЙ")


func test_cli_legacy_hash_can_be_inspected_without_strict_check() -> void:
	var report: Dictionary = _interim_report(5)
	report.erase("hero_index")
	report["hash"] = 0
	var result: CliResult = _run_cli(report, [])
	var output: String = result.output
	assert_eq(result.code, 0, output)
	assert_string_contains(output, "РАЗНЫЙ")


func test_cli_view_stops_at_interim_tick_including_tick_zero_commands() -> void:
	for tick: int in [0, 5]:
		var result: CliResult = _run_cli(_interim_report(tick), ["--view=1000"])
		var output: String = result.output
		assert_eq(result.code, 0, output)
		var view_line: String = ""
		for line: String in output.split("\n"):
			if line.begins_with("RITUAL REPLAY VIEW:"):
				view_line = line
		assert_string_contains(view_line, "тик %d," % tick)
		assert_string_contains(view_line, "совпал с чистым повтором")


func _interim_report(ticks: int) -> Dictionary:
	var trial: RitualTrial = RitualTrial.new(_settings, 0, 11)
	assert_eq(trial.execute(RitualCommand.new(RitualCommand.Action.BUY,
		0, trial.field.get_buildable_cells()[0])), "")
	for tick: int in ticks:
		trial.tick()
	return JSON.parse_string(JSON.stringify(RitualTrialRecord.build_report(trial)))


func _run_cli(report: Dictionary, extra: Array[String]) -> CliResult:
	var folder: String = "res://.godot/checks"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var path: String = folder + "/replay_cli_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file == null:
		return CliResult.new(-1, "Не удалось создать тестовую запись")
	file.store_string(JSON.stringify(report))
	file.close()
	var arguments: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"-s", "res://tools/ritual_replay.gd", "--", path]
	arguments.append_array(extra)
	var output: Array[String] = []
	var code: int = OS.execute(OS.get_executable_path(), arguments, output, true)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return CliResult.new(code, "\n".join(output))


class CliResult:
	var code: int
	var output: String

	func _init(exit_code: int, text: String) -> void:
		code = exit_code
		output = text

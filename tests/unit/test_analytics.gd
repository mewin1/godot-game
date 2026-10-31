extends GutTest
## Лог матча и параллельный прогон ботов.

const TEST_LOG_DIR: String = "res://logs/test_tmp"

var _config: GameConfig


func before_each() -> void:
	_config = SimFixtures.make_config()


func after_each() -> void:
	var dir_path: String = ProjectSettings.globalize_path(TEST_LOG_DIR)
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	for file_name: String in DirAccess.get_files_at(dir_path):
		DirAccess.remove_absolute(dir_path.path_join(file_name))
	DirAccess.remove_absolute(dir_path)


func test_logger_writes_all_event_types() -> void:
	var path: String = ProjectSettings.globalize_path(TEST_LOG_DIR).path_join("match.jsonl")
	var sim: MatchSim = MatchSim.new(_config, 11, 2, 0)
	var logger: MatchLogger = MatchLogger.new(sim, path, "test")
	sim.start()
	while sim.phase != MatchSim.Phase.OVER:
		sim.tick()
	assert_false(logger.is_open(), "лог закрывается в конце матча")
	var events: Dictionary[String, int] = {}
	for line: String in FileAccess.get_file_as_string(path).split("\n", false):
		var parsed: Variant = JSON.parse_string(line)
		assert_true(parsed is Dictionary, "каждая строка — JSON-объект")
		var event: Dictionary = parsed
		var event_name: String = event["event"]
		events[event_name] = events.get(event_name, 0) + 1
		if event_name == "round_end":
			var players: Array = event["players"]
			for value: Variant in players:
				var player: Dictionary = value
				var report: Dictionary = player["battle_report"]
				var kills: int = report["killed"]
				var expected_kills: int = player["kills"]
				var hp_lost: int = report["hp_lost"]
				var expected_loss: int = player["hp_lost"]
				assert_eq(kills, expected_kills)
				assert_eq(hp_lost, expected_loss)
	for expected: String in ["match_start", "round_start", "command", "wave_start",
			"round_end", "eliminated", "match_end"]:
		assert_true(events.has(expected), "есть событие %s" % expected)
	assert_eq(events["round_start"], sim.round_number)


func test_runner_runs_matches_in_parallel() -> void:
	var runner: BotMatchRunner = BotMatchRunner.new(_config, 2, "")
	var seeds: Array[int] = [5, 6, 7]
	var results: Array[Dictionary] = runner.run(seeds, 3)
	assert_eq(results.size(), 3)
	for result: Dictionary in results:
		var is_finished: bool = result["finished"]
		assert_true(is_finished)


func test_runner_same_seed_same_result_as_single_thread() -> void:
	var seeds: Array[int] = [21, 22]
	var parallel: Array[Dictionary] = BotMatchRunner.new(_config, 2, "").run(seeds, 2)
	var single: Array[Dictionary] = BotMatchRunner.new(_config, 2, "").run(seeds, 1)
	assert_eq(parallel, single, "потоки не влияют на результат")


func test_logger_separates_actual_losses_from_overkill() -> void:
	var path: String = ProjectSettings.globalize_path(TEST_LOG_DIR).path_join("losses.jsonl")
	var sim: MatchSim = MatchSim.new(_config, 11, 2, 2)
	var logger: MatchLogger = MatchLogger.new(sim, path, "test")
	sim.start()
	sim.players[0].hero_hp = 2
	var mob: MobState = MobState.create(_config.army_mob)
	mob.breach_damage = 10
	mob.sender_index = 1
	sim.players[0].field.pending_breaches.append(mob)
	sim._collect_field_results(sim.players[0])
	assert_eq(sim.players[0].hp_lost_this_round, 2)
	assert_eq(sim.players[0].raw_breach_damage, 10)
	logger._on_sim_round_finished(1)
	logger.close()
	var found: bool = false
	# Читаем по событию: служебные события могут добавляться без смены смысла теста.
	for line: String in FileAccess.get_file_as_string(path).split("\n", false):
		var event: Dictionary = JSON.parse_string(line)
		if event["event"] != "round_end":
			continue
		found = true
		var row: Dictionary = event["players"][0]
		var actual: float = row["hp_lost"]
		var raw_damage: float = row["raw_breach_damage"]
		var hp: float = row["hp"]
		assert_eq(actual, 2.0)
		assert_eq(raw_damage, 10.0)
		assert_eq(hp, -8.0)
	assert_true(found)

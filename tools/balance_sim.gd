extends SceneTree
## Прогон матчей ботов без графики (параллельно на всех ядрах) с логами для анализа баланса.
## Запуск:
##   godot --headless --path . -s res://tools/balance_sim.gd -- --matches=100 --players=5
## Параметры: --matches=N, --players=N, --threads=N (по умолчанию — все ядра),
##   --seed=N (первый сид), --config=res://... (вариант конфига), --no-log.
## Логи: logs/bots/<дата_время>/match_*.jsonl и summary.json с итогами.

const CONFIG_PATH: String = "res://data/game_config.tres"
const LOG_ROOT: String = "res://logs/bots"


func _initialize() -> void:
	var args: Dictionary[String, String] = _parse_args()
	var match_count: int = _arg_int(args, "matches", 20)
	var player_count: int = _arg_int(args, "players", 5)
	var thread_count: int = _arg_int(args, "threads", OS.get_processor_count())
	var first_seed: int = _arg_int(args, "seed", 1)
	var config_path: String = args.get("config", CONFIG_PATH)
	if not config_path.begins_with("res://"):
		push_error("Конфиг должен находиться внутри проекта: res://...")
		quit(1)
		return
	var config: GameConfig = load(config_path) as GameConfig
	if config == null:
		push_error("Не удалось загрузить конфиг: %s" % config_path)
		quit(1)
		return
	var run_dir: String = ""
	if not args.has("no-log"):
		run_dir = ProjectSettings.globalize_path(LOG_ROOT).path_join(_timestamp())
	var seeds: Array[int] = []
	for i: int in match_count:
		seeds.append(first_seed + i)
	var started_ms: int = Time.get_ticks_msec()
	var results: Array[Dictionary] = BotMatchRunner.new(config, player_count, run_dir).run(
			seeds, thread_count)
	var seconds: float = (Time.get_ticks_msec() - started_ms) / 1000.0
	_report(results, seconds, thread_count, run_dir)
	quit()


func _report(results: Array[Dictionary], seconds: float, thread_count: int,
		run_dir: String) -> void:
	var rounds: Array[int] = []
	for result: Dictionary in results:
		var value: int = result["rounds"]
		rounds.append(value)
	rounds.sort()
	var total: int = 0
	for value: int in rounds:
		total += value
	var average: float = float(total) / rounds.size()
	# Это консольный инструмент: печать — его результат.
	print("Матчей: %d за %.1f с (%d потоков)" % [results.size(), seconds, thread_count])
	print("Раунды: среднее %.1f, медиана %d, мин %d, макс %d" % [average,
			rounds[rounds.size() / 2], rounds[0], rounds[rounds.size() - 1]])
	if run_dir == "":
		return
	var summary: FileAccess = FileAccess.open(run_dir.path_join("summary.json"), FileAccess.WRITE)
	if summary == null:
		push_error("Не удалось записать summary.json в %s" % run_dir)
		return
	summary.store_string(JSON.stringify({"seconds": seconds, "average_rounds": average,
			"matches": results}, "\t"))
	summary.close()
	print("Логи: ", run_dir)


func _timestamp() -> String:
	return Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")


func _arg_int(args: Dictionary[String, String], key: String, default_value: int) -> int:
	if not args.has(key):
		return default_value
	return args[key].to_int()


func _parse_args() -> Dictionary[String, String]:
	var result: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		result[parts[0]] = parts[1] if parts.size() > 1 else ""
	return result

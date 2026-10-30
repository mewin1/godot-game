class_name BotMatchRunner
extends RefCounted
## Гоняет матчи ботов без графики, параллельно на нескольких ядрах процессора.
## Каждый матч — своя симуляция и свой лог, общего изменяемого состояния у потоков нет
## (конфиг и данные только читаются). Результат — по одной строке на матч.

## Предел тиков на матч (защита от бесконечного матча при неудачном балансе).
const MAX_TICKS: int = 2_000_000

var _config: GameConfig
var _player_count: int
var _log_dir: String
var _seeds: Array[int] = []
var _results: Array[Dictionary] = []
var _mutex: Mutex = Mutex.new()


## log_dir — папка для логов ("" — без логов).
func _init(config: GameConfig, player_count: int, log_dir: String) -> void:
	_config = config
	_player_count = player_count
	_log_dir = log_dir


## Прогоняет матчи с этими сидами в thread_count потоков. Возвращает итоги по сидам по порядку.
func run(seeds: Array[int], thread_count: int) -> Array[Dictionary]:
	_seeds = seeds
	_results.clear()
	_results.resize(seeds.size())
	var task: int = WorkerThreadPool.add_group_task(_run_one, seeds.size(), thread_count)
	WorkerThreadPool.wait_for_group_task_completion(task)
	return _results


func _run_one(index: int) -> void:
	var seed_value: int = _seeds[index]
	var sim: MatchSim = MatchSim.new(_config, seed_value, _player_count, 0)
	var logger: MatchLogger = null
	if _log_dir != "":
		var path: String = _log_dir.path_join("match_%04d_seed%d.jsonl" % [index, seed_value])
		logger = MatchLogger.new(sim, path, "bots", {"seed": seed_value, "match_index": index})
	sim.start_with_hero_select()
	var guard: int = 0
	while sim.phase != MatchSim.Phase.OVER and guard < MAX_TICKS:
		sim.tick()
		guard += 1
	if logger != null:
		logger.close()
	var winner: PlayerState = sim.get_winner()
	var result: Dictionary = {"seed": seed_value, "rounds": sim.round_number,
			"ticks": sim.tick_count, "finished": sim.phase == MatchSim.Phase.OVER,
			"winner": winner.index if winner != null else -1}
	_mutex.lock()
	_results[index] = result
	_mutex.unlock()

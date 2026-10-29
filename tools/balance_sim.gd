extends SceneTree
## Прогоняет матчи бот против бота без графики и печатает, сколько раундов они длились.
## Нужен, чтобы быстро проверять цифры баланса (цель — матч 15–18 раундов).
## Запуск: godot --headless --path . -s res://tools/balance_sim.gd -- --matches=20 --players=2

const CONFIG_PATH: String = "res://data/game_config.tres"
const MAX_TICKS: int = 1_000_000


func _initialize() -> void:
	var args: Dictionary[String, String] = _parse_args()
	var matches_text: String = args.get("matches", "20")
	var players_text: String = args.get("players", "2")
	var config: GameConfig = load(CONFIG_PATH) as GameConfig
	var rounds: Array[int] = []
	for seed_value: int in matches_text.to_int():
		rounds.append(_run_match(config, seed_value, players_text.to_int()))
	rounds.sort()
	var total: int = 0
	for value: int in rounds:
		total += value
	# Это консольный инструмент: печать — его результат.
	print("Раунды по матчам: ", rounds)
	print("Среднее: %.1f, медиана: %d" % [float(total) / rounds.size(), rounds[rounds.size() / 2]])
	quit()


func _run_match(config: GameConfig, seed_value: int, player_count: int) -> int:
	var sim: MatchSim = MatchSim.new(config, seed_value, player_count, 0)
	sim.start()
	var guard: int = 0
	while sim.phase != MatchSim.Phase.OVER and guard < MAX_TICKS:
		sim.tick()
		guard += 1
	return sim.round_number


func _parse_args() -> Dictionary[String, String]:
	var result: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--") or not arg.contains("="):
			continue
		var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		result[parts[0]] = parts[1]
	return result

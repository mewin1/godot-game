extends SceneTree
## godot --headless --path . -s res://tools/replay_siege.gd -- res://.godot/duels/FILE.json


func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() != 1:
		printerr("Укажите один путь к журналу дуэли после --")
		quit(1)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(arguments[0]))
	if not parsed is Dictionary:
		printerr("Некорректный JSON журнала")
		quit(1)
		return
	var settings: SiegeTrialConfig = load("res://data/siege_trial.tres") as SiegeTrialConfig
	var report: Dictionary = parsed
	var trial: SiegeTrial = SiegeTrialLog.replay(report, settings)
	if trial == null:
		printerr("Повтор не совпал: проверьте формат, команды и версию данных/кода")
		quit(1)
		return
	print("SIEGE REPLAY: OK seed=%d ticks=%d hash=%d" % [trial.seed_value, trial.tick_count, trial.state_hash()])
	quit()

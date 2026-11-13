extends SceneTree
## Повтор записи бесконечного "Обряда" (docs/37 P0): сверка рассветов и хеша с записью.
## godot --headless --path . -s res://tools/ritual_replay.gd -- res://.godot/ritual/FILE.json [--hero=1]
## `--hero=N` - герой для записей до 12.11.2026 (они его не хранят); `--dawns` - печать каждого рассвета.
## `--rules=res://...tres` - правила, с которыми играли: запись проигрывается только на них. Старые правила
## из Git: git show <коммит>:data/ritual/endless.tres > .godot/ritual/endless_<коммит>.tres
## `--hash` - код выхода 1 при несовпадении хеша; старые записи без этого ключа можно исследовать,
## даже если их хеш был записан до исправления BUG-20.
## `--view=N` - без --headless: тот же забег через настоящую панель в окне, N тиков за кадр
## (проверка отрисовки и ошибок в журнале на всем забеге), в конце сверка хеша с чистым повтором.


func _initialize() -> void:
	var path: String = ""
	var hero: int = -1
	var print_dawns: bool = false
	var check_hash: bool = false
	var view_ticks: int = 0
	var rules_path: String = "res://data/ritual/endless.tres"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--rules="):
			rules_path = argument.trim_prefix("--rules=")
		elif argument.begins_with("--view="):
			view_ticks = maxi(1, argument.trim_prefix("--view=").to_int())
		elif argument.begins_with("--hero="):
			hero = argument.trim_prefix("--hero=").to_int()
		elif argument == "--dawns":
			print_dawns = true
		elif argument == "--hash":
			check_hash = true
		else:
			path = argument
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		printerr("Укажите путь к записи attempt_*.json после --")
		quit(1)
		return
	var report: Dictionary = parsed
	var settings: RitualTrialConfig = load(rules_path) as RitualTrialConfig
	var started: int = Time.get_ticks_msec()
	var trial: RitualTrial = RitualTrialRecord.replay(report, settings, -1, hero)
	if trial == null:
		printerr("Повтор не прошел: другая версия, другие правила (см. --rules) или команда отклонена")
		quit(1)
		return
	var recorded: Array = RitualStateCodec.array(report.get("dawns"))
	# Обе стороны через JSON: числа там дробные, сравнение по одному формату.
	var replayed: Variant = JSON.parse_string(JSON.stringify(trial.dawns))
	var mismatches: int = 0
	for index: int in recorded.size():
		var expected: String = JSON.stringify(recorded[index])
		var actual: String = JSON.stringify(replayed[index]) if index < trial.dawns.size() else "-"
		if expected != actual:
			mismatches += 1
			print("Рассвет %d расходится:\n  запись: %s\n  повтор: %s" % [index + 1, expected, actual])
		elif print_dawns:
			print(actual)
	var actual_hash: int = trial.state_hash()
	var recorded_hash: int = RitualTrialRecord.number(report.get("hash"))
	print("RITUAL REPLAY: тик %d, ночей %d, HP %d, золото %d, рассветов %d/%d совпало, %.1f с" % [
		trial.tick_count, trial.nights_survived(), trial.hp, trial.gold, recorded.size() - mismatches,
		recorded.size(), (Time.get_ticks_msec() - started) / 1000.0])
	print("Хеш: повтор %d, запись %d (%s)" % [actual_hash, recorded_hash,
		"совпал" if actual_hash == recorded_hash else "РАЗНЫЙ"])
	if mismatches > 0 or (check_hash and actual_hash != recorded_hash):
		quit(1)
		return
	if view_ticks > 0:
		_view.call_deferred(report, settings, trial.hero_index, view_ticks, actual_hash)
		return
	quit()


func _view(report: Dictionary, settings: RitualTrialConfig, hero: int, per_frame: int, expected: int) -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = DisplayServer.screen_get_size()
	var panel: RitualTrialPanel = (load("res://scenes/ritual_trial.tscn") as PackedScene).instantiate() as RitualTrialPanel
	panel.settings = settings
	root.add_child(panel)
	await process_frame
	panel._hero_panel.hide()
	var summary: Dictionary = RitualStateCodec.dictionary(report.get("summary"))
	var trial: RitualTrial = RitualTrial.new(settings, 0, RitualTrialRecord.number(summary.get("seed")), hero)
	panel.trial = trial
	panel._board_reset()
	# Панель не тикает сама и не пишет новую запись: забег ведет этот инструмент.
	panel.set_process(false)
	panel._saved_result = true
	var commands: Array = RitualStateCodec.array(report.get("commands"))
	var last_tick: int = RitualTrialRecord.number(summary.get("tick"))
	var next: int = 0
	var frames: int = 0
	var finished: bool = false
	while not finished:
		for step: int in per_frame:
			while next < commands.size() and RitualTrialRecord.number(commands[next]["tick"]) == trial.tick_count:
				var error: String = trial.execute(RitualTrialRecord._command(RitualStateCodec.dictionary(commands[next])))
				if not error.is_empty():
					printerr("Команда повтора отклонена на тике %d: %s" % [trial.tick_count, error])
					quit(1)
					return
				next += 1
			if trial.phase != RitualTrial.Phase.RUNNING or trial.tick_count >= last_tick:
				finished = true
				break
			trial.tick()
		panel._refresh()
		await process_frame
		frames += 1
	print("RITUAL REPLAY VIEW: кадров %d, тик %d, хеш %d (%s с чистым повтором)" % [frames, trial.tick_count,
		trial.state_hash(), "совпал" if trial.state_hash() == expected else "РАЗНЫЙ"])
	quit(0 if trial.state_hash() == expected else 1)

extends SceneTree
## Контрольные прогоны, не оценка удовольствия и не замена авторского плейтеста.

const SETTINGS: RitualTrialConfig = preload("res://data/ritual/trial.tres")
var _results: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _play(trial: RitualTrial, scripted: bool, moves: bool) -> void:
	if trial.phase == RitualTrial.Phase.PREP:
		var error: String = trial.execute(RitualCommand.new(RitualCommand.Action.START))
		assert(error.is_empty(), error)
	var initial_hash: int = _normalized_initial_hash(trial)
	var rejected: Array[Dictionary] = []
	while trial.phase == RitualTrial.Phase.RUNNING:
		var command: RitualCommand = null
		if scripted and trial.tick_count in [6600, 7500]:
			command = RitualCommand.new(RitualCommand.Action.SKILL, 0, Vector2i.ZERO, 0, 0,
				12000 if trial.tick_count == 6600 else 45000)
		elif scripted and trial.tick_count == 6560:
			command = RitualCommand.new(RitualCommand.Action.PALISADE, 0, Vector2i.ZERO, 0, 0, 15000)
		if command != null:
			var error: String = trial.execute(command)
			if not error.is_empty():
				rejected.append({"tick": trial.tick_count, "error": error})
		if moves and trial.tick_count in [6520, 7000]:
			var id: int = 4 if trial.field.towers[3].data.id == &"furnace" else 1
			var destination: Vector2i = Vector2i(8, 8) if trial.tick_count == 6520 else Vector2i(7, 10)
			var error: String = trial.execute(RitualCommand.new(RitualCommand.Action.MOVE, 0, destination, 0, id))
			if not error.is_empty():
				rejected.append({"tick": trial.tick_count, "error": error})
		trial.tick()
	var report: Dictionary = RitualTrialRecord.build_report(trial)
	report.merge(trial.summary())
	report["initial_hash"] = initial_hash
	report["mode"] = int(trial.control_mode)
	report["scripted"] = scripted
	report["moves"] = moves
	report["rejected"] = rejected
	report["roster"] = trial.roster()
	report["dawns"] = trial.dawns
	report["hash"] = trial.state_hash()
	_results.append(report)
	print("RITUAL PROBE: %s / %s — HP %d, добыча %d, остатки %d, %s" % [trial.title,
		"переносы" if moves else "приёмы" if scripted else "без команд", trial.hp,
		trial.earned, trial.field.count_alive_mobs(), trial.result])


func _run() -> void:
	for index: int in [0, 1, 2]:
		var trial: RitualTrial = RitualTrial.new(SETTINGS, index)
		trial.control_mode = RitualTrial.ControlMode.PASSIVE
		_play(trial, false, false)
	for index: int in [4, 5]:
		var source: RitualTrial = RitualTrial.new(SETTINGS, index)
		assert(source.phase == RitualTrial.Phase.RUNNING)
		for mode: RitualTrial.ControlMode in [RitualTrial.ControlMode.PASSIVE,
				RitualTrial.ControlMode.ABILITIES, RitualTrial.ControlMode.TRANSFERS]:
			var branch: RitualTrial = source.fork_control(mode)
			_play(branch, mode != RitualTrial.ControlMode.PASSIVE, mode == RitualTrial.ControlMode.TRANSFERS)
	var directory: String = ProjectSettings.globalize_path(RitualTrialRecord.DIRECTORY)
	var error: Error = DirAccess.make_dir_recursive_absolute(directory)
	assert(error == OK)
	var file: FileAccess = FileAccess.open(RitualTrialRecord.DIRECTORY + "/control_report.json", FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(_results, "\t"))
	file.close()
	print("RITUAL PROBE: отчёт .godot/ritual/control_report.json; политики фиксированные, не оптимальные")
	quit()


func _normalized_initial_hash(trial: RitualTrial) -> int:
	var state: Dictionary = trial.snapshot()
	var control: Dictionary = RitualStateCodec.dictionary(state["trial"])
	control["control_mode"] = int(RitualTrial.ControlMode.OPEN)
	control["economy_frozen"] = false
	var hasher: StateHasher = StateHasher.new()
	RitualStateCodec.hash_value(hasher, state)
	return hasher.value

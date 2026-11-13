class_name RitualTrialRecord
extends RefCounted
## Локальные записи полигона вне Git. В sim нет доступа к файлам/часам.

const DIRECTORY: String = "res://.godot/ritual"
const SNAPSHOT_PATH: String = DIRECTORY + "/checkpoint.bin"
static var _save_sequence: int = 0


static func save_checkpoint(trial: RitualTrial, path: String = SNAPSHOT_PATH) -> String:
	var error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	if error != OK:
		return error_string(error)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return error_string(FileAccess.get_open_error())
	file.store_var(trial.snapshot())
	file.close()
	return ""


static func load_checkpoint(settings: RitualTrialConfig, path: String = SNAPSHOT_PATH) -> RitualTrial:
	if not FileAccess.file_exists(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var state: Variant = file.get_var(false)
	file.close()
	if not state is Dictionary:
		return null
	return RitualTrial.from_snapshot(settings, RitualStateCodec.dictionary(state))


static func save_result(trial: RitualTrial, observations: Dictionary = {}) -> String:
	var error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY))
	if error != OK:
		return ""
	_save_sequence += 1
	var stage: String = "final" if trial.phase == RitualTrial.Phase.OVER else "interim"
	var path: String = DIRECTORY + "/attempt_%d_%d_%d_%s.json" % [
		Time.get_unix_time_from_system(), Time.get_ticks_usec(), _save_sequence, stage]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify(build_report(trial, observations), "\t"))
	file.close()
	return path


static func build_report(trial: RitualTrial, observations: Dictionary = {}) -> Dictionary[String, Variant]:
	return {"simulation_version": RitualTrial.SNAPSHOT_VERSION, "rules_hash": trial.rules_hash,
		"completed": trial.phase == RitualTrial.Phase.OVER, "summary": trial.summary(),
		"dawns": trial.dawns.duplicate(true), "commands": trial.commands.duplicate(true),
		"events": trial.journal.duplicate(true), "roster": trial.roster(),
		"idols": trial.idol_report(), "remaining": trial.remaining_report(),
		"control": int(trial.control_mode), "observations": observations.duplicate(true),
		"hero_index": trial.hero_index, "hash": trial.state_hash()}


## Повтор записи: те же правила, сид, герой и команды в те же тики. До `until_tick` (-1 - до конца
## записи). null - запись другой версии или других правил, либо команда не прошла.
## Записи до 12.11.2026 героя не хранят: его передают в `hero_index`.
static func replay(report: Dictionary, settings: RitualTrialConfig, until_tick: int = -1,
		hero_index: int = -1) -> RitualTrial:
	if number(report.get("simulation_version", -1)) != RitualTrial.SNAPSHOT_VERSION:
		return null
	var summary: Dictionary = RitualStateCodec.dictionary(report.get("summary"))
	var hero: int = hero_index if hero_index >= 0 else number(report.get("hero_index", 0))
	var trial: RitualTrial = RitualTrial.new(settings, 0, number(summary.get("seed", 0)), hero)
	if trial.rules_hash != number(report.get("rules_hash", -1)):
		return null
	var commands: Array = RitualStateCodec.array(report.get("commands"))
	var last_tick: int = number(summary.get("tick", 0)) if until_tick < 0 else until_tick
	var next: int = 0
	while true:
		while next < commands.size() and number(commands[next]["tick"]) == trial.tick_count:
			if not trial.execute(_command(RitualStateCodec.dictionary(commands[next]))).is_empty():
				return null
			next += 1
		if trial.phase != RitualTrial.Phase.RUNNING or trial.tick_count >= last_tick:
			break
		trial.tick()
	return trial


## Целое из JSON: числа там приходят дробными.
static func number(value: Variant) -> int:
	if value is float:
		var decimal: float = value
		return roundi(decimal)
	return value if value is int else 0


static func _command(entry: Dictionary) -> RitualCommand:
	# Клетка в JSON - текст "(x, y)".
	var xy: PackedStringArray = str(entry.get("cell", "(0, 0)")).trim_prefix("(").trim_suffix(")").split(",")
	return RitualCommand.new(number(entry["action"]) as RitualCommand.Action, number(entry["item"]),
		Vector2i(xy[0].to_int(), xy[1].to_int()), number(entry["rotation"]), number(entry["tower_id"]),
		number(entry["progress"]))

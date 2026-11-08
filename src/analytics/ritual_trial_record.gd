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
		"hash": trial.state_hash()}

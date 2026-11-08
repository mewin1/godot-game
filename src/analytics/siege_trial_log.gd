class_name SiegeTrialLog
extends RefCounted
## Только принятые приказы человека. Бот восстанавливается из сида, без чтения будущего.

const FORMAT: int = 1
const DIRECTORY: String = "res://.godot/duels"
var orders: Array[Dictionary] = []


func record(command: SiegeTrialCommand, tick: int) -> void:
	orders.append({"tick": tick, "action": int(command.action), "side": command.side,
			"x": command.cell.x, "y": command.cell.y, "value": command.value})


func report(trial: SiegeTrial) -> Dictionary:
	var sides: Array[Dictionary] = []
	for side: SiegeTrialSide in trial.sides:
		sides.append({"hero": String(side.hero), "hp": side.hp,
				"reserve_plan": trial.settings.reserve_plans[side.reserve_kind].display_name,
				"release_tick": side.released_tick, "automatic": side.released_automatically,
				"skill_tick": side.skill_tick, "breaches_received": side.breached_count,
				"breaches_opening": side.attack.breaches(false), "breaches_reserve": side.attack.breaches(true)})
	return {"format": FORMAT, "seed": str(trial.seed_value), "hero": String(trial.sides[0].hero),
			"bot_enabled": trial.bot_enabled, "orders": orders.duplicate(true), "sides": sides,
			"ticks": trial.tick_count, "final_hash": trial.state_hash(), "bot_defense": trial.bot_defense_index,
			"config_sha256": FileAccess.get_sha256(trial.settings.resource_path),
			"journal": Array(trial.journal)}


func save(trial: SiegeTrial) -> String:
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRECTORY)) != OK:
		return ""
	var stamp: String = Time.get_datetime_string_from_system(true).replace(":", "-")
	var path: String = "%s/%s_%d_%d.json" % [DIRECTORY, stamp, trial.seed_value, Time.get_ticks_usec()]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify(report(trial), "\t"))
	return path if file.get_error() == OK else ""


static func replay(data: Dictionary, settings: SiegeTrialConfig) -> SiegeTrial:
	if data.get("format", 0) != FORMAT or data.get("config_sha256", "") != FileAccess.get_sha256(settings.resource_path):
		return null
	var seed_text: String = data.get("seed", "")
	if not seed_text.is_valid_int():
		return null
	var seed_value: int = seed_text.to_int()
	var hero: String = data.get("hero", "")
	if not [String(SiegeTrial.YAGA), String(SiegeTrial.GORYNYCH), String(SiegeTrial.DOMOVOY)].has(hero):
		return null
	var trial: SiegeTrial = SiegeTrial.new(settings, StringName(hero), seed_value)
	trial.bot_enabled = data.get("bot_enabled", true)
	var inputs: Array = data.get("orders", [])
	for raw: Variant in inputs:
		if not raw is Dictionary:
			return null
		var order: Dictionary = raw
		if not _replay_order(trial, order):
			return null
	if trial.phase == SiegeTrial.Phase.PREP:
		return null
	while trial.phase == SiegeTrial.Phase.BATTLE:
		trial.tick()
	var expected_hash: int = data.get("final_hash", -1)
	return trial if trial.state_hash() == expected_hash else null


static func _replay_order(trial: SiegeTrial, order: Dictionary) -> bool:
	var at: int = order.get("tick", -1)
	if at < trial.tick_count or at > trial.settings.max_ticks:
		return false
	while trial.tick_count < at:
		if trial.phase != SiegeTrial.Phase.BATTLE:
			return false
		trial.tick()
	var action: int = order.get("action", -1)
	if action < 0 or action >= SiegeTrialCommand.Action.size():
		return false
	var side: int = order.get("side", -1)
	var x: int = order.get("x", 0)
	var y: int = order.get("y", 0)
	var value: int = order.get("value", 0)
	var command: SiegeTrialCommand = SiegeTrialCommand.new(action as SiegeTrialCommand.Action, side, Vector2i(x, y), value)
	return trial.execute(command).is_empty()

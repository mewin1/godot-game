class_name PlanReserveCommand
extends SimCommand
## Назначить тип и количество купленных бойцов в подкрепление.

var kind: StringName
var resistance: StringName
var count: int


func _init(mob_kind: StringName = &"", mob_resistance: StringName = &"",
		mob_count: int = 0) -> void:
	kind = mob_kind
	resistance = mob_resistance
	count = mob_count


func execute(sim: MatchSim, player: PlayerState) -> String:
	if sim.config.active_battle == null:
		return "Подкрепление не включено"
	return player.army.set_reserve(kind, resistance, count)


func to_log(_sim: MatchSim, _player: PlayerState) -> Dictionary:
	return {"type": "plan_reserve", "kind": kind, "resist": resistance, "count": count}

class_name AimHeroCommand
extends SimCommand
## Назначить поле/клетку или подготовленную башню без применения приёма.

var target: int
var cell: Vector2i
var tower_id: int
var second_id: int


func _init(field_index: int, at: Vector2i, first: int = 0, second: int = 0) -> void:
	target = field_index
	cell = at
	tower_id = first
	second_id = second


func requires_prep() -> bool:
	return false


func execute(sim: MatchSim, player: PlayerState) -> String:
	return sim.battle_heroes.aim(sim, player.index, target, cell, tower_id, second_id)


func to_log(_sim: MatchSim, _player: PlayerState) -> Dictionary:
	return {"type": "aim_hero", "target": target, "x": cell.x, "y": cell.y,
			"tower": tower_id, "second": second_id}

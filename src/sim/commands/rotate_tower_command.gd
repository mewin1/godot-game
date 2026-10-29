class_name RotateTowerCommand
extends SimCommand
## Повернуть поставленную башню на 90°. Если на месте не помещается — ищется ближайшее место рядом.

var tower_id: int


func _init(id: int) -> void:
	tower_id = id


func execute(_sim: MatchSim, player: PlayerState) -> String:
	return player.rotate_tower(tower_id)


func to_log(_sim: MatchSim, _player: PlayerState) -> Dictionary:
	return {"type": "rotate", "tower": tower_id}

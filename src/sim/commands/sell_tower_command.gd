class_name SellTowerCommand
extends SimCommand
## Продать башню.

var tower_id: int


func _init(id: int) -> void:
	tower_id = id


func execute(_sim: MatchSim, player: PlayerState) -> String:
	return player.sell_tower(tower_id)

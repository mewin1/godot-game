class_name MergeTowersCommand
extends SimCommand
## Слить башню source в такую же башню target (target повышает уровень).

var source_id: int
var target_id: int


func _init(source_tower_id: int, target_tower_id: int) -> void:
	source_id = source_tower_id
	target_id = target_tower_id


func execute(_sim: MatchSim, player: PlayerState) -> String:
	return player.merge_towers(source_id, target_id)

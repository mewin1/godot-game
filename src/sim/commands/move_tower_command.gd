class_name MoveTowerCommand
extends SimCommand
## Перенести или повернуть поставленную башню.

var tower_id: int
var anchor: Vector2i
var rotation: int


func _init(id: int, at_anchor: Vector2i, turns: int) -> void:
	tower_id = id
	anchor = at_anchor
	rotation = turns


func execute(_sim: MatchSim, player: PlayerState) -> String:
	return player.move_tower(tower_id, anchor, rotation)


func to_log(_sim: MatchSim, _player: PlayerState) -> Dictionary:
	return {"type": "move", "tower": tower_id, "x": anchor.x, "y": anchor.y, "rotation": rotation}

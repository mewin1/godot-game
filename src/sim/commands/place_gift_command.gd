class_name PlaceGiftCommand
extends SimCommand
## Поставить подарок «тройки» на поле (бесплатно).

var gift_index: int
var anchor: Vector2i
var rotation: int


func _init(index: int, at_anchor: Vector2i, turns: int) -> void:
	gift_index = index
	anchor = at_anchor
	rotation = turns


func execute(_sim: MatchSim, player: PlayerState) -> String:
	return player.place_gift(gift_index, anchor, rotation)


func to_log(_sim: MatchSim, player: PlayerState) -> Dictionary:
	var gifts: Array[TowerData] = player.gift_towers
	var valid: bool = gift_index >= 0 and gift_index < gifts.size()
	return {"type": "place_gift", "tower": String(gifts[gift_index].id) if valid else "",
			"x": anchor.x, "y": anchor.y, "rotation": rotation}

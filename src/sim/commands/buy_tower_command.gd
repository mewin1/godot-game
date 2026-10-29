class_name BuyTowerCommand
extends SimCommand
## Купить башню с витрины и сразу поставить её на поле.

var offer_index: int
var anchor: Vector2i
var rotation: int


func _init(offer: int, at_anchor: Vector2i, turns: int) -> void:
	offer_index = offer
	anchor = at_anchor
	rotation = turns


func execute(_sim: MatchSim, player: PlayerState) -> String:
	return player.buy_tower(offer_index, anchor, rotation)


func to_log(_sim: MatchSim, player: PlayerState) -> Dictionary:
	return {"type": "buy", "offer": offer_index, "tower": _offer_name(player),
			"x": anchor.x, "y": anchor.y, "rotation": rotation}


func _offer_name(player: PlayerState) -> String:
	var data: TowerData = player.shop.get_offer(offer_index)
	return String(data.id) if data != null else ""

class_name BuyRiteCommand
extends SimCommand
## Купить заговор и сразу применить к выбранному идолу или постройке.

var offer_index: int
var target_id: int


func _init(offer: int, target: int) -> void:
	offer_index = offer
	target_id = target


func execute(_sim: MatchSim, player: PlayerState) -> String:
	return player.buy_rite(offer_index, target_id)


func to_log(_sim: MatchSim, player: PlayerState) -> Dictionary:
	var rite: RiteData = player.shop.get_rite(offer_index)
	return {"type": "buy_rite", "offer": offer_index, "target": target_id,
			"rite": String(rite.id) if rite != null else ""}

class_name BuyIntoTowerCommand
extends SimCommand
## Купить копию башни и сразу слить её с такой же башней 1-го уровня на поле.

var offer_index: int
var target_id: int


func _init(offer: int, target_tower_id: int) -> void:
	offer_index = offer
	target_id = target_tower_id


func execute(_sim: MatchSim, player: PlayerState) -> String:
	return player.buy_tower_into(offer_index, target_id)

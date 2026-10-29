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

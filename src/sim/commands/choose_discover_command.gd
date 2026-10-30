class_name ChooseDiscoverCommand
extends SimCommand
## «Тройка → открытие»: выбрать постройку в подарок.

var offer_index: int


func _init(index: int) -> void:
	offer_index = index


func execute(_sim: MatchSim, player: PlayerState) -> String:
	return player.choose_discover(offer_index)


func to_log(_sim: MatchSim, player: PlayerState) -> Dictionary:
	var offers: Array[TowerData] = player.discover_offers
	var valid: bool = offer_index >= 0 and offer_index < offers.size()
	return {"type": "discover", "tower": String(offers[offer_index].id) if valid else ""}

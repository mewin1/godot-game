class_name ChooseBuffCommand
extends SimCommand
## Выбрать один из предложенных бафов отправки.

var offer_index: int


func _init(offer: int) -> void:
	offer_index = offer


func execute(_sim: MatchSim, player: PlayerState) -> String:
	return player.choose_buff(offer_index)


func to_log(_sim: MatchSim, _player: PlayerState) -> Dictionary:
	return {"type": "choose_buff", "offer": offer_index}

class_name ChooseIdolCommand
extends SimCommand
## Бесплатное посвящение/усиление идола после повышения магазина или явный отказ.

var god: StringName
var slot: int


func _init(chosen_god: StringName = &"", chosen_slot: int = -1) -> void:
	god = chosen_god
	slot = chosen_slot


func execute(_sim: MatchSim, player: PlayerState) -> String:
	return player.choose_idol(god, slot)


func to_log(_sim: MatchSim, _player: PlayerState) -> Dictionary:
	return {"type": "choose_idol", "god": String(god), "slot": slot}

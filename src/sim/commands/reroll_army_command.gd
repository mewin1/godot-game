class_name RerollArmyCommand
extends SimCommand
## Обновить лавку армии за золото (казино юнитов).


func execute(_sim: MatchSim, player: PlayerState) -> String:
	return player.reroll_army()


func to_log(_sim: MatchSim, _player: PlayerState) -> Dictionary:
	return {"type": "reroll_army"}

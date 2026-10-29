class_name ReadyCommand
extends SimCommand
## Игрок готов: подготовка закончится, когда готовы все люди (или выйдет время).


func execute(_sim: MatchSim, player: PlayerState) -> String:
	player.is_ready = true
	return ""

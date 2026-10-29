class_name SendUnitsCommand
extends SimCommand
## Скилл отправки: пачка юнитов сопернику в следующую волну, +доход навсегда.


func execute(sim: MatchSim, player: PlayerState) -> String:
	return player.send_units(sim.round_number)

class_name ReleaseReserveCommand
extends SimCommand
## Один приказ выпускает подкрепление по всем маршрутам игрока.


func requires_prep() -> bool:
	return false


func execute(sim: MatchSim, player: PlayerState) -> String:
	if sim.config.active_battle == null or sim.phase != MatchSim.Phase.WAVE:
		return "Подкрепление доступно только в бою"
	return sim.battle_reserves.release(sim, player.index)


func to_log(_sim: MatchSim, _player: PlayerState) -> Dictionary:
	return {"type": "release_reserve"}

class_name UpgradeShopCommand
extends SimCommand
## Повысить уровень магазина (заодно удлиняет путь и открывает клетки).


func execute(_sim: MatchSim, player: PlayerState) -> String:
	return player.upgrade_shop()


func to_log(_sim: MatchSim, _player: PlayerState) -> Dictionary:
	return {"type": "upgrade_shop"}

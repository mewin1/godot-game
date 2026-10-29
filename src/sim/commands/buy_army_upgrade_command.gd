class_name BuyArmyUpgradeCommand
extends SimCommand
## Купить улучшение армии (вкладка «Армия»): навсегда сильнее армия и +доход.

var upgrade_index: int


func _init(index: int) -> void:
	upgrade_index = index


func execute(_sim: MatchSim, player: PlayerState) -> String:
	return player.buy_army_upgrade(upgrade_index)


func to_log(_sim: MatchSim, player: PlayerState) -> Dictionary:
	var upgrade: ArmyUpgradeData = player.army.get_upgrade(upgrade_index)
	return {"type": "army_upgrade", "upgrade": String(upgrade.id) if upgrade != null else "",
			"cost": player.army.get_upgrade_cost(upgrade_index) if upgrade != null else 0}

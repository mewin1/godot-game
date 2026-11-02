class_name BuyArmyUpgradeCommand
extends SimCommand
## Купить улучшение армии (вкладка «Армия»): навсегда сильнее армия и +доход.
## element — стихия резиста для «Духа» (пусто — первая активная).

var upgrade_index: int
var element: StringName = &""


func _init(index: int, chosen_element: StringName = &"") -> void:
	upgrade_index = index
	element = chosen_element


func execute(_sim: MatchSim, player: PlayerState) -> String:
	return player.buy_army_upgrade(upgrade_index, element)


func to_log(_sim: MatchSim, player: PlayerState) -> Dictionary:
	var upgrade: ArmyUpgradeData = player.army.get_upgrade(upgrade_index)
	return {"type": "army_upgrade", "upgrade": String(upgrade.id) if upgrade != null else "",
			"cost": player.army.get_upgrade_cost(upgrade_index) if upgrade != null else 0}

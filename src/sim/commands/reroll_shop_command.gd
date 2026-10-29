class_name RerollShopCommand
extends SimCommand
## Обновить витрину за золото.


func execute(_sim: MatchSim, player: PlayerState) -> String:
	return player.reroll_shop()

class_name FreezeShopEffect
extends HeroEffect
## «Премудрость» Василисы: витрина не обновится в следующем раунде (пустые места докупятся).


func activate(_sim: MatchSim, player: PlayerState) -> String:
	if player.shop.is_frozen:
		return "Витрина уже заморожена"
	player.shop.is_frozen = true
	player.field.play_effect(&"hero_skill")
	player.hero_message = "Премудрость: витрина сохранится до следующего раунда"
	return ""


## Боту — когда на витрине осталось что-то, а золота на покупку уже нет.
func bot_wants_to_use(sim: MatchSim, player: PlayerState) -> bool:
	if player.gold - player.get_skill_cost() >= sim.config.tower_cost:
		return false
	for data: TowerData in player.shop.offers:
		if data != null:
			return true
	return false

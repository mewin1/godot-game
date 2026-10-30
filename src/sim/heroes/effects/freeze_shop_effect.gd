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


## Бот не умеет планировать витрину на два раунда: с заморозкой он играл хуже (6% побед против
## 15–20% без неё), поэтому навык не жмёт. Это навык для человека.
func bot_wants_to_use(_sim: MatchSim, _player: PlayerState) -> bool:
	return false

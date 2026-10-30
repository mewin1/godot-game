class_name ChooseHeroCommand
extends SimCommand
## Выбрать героя из трёх предложенных (только перед первым раундом).

var offer_index: int


func _init(index: int) -> void:
	offer_index = index


func requires_prep() -> bool:
	return false


func execute(sim: MatchSim, player: PlayerState) -> String:
	return sim.choose_hero(player.index, offer_index)


func to_log(_sim: MatchSim, player: PlayerState) -> Dictionary:
	var offers: Array[HeroData] = player.hero_offers
	var valid: bool = offer_index >= 0 and offer_index < offers.size()
	return {"type": "choose_hero", "hero": String(offers[offer_index].id) if valid else ""}

class_name DamageFieldEffect
extends HeroEffect
## «Палица» Ильи Муромца: все мобы на своём поле теряют percent% текущего HP.

@export var percent: int = 40
## Бот жмёт, когда на поле столько живых мобов или больше.
@export var bot_min_mobs: int = 6


func activate(_sim: MatchSim, player: PlayerState) -> String:
	if player.field.count_alive_mobs() == 0:
		return "На поле нет мобов"
	player.field.damage_all_by_percent(percent)
	player.hero_message = "Палица! Все мобы потеряли %d%% HP" % percent
	return ""


func bot_wants_to_use(_sim: MatchSim, player: PlayerState) -> bool:
	return player.field.count_alive_mobs() >= bot_min_mobs

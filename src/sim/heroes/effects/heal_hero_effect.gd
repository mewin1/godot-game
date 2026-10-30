class_name HealHeroEffect
extends HeroEffect
## «Пирожки» Бабушки: +amount HP терему, но не выше стартового.

@export var amount: int = 3


func activate(_sim: MatchSim, player: PlayerState) -> String:
	if player.hero_hp >= player.hero_max_hp:
		return "Терем и так цел"
	var healed: int = mini(amount, player.hero_max_hp - player.hero_hp)
	player.hero_hp += healed
	player.field.play_effect(&"hero_heal")
	player.hero_message = "Пирожки! Терем +%d HP" % healed
	return ""


func bot_wants_to_use(_sim: MatchSim, player: PlayerState) -> bool:
	return player.hero_hp <= player.hero_max_hp - amount

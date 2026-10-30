class_name SummonArmyEffect
extends HeroEffect
## «Ватага» Соловья: в эту волну с армией идут count мобов вида mob (только на один раунд).

@export var mob: MobData
@export var count: int = 3


func activate(_sim: MatchSim, player: PlayerState) -> String:
	for i: int in count:
		player.army.temporary_mobs.append(mob)
	player.field.play_effect(&"hero_skill")
	player.hero_message = "Ватага: +%d «%s» в армию на эту волну" % [count, mob.display_name]
	return ""


func affects_opponents() -> bool:
	return true

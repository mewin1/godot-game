class_name SummonArmyEffect
extends HeroEffect
## «Ватага» Соловья: в эту волну с армией идут count мобов вида mob (только на один раунд).

@export var mob: MobData
@export var count: int = 3


func activate(_sim: MatchSim, player: PlayerState) -> String:
	for i: int in count:
		player.army.temporary_mobs.append(mob)
	player.hero_message = "Ватага: +%d «%s» в армию на эту волну" % [count, mob.display_name]
	return ""

class_name SummonArmyEffect
extends HeroEffect
## «Ватага» Соловья: в эту волну с армией идут count мобов вида mob (только на один раунд).

@export var mob: MobData
@export var count: int = 3


func check_activation(sim: MatchSim, _player: PlayerState) -> String:
	if sim.round_number < sim.config.army_first_round:
		return "Армия выходит с раунда %d" % sim.config.army_first_round
	return ""


func activate(_sim: MatchSim, player: PlayerState) -> String:
	for i: int in count:
		player.army.temporary_mobs.append(mob)
	player.field.play_effect(&"hero_skill")
	player.hero_message = "Ватага: +%d «%s» в армию на эту волну" % [count, mob.display_name]
	return ""


func affects_opponents() -> bool:
	return true

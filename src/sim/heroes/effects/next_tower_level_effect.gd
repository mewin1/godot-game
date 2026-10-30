class_name NextTowerLevelEffect
extends HeroEffect
## «Варево» Бабы-Яги: следующая купленная башня приходит на levels уровней выше.

@export var levels: int = 1


func activate(_sim: MatchSim, player: PlayerState) -> String:
	if player.next_tower_bonus_levels > 0:
		return "Варево уже готово — купите башню"
	player.next_tower_bonus_levels = levels
	player.hero_message = "Варево готово: следующая башня сразу %d-го уровня" % (1 + levels)
	return ""


## Боту выгодно, когда золота хватит и на варево, и на башню.
func bot_wants_to_use(sim: MatchSim, player: PlayerState) -> bool:
	var skill_cost: int = player.get_skill_cost()
	return player.gold >= skill_cost + sim.config.tower_cost

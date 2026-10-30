class_name UseHeroSkillCommand
extends SimCommand
## Нажать навык героя. Когда можно — решает сам навык (подготовка, волна или всегда).


func requires_prep() -> bool:
	return false


func execute(sim: MatchSim, player: PlayerState) -> String:
	return player.use_hero_skill(sim)


func to_log(_sim: MatchSim, player: PlayerState) -> Dictionary:
	var skill_name: String = ""
	if player.hero != null and player.hero.skill != null:
		skill_name = String(player.hero.id)
	return {"type": "hero_skill", "hero": skill_name, "cost": player.get_skill_cost()}

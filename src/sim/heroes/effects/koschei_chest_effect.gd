class_name KoscheiChestEffect
extends HeroEffect
## «Смерть в игле» Кощея: когда HP впервые падает ниже threshold_percent% стартового,
## самая дорогая башня рушится (без возврата), а все остальные получают +1 уровень.


@export var threshold_percent: int = 50


func on_hp_lost(sim: MatchSim, player: PlayerState) -> void:
	if player.is_hero_triggered or player.hero_hp <= 0:
		return
	if player.hero_hp * 100 >= player.hero_max_hp * threshold_percent:
		return
	player.is_hero_triggered = true
	var victim: TowerState = _most_expensive(player.field.towers)
	if victim != null:
		player.field.remove_tower(victim)
	for tower: TowerState in player.field.towers:
		tower.level = mini(tower.level + 1, sim.config.max_tower_level)
	player.field.mark_towers_changed()
	player.field.play_effect(&"chest")
	player.hero_message = "Кощей разбил сундук: башни +1 уровень!"
	sim.hero_event.emit(player.index, player.hero_message)


## Больше всего вложенного золота; при равенстве — раньше поставленная (меньший id).
func _most_expensive(towers: Array[TowerState]) -> TowerState:
	var best: TowerState = null
	for tower: TowerState in towers:
		if best == null or tower.invested_total > best.invested_total:
			best = tower
	return best

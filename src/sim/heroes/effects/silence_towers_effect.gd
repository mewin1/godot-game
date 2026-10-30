class_name SilenceTowersEffect
extends HeroEffect
## «Три головы» Змея Горыныча: башни на всех полях, куда идёт армия героя, молчат ticks тиков.

@export var ticks: int = 80
## Бот жмёт, когда на чужих полях живо столько его юнитов или больше.
@export var bot_min_units: int = 3


func activate(sim: MatchSim, player: PlayerState) -> String:
	var fields: Array[FieldState] = sim.get_army_target_fields(player.index)
	if fields.is_empty():
		return "Армия сегодня никуда не идёт"
	for field: FieldState in fields:
		field.silence_towers(ticks)
	player.hero_message = "Три головы! Башни соперника опалены"
	return ""


func bot_wants_to_use(sim: MatchSim, player: PlayerState) -> bool:
	var units: int = 0
	for field: FieldState in sim.get_army_target_fields(player.index):
		units += field.count_alive_mobs_of(player.index)
	return units >= bot_min_units


func affects_opponents() -> bool:
	return true

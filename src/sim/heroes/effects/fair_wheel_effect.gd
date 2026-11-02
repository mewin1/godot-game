class_name FairWheelEffect
extends HeroEffect
## «Ярмарка» Скомороха: колесо со случайным исходом (ГСЧ игрока — детерминированно).
## Исходы по порядку: золото, юнит армии навсегда, доход навсегда, утешительное золото.
## Каждый исход в плюс: худший всё равно дороже цены навыка.

## Веса исходов (в сумме — сколько угодно, обычно 100).
@export var weights: Array[int] = [40, 25, 20, 15]
## Исход 0 — сразу золото; исход 2 — постоянный доход; исход 3 — утешительное золото.
@export var gold: int = 8
@export var income: int = 1
@export var units: int = 1
@export var consolation_gold: int = 4
## Бот не тратит последнее золото на азарт: жмёт, только когда есть этот запас сверх цены.
@export var min_gold_for_bot: int = 15


func activate(_sim: MatchSim, player: PlayerState) -> String:
	var total: int = 0
	for weight: int in weights:
		total += weight
	var roll: int = player.rng.randi_range(1, total)
	var outcome: int = 0
	while roll > weights[outcome]:
		roll -= weights[outcome]
		outcome += 1
	player.field.play_effect(&"hero_skill")
	match outcome:
		0:
			player.gold += gold
			player.hero_message = "Ярмарка: +%d золота!" % gold
		1:
			player.army.extra_units += units
			player.hero_message = "Ярмарка: +%d юнит армии навсегда!" % units
		2:
			player.income += income
			player.hero_message = "Ярмарка: +%d к доходу навсегда!" % income
		_:
			player.gold += consolation_gold
			player.hero_message = "Ярмарка: скромно, но +%d золота" % consolation_gold
	return ""


## Не тратит последнее золото на лотерею — азарт только после запаса.
func bot_wants_to_use(_sim: MatchSim, player: PlayerState) -> bool:
	return player.gold >= player.get_skill_cost() + min_gold_for_bot

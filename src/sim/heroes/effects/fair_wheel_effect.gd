class_name FairWheelEffect
extends HeroEffect
## «Ярмарка» Скомороха: колесо со случайным исходом (ГСЧ игрока — детерминированно).
## Исходы по порядку: золото, юнит армии навсегда, доход навсегда, ничего.

## Веса исходов (в сумме — сколько угодно, обычно 100).
@export var weights: Array[int] = [30, 25, 20, 25]
@export var gold: int = 9
@export var income: int = 1


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
			player.army.extra_units += 1
			player.hero_message = "Ярмарка: +1 юнит армии навсегда!"
		2:
			player.income += income
			player.hero_message = "Ярмарка: +%d к доходу навсегда!" % income
		_:
			player.gold += 2
			player.hero_message = "Ярмарка: освистали… утешительные +2 золота"
	return ""

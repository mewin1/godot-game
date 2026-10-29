class_name GameConfig
extends Resource
## Все правила и числа матча (заглушки из docs/02_economy.md) и ссылки на контент.
## Значения правятся в data/game_config.tres, а не в коде.

@export_group("Контент")
@export var board: BoardLayout
@export var towers: Array[TowerData] = []
@export var send_buffs: Array[SendBuffData] = []
## Моб базовой волны и обычный юнит отправки.
@export var wave_mob: MobData
@export var send_mob: MobData

@export_group("Время (в тиках)")
@export var ticks_per_second: int = 20
@export var prep_ticks: int = 500
@export var wave_max_ticks: int = 1200

@export_group("Герой")
@export var hero_hp: int = 40

@export_group("Экономика")
@export var start_gold: int = 20
@export var base_income: int = 10
@export var tower_cost: int = 6
@export var reroll_cost: int = 2
## Продажа не в ту фазу, где куплено: вложенное / sell_divisor (округление вниз).
@export var sell_divisor: int = 3

@export_group("Магазин")
@export var shop_base_offers: int = 3
@export var max_shop_level: int = 4
## Полная цена повышения 1→2, 2→3, 3→4.
@export var shop_upgrade_costs: Array[int] = [6, 10, 14]
@export var shop_upgrade_min_cost: int = 2
## Шанс (в процентах) редкого бафа в каждом слоте на уровне магазина 1, 2, 3, 4.
@export var rare_buff_chance_by_level: Array[int] = [0, 15, 35, 50]
@export var buff_offer_count: int = 3

@export_group("Башни")
@export var max_tower_level: int = 3
## Урон башни уровня 1, 2, 3 в процентах от базового.
@export var level_damage_percent: Array[int] = [100, 220, 480]
## На каком расстоянии (в клетках, по горизонтали/вертикали/диагонали) от открытого пути можно строить.
@export var build_radius: int = 2

@export_group("Отправка")
@export var send_base_cost: int = 5
@export var send_cost_per_round: int = 2
@export var send_min_cost: int = 1
@export var send_income_bonus: int = 1
@export var send_pack_size: int = 3
## Награда защитнику за всю пачку — такой процент от цены отправки.
@export var send_reward_percent: int = 25
@export var send_spawn_delay_ticks: int = 40
@export var send_spawn_interval_ticks: int = 16

@export_group("Базовая волна")
@export var wave_base_count: int = 5
@export var wave_count_per_round: int = 1
## HP мобов растёт каждый раунд на столько процентов от прошлого раунда (сложный процент).
## Юниты отправки растут так же, иначе поздние отправки бесполезны.
@export var wave_hp_growth_percent: int = 25
@export var wave_spawn_interval_ticks: int = 20

@export_group("Осада лидера")
## Осада в раундах, кратных этому числу (5, 10, 15…), если живых не меньше siege_min_players.
@export var siege_every_rounds: int = 5
@export var siege_min_players: int = 3
## Атакующему — столько золота за каждое HP, снятое лидеру его мобами.
@export var siege_gold_per_hp: int = 2
## Лидер пропустил столько HP или больше — бонус каждому атакующему, иначе — бонус лидеру.
@export var siege_breach_threshold: int = 5
@export var siege_attacker_bonus: int = 10
@export var siege_leader_bonus: int = 15

@export_group("Прорыв")
## С какого раунда какой множитель урона прорыва (по возрастанию раундов).
@export var breach_multiplier_start_rounds: Array[int] = [10, 15]
@export var breach_multipliers: Array[int] = [2, 3]


## Цена скилла отправки в раунде без бафов.
func get_send_cost(round_number: int) -> int:
	return send_base_cost + send_cost_per_round * (round_number - 1)


## Множитель урона прорыва в раунде.
func get_breach_multiplier(round_number: int) -> int:
	var multiplier: int = 1
	for i: int in breach_multiplier_start_rounds.size():
		if round_number >= breach_multiplier_start_rounds[i]:
			multiplier = breach_multipliers[i]
	return multiplier


## Полная цена повышения магазина с уровня level на следующий (0 — уже максимум).
func get_shop_upgrade_cost(level: int) -> int:
	if level < 1 or level > shop_upgrade_costs.size():
		return 0
	return shop_upgrade_costs[level - 1]


## Во сколько процентов от базового HP мобы в раунде (раунд 1 — 100).
func get_round_hp_percent(round_number: int) -> int:
	var percent: int = 100
	for i: int in round_number - 1:
		percent = percent * (100 + wave_hp_growth_percent) / 100
	return percent


func get_level_damage(base_damage: int, tower_level: int) -> int:
	var index: int = clampi(tower_level, 1, level_damage_percent.size()) - 1
	return base_damage * level_damage_percent[index] / 100

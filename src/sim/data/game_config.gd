class_name GameConfig
extends Resource
## Все правила и числа матча (заглушки из docs/02_economy.md) и ссылки на контент.
## Значения правятся в data/game_config.tres, а не в коде.

@export_group("Контент")
@export var board: BoardLayout
@export var towers: Array[TowerData] = []
@export var send_buffs: Array[SendBuffData] = []
## Моб базовой волны и обычный юнит армии.
@export var wave_mob: MobData
@export var army_mob: MobData
## Улучшения армии (вкладка «Армия»), по порядку показа.
@export var army_upgrades: Array[ArmyUpgradeData] = []

@export_group("Время (в тиках)")
@export var ticks_per_second: int = 20
@export var prep_ticks: int = 800
## После стольких тиков волны мобы впадают в ярость (бегут быстрее)...
@export var wave_max_ticks: int = 1200
## ...и ещё через столько тиков все оставшиеся засчитываются прорвавшимися (волна обязана кончиться).
@export var wave_enrage_extra_ticks: int = 600
## Ярость: на сколько процентов быстрее бегут мобы (замедление льда на них тоже действует).
@export var wave_enrage_speed_percent: int = 200

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
@export var shop_upgrade_costs: Array[int] = [10, 18, 28]
@export var shop_upgrade_min_cost: int = 5
## Шанс (в процентах) редкого бафа в каждом слоте на уровне магазина 1, 2, 3, 4.
@export var rare_buff_chance_by_level: Array[int] = [0, 15, 35, 50]
@export var buff_offer_count: int = 3

@export_group("Башни")
@export var max_tower_level: int = 3
## Урон башни уровня 1, 2, 3 в процентах от базового.
@export var level_damage_percent: Array[int] = [100, 200, 400]
## На каком расстоянии (в клетках, по горизонтали/вертикали/диагонали) от открытого пути можно строить.
@export var build_radius: int = 2

@export_group("Армия")
## Сколько обычных юнитов в армии без улучшений.
@export var army_base_units: int = 3
## Цена улучшения армии не опускается ниже этого (скидки от бафов).
@export var army_upgrade_min_cost: int = 1
## Каждая покупка улучшения армии навсегда добавляет к доходу такой процент от его базовой цены
## (20% — первая покупка окупается за ~5 раундов, повторные — дольше).
@export var army_income_percent: int = 20
## Хозяин армии получает столько золота за каждое HP, снятое его армией с героя соперника.
## Личная награда за атаку: в бою «все против всех» без неё атаковать невыгодно.
@export var army_gold_per_hp: int = 2
## HP юнитов армии растёт сам по себе на столько процентов за раунд (сложный процент).
## Небольшой: сила армии должна в основном зависеть от вложенного золота.
@export var army_hp_growth_percent: int = 10
## Армия появляется на поле соперника через столько тиков после начала волны, с таким интервалом.
@export var army_spawn_delay_ticks: int = 40
@export var army_spawn_interval_ticks: int = 16

@export_group("Базовая волна")
@export var wave_base_count: int = 4
@export var wave_count_per_round: int = 1
## HP мобов базовой волны растёт каждый раунд на столько процентов (сложный процент).
## Это давление, которое в итоге заканчивает матч.
@export var wave_hp_growth_percent: int = 12
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
## Сколько процентов урона прорыва получает лидер от армий атакующих. Армий две, поэтому 50% —
## вместе как одна армия в дуэли: осада выравнивает шансы, а не добивает лидера.
@export var siege_leader_damage_percent: int = 50

@export_group("Прорыв")
## С какого раунда какой множитель урона прорыва (по возрастанию раундов).
@export var breach_multiplier_start_rounds: Array[int] = [10, 15]
@export var breach_multipliers: Array[int] = [2, 3]


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


## Во сколько процентов от базового HP мобы в раунде (раунд 1 — 100) при росте growth_percent.
func get_round_hp_percent(round_number: int, growth_percent: int) -> int:
	var percent: int = 100
	for i: int in round_number - 1:
		percent = percent * (100 + growth_percent) / 100
	return percent


func get_level_damage(base_damage: int, tower_level: int) -> int:
	var index: int = clampi(tower_level, 1, level_damage_percent.size()) - 1
	return base_damage * level_damage_percent[index] / 100

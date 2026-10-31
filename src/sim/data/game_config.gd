class_name GameConfig
extends Resource
## Все правила и числа матча (заглушки из docs/02_economy.md) и ссылки на контент.
## Значения правятся в data/game_config.tres, а не в коде.

@export_group("Контент")
@export var gods: Array[StringName] = []
@export var draft_count: int = 0
@export var lessons: Array[ReactionLessonData] = []
@export var training_mob: MobData
@export var board: BoardLayout
@export var reactions: Array[ReactionData] = []
@export var towers: Array[TowerData] = []
@export var rites: Array[RiteData] = []
@export var rite_offer_percent: int = 30
@export var reserve_capacity_by_level: Array[int] = [8, 10, 12, 14]
@export var idol_slots: int = 3
@export var spawn_window_ticks: int = 0
@export var early_prep_rounds: int = 2
@export var early_prep_ticks: int = 600
@export var army_warmup_percent: Array[int] = []
@export var synchronized_battle: bool = false
@export var battle_real_ticks: int = 800
@export var battle_speed_thresholds: Array[int] = [400, 600]
@export var battle_speeds: Array[int] = [1, 2, 5]
## -1 оставляет старые заряды в исторических тестах; активная сборка использует шанс.
@export var chain_chance_percent: int = -1
## Для старых фикстур без реакций; активный бонус мокроты задаёт ReactionData.
@export var wet_chain_chance_percent: int = 80
@export var curse_spread_radius_milli: int = 1500
@export var chain_hits: int = 3
@export var chain_percent: int = 40
@export var chain_range_milli: int = 2000
@export var chain_lifetime_ticks: int = 60
@export var max_wind_slow_percent: int = 55
@export var wind_fire_bonus_percent: int = 25
@export var enchant_damage_percent: int = 20
@export var enchant_rate_percent: int = 15
@export var enchant_range_milli: int = 500
@export var awakening_power_percent: int = 30
@export var awakening_extra_targets: int = 1
@export var send_buffs: Array[SendBuffData] = []
## Моб базовой волны и обычный юнит армии.
@export var wave_mob: MobData
@export var army_mob: MobData
## Бонусы школ (2/4/6 построек одной школы на поле).
@export var school_bonuses: Array[SchoolBonusData] = []
## Особые мобы базовой волны: с какого раунда и сколько.
@export var wave_specials: Array[WaveSpecialData] = []
## Улучшения армии (вкладка «Армия»), по порядку показа.
@export var army_upgrades: Array[ArmyUpgradeData] = []
## Все герои: перед матчем каждому выпадает hero_offer_count разных на выбор.
@export var heroes: Array[HeroData] = []

@export_group("Время (в тиках)")
@export var ticks_per_second: int = 20
## Для живого тестирования: подготовка заканчивается только готовностью людей.
@export var prep_requires_ready: bool = false
@export var prep_ticks: int = 800
## После стольких тиков волны мобы впадают в ярость (бегут быстрее)...
@export var wave_max_ticks: int = 1200
## ...и ещё через столько тиков все оставшиеся засчитываются прорвавшимися (волна обязана кончиться).
@export var wave_enrage_extra_ticks: int = 600
## Ярость: на сколько процентов быстрее бегут мобы (замедление льда на них тоже действует).
@export var wave_enrage_speed_percent: int = 200

@export_group("Герой")
## HP терема без героя (у героев — своё, в HeroData).
@export var hero_hp: int = 40
@export var hero_offer_count: int = 3
## Сколько тиков на выбор героя (потом берётся первый предложенный).
@export var hero_select_ticks: int = 600

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
## Ниже этой цены не опускает повышение магазина скидка героя (Космонавт).
@export var shop_upgrade_discounted_min_cost: int = 3
## Шанс (в процентах) редкого бафа в каждом слоте на уровне магазина 1, 2, 3, 4.
@export var rare_buff_chance_by_level: Array[int] = [0, 15, 35, 50]
@export var buff_offer_count: int = 3

@export_group("Башни")
## Реактивный финишер сначала спасает последнюю клетку от прорыва.
@export var reaction_target_emergency_milli: int = 1000
@export var max_tower_level: int = 3
## «Тройка → открытие»: постройка дошла до максимального уровня — выбор 1 из стольких в подарок.
@export var discover_offer_count: int = 3
## Тир подарка = уровень магазина + это число (1 — «следующий тир», 0 — тот же).
@export var discover_tier_offset: int = 1
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
## С какого раунда армии идут к соперникам (1 — сразу; 2 — первый раунд только базовая волна,
## мягче для новичка).
@export var army_first_round: int = 1
## «Злость армии»: армия, не снявшая за раунд ни одного HP, в следующий раунд крепче на столько
## процентов HP (копится); после первого прорыва сбрасывается. 0 — выключено.
@export var army_rage_percent: int = 0
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
## Общий предел урона поля за раунд; пустой список — без предела (прежние правила).
@export var breach_limits: Array[int] = []
@export var breach_limit_rounds_per_step: int = 4


## Множитель урона прорыва в раунде.
func get_breach_multiplier(round_number: int) -> int:
	var multiplier: int = 1
	for i: int in breach_multiplier_start_rounds.size():
		if round_number >= breach_multiplier_start_rounds[i]:
			multiplier = breach_multipliers[i]
	return multiplier


## 0 означает отсутствие предела. Общий для базовой волны и всех атакующих осады.
func get_breach_limit(round_number: int) -> int:
	if breach_limits.is_empty():
		return 0
	var index: int = maxi(0, round_number - 1) / maxi(1, breach_limit_rounds_per_step)
	return breach_limits[mini(index, breach_limits.size() - 1)]


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


## Общий профиль перемотки для матча и безопасной пробы защиты.
func get_battle_speed_at(real_tick: int) -> int:
	if not synchronized_battle:
		return 1
	var speed_index: int = 0
	for threshold: int in battle_speed_thresholds:
		if real_tick > threshold:
			speed_index += 1
	return battle_speeds[speed_index]

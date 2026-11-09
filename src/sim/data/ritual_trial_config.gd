class_name RitualTrialConfig
extends Resource
## Отдельные параметры полигона. Общие ресурсы матча используются только для чтения.

@export var combat: GameConfig
@export var costs: Array[int] = []
@export var rites: Array[RiteData] = []
@export var enemies: Array[MobData] = []
@export var spawns: Array[RitualSpawn] = []
@export var loadouts: Array[RitualLoadout] = []
@export var build_regions: Array[Rect2i] = []
@export var hero_hp: int = 50
@export var start_gold: int = 92
## 0 — число башен не ограничено (редакция 3, docs/30 §15).
@export var tower_limit: int = 0
## Повторный заговор идола дороже на шаг за каждую прежнюю покупку.
@export var rite_cost_step: int = 3
## Чары на одну башню и их цены в этом опыте.
@export var enchants: Array[RiteData] = []
@export var enchant_costs: Array[int] = []
## Лавка с азартом (docs/34 §13): 0 — все постройки сразу (прежний опыт), иначе столько
## случайных карточек с весами лавки PvP (TowerData.shop_weight).
@export var market_offers: int = 0
## Первые столько мест — только стреляющие постройки (как первые места лавки PvP).
@export var market_shooter_slots: int = 2
## Обновление прилавка: цена + шаг за каждое обновление в эти сутки; на рассвете — сброс
## и новый прилавок бесплатно.
@export var reroll_cost: int = 2
@export var reroll_cost_step: int = 1
@export var repair_hp: int = 5
@export var repair_cost: int = 10
## Здоровье тела врагов по суткам, в процентах.
@export var cycle_hp_percent: Array[int] = [100, 100, 100, 100]
@export var cycle_ticks: int = 1800
@export var dusk_tick: int = 600
@export var night_tick: int = 700
@export var cycles: int = 4
@export var end_tick: int = 8400
@export var aura_percent: int = 125
@export var install_ticks: int = 60
@export var sell_percent: int = 50
@export var hero_warning: int = 20
@export var hero_cooldown: int = 900
@export var hero_radius: int = 2200
@export var hero_percent: int = 45
@export var hero_cap: int = 500
@export var ward_hp: int = 120
@export var ward_fire_percent: int = 200
@export var ward_physical_percent: int = 25
@export var ward_break_stun: int = 20
@export var banner_radius: int = 4000
@export var banner_damage_percent: int = 70
@export var boss_start: int = 12000
@export var boss_end: int = 32000
@export var boss_warning: int = 40
@export var boss_speed: int = 250
@export var boss_vulnerability_ticks: int = 80
@export var boss_damage_percent: int = 125
@export var boss_immunity_ticks: int = 160
@export var palisade_install: int = 40
@export var palisade_stun: int = 60
@export var ward_tag: StringName = &"ward"
@export var banner_tag: StringName = &"banner"
@export var boss_tag: StringName = &"boss"
@export var heavy_tag: StringName = &"heavy"
## Бесконечный забег (docs/34). Пусто — прежний опыт из четырёх суток по spawns.
@export var nights: RitualNightRules


func is_endless() -> bool:
	return nights != null


func is_night(at_tick: int) -> bool:
	if is_endless():
		return nights.is_night(at_tick)
	return at_tick < cycle_ticks * cycles and at_tick % cycle_ticks >= night_tick


func period_name(at_tick: int) -> String:
	if is_endless():
		return nights.period_name(at_tick)
	if at_tick >= cycle_ticks * cycles:
		return "Рассвет · зачистка"
	var local: int = at_tick % cycle_ticks
	if local >= night_tick:
		return "Ночь"
	if local >= dusk_tick:
		return "Закат"
	return "День"


## Время для света: [тик внутри суток, начало заката, начало ночи, номер суток с 0].
func cycle_view(at_tick: int) -> Array[int]:
	if is_endless():
		return nights.cycle_view(at_tick)
	return [at_tick % cycle_ticks, dusk_tick, night_tick, at_tick / cycle_ticks]


## Закончились ли сутки опыта (у бесконечного забега — никогда).
func is_finished(at_tick: int) -> bool:
	return not is_endless() and at_tick >= cycle_ticks * cycles

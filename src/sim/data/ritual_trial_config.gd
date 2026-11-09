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
## Пристраиваемые улицы по порядку покупки (docs/34 §3); пусто — город не растёт.
## Улица N даёт вход N + 1: главная дорога поля — вход 1.
@export var streets: Array[RitualStreetData] = []
@export var hero_hp: int = 50
@export var start_gold: int = 92
## 0 — число башен не ограничено (редакция 3, docs/30 §15).
@export var tower_limit: int = 0
## Повторный заговор идола дороже на шаг за каждую прежнюю покупку.
@export var rite_cost_step: int = 3
## false — заговоры без предела покупок (бесконечный забег); правила — rite_curves.
@export var rite_purchase_limit: bool = true
## Затухание/рост цены заговоров без предела (docs/34 §6).
@export var rite_curves: Array[RitualRiteCurve] = []
## Скидка своей стихии (docs/34 §7): от числа заговоров на идоле этой стихии, с затуханием,
## в базисных пунктах. 0 — скидки нет.
@export var discount_cap_bp: int = 0
@export var discount_step_bp: int = 1500
## Чары на одну башню и их цены в этом опыте.
@export var enchants: Array[RiteData] = []
@export var enchant_costs: Array[int] = []
## Лавка с азартом (docs/34 §13): 0 — все постройки сразу (прежний опыт), иначе столько
## случайных карточек с весами лавки PvP (TowerData.shop_weight).
@export var market_offers: int = 0
## Первые столько мест — только стреляющие постройки (как первые места лавки PvP).
@export var market_shooter_slots: int = 2
## Карточки-заговоры в конце прилавка (плейтест 9 ноября): заговор выпадает в лавке, а не висит
## отдельной сеткой. 0 — все заговоры сразу (прежний опыт).
@export var market_rite_slots: int = 0
## Лавка выбирает сначала стихию (все равновероятно), потом её постройку/заговор: иначе стихии
## с несколькими постройками выпадают чаще. false — веса shop_weight, как в PvP.
@export var market_by_element: bool = false
## Нежить ночи кончилась (все пачки вышли и убиты) — сразу рассвет, без пустого ожидания.
@export var early_dawn: bool = false
## Обновление прилавка: цена + шаг за каждое обновление в эти сутки; на рассвете — сброс
## и новый прилавок бесплатно.
@export var reroll_cost: int = 2
@export var reroll_cost_step: int = 1
## Материал = уровень слияния (docs/34 §2): дерево → камень → кирпич → белый камень.
@export var level_names: Array[String] = []
## Поведение построек по уровням; пусто — уровень меняет только урон (прежний опыт).
@export var building_levels: Array[RitualBuildingLevels] = []
## Износ домов от боя (docs/34 §5): прочность дома 1-го уровня в тиках боя; уровень ×2 (как копии).
## 0 — износа нет (прежний опыт).
@export var wear_ticks: int = 0
## Ниже половины прочности дом бьёт этой долей урона; на нуле молчит, но стоит.
@export var worn_damage_percent: int = 60
## Полный ремонт стоит такую долю цены постройки этого уровня (со скидкой стихии).
@export var repair_percent: int = 40
## Дары за боссов: из списка без повторов предлагается gift_choices штук.
@export var gifts: Array[RitualGiftData] = []
@export var gift_choices: int = 3
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
## Ночью (плейтест автора 9 ноября): стройка дороже, установка/слияние и перенос дольше.
## 100 / 0 — как днём (прежний опыт).
@export var night_cost_percent: int = 100
@export var night_install_ticks: int = 0
@export var night_move_ticks: int = 0
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


func levels_for(data: TowerData) -> RitualBuildingLevels:
	for levels: RitualBuildingLevels in building_levels:
		if levels.tower_id == data.id:
			return levels
	return null


func level_behavior(tower: TowerState) -> RitualLevelBehavior:
	var levels: RitualBuildingLevels = levels_for(tower.data)
	return levels.at_level(tower.level) if levels != null else null


func level_name(level: int) -> String:
	if level >= 1 and level <= level_names.size():
		return level_names[level - 1]
	return "ур. %d" % level


func rite_curve(rite_id: StringName) -> RitualRiteCurve:
	for curve: RitualRiteCurve in rite_curves:
		if curve.rite_id == rite_id:
			return curve
	return null


## Бонус заговоров идола с эффектом effect, которого нет в полях IdolState (дальность, темп).
func idol_curve_bonus(idol: IdolState, effect: RiteData.Effect) -> int:
	if idol == null:
		return 0
	var total: int = 0
	for rite: RiteData in rites:
		if rite.god != idol.god or rite.effect != effect:
			continue
		var curve: RitualRiteCurve = rite_curve(rite.id)
		var count: int = idol.purchases.get(rite.id, 0)
		if curve != null:
			total += curve.bonus(count)
	return total


func max_durability(level: int) -> int:
	return wear_ticks << maxi(0, level - 1)


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

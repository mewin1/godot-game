class_name ArmyUpgradeData
extends Resource
## Улучшение армии во вкладке «Армия»: покупается за золото, действует до конца матча,
## каждое навсегда добавляет доход (процент от цены — в конфиге). После покупки дорожает на cost_step.

@export var id: StringName = &""
@export var display_name: String = ""
## Что делает улучшение — те же виды, что у бафов армии.
@export var kind: SendBuffData.Kind = SendBuffData.Kind.EXTRA_UNITS
@export var value: int = 1
## Для ADD_MOB: какой юнит добавить в армию.
@export var mob: MobData
@export var base_cost: int = 6
@export var cost_step: int = 3
## Сколько раз можно купить (0 — без ограничения).
@export var max_purchases: int = 0
## С какого уровня магазина доступно.
@export var min_shop_level: int = 1

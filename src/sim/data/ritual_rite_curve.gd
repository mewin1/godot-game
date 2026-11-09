class_name RitualRiteCurve
extends Resource
## Заговор «Обряда» без предела покупок (docs/34 §6).
## cap > 0 — затухание: бонус(n) = предел × (1 − (1 − шаг)^n), каждый следующий слабее.
## cap = 0 — линейно: каждый заговор даёт RiteData.value (урон), цена растёт быстрее.

@export var rite_id: StringName = &""
## Предел бонуса в единицах эффекта (тысячные клетки, тики, проценты; цели — в тысячных).
@export var cap: int = 0
## Доля остатка до предела за один заговор, в базисных пунктах (2500 = 25%).
@export var step_bp: int = 2500
## Делитель единиц для поля идола: 1000 — цели копятся тысячными, в бою целые.
@export var unit: int = 1
## Цена n-го заговора: (база + cost_step × n) × (100 + cost_growth_percent)^n / 100^n.
@export var cost_step: int = 0
@export var cost_growth_percent: int = 0


## Целочисленное затухание: остаток до предела умножается на (1 − шаг) с округлением вверх,
## поэтому бонус растёт, но предела никогда не достигает.
static func decay(limit: int, step: int, count: int) -> int:
	var remaining: int = limit
	for index: int in maxi(0, count):
		remaining = (remaining * (10000 - step) + 9999) / 10000
	return limit - remaining


## Бонус после count покупок в единицах поля идола.
func bonus(count: int) -> int:
	return decay(cap, step_bp, count) / maxi(1, unit)


func cost(base: int, count: int) -> int:
	var value: int = base + cost_step * count
	for index: int in count:
		value = value * (100 + cost_growth_percent) / 100
	return value

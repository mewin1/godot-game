class_name SchoolBonusData
extends Resource
## Бонус школы: чем больше построек одной школы на поле, тем сильнее все они.
## Ступени по counts (например 2 / 4 / 6), сила каждой ступени — в values.

enum Kind {
	DAMAGE_PERCENT, ## постройки школы +value% урона
	FIRE_RATE_PERCENT, ## постройки школы стреляют на value% чаще
	RANGE_MILLI, ## постройки школы бьют на value тысячных клетки дальше
	INCOME, ## +value дохода в конце раунда
}

@export var school: StringName = &""
@export var display_name: String = ""
@export var kind: Kind = Kind.DAMAGE_PERCENT
## Сколько построек школы нужно для каждой ступени (по возрастанию).
@export var counts: Array[int] = [2, 4, 6]
@export var values: Array[int] = [15, 30, 50]


## Сила бонуса при count постройках школы (0 — ступень не набрана).
func get_value(count: int) -> int:
	var value: int = 0
	for i: int in counts.size():
		if count >= counts[i]:
			value = values[i]
	return value


## Сколько построек нужно до следующей ступени (0 — набрана последняя).
func get_next_count(count: int) -> int:
	for needed: int in counts:
		if count < needed:
			return needed
	return 0


func get_effect_text(value: int) -> String:
	match kind:
		Kind.DAMAGE_PERCENT:
			return "+%d%% урона" % value
		Kind.FIRE_RATE_PERCENT:
			return "+%d%% скорости" % value
		Kind.RANGE_MILLI:
			return "+%.1f радиуса" % (value / 1000.0)
	return "+%d дохода" % value

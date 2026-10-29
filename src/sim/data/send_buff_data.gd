class_name SendBuffData
extends Resource
## Баф отправки: постоянное усиление своих юнитов отправки. Выбирается 1 из 3 после каждой битвы.

enum Kind {
	HP_PERCENT, ## юниты +value% HP
	SPEED_PERCENT, ## юниты +value% скорости
	EXTRA_UNITS, ## +value обычных юнитов в пачке
	ADD_MOB, ## в пачку добавляется value юнитов вида mob
	COST_DISCOUNT, ## скилл отправки дешевле на value
	EXTRA_INCOME, ## каждое применение даёт +value к доходу сверх обычного
}

@export var id: StringName = &""
@export var display_name: String = ""
@export var is_rare: bool = false
@export var kind: Kind = Kind.HP_PERCENT
@export var value: int = 0
## Для ADD_MOB: какой юнит добавить.
@export var mob: MobData

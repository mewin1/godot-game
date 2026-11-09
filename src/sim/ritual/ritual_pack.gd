class_name RitualPack
extends RefCounted
## Одна пачка ночи: кто, когда и с какой силой. Создаёт только RitualNightPlan.

var night: int = 1
var at_tick: int = 0
var spacing: int = 1
## Индексы врагов (RitualTrialConfig.enemies) в порядке выхода на дорогу.
var members: Array[int] = []
## Самый сильный враг пачки — им пачка показана в очереди разведки.
var leader: int = -1
var boss: bool = false
## Стихийная неуязвимость (бог постройки), пусто — нет.
var resist: StringName = &""
var hp_percent: int = 100


## Номер врага пачки, выходящего ровно в этот тик, или -1.
func member_at(tick: int) -> int:
	var offset: int = tick - at_tick
	if offset < 0 or offset % spacing != 0:
		return -1
	var index: int = offset / spacing
	return members[index] if index < members.size() else -1


func last_tick() -> int:
	return at_tick + (members.size() - 1) * spacing


func count_of(enemy_index: int) -> int:
	return members.count(enemy_index)

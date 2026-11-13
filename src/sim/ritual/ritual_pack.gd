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
## Здоровье самого босса (у свиты — hp_percent).
var boss_hp_percent: int = 100
## Ранг элиты каждого врага (0 - обычный): здоровье и награда x elite_multiplier за ранг.
var elite: Array[int] = []
## Награда за каждого врага (золото): награда ночи, разделенная по обычной награде врагов.
var bounties: Array[int] = []
## Множитель элиты (из правил ночей).
var elite_multiplier: int = 3
## Сколько бюджета не поместилось в полную пачку (только для генератора).
var overflow: int = 0
## Место пачки в ночи и сдвиг входов этой ночи: пачки ночи по очереди раздаются по входам,
## начиная со случайного. Сам вход зависит от числа открытых входов — lane_for.
var slot: int = 0
var lane_shift: int = 0


## Вход пачки (0 — главная дорога), если к её ночи открыто entrances входов.
func lane_for(entrances: int) -> int:
	return (lane_shift + slot) % maxi(1, entrances)


## Здоровье врага на месте index в процентах от данных: босс растет своим темпом, элита - x множитель.
func hp_at(index: int, boss_enemy: int) -> int:
	if boss and members[index] == boss_enemy:
		return boss_hp_percent
	return hp_percent * elite_factor(index)


func elite_factor(index: int) -> int:
	var factor: int = 1
	for rank: int in elite[index]:
		factor *= elite_multiplier
	return factor


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

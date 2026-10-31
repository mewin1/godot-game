class_name FieldBattleReport
extends RefCounted
## Наблюдение за одной волной. Эти данные не меняют правила, RNG и хэш симуляции.

var killed: int = 0
var retreated: int = 0
var hp_lost: int = 0
var damage_by_tower: Dictionary[int, int] = {}
var marks_by_tower: Dictionary[int, int] = {}
var wind_ticks_by_tower: Dictionary[int, int] = {}
var tower_names: Dictionary[int, String] = {}
var damage_by_kind: Dictionary[StringName, int] = {}
var breach_counts: Dictionary[StringName, int] = {}
var breach_hp: Dictionary[StringName, int] = {}
var mob_names: Dictionary[StringName, String] = {}


## Снимок названий переживает продажу/слияние башни в следующую подготовку.
func register_tower(tower: TowerState) -> void:
	tower_names[tower.id] = "%s #%d (ур.%d)" % [tower.data.display_name, tower.id, tower.level]


## Только фактически снятые HP, после брони и щита, без избыточного урона.
func record_damage(tower_id: int, kind: StringName, actual: int) -> void:
	if actual <= 0:
		return
	damage_by_kind[kind] = damage_by_kind.get(kind, 0) + actual
	if tower_id > 0:
		damage_by_tower[tower_id] = damage_by_tower.get(tower_id, 0) + actual


## Наложение или обновление метки не является оценкой добавочного урона.
func record_mark(tower_id: int) -> void:
	marks_by_tower[tower_id] = marks_by_tower.get(tower_id, 0) + 1


## Контакт живой цели с потоком, в цель·тиках; не обещает замедления попутного ветра.
func record_wind(tower_id: int) -> void:
	wind_ticks_by_tower[tower_id] = wind_ticks_by_tower.get(tower_id, 0) + 1


## Каждый прорыв учитывается и после исчерпания предела HP.
func record_breach(mob: MobState) -> void:
	mob_names[mob.data.id] = mob.data.display_name
	breach_counts[mob.data.id] = breach_counts.get(mob.data.id, 0) + 1


## Матч передаёт результат после осады, предела и остатка HP героя.
func record_hp_loss(mob: MobState, actual: int) -> void:
	hp_lost += actual
	breach_hp[mob.data.id] = breach_hp.get(mob.data.id, 0) + actual


## Копия для логов, без ссылок на изменяемые боевые объекты.
func snapshot() -> Dictionary:
	return {"killed": killed, "retreated": retreated, "hp_lost": hp_lost,
			"damage_by_tower": damage_by_tower.duplicate(),
			"marks_by_tower": marks_by_tower.duplicate(),
			"wind_ticks_by_tower": wind_ticks_by_tower.duplicate(),
			"tower_names": tower_names.duplicate(), "damage_by_kind": damage_by_kind.duplicate(),
			"breach_counts": breach_counts.duplicate(), "breach_hp": breach_hp.duplicate(),
			"mob_names": mob_names.duplicate()}

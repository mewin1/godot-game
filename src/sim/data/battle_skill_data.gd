class_name BattleSkillData
extends Resource
## Один бесплатный приём героя; параметры активной сборки находятся в ресурсе.

enum Kind { WALK, SWAP, SUPPRESS, STRIKE, TRAP, RUSH, WARD, REVIVE, HEAL, DECOY, CHARGE }
@export var hero_id: StringName = &""
@export var title: String = ""
@export_multiline var description: String = ""
@export var kind: Kind = Kind.WALK
@export var offensive: bool = false
@export var warning_ticks: int = 0
@export var duration_ticks: int = 0
@export var radius_milli: int = 0
@export var power: int = 0
@export var cap: int = 0
@export var decoy: MobData


func requires_preparation() -> bool:
	return kind in [Kind.WALK, Kind.SWAP, Kind.CHARGE]

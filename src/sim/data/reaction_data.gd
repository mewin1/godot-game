class_name ReactionData
extends Resource
## Направленная реакция: тег удара и уже существующий статус.

@export var id: StringName = &""
@export var incoming: StringName = &""
@export var required: StringName = &""
@export var consume: Array[StringName] = []
@export var damage_percent: int = 100
@export var stun_ticks: int = 0
@export var suppress_status: bool = false

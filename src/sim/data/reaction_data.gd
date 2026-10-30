class_name ReactionData
extends Resource
## Направленная реакция: тег удара и уже существующий статус.

@export var display_name: String = ""
@export var explanation: String = ""
@export var id: StringName = &""
@export var incoming: StringName = &""
@export var required: StringName = &""
@export var consume: Array[StringName] = []
@export var damage_percent: int = 100
@export var stun_ticks: int = 0
@export var suppress_status: bool = false
@export var minimum_statuses: int = 0
@export var freeze_ticks: int = 0
@export var chain_chance_bonus: int = 0
@export var curse_damage_percent: int = 100
@export var curse_extra_ticks: int = 0
@export var makes_contagious: bool = false
@export var spread_radius_milli: int = 0
@export var spread_duration_ticks: int = 0
@export var push_milli: int = 0
@export var interval_ticks: int = 0
@export var spread_slow_percent: int = 0

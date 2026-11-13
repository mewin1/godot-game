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
## Доля накопленного урона поглощаемых статусов, превращаемая в урон финишера.
@export var stored_damage_percent: int = 0
@export var slow_percent: int = 0
@export var slow_ticks: int = 0
## docs/37 RX-2: перезарядка этой реакции на одном враге (тики); 0 — без перезарядки (как в PvP).
## Пока реакция перезаряжается, входящая стихия просто ставит свой статус.
@export var cooldown_ticks: int = 0
## docs/37 RX-9: поглощённые горение и проклятие отдают оставшийся урон сразу, а не пропадают.
@export var pay_out_consumed: bool = false

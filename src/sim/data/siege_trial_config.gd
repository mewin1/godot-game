class_name SiegeTrialConfig
extends Resource
## Отдельные параметры короткой дуэли; основной баланс не меняется.

@export var game: GameConfig
@export var towers: Array[TowerData] = []
@export var positions: Array[Vector2i] = []
@export var levels: Array[int] = []
@export var bot_defenses: Array[SiegeDefensePlan] = []
@export var main_mob: MobData
@export var reserves: Array[MobData] = []
@export var reserve_plans: Array[SiegeReservePlan] = []
@export var main_count: int = 8
@export var main_hp: int = 160
@export var reserve_hp: Array[int] = [180, 320]
@export var main_speed: int = 75
@export var reserve_speed: Array[int] = [100, 65]
@export var spawn_interval: int = 10
@export var reserve_deadline: int = 280
@export var max_ticks: int = 900
@export var hero_hp: int = 20
@export var shop_level: int = 3
@export var walk_ticks: int = 60
@export var swap_ticks: int = 40
@export var walk_destination: Vector2i = Vector2i(5, 7)
@export var fire_target: Vector2i = Vector2i(3, 4)
@export var fire_warning_ticks: int = 24
@export var fire_ticks: int = 100
@export var fire_radius_milli: int = 2400
@export var bot_release_ticks: Array[int] = [120, 180, 240]
@export var bot_walk_progress: int = 9000
@export var bot_fire_progress: int = 4000
@export var bot_reaction_ticks: int = 10
@export var bot_domovoy_chance: int = 25


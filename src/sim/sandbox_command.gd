class_name SandboxCommand
extends RefCounted
## Ввод отдельной песочницы. Команды не поступают в настоящий матч.

enum Action { TOWER, MOB, REMOVE, STRIKE, STEP, RESET, CLEAR }

var action: Action
var tower: TowerData
var mob: MobData
var cell: Vector2i
var progress: int = 0
var level: int = 1
var rotation: int = 0
var hp: int = 0
var stationary: bool = true
var tower_id: int = 0
var mob_id: int = 0
var ticks: int = 1
var automatic_fire: bool = true
var enchantment: int = -1
var awakening: int = -1


func _init(kind: Action) -> void:
	action = kind

class_name SiegeTrialCommand
extends RefCounted
## Ввод опытной дуэли. Индекс стороны проверяется в симуляции.

enum Action { START, RELEASE, SKILL, TARGET, RESERVE, HUT }
var action: Action
var side: int
var cell: Vector2i
var value: int


func _init(kind: Action, player: int = 0, at: Vector2i = Vector2i.ZERO,
		choice: int = 0) -> void:
	action = kind
	side = player
	cell = at
	value = choice


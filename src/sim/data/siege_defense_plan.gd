class_name SiegeDefensePlan
extends Resource
## Только расстановка: состав и уровни башен остаются общими для дуэли.

@export var display_name: String = ""
@export_multiline var description: String = ""
@export var positions: Array[Vector2i] = []

class_name ReactionLessonData
extends Resource
## Пошаговый пример настоящих попаданий. Только учебные данные, не новые правила боя.

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var explanation: String = ""
@export var sources: Array[TowerData] = []
@export var finisher: TowerData
@export var reaction_id: StringName = &""
@export var wait_ticks: int = 60
@export var seed_value: int = 1

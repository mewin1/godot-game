class_name RitualBuildingLevels
extends Resource
## Поведение одной постройки «Обряда» по уровням: levels[0] — 1-й уровень (дерево).

@export var tower_id: StringName = &""
@export var levels: Array[RitualLevelBehavior] = []


func at_level(level: int) -> RitualLevelBehavior:
	if levels.is_empty():
		return null
	return levels[clampi(level, 1, levels.size()) - 1]

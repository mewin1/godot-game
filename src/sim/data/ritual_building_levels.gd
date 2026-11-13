class_name RitualBuildingLevels
extends Resource
## Поведение одной постройки «Обряда» по уровням: levels[0] — 1-й уровень (дерево).

@export var tower_id: StringName = &""
@export var levels: Array[RitualLevelBehavior] = []
@export var role: String = ""
@export var branches: Array[RitualSpecialisation] = []


func at_level(level: int, branch: int = -1) -> RitualLevelBehavior:
	if level >= 3 and branch >= 0 and branch < branches.size():
		return branches[branch].at_level(level)
	if levels.is_empty():
		return null
	return levels[clampi(level, 1, levels.size()) - 1]

class_name RitualSpecialisation
extends Resource
## Ветка постройки: название и поведение на третьем и четвертом уровнях.

@export var title: String = ""
@export var levels: Array[RitualLevelBehavior] = []


func at_level(level: int) -> RitualLevelBehavior:
	return levels[clampi(level - 3, 0, levels.size() - 1)] if not levels.is_empty() else null

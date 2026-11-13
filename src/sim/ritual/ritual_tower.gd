class_name RitualTower
extends TowerState
## Состояние дома на участке. Старые башни и PvP этих полей не используют.

var branch: int = -1
## Каждое вложение отдельно: цена и тик, чтобы возврат улучшения не отменял цену старого дома.
var investments: Array[Vector2i] = []
var used: bool = false
var last_support_tick: int = -1

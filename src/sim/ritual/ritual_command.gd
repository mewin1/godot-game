class_name RitualCommand
extends RefCounted
## Все изменения игрока проходят через одну проверяемую команду.

## MERGE: tower_id — сливаемая копия, item — ID башни, которая растёт. ENCHANT: item — чара.
## BUY с tower_id — новая копия сразу сливается с этой башней 1-го уровня.
## REROLL — платно обновить прилавок лавки с азартом.
enum Action { START, BUY, MOVE, SELL, RITE, SKILL, PALISADE, CANCEL_MOVE, MERGE, ENCHANT, REPAIR, REROLL }
var action: Action
var item: int
var cell: Vector2i
var rotation: int
var tower_id: int
var progress: int


func _init(kind: Action, catalog_index: int = 0, at_cell: Vector2i = Vector2i.ZERO,
		turns: int = 0, selected_id: int = 0, path_progress: int = 0) -> void:
	action = kind
	item = catalog_index
	cell = at_cell
	rotation = turns
	tower_id = selected_id
	progress = path_progress


func record() -> Dictionary[String, Variant]:
	return {"action": int(action), "item": item, "cell": cell,
		"rotation": rotation, "tower_id": tower_id, "progress": progress}

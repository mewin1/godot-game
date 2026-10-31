class_name SandboxCatalog
extends VBoxContainer
## Возвращённая в каталог башня убирается с экспериментального поля.

signal tower_returned(tower_id: int)


func _can_drop_data(_at_position: Vector2, value: Variant) -> bool:
	if not (value is DragPayload):
		return false
	var payload: DragPayload = value
	return payload.kind == DragPayload.Kind.TOWER


func _drop_data(_at_position: Vector2, value: Variant) -> void:
	var payload: DragPayload = value
	tower_returned.emit(payload.tower_id)

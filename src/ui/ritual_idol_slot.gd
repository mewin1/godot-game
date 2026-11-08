class_name RitualIdolSlot
extends IdolSlot
## Тот же слот PvP. Заговор отправляется в существующую команду опыта.

signal rite_chosen(index: int)
var trial: RitualTrial

func _can_drop_data(_at_position: Vector2, value: Variant) -> bool:
	if not value is DragPayload or trial == null:
		return false
	var payload: DragPayload = value
	if payload.kind != DragPayload.Kind.RITE or payload.rite == null:
		return false
	var target: IdolState = trial.field.get_idol(payload.rite.god)
	if target == null:
		for candidate: IdolState in trial.field.idols:
			if candidate.god == &"":
				target = candidate
				break
	var allowed: bool = target == idol and trial.gold >= payload.rite.cost and not trial.rite_bought.has(payload.rite.id)
	payload.show_rite_feedback("" if allowed else "Выберите свободный идол этой силы")
	return allowed


func _drop_data(_at_position: Vector2, value: Variant) -> void:
	if value is DragPayload:
		var payload: DragPayload = value
		rite_chosen.emit(payload.offer_index)

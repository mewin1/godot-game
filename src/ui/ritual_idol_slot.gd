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
	var index: int = payload.offer_index
	var reason: String = ""
	if payload.rite.target != RiteData.Target.IDOL or index < 0 or index >= trial.settings.rites.size():
		reason = "Чару кладут на башню"
	elif target != idol:
		reason = "Выберите свободный идол этой силы"
	elif trial.rite_count(index) >= trial.settings.rites[index].max_purchases:
		reason = "Заговор уже усилен до предела"
	elif trial.gold < trial.rite_cost(index):
		reason = "Не хватает золота"
	var allowed: bool = reason.is_empty()
	payload.show_rite_feedback(reason)
	return allowed


func _drop_data(_at_position: Vector2, value: Variant) -> void:
	if value is DragPayload:
		var payload: DragPayload = value
		rite_chosen.emit(payload.offer_index)

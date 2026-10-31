class_name ReactionInspector
extends RefCounted
## Объясняет текущее состояние выбранной пары через настоящие запросы симуляции.


## Предварительный результат ручного попадания, а не гарантия автоматического выбора цели.
static func hit_hint(field: FieldState, tower: TowerState, mob: MobState) -> String:
	if tower == null or mob == null:
		return "Выберите башню и цель для разбора следующего удара"
	if not mob.is_alive():
		return "Цель погибла или ушла: попадания больше не действуют"
	if tower.data.wind_length_milli > 0:
		return "Ветер: пустите время; положение и направление потока определяют эффект"
	if mob.shield_left > 0:
		return "Следующее попадание поглотит щит: урона и новой реакции не будет"
	var rule: ReactionData = null
	for tag: StringName in tower.data.tags:
		rule = ReactionResolver.resolve(tag, mob.status_tags(), field.config.reactions)
		if rule != null:
			break
	var text: String = "Следующий ручной удар: "
	if rule != null:
		if rule.curse_extra_ticks > 0 and mob.is_conserved:
			text += "Консервация уже использована; повторного усиления нет"
		elif rule.chain_chance_bonus > 0:
			text += "Цепь: шанс %d%%, требуется соседняя живая цель" % \
					DivineCombat.chain_chance(field, mob)
		else:
			text += rule.display_name
	else:
		text += "без особой реакции"
	var blocked: PackedStringArray = []
	for tag: StringName in tower.data.get_status_tags():
		if not mob.can_apply_status(tag):
			blocked.append(_status_name(tag))
	if not blocked.is_empty() and rule == null:
		text += "; два слота заняты, не наложится: " + ", ".join(blocked)
	if not field._can_target(tower, tower.center_milli(), field.get_tower_range(tower), mob):
		text += "\nАвтострельба: выбранная цель вне радиуса или недоступна этой башне"
	return text


## Кандидат переноса сейчас; будущие выстрелы, движение и смерть могут его изменить.
static func curse_hint(field: FieldState, mob: MobState) -> String:
	if mob == null or not mob.is_alive() or mob.curse_ticks_left <= 0:
		return ""
	if not mob.is_contagious:
		return "Проклятие не заразно: мокрота должна быть на цели до удара проклятием"
	var neighbor: MobState = CurseCombat.find_wet_neighbor(field, mob)
	if neighbor == null:
		return "Зараза: сейчас нет мокрого соседа в радиусе переноса"
	var text: String = "Зараза: сейчас подходит #%d · мокрота %.2fс · взрыв через %.2fс" % [
			neighbor.id, float(neighbor.wet_ticks_left) / field.config.ticks_per_second,
			float(mob.curse_ticks_left) / field.config.ticks_per_second]
	if neighbor.wet_ticks_left < mob.curse_ticks_left:
		text += "\nБез обновления мокрота соседа закончится раньше взрыва"
	elif neighbor.wet_ticks_left == mob.curse_ticks_left:
		text += "\nСроки совпадают: порядок тиков важен; обновите мокроту для надёжного переноса"
	return text


static func _status_name(tag: StringName) -> String:
	match tag:
		&"wet": return "мокрота"
		&"burn": return "горение"
		&"charge": return "заряд"
		&"curse": return "проклятие"
		&"cold", &"frozen": return "холод"
	return String(tag)

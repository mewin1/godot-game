class_name BattleReportText
extends RefCounted
## Компактный итог и подробности из наблюдений, без предположений о причине поражения.

const DETAIL_LIMIT: int = 5


## Одна строка остаётся доступной всю следующую подготовку.
static func summary(report: FieldBattleReport) -> String:
	var breached: int = 0
	for count: int in report.breach_counts.values():
		breached += count
	return "Итог: −%d HP · убито %d · прошли %d · отступили %d ⓘ" % [
			report.hp_lost, report.killed, breached, report.retreated]


## Главные угрозы и вклад башен; полный набор остаётся в логе.
static func details(report: FieldBattleReport, include_hp_loss: bool = true) -> String:
	var lines: PackedStringArray = []
	if include_hp_loss:
		lines.append(summary(report))
	lines.append("ПРОРЫВЫ · фактические потери терема" if include_hp_loss else "ПРОРЫВЫ ПРОБЫ")
	var threats: Array[StringName] = report.breach_counts.keys()
	threats.sort_custom(func(a: StringName, b: StringName) -> bool:
		var first: int = report.breach_hp.get(a, 0)
		var second: int = report.breach_hp.get(b, 0)
		return first > second if first != second else String(a) < String(b))
	for id: StringName in threats.slice(0, DETAIL_LIMIT):
		var text: String = "%s ×%d" % [report.mob_names[id], report.breach_counts[id]]
		if include_hp_loss:
			text += ": −%d HP" % report.breach_hp.get(id, 0)
		lines.append(text)
	if threats.is_empty():
		lines.append("Никто не прорвался")
	if include_hp_loss:
		lines.append("После предела/выбывания прорыв может снять 0 HP. Отступление без потерь.")
	lines.append("\nУРОН · снятые HP врагов, без избыточного урона")
	var attackers: Array[int] = _ranked(report.damage_by_tower)
	for id: int in attackers.slice(0, DETAIL_LIMIT):
		lines.append("%s: %d" % [report.tower_names.get(id, "Башня #%d" % id),
				report.damage_by_tower[id]])
	lines.append("У башен указаны удары и цепи, включая урон поглощённых меток.")
	lines.append("Отдельно: горение %d · взрывы проклятия %d · прочее/навыки %d" % [
			report.damage_by_kind.get(&"burn", 0), report.damage_by_kind.get(&"curse", 0),
			report.damage_by_kind.get(&"other", 0)])
	lines.append("\nПОДДЕРЖКА · наложения и обновления меток")
	lines.append("Зараза: %d фактических переносов проклятия" % report.curse_transfers)
	var supporters: Array[int] = _ranked(report.marks_by_tower)
	for id: int in supporters.slice(0, DETAIL_LIMIT):
		lines.append("%s: %d" % [report.tower_names.get(id, "Башня #%d" % id),
				report.marks_by_tower[id]])
	if supporters.is_empty():
		lines.append("Меток от построек нет")
	if not report.wind_ticks_by_tower.is_empty():
		lines.append("Потоки касались целей: %d построек (это не оценка замедления)." %
				report.wind_ticks_by_tower.size())
	lines.append("Число меток не равно пользе: важны порядок и попадание финишера.")
	lines.append("Показываются первые %d в каждой группе. Сравните перестановку кнопкой «Проба»." %
			DETAIL_LIMIT)
	return "\n".join(lines)


static func _ranked(values: Dictionary[int, int]) -> Array[int]:
	var ids: Array[int] = values.keys()
	ids.sort_custom(func(a: int, b: int) -> bool:
		return values[a] > values[b] if values[a] != values[b] else a < b)
	return ids

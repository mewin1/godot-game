class_name ArmyPreview
extends RefCounted
## Короткая угроза и подробный состав из той же сборки армий, что использует бой.


## Две строки: надпись в HUD и подробная подсказка. Не предсказывает исход защиты.
static func describe(sim: MatchSim, receiver: int) -> PackedStringArray:
	var army: Array[MobState] = sim.build_incoming_armies(receiver)
	var base: Array[MobState] = WaveBuilder.build_base_wave(sim.config, sim.round_number)
	var counts: Dictionary[String, int] = {}
	var health: Dictionary[String, int] = {}
	var potential: int = 0
	for mob: MobState in army:
		var name_text: String = mob.data.display_name
		counts[name_text] = counts.get(name_text, 0) + 1
		health[name_text] = mob.max_hp
		potential += mob.breach_damage * sim.config.get_breach_multiplier(sim.round_number)
	var limit: int = sim.config.get_breach_limit(sim.round_number)
	var text: String = "Идут: армия %d + волна %d" % [army.size(), base.size()]
	if limit > 0:
		text += " · предел %d HP" % limit
	var details: PackedStringArray = ["Состав на данный момент; покупки ещё могут его изменить."]
	for name_text: String in counts:
		details.append("%s ×%d · %d HP у бойца" % [
				name_text, counts[name_text], health[name_text]])
	details.append("Базовая волна: %d бойцов" % base.size())
	details.append("Урон всей армии до осадного снижения и предела: %d HP" % potential)
	if limit > 0:
		details.append("Предел общий для волны и всех атакующих, включая осаду.")
	details.append("Лекари не складывают лечение одной цели. Их можно выбить сосредоточенным огнём.")
	return [text, "\n".join(details)]

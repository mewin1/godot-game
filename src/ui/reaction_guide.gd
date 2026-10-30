class_name ReactionGuide
extends RefCounted
## Короткая справка читает те же ресурсы, что и резолвер боя.

## Таблица для наведения, без второго набора правил в интерфейсе.
static func text(config: GameConfig) -> String:
	var lines: PackedStringArray = ["Максимум два статуса; третий не накладывается. Стрелка — порядок удара."]
	var seen: Array[String] = []
	for rule: ReactionData in config.reactions:
		if rule.explanation.is_empty() or seen.has(rule.explanation):
			continue
		seen.append(rule.explanation)
		lines.append("%s · %s" % [rule.display_name, rule.explanation])
	lines.append("Заряд + Лёд: сосуществуют; Война связывает пары без прямой реакции.")
	return "\n".join(lines)

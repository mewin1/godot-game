class_name ReactionResolver
extends RefCounted
## Чистый выбор реакции. Порядок ресурсов задаёт приоритет, RNG и мутаций нет.

## Возвращает первую подходящую реакцию или null.
static func resolve(incoming: StringName, statuses: Array[StringName],
		rules: Array[ReactionData]) -> ReactionData:
	for rule: ReactionData in rules:
		if rule.incoming == incoming and statuses.size() >= rule.minimum_statuses \
				and (rule.required == &"" or statuses.has(rule.required)):
			return rule
	return null

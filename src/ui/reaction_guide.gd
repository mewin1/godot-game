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


## Доступные пары и физические мосты именно этого матча, из настоящих ресурсов.
static func draft_recipes(config: GameConfig, gods: Array[StringName]) -> PackedStringArray:
	var result: PackedStringArray = []
	for rule: ReactionData in config.reactions:
		if rule.minimum_statuses >= 2:
			_append_bridges(result, config, gods, rule)
			continue
		for source: StringName in gods:
			if not _god_statuses(config, source).has(rule.required):
				continue
			for finisher: StringName in gods:
				if source == finisher or not _god_elements(config, finisher).has(rule.incoming):
					continue
				var line: String = "%s → %s: %s" % [IdolSlot.god_name(source),
						IdolSlot.god_name(finisher), rule.display_name]
				if not result.has(line):
					result.append(line)
	_append_freeze_finishers(result, config, gods)
	return result


## Короткий отчёт заканчивающегося/прошлого боя, не предполагает срабатывания заранее.
static func battle_report(config: GameConfig, counts: Dictionary[StringName, int]) -> String:
	var parts: PackedStringArray = []
	for rule: ReactionData in config.reactions:
		var count: int = counts.get(rule.id, 0)
		if count > 0:
			parts.append("%s ×%d" % [rule.display_name, count])
	return "Реакций ещё нет" if parts.is_empty() else " · ".join(parts)


static func _append_bridges(result: PackedStringArray, config: GameConfig,
		gods: Array[StringName], rule: ReactionData) -> void:
	for finisher: StringName in gods:
		if not _god_elements(config, finisher).has(rule.incoming):
			continue
		for a: int in gods.size():
			var first: Array[StringName] = _god_statuses(config, gods[a])
			if first.is_empty() or gods[a] == finisher:
				continue
			for b: int in range(a + 1, gods.size()):
				var second: Array[StringName] = _god_statuses(config, gods[b])
				if second.is_empty() or gods[b] == finisher or first[0] == second[0]:
					continue
				if not _can_keep_both(config, gods[a], gods[b]):
					continue
				result.append("%s + %s → %s: %s" % [IdolSlot.god_name(gods[a]),
						IdolSlot.god_name(gods[b]), IdolSlot.god_name(finisher), rule.display_name])


static func _god_statuses(config: GameConfig, god: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for tower: TowerData in config.towers:
		if tower.god != god:
			continue
		if tower.wet_ticks > 0 and not result.has(&"wet"):
			result.append(&"wet")
		if tower.burn_percent > 0 and not result.has(&"burn"):
			result.append(&"burn")
		if tower.charge_ticks > 0 and not result.has(&"charge"):
			result.append(&"charge")
		if tower.cold_ticks > 0 and not result.has(&"cold"):
			result.append(&"cold")
		if tower.curse_ticks > 0 and not result.has(&"curse"):
			result.append(&"curse")
	return result


static func _god_elements(config: GameConfig, god: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for tower: TowerData in config.towers:
		if tower.god == god:
			for tag: StringName in tower.tags:
				if not result.has(tag):
					result.append(tag)
	return result


## Только сочетания этого драфта; объясняет, когда ветер даёт один контроль.
static func draft_text(config: GameConfig, gods: Array[StringName]) -> String:
	var recipes: PackedStringArray = draft_recipes(config, gods)
	var lines: PackedStringArray = ["СОЧЕТАНИЯ ЭТОГО МАТЧА"]
	lines.append_array(recipes)
	for god: StringName in gods:
		if not _god_elements(config, god).has(&"wind"):
			continue
		var has_recipe: bool = false
		for recipe: String in recipes:
			has_recipe = has_recipe or recipe.contains(IdolSlot.god_name(god))
		if not has_recipe:
			lines.append("%s: только контроль; огня, воды и холода для разноса нет." %
					IdolSlot.god_name(god))
	for rule: ReactionData in config.reactions:
		for recipe: String in recipes:
			if recipe.ends_with(": " + rule.display_name):
				lines.append(rule.explanation)
				break
	lines.append("Порядок попаданий важен. Третий статус не накладывается.")
	return "\n".join(lines)


static func _can_keep_both(config: GameConfig, first: StringName, second: StringName) -> bool:
	for source: StringName in [first, second]:
		var hitter: StringName = second if source == first else first
		for tag: StringName in _god_elements(config, hitter):
			var rule: ReactionData = ReactionResolver.resolve(tag, _god_statuses(config, source),
					config.reactions)
			if rule != null and (not rule.consume.is_empty() or rule.freeze_ticks > 0):
				return false
	return true


static func _append_freeze_finishers(result: PackedStringArray, config: GameConfig,
		gods: Array[StringName]) -> void:
	for freezing: ReactionData in config.reactions:
		if freezing.freeze_ticks <= 0:
			continue
		for breaking: ReactionData in config.reactions:
			if breaking.required != &"frozen":
				continue
			for source: StringName in gods:
				if not _god_statuses(config, source).has(freezing.required):
					continue
				for freezer: StringName in gods:
					if not _god_elements(config, freezer).has(freezing.incoming):
						continue
					for finisher: StringName in gods:
						if _god_elements(config, finisher).has(breaking.incoming):
							result.append("%s → %s → %s: %s" % [IdolSlot.god_name(source),
									IdolSlot.god_name(freezer), IdolSlot.god_name(finisher),
									breaking.display_name])

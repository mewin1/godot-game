class_name CombatCoverage
extends RefCounted
## Совместное покрытие дороги. Это возможность реакции, а не гарантия порядка попаданий.

## Клетки, где выбранная башня участвует в доступной паре или физическом мосте.
static func reaction_cells(field: FieldState, selected: TowerState) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in field.get_active_path():
		var point: Vector2i = cell * FieldState.MILLI + Vector2i(500, 500)
		if not covers(field, selected, point):
			continue
		var covering: Array[TowerState] = []
		var statuses: Array[StringName] = []
		for tower: TowerState in field.towers:
			if not covers(field, tower, point):
				continue
			covering.append(tower)
			for status: StringName in tower.data.get_status_tags():
				if not statuses.has(status):
					statuses.append(status)
		if _has_reaction(field.config, selected, covering, statuses):
			result.append(cell)
	return result


## Радиус и поток читаются из тех же целочисленных правил, что и настоящий бой.
static func covers(field: FieldState, tower: TowerState, point: Vector2i) -> bool:
	if tower.data.wind_length_milli > 0:
		return DivineCombat.is_in_wind(field, tower, point)
	var offset: Vector2i = point - tower.center_milli()
	var reach: int = field.get_tower_range(tower)
	return offset.x * offset.x + offset.y * offset.y <= reach * reach


static func _has_reaction(config: GameConfig, selected: TowerState,
		covering: Array[TowerState], statuses: Array[StringName]) -> bool:
	# Заморозка возникает из двух участников, а не из одной постройки.
	var possible: Array[StringName] = statuses.duplicate()
	for rule: ReactionData in config.reactions:
		if rule.freeze_ticks > 0 and statuses.has(rule.required) \
				and _has_element(covering, rule.incoming):
			possible.append(&"frozen")
	for rule: ReactionData in config.reactions:
		if possible.size() < rule.minimum_statuses \
				or (rule.required != &"" and not possible.has(rule.required)):
			continue
		if _contributes(selected.data, rule) and _has_element(covering, rule.incoming):
			return true
	return false


static func _has_element(towers: Array[TowerState], tag: StringName) -> bool:
	for tower: TowerState in towers:
		if tower.data.tags.has(tag):
			return true
	return false


static func _contributes(data: TowerData, rule: ReactionData) -> bool:
	var statuses: Array[StringName] = data.get_status_tags()
	if data.tags.has(rule.incoming) or statuses.has(rule.required):
		return true
	if rule.minimum_statuses >= 2 and not statuses.is_empty():
		return true
	return rule.required == &"frozen" and (statuses.has(&"wet") or statuses.has(&"cold"))

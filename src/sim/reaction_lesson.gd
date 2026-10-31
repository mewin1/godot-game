class_name ReactionLesson
extends RefCounted
## Строит новый учебный снимок для выбранного шага; настоящий матч не изменяется.

## 0 — мишени, 1 — подготовка меток, 2 — удар, 3 — последствия одиночного сочетания.
static func build(config: GameConfig, lesson: ReactionLessonData, step: int) -> FieldState:
	var field: FieldState = FieldState.new(config, config.max_shop_level, lesson.seed_value)
	var target: MobState = MobState.create(config.training_mob)
	target.id = 1
	target.progress = 3000
	field.mobs.append(target)
	var neighbor: MobState = MobState.create(config.training_mob)
	neighbor.id = 2
	neighbor.progress = 3500
	field.mobs.append(neighbor)
	for i: int in lesson.sources.size():
		var source: TowerState = field.add_tower(lesson.sources[i], Vector2i(2, 5 + i * 2), 0)
		if step >= 1:
			field._shoot(source, target)
	var is_wind: bool = lesson.finisher.wind_length_milli > 0
	var anchor: Vector2i = Vector2i(0, 4) if is_wind else Vector2i(0, 5)
	if not field.can_place_tower_data(lesson.finisher, anchor, 2 if is_wind else 0):
		anchor = Vector2i(2, 7)
	var finisher: TowerState = field.add_tower(lesson.finisher, anchor, 2 if is_wind else 0)
	if step >= 2:
		if is_wind:
			DivineCombat.apply_wind(field, target)
		else:
			field._shoot(finisher, target)
	if step >= 3:
		_advance_single_combo(field, lesson.wait_ticks)
	for mob: MobState in field.mobs:
		mob.previous_progress = mob.progress
		mob.visual_start_progress = mob.progress
	return field


static func _advance_single_combo(field: FieldState, ticks: int) -> void:
	# Никаких повторных выстрелов: изучаем последствия одного сочетания, шаг за шагом.
	for tick_index: int in ticks:
		for mob: MobState in field.mobs:
			DivineCombat.apply_wind(field, mob)
			DivineCombat.tick_effects(field, mob)
			mob.advance()
		field.wave_tick += 1

extends SceneTree
## Экспорт настоящих учебных снимков для автономной демонстрации без запуска игры.


func _initialize() -> void:
	var config: GameConfig = load("res://data/game_config.tres") as GameConfig
	var lessons: Array[Dictionary] = []
	for lesson: ReactionLessonData in config.lessons:
		var steps: Array[Dictionary] = []
		for step: int in 4:
			var field: FieldState = ReactionLesson.build(config, lesson, step)
			var targets: Array[Dictionary] = []
			for mob: MobState in field.mobs:
				targets.append({"hp": mob.hp, "max_hp": mob.max_hp,
						"wet": mob.wet_ticks_left, "charge": mob.charge_ticks_left,
						"burn": mob.burn_ticks_left, "burn_damage": mob.burn_damage,
						"cold": mob.cold_ticks_left, "frozen": mob.freeze_ticks_left,
						"curse": mob.curse_ticks_left, "curse_damage": mob.curse_damage,
						"slow": mob.slow_percent, "slow_ticks": mob.slow_ticks_left,
						"stun": mob.stun_ticks_left})
			steps.append({"targets": targets, "reactions": field.reaction_counts})
		lessons.append({"title": lesson.title, "id": lesson.id,
				"explanation": lesson.explanation, "steps": steps})
	var file: FileAccess = FileAccess.open(
			"res://docs/presentation/gameplay-demo.json", FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"source": "Godot ReactionLesson", "lessons": lessons}, "\t"))
	file.close()
	print("DEMO: exported 12 actual lessons x 4 steps")
	quit()

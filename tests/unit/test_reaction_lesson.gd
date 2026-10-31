extends GutTest
## Все учебные примеры используют настоящие ресурсы, попадания и резолвер.


func test_infection_lesson_demonstrates_transfer_not_just_reaction_name() -> void:
	var config: GameConfig = load("res://data/game_config.tres") as GameConfig
	for lesson: ReactionLessonData in config.lessons:
		if lesson.id == &"infection":
			var field: FieldState = ReactionLesson.build(config, lesson, 3)
			assert_gt(field.mobs[1].curse_ticks_left, 0)
			assert_true(field.mobs[1].is_contagious)


func test_all_lessons_reproduce_their_reaction_and_are_repeatable() -> void:
	var config: GameConfig = load("res://data/game_config.tres") as GameConfig
	assert_eq(config.lessons.size(), 12)
	for lesson: ReactionLessonData in config.lessons:
		var clean: FieldState = ReactionLesson.build(config, lesson, 0)
		assert_true(clean.reaction_counts.is_empty(), String(lesson.id))
		var reacted: FieldState = ReactionLesson.build(config, lesson, 2)
		var count: int = reacted.reaction_counts.get(lesson.reaction_id, 0)
		assert_gt(count, 0, String(lesson.id))
		for tower: TowerState in reacted.towers:
			assert_true(reacted.can_place(tower.cells(), tower.id), String(lesson.id))
		var later: FieldState = ReactionLesson.build(config, lesson, 3)
		var repeat: FieldState = ReactionLesson.build(config, lesson, 3)
		var first_hash: StateHasher = StateHasher.new()
		var second_hash: StateHasher = StateHasher.new()
		later.add_to_hash(first_hash)
		repeat.add_to_hash(second_hash)
		assert_eq(first_hash.value, second_hash.value, String(lesson.id))

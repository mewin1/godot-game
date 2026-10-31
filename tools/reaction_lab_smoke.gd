extends SceneTree
## Все учебные примеры/шаги и две ширины окна, без графического дисплея.


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	root.size = Vector2i(1600, 900)
	var packed: PackedScene = load(ScenePaths.REACTION_LAB) as PackedScene
	var lab: ReactionLab = packed.instantiate() as ReactionLab
	root.add_child(lab)
	await process_frame
	for size_value: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = size_value
		for i: int in 3:
			await process_frame
		for lesson_index: int in lab._config.lessons.size():
			lab._choose_lesson(lesson_index)
			for step: int in 4:
				lab.show_step(step)
				await process_frame
				assert(not lab._report.text.is_empty())
				var bounds: Rect2 = lab.get_global_rect().grow(2)
				for child: Node in lab.find_children("*", "Control", true, false):
					if child is Button or child is FieldView:
						var control: Control = child as Control
						assert(bounds.encloses(control.get_global_rect()),
								"Кнопки и поле стенда помещаются на экране")
	lab.queue_free()
	await process_frame
	print("SMOKE: 12 lessons x 4 steps x 2 window sizes, controls fit")
	quit()

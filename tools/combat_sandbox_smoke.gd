extends SceneTree
## Настоящая сцена песочницы: ввод, перенос проклятия и границы всех элементов.


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	root.size = Vector2i(1600, 900)
	var packed: PackedScene = load("res://scenes/combat_sandbox.tscn") as PackedScene
	var scene: CombatSandboxPanel = packed.instantiate() as CombatSandboxPanel
	root.add_child(scene)
	await process_frame
	scene.infection_example()
	assert(scene.sandbox.field.towers.size() == 2)
	assert(scene.sandbox.field.mobs.size() == 2)
	scene._advance(60)
	assert(scene.sandbox.find_mob(2).is_contagious)
	assert(scene.sandbox.find_mob(2).curse_ticks_left > 0)
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = resolution
		for index: int in 4:
			await process_frame
		var bounds: Rect2 = scene.get_global_rect().grow(2)
		for child: Node in scene.find_children("*", "Control", true, false):
			var control: Control = child as Control
			if not control.is_visible_in_tree() or control is LineEdit:
				continue
			if control is Button or control is SpinBox or control is Label:
				assert(bounds.encloses(control.get_global_rect()),
						"За экраном: %s %s" % [control.get_class(), control.get_global_rect()])
	scene._reset()
	assert(scene.sandbox.field.wave_tick == 0)
	assert(scene.sandbox.field.mobs.size() == 2)
	scene._clear()
	assert(scene.sandbox.field.mobs.is_empty())
	print("SMOKE: sandbox placement, manual hits, curse transfer, reset and layout OK")
	scene.queue_free()
	await process_frame
	quit()

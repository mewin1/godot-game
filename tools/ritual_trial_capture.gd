extends SceneTree
## Графическая проверка отдельного режима без смены настроек проекта.


func _initialize() -> void:
	_run.call_deferred()


func _capture(panel: RitualTrialPanel, filename: String) -> void:
	panel._refresh()
	await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	var error: Error = picture.save_png("res://.godot/ritual/" + filename)
	assert(error == OK)


func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600, 900)
	var error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://.godot/ritual"))
	assert(error == OK)
	var scene: PackedScene = load("res://scenes/ritual_trial.tscn") as PackedScene
	var panel: RitualTrialPanel = scene.instantiate() as RitualTrialPanel
	panel.settings = RitualTrialPanel.TRIAL
	root.add_child(panel)
	await process_frame
	panel._paused = true
	await _capture(panel, "day.png")
	panel._show_schedule()
	await _capture(panel, "schedule.png")
	panel._hide_schedule()
	panel._step()
	while panel.trial.tick_count < 1700 and panel.trial.phase == RitualTrial.Phase.RUNNING:
		panel.trial.tick()
	await _capture(panel, "night.png")
	while panel.trial.tick_count < 6620 and panel.trial.phase == RitualTrial.Phase.RUNNING:
		panel.trial.tick()
	panel.board.action = &"skill"
	panel.board.hover_cell = Vector2i(13, 2)
	await _capture(panel, "boss.png")
	panel.board.action = &"palisade"
	await _capture(panel, "palisade.png")
	panel.queue_free()
	await process_frame
	print("RITUAL CAPTURE: OK — day.png / schedule.png / night.png / boss.png / palisade.png")
	quit()

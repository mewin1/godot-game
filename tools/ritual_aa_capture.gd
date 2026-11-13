extends SceneTree
## Кадры для выбора сглаживания (docs/37 VIS-1c): один и тот же вечер и ночь "Обряда" в окне размером
## с экран, полный кадр и вырезка 1:1 в docs/reports/2026-11-12_gorodishche_audit/.
## godot --path . -s res://tools/ritual_aa_capture.gd -- --aa=taa|taa_sharp|fsr2 (по умолчанию FSR2)

const OUT: String = "res://docs/reports/2026-11-12_gorodishche_audit/"
const CROP: Vector2i = Vector2i(800, 450)
## Дома по кругу каталога на места под постройки: город с разными стихиями.
const BUILDINGS: int = 12


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var mode: String = "fsr2"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--aa="):
			mode = argument.trim_prefix("--aa=")
	root.mode = Window.MODE_WINDOWED
	root.size = DisplayServer.screen_get_size()
	var scene: PackedScene = load("res://scenes/ritual_trial.tscn") as PackedScene
	var panel: RitualTrialPanel = scene.instantiate() as RitualTrialPanel
	root.add_child(panel)
	await process_frame
	panel._pick_hero(0)
	var trial: RitualTrial = RitualTrial.new(panel.settings, 0, 915701, 0)
	panel.trial = trial
	panel._board_reset()
	trial.hp = 100000
	var towers: Array[TowerData] = panel.settings.combat.towers
	var cells: Array[Vector2i] = trial.field.get_buildable_cells()
	for index: int in BUILDINGS:
		var tower: TowerState = trial.field.add_tower(towers[index % towers.size()], cells[index * 3 % cells.size()], 0)
		tower.level = 1 + index % 4
	trial.field.mark_towers_changed()
	await _shoot(panel, "evening", mode)
	while trial.tick_count < panel.settings.nights.night_start(1) + 260:
		trial.tick()
	await _shoot(panel, "night", mode)
	print("RITUAL AA CAPTURE: %s, окно %s" % [mode, root.size])
	quit()


func _shoot(panel: RitualTrialPanel, moment: String, mode: String) -> void:
	panel._paused = true
	panel._refresh()
	# TAA и FSR2 сходятся за несколько кадров неподвижной сцены.
	for frame: int in 40:
		await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	var error: Error = picture.save_jpg(OUT + "vis1_%s_%s_full.jpg" % [moment, mode], 0.92)
	assert(error == OK)
	var corner: Vector2i = Vector2i(picture.get_width() * 2 / 5, picture.get_height() / 4)
	error = picture.get_region(Rect2i(corner, CROP)).save_png(OUT + "vis1_%s_%s_crop.png" % [moment, mode])
	assert(error == OK)

extends SceneTree
## Проверяет экран/приказы на трёх размерах. --capture сохраняет реальный кадр GPU.

var _panel: SiegeTrialPanel


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1600, 900)
	var menu_scene: PackedScene = load("res://scenes/main_menu.tscn") as PackedScene
	var menu: Control = menu_scene.instantiate() as Control
	root.add_child(menu)
	await process_frame
	await process_frame
	var found_entry: bool = false
	for node: Node in menu.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button.text.contains("Дуэль волхвов"):
			found_entry = true
			assert(menu.get_global_rect().encloses(button.get_global_rect()), "Вход в прототип обрезан")
	assert(found_entry, "В главном меню нет прототипа")
	menu.queue_free()
	await process_frame
	var scene: PackedScene = load("res://scenes/siege_trial.tscn") as PackedScene
	_panel = scene.instantiate() as SiegeTrialPanel
	root.add_child(_panel)
	await process_frame
	await process_frame
	_panel.set_process(false)
	_check_transfer_geometry()
	assert(_panel._reserve.item_count == _panel.SETTINGS.reserve_plans.size())
	_panel._reserve.select(4)
	_panel._reserve.item_selected.emit(4)
	assert(_panel._release_button.text.contains("3 бойцов"))
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]:
		root.size = resolution
		await process_frame
		await process_frame
		for control: Control in [_panel._hero, _panel._reserve, _panel._release_button,
				_panel._skill_button, _panel._own, _panel._enemy, _panel._new_button]:
			assert(_panel.get_global_rect().encloses(control.get_global_rect()), "Экран обрезан: %s" % control)
		assert(_panel._own.size.x > 300 and _panel._own.size.y > 300)
	root.size = Vector2i(1600, 900)
	await process_frame
	await process_frame
	_click_cell(_panel._own, Vector2i(2, 3))
	assert(_panel.trial.sides[0].walk_tower_id == _panel.trial.sides[0].field.towers[1].id)
	_click_cell(_panel._own, Vector2i(5, 6))
	assert(_panel.trial.sides[0].destination == Vector2i(5, 6))
	_panel._start_button.pressed.emit()
	assert(_panel.trial.phase == SiegeTrial.Phase.BATTLE)
	for tick: int in 125:
		_panel.trial.tick()
	_panel._release_button.pressed.emit()
	_panel._skill_button.pressed.emit()
	assert(_panel.trial.sides[0].released and _panel.trial.sides[0].walk_left > 0)
	for tick: int in 24:
		_panel.trial.tick()
	_panel._refresh()
	await process_frame
	await process_frame
	if OS.get_cmdline_user_args().has("--capture"):
		await _capture("res://.godot/siege_yaga.png")
	for tick: int in _panel.SETTINGS.max_ticks:
		_panel.trial.tick()
	_panel._refresh()
	assert(_panel.trial.phase == SiegeTrial.Phase.OVER)
	assert(_panel._release_button.disabled and _panel._skill_button.disabled)
	assert(_panel._guide.text.contains("прорывы: первый заход"))
	assert(_panel._guide.text.contains("Соперник:"))
	if OS.get_cmdline_user_args().has("--capture"):
		await _capture("res://.godot/siege_result.png")
	_panel._repeat_button.pressed.emit()
	assert(_panel.trial.sides[0].destination == Vector2i(5, 6))
	assert(_panel.trial.sides[0].reserve_kind == 4)
	assert(_panel.trial.sides[0].walk_tower_id == _panel.trial.sides[0].field.towers[1].id)
	_panel._hero.select(1)
	_panel._hero.item_selected.emit(1)
	_click_cell(_panel._enemy, Vector2i(2, 3))
	assert(_panel.trial.sides[0].target == Vector2i(2, 3))
	_panel._reserve.select(1)
	_panel._reserve.item_selected.emit(1)
	assert(_panel.trial.sides[0].reserve_kind == 1)
	_panel._start_button.pressed.emit()
	for tick: int in 75:
		_panel.trial.tick()
	_panel._skill_button.pressed.emit()
	_panel._refresh()
	assert(_panel._skill_button.text.contains("До налёта"))
	for tick: int in _panel.SETTINGS.fire_warning_ticks + 5:
		_panel.trial.tick()
	_panel._refresh()
	assert(_panel.trial.sides[0].fire_left > 0)
	assert(_panel._skill_button.text.begins_with("Налёт"))
	await process_frame
	await process_frame
	if OS.get_cmdline_user_args().has("--capture"):
		await _capture("res://.godot/siege_gorynych.png")
	for tick: int in _panel.SETTINGS.max_ticks:
		_panel.trial.tick()
	_panel._refresh()
	_panel._hero.select(2)
	_panel._on_hero_selected(2)
	_click_cell(_panel._own, Vector2i(0, 7))
	_click_cell(_panel._own, Vector2i(5, 3))
	var selected: int = _panel.trial.sides[0].walk_tower_id
	var swapped: int = _panel.trial.sides[0].swap_tower_id
	assert(selected == _panel.trial.sides[0].field.towers[0].id)
	assert(swapped == _panel.trial.sides[0].field.towers[3].id)
	_panel._start_button.pressed.emit()
	_panel._skill_button.pressed.emit()
	assert(_panel._skill_button.text.begins_with("Обмен"))
	for tick: int in _panel.SETTINGS.max_ticks:
		_panel.trial.tick()
	_panel._refresh()
	_panel._repeat_button.pressed.emit()
	assert(_panel.trial.sides[0].walk_tower_id == selected)
	assert(_panel.trial.sides[0].swap_tower_id == swapped)
	assert(_panel.trial.sides[0].walk_origin == Vector2i(0, 7))
	assert(_panel.trial.sides[0].destination == Vector2i(5, 3))
	assert(_panel._previous_trial != null)
	assert(not _panel._comparison.visible)
	_panel._start_button.pressed.emit()
	_panel._skill_button.pressed.emit()
	for tick: int in _panel.SETTINGS.max_ticks:
		_panel.trial.tick()
	_panel._refresh()
	assert(_panel._comparison.visible)
	assert(_panel._comparison.text.contains("ваша застава +0"))
	assert(_panel._comparison.text.contains("соперник +0"))
	assert(_panel._guide.text.contains("(авто)"))
	assert(not _panel._log_path.is_empty())
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_panel._log_path))
	var replay: SiegeTrial = SiegeTrialLog.replay(saved, _panel.SETTINGS)
	assert(replay != null and replay.state_hash() == _panel.trial.state_hash())
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]:
		root.size = resolution
		await process_frame
		await process_frame
		assert(_panel.get_global_rect().encloses(_panel._comparison.get_global_rect()))
		assert(_panel.get_global_rect().encloses(_panel._event.get_global_rect()))
	_panel._new_button.pressed.emit()
	assert(_panel._previous_trial == null)
	assert(not _panel._comparison.visible)
	print("SIEGE SMOKE: 3 resolutions, 3 heroes, mixed reserve, selected towers, repeat, battle end OK")
	quit()


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	assert(picture.save_png(path) == OK)


func _check_transfer_geometry() -> void:
	var side: SiegeTrialSide = _panel.trial.sides[0]
	var tower: TowerState = side.field.towers[2]
	var stage: ArenaStage3D = _panel._own._stage
	var model: Node3D = stage._towers[tower.id]
	var origin: Vector3 = model.position
	stage.show_tower_transfer(tower.id, tower.anchor, side.destination, 0.0)
	assert(model.position.distance_to(origin) < 0.001, "Широкая башня прыгает в начале переноса")


func _click_cell(view: SiegeFieldView, cell: Vector2i) -> void:
	var position: Vector2 = view._to_screen(Vector2(cell * 1000 + Vector2i(500, 500)))
	for down: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = position
		event.pressed = down
		view._gui_input(event)

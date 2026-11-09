extends SceneTree
## Запуск новой сцены, ввод, полная запись/загрузка и возврат в прежнее меню.

var _failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)


## Основной режим: бесконечный забег идёт сам, ночь приходит после вечера, конец — экран поражения.
func _check_endless(scene: PackedScene) -> void:
	var panel: RitualTrialPanel = scene.instantiate() as RitualTrialPanel
	root.add_child(panel)
	await process_frame
	await process_frame
	_check(panel.settings.is_endless(), "«Играть» ведёт не в бесконечный забег")
	_check(panel.trial.phase == RitualTrial.Phase.RUNNING and not panel._paused, "Забег не идёт сам с вечера")
	_check(panel.get_combined_minimum_size().y <= panel.size.y, "Бесконечный забег не помещается по высоте")
	_check(panel._scout.visible and panel._scout._cards.size() >= panel.settings.nights.scout_packs,
		"Нет очереди разведки из %d пачек" % panel.settings.nights.scout_packs)
	_check(panel._scout._cards[0].tooltip_text.contains("Состав"), "В подсказке пачки нет состава")
	_check(panel._scout.get_global_rect().end.x <= panel.size.x, "Очередь разведки за краем экрана")
	panel._paused = true
	panel._choose_purchase(0)
	panel._on_cell(Vector2i(10, 3), false)
	_check(panel.trial.field.towers.size() == 1, "Вечером нельзя строить")
	var nights: RitualNightRules = panel.settings.nights
	while panel.trial.tick_count < nights.night_start(1) + 1:
		panel.trial.tick()
	panel._refresh()
	_check(panel._clock.text.begins_with("Ночь 1"), "Ночь не наступила после вечера: " + panel._clock.text)
	panel.trial.hp = 1
	while panel.trial.phase == RitualTrial.Phase.RUNNING:
		panel.trial.tick()
	panel._process(0.0)
	_check(panel._defeat.visible and panel._defeat_text.text.contains("Продержались ночей"), "Нет экрана поражения")
	panel.queue_free()
	await process_frame


func _run() -> void:
	var scene: PackedScene = load("res://scenes/ritual_trial.tscn") as PackedScene
	await _check_endless(scene)
	var panel: RitualTrialPanel = scene.instantiate() as RitualTrialPanel
	panel.settings = RitualTrialPanel.TRIAL
	root.add_child(panel)
	await process_frame
	await process_frame
	_check(panel.trial != null, "Нет симуляции опыта")
	_check(panel.size.x >= 1200, "Не задан размер экрана")
	_check(panel.get_combined_minimum_size().x <= panel.size.x, "Интерфейс не помещается по ширине")
	_check(panel.get_combined_minimum_size().y <= panel.size.y, "Интерфейс не помещается по высоте")
	_check(panel._palisade_button.get_global_rect().end.y <= panel.size.y, "Припас за границей окна")
	for slot: IdolSlot in panel._idol_slots:
		_check(slot.get_global_rect().end.y <= panel.size.y, "Идол за границей окна")
	_check(panel._threat.get_global_rect().end.y <= panel.size.y, "Очередь угроз за границей окна")
	panel._choose_purchase(0)
	panel._on_cell(Vector2i(1, 2), false)
	_check(panel.trial.gold == 0, "Отказ покупки списал деньги")
	panel._on_cell(Vector2i(10, 3), false)
	panel.board.action = &""
	panel._on_cell(Vector2i(10, 3), false)
	_check(panel.board.selected_id == 1, "Башня не выбирается")
	panel._choose_move()
	panel._on_cell(Vector2i(9, 8), false)
	_check(panel.trial.field.get_tower(1).anchor == Vector2i(9, 8), "Перенос подготовки не выполнен")
	panel._start()
	panel._paused = true
	for index: int in 35:
		panel.trial.tick()
	panel._choose_skill()
	panel._on_cell(Vector2i(7, 2), false)
	_check(panel.trial.hero_due >= 0, "Нет замаха Ильи")
	panel._capture(RitualTrialRecord.DIRECTORY + "/smoke_checkpoint.bin")
	var expected: int = panel.trial.state_hash()
	var restored: RitualTrial = RitualTrialRecord.load_checkpoint(panel.settings, RitualTrialRecord.DIRECTORY + "/smoke_checkpoint.bin")
	_check(restored != null and restored.state_hash() == expected, "Файл снимка не восстанавливает состояние")
	panel._branch.select(1)
	panel._restore_branch()
	_check(panel.trial.control_mode == RitualTrial.ControlMode.PASSIVE, "Не включён пассивный контроль")
	panel._step()
	_check(panel.trial.hero_due >= 0, "Смена ветки потеряла начатый замах")
	panel._save_result()
	_check(not panel._saved_result, "Промежуточное сохранение ошибочно помечено финальным")
	panel._reset(4)
	_check(panel.trial.phase == RitualTrial.Phase.RUNNING, "Заполненный старт получил подготовку")
	_check(panel._paused, "Заполненный старт должен быть на паузе")
	panel._on_cell(Vector2i(10, 3), false)
	panel._choose_move()
	panel._on_cell(Vector2i(9, 8), false)
	_check(panel.trial.field.get_tower(1).is_action_blocked(), "Перенос заполненного старта бесплатный")
	panel.queue_free()
	await process_frame
	var menu: PackedScene = load("res://scenes/main_menu.tscn") as PackedScene
	var menu_node: Control = menu.instantiate() as Control
	root.add_child(menu_node)
	await process_frame
	await process_frame
	var library: Control = menu_node.get_node("%Library") as Control
	_check(library.get_global_rect().end.y <= menu_node.size.y, "Кнопки меню вышли за экран")
	_check(ResourceLoader.exists(ScenePaths.MATCH), "Потерян основной матч")
	_check(ResourceLoader.exists(ScenePaths.SIEGE_TRIAL), "Потеряна прежняя дуэль")
	menu_node.queue_free()
	await process_frame
	if not _failed:
		print("RITUAL SMOKE: OK — бесконечный забег, сцена, ввод, снимок, ветка, запись, старое меню")
	quit(1 if _failed else 0)

extends SceneTree
## Графическая интеграционная проверка настоящего GUI и проекции 3D.
## События направляются в viewport Godot, без обхода обработчиков кнопок/поля.

var panel: RitualTrialPanel
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)
	else:
		print("PASS: " + description)

func _button(node: Node, prefix: String) -> Button:
	if node is Button and (node as Button).text.begins_with(prefix):
		return node as Button
	for child: Node in node.get_children():
		var found: Button = _button(child, prefix)
		if found != null:
			return found
	return null

func _click(point: Vector2, right: bool = false) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	await process_frame
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_RIGHT if right else MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await process_frame

func _press(prefix: String) -> void:
	for card: OfferCard in panel._shop._cards:
		if card.data != null and card.data.display_name.begins_with(prefix):
			_check(card.is_visible_in_tree(), "Карточка PvP доступна: " + prefix)
			await _click(card.get_global_rect().get_center())
			return
	for card: MarketOffer in panel._shop._ritual_rites:
		if card.rite.display_name.begins_with(prefix):
			_check(card.is_visible_in_tree(), "Карточка заговора PvP доступна: " + prefix)
			await _click(card.get_global_rect().get_center())
			return
	var button: Button = panel._pause_button if prefix == "Пауза" else _button(panel, prefix)
	var opened: bool = false
	if button != null and not button.is_visible_in_tree():
		await _press("Проверки")
		await create_timer(0.05).timeout
		opened = true
	_check(button != null and button.is_visible_in_tree(), "Кнопка доступна: " + prefix)
	if button != null:
		await process_frame
		await process_frame
		await _click(button.get_global_rect().get_center())
	if opened:
		await _press("Проверки")

func _drop_via_adapter(from: Vector2, to: Vector2) -> void:
	# Viewport.push_input не перемещает системный курсор, который Godot использует
	# для drag-and-drop. Здесь отдельно проверяются штатные callbacks переноса.
	var payload: DragPayload = null
	for card: OfferCard in panel._shop._cards:
		if card.get_global_rect().has_point(from):
			payload = DragPayload.for_offer(card.offer_index, card.data, card.rotation_turns)
	for card: MarketOffer in panel._shop._ritual_rites:
		if card.get_global_rect().has_point(from):
			payload = DragPayload.for_rite(card.offer_index, card.rite)
	if payload == null:
		var tower: TowerState = panel.trial.field.get_tower_at(panel.board.stage.cell_at(from))
		if tower != null:
			payload = DragPayload.for_tower(tower)
	_check(payload != null, "Источник переноса — объект PvP")
	if payload == null:
		return
	for slot: IdolSlot in panel._idol_slots:
		if slot.get_global_rect().has_point(to):
			if slot._can_drop_data(to - slot.global_position, payload):
				slot._drop_data(to - slot.global_position, payload)
			return
	if panel._shop.get_global_rect().has_point(to):
		if panel._shop._can_drop_data(to - panel._shop.global_position, payload):
			panel._shop._drop_data(to - panel._shop.global_position, payload)
	elif panel.board._can_drop_data(to, payload):
		panel.board._drop_data(to, payload)
	await process_frame


func _cell_point(cell: Vector2i) -> Vector2:
	return panel.board.global_position + panel.board._point(cell * 1000 + Vector2i(500, 500))


func _cell(cell: Vector2i, right: bool = false) -> void:
	await _click(panel.board.global_position + panel.board._point(cell * 1000 + Vector2i(500, 500)), right)

func _capture(filename: String) -> void:
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png("res://.godot/ritual/pvp_" + filename + ".png") == OK, "Кадр " + filename)

func _advance(tick: int) -> void:
	while panel.trial.tick_count < tick - 6 and panel.trial.phase == RitualTrial.Phase.RUNNING:
		panel.trial.tick()
	panel.board._hits.clear()
	panel.board.effects._projectiles.clear()
	panel.board.effects._impacts.clear()
	panel.board.effects._texts.clear()
	panel.board.effects._flashes.clear()
	panel.board.effects._lightning.clear()
	while panel.trial.tick_count < tick and panel.trial.phase == RitualTrial.Phase.RUNNING:
		panel.trial.tick()
		await create_timer(0.05).timeout
	panel._refresh()
	await process_frame

func _run() -> void:
	panel = (load("res://scenes/ritual_trial.tscn") as PackedScene).instantiate() as RitualTrialPanel
	root.add_child(panel)
	await create_timer(0.7).timeout
	panel._preset.select(3)
	await _press("Заново")
	_check(panel.trial.gold == 92 and panel.trial.field.towers.is_empty(), "Свободный старт")
	var aligned: bool = true
	for y: int in 14:
		for x: int in 20:
			var cell: Vector2i = Vector2i(x, y)
			var point: Vector2 = panel.board.stage.project_milli(Vector2(cell * 1000 + Vector2i(500, 500)))
			aligned = aligned and panel.board.stage.cell_at(point) == cell
	_check(aligned, "280 центров клеток совпадают с обратной проекцией")
	await _press("Ветродуй")
	await _cell(Vector2i(5, 4), true)
	_check(panel.board.preview_rotation == 1, "ПКМ поворачивает покупку")
	await _cell(Vector2i(5, 4))
	_check(panel.trial.field.towers.size() == 1 and panel.trial.gold == 80, "Покупка на 3D-поле")
	await _cell(Vector2i(5, 4))
	await _press("Перенести")
	await _cell(Vector2i(7, 4))
	_check(panel.trial.field.towers[0].anchor == Vector2i(7, 4), "Перенос на 3D-поле")
	await _cell(Vector2i(7, 4), true)
	_check(panel.trial.field.towers[0].rotation == 2, "Поворот размещённой башни")
	await _cell(Vector2i(7, 4))
	await _press("Продать")
	_check(panel.trial.field.towers.is_empty(), "Продажа выбранной башни")
	await _press("Самострел")
	await _cell(Vector2i(10, 3))
	await _press("Слово войны")
	_check(panel.trial.field.idols[0].god != &"", "Покупка заговора развивает идола")
	await _drop_via_adapter(_cell_point(Vector2i(10, 3)), _cell_point(Vector2i(8, 4)))
	_check(panel.trial.field.towers[0].anchor == Vector2i(8, 4), "Адаптер переноса башни PvP")
	await _drop_via_adapter(panel._shop._cards[0].get_global_rect().get_center(), _cell_point(Vector2i(6, 8)))
	_check(panel.trial.field.towers.size() == 2, "Адаптер размещения карточки PvP")
	await _drop_via_adapter(_cell_point(Vector2i(6, 8)), panel._shop._level_title.get_global_rect().get_center())
	_check(panel.trial.field.towers.size() == 1, "Адаптер продажи сбросом на лавку PvP")
	await _drop_via_adapter(panel._shop._ritual_rites[1].get_global_rect().get_center(), panel._idol_slots[1].get_global_rect().get_center())
	_check(panel.trial.field.idols[1].god == &"svarog", "Адаптер заговора через настоящий IdolSlot PvP")
	await _capture("purchase")
	# Полноценная сборка для прохождения расписания без изменения правил/HP/врагов.
	panel._preset.select(0)
	await _press("Заново")
	await _capture("day")
	await _press("Начать")
	await _press("Пауза")
	await _press("Удар Ильи")
	await _cell(Vector2i(8, 2))
	_check(panel.trial.hero_due >= 0, "Активка Ильи через поле")
	await _capture("skill")
	await _advance(650)
	await _capture("sunset")
	await _advance(900)
	await _capture("night")
	await _advance(1800)
	await _capture("dawn")
	var supplies_checkpoint: Dictionary = panel.trial.snapshot()
	_check(panel.trial.palisades == 1, "Частокол получен на рассвете")
	await _press("Частокол")
	await _cell(Vector2i(8, 7))
	_check(panel.trial.palisade_progress >= 0, "Частокол установлен кликом по дороге")
	await _advance(1845)
	await _capture("palisade")
	await _press("Проверки")
	var snapshot_button: Button = _button(panel, "Снимок")
	snapshot_button.pressed.disconnect(panel._capture)
	snapshot_button.pressed.connect(panel._capture.bind("res://.godot/ritual/pvp_check_checkpoint.bin"))
	await _press("Снимок")
	var checkpoint_tick: int = panel.trial.tick_count
	await _advance(1900)
	panel._branch.select(2)
	await _press("Ветка из снимка")
	_check(panel.trial.tick_count == checkpoint_tick, "Ветка восстановила исходное время")
	await _press("Расписание")
	_check(panel._schedule.visible, "Полное расписание открывается")
	await _capture("schedule")
	await _press("Закрыть")
	await _press("Проверки")
	# Возврат к свободному контролю исходного снимка для последующих активок.
	panel.trial = RitualTrial.from_snapshot(panel.SETTINGS, panel._checkpoint)
	panel._board_reset()
	await _advance(3000)
	await _capture("ward")
	await _advance(6620)
	await _capture("boss")
	var boss: RitualMob = null
	for base: MobState in panel.trial.field.mobs:
		if base.data.id == &"voevoda":
			boss = base as RitualMob
	_check(boss != null and boss.boss_phase == RitualMob.BossPhase.WARNING, "Воевода предупреждает о рывке")
	if boss != null:
		await _press("Удар Ильи")
		await _cell(panel.trial.field.layout.path_cells[boss.progress / 1000])
		await _advance(panel.trial.tick_count + panel.SETTINGS.hero_warning + 1)
		_check(panel.trial.hero_due < 0 and panel.trial.hero_ready > panel.trial.tick_count,
			"Удар выполнен, восстановление идёт; Илья не оглушает")
		await _capture("hero_boss")
	panel.trial = RitualTrial.from_snapshot(panel.SETTINGS, supplies_checkpoint)
	panel._board_reset()
	await _advance(6620)
	for base: MobState in panel.trial.field.mobs:
		if base.data.id == &"voevoda":
			boss = base as RitualMob
	if boss != null:
		await _press("Частокол")
		_check(panel.board.action == &"palisade", "Кнопка припаса переключила действие поля")
		await _cell(panel.trial.field.layout.path_cells[mini(boss.progress / 1000 + 10, 30)])
		var limit: int = panel.trial.tick_count + 220
		while panel.trial.tick_count < limit and boss.boss_phase != RitualMob.BossPhase.SPENT:
			await _advance(panel.trial.tick_count + 5)
		_check(boss.boss_phase == RitualMob.BossPhase.SPENT and boss.immune_until > panel.trial.tick_count,
			"Частокол прерывает рывок, иммунитет отображается")
		await _capture("interrupt")
	print("RITUAL PVP GRAPHICAL CHECK: %d failures" % failures)
	panel.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)

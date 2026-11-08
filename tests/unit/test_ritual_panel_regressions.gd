extends GutTest
## Регрессии доступа к информации и автоматического финального сохранения.


func _panel() -> RitualTrialPanel:
	var scene: PackedScene = load("res://scenes/ritual_trial.tscn") as PackedScene
	var panel: RitualTrialPanel = scene.instantiate() as RitualTrialPanel
	add_child_autofree(panel)
	return panel


func _schedule_button(node: Node) -> Button:
	if node is Button:
		var button: Button = node as Button
		if button.text.contains("Расписание"):
			return button
	for child: Node in node.get_children():
		var found: Button = _schedule_button(child)
		if found != null:
			return found
	return null


func _all_label_text(node: Node) -> String:
	var result: String = ""
	if node is Label:
		result = (node as Label).text + "\n"
	for child: Node in node.get_children():
		result += _all_label_text(child)
	return result


func test_full_schedule_is_accessible_before_start_and_during_battle() -> void:
	var panel: RitualTrialPanel = _panel()
	await get_tree().process_frame
	var button: Button = _schedule_button(panel)
	assert_not_null(button, "Полное расписание должно открываться из игры")
	if button == null:
		return
	button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var text: String = _all_label_text(panel)
	assert_true(text.contains("Воевода"))
	assert_true(text.contains("5:20"))
	assert_eq(panel.trial.phase, RitualTrial.Phase.PREP)
	var overview: Control = _control(panel.get("_schedule"))
	assert_not_null(overview)
	if overview == null:
		return
	assert_true(overview.visible)
	assert_lte(overview.get_global_rect().end.y, panel.size.y)
	panel._hide_schedule()
	panel._start()
	var tick_before: int = panel.trial.tick_count
	button.pressed.emit()
	assert_true(panel._paused)
	panel._process(0.5)
	assert_eq(panel.trial.tick_count, tick_before)
	panel._hide_schedule()
	assert_false(panel._paused, "Закрытие возвращает прежнее состояние времени")


func test_manual_interim_save_does_not_suppress_automatic_final_save() -> void:
	var panel: RitualTrialPanel = _panel()
	await get_tree().process_frame
	panel._start()
	panel._paused = true
	panel._save_result()
	var interim: String = panel._message.text
	assert_false(panel._saved_result, "Промежуточная запись не является финалом")
	panel.trial.phase = RitualTrial.Phase.OVER
	panel.trial.result = "Проверочный финал"
	panel._process(0.0)
	assert_true(panel._saved_result)
	assert_ne(panel._message.text, interim, "Финал должен получить отдельную запись")
	assert_eq(panel._attempts.size(), 2)


func _control(value: Variant) -> Control:
	return value if value is Control else null


func _button_with_text(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node as Button
	for child: Node in node.get_children():
		var found: Button = _button_with_text(child, text)
		if found != null:
			return found
	return null


func test_space_pauses_even_after_clicking_panel_button() -> void:
	var panel: RitualTrialPanel = _panel()
	await get_tree().process_frame
	panel._start()
	var sell: Button = _button_with_text(panel, "Продать")
	assert_not_null(sell)
	if sell == null:
		return
	# Клик мышью даёт фокус любой кнопке, которая может его взять.
	if sell.focus_mode != Control.FOCUS_NONE:
		sell.grab_focus()
	var tower: TowerState = panel.trial.field.towers[0]
	panel.board.selected_id = tower.id
	var space: InputEventKey = InputEventKey.new()
	space.keycode = KEY_SPACE
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	get_viewport().push_input(space)
	await get_tree().process_frame
	var release: InputEventKey = space.duplicate() as InputEventKey
	release.pressed = false
	get_viewport().push_input(release)
	await get_tree().process_frame
	assert_not_null(panel.trial.field.get_tower(tower.id), "Пробел не должен продавать выбранную башню")
	assert_true(panel._paused, "Пробел ставит паузу")


func test_right_click_while_aiming_cancels_instead_of_rotating_tower() -> void:
	var panel: RitualTrialPanel = _panel()
	await get_tree().process_frame
	panel._start()
	var tower: TowerState = panel.trial.field.towers[3]
	panel._choose_skill()
	panel._on_cell(tower.anchor, true)
	assert_false(tower.is_action_blocked(), "ПКМ при прицеливании не трогает башни")
	assert_eq(panel.board.action, &"")


func test_move_onto_twin_merges_and_enchant_click_applies() -> void:
	var panel: RitualTrialPanel = _panel()
	await get_tree().process_frame
	panel._reset(3)
	panel.trial.gold = 200
	assert_eq(panel.trial.execute(RitualCommand.new(RitualCommand.Action.BUY, 0, Vector2i(4, 3), 0)), "")
	assert_eq(panel.trial.execute(RitualCommand.new(RitualCommand.Action.BUY, 0, Vector2i(8, 3), 0)), "")
	var source: TowerState = panel.trial.field.towers[0]
	var target: TowerState = panel.trial.field.towers[1]
	panel.board.selected_id = source.id
	panel._choose_move()
	panel._on_cell(target.anchor, false)
	assert_eq(target.level, 2, "Перенос на близнеца — слияние")
	assert_eq(panel.trial.field.towers.size(), 1)
	panel._choose_enchant(0)
	panel._on_cell(target.anchor, false)
	assert_true(target.has_enchantment(RitualTrialPanel.SETTINGS.enchants[0].effect))
	assert_eq(panel.board.action, &"")


func test_board_accepts_enchant_and_twin_drops_but_not_idol_rite() -> void:
	var panel: RitualTrialPanel = _panel()
	await get_tree().process_frame
	panel._reset(3)
	assert_eq(panel.trial.execute(RitualCommand.new(RitualCommand.Action.BUY, 0, Vector2i(4, 3), 0)), "")
	assert_eq(panel.trial.execute(RitualCommand.new(RitualCommand.Action.BUY, 0, Vector2i(8, 3), 0)), "")
	var first: TowerState = panel.trial.field.towers[0]
	var second: TowerState = panel.trial.field.towers[1]
	var tower_payload: DragPayload = DragPayload.for_tower(first)
	assert_eq(panel.board.merge_target(tower_payload, second), second)
	var offer: DragPayload = DragPayload.for_offer(0, first.data, 0)
	assert_eq(panel.board.merge_target(offer, second), second, "Карточка на башню 1-го уровня")
	assert_null(panel.board.merge_target(DragPayload.for_offer(1, panel.trial.settings.combat.towers[1], 0), second))


func test_idol_slot_accepts_repeated_rite_until_limit() -> void:
	var panel: RitualTrialPanel = _panel()
	await get_tree().process_frame
	panel._reset(3)
	panel.trial.gold = 500
	var rite: RiteData = RitualTrialPanel.SETTINGS.rites[0]
	assert_eq(panel.trial.execute(RitualCommand.new(RitualCommand.Action.RITE, 0)), "")
	panel._refresh()
	var idol: IdolState = panel.trial.field.get_idol(rite.god)
	var slot: RitualIdolSlot = panel._idol_slots[panel.trial.field.idols.find(idol)] as RitualIdolSlot
	assert_true(slot._can_drop_data(Vector2.ZERO, DragPayload.for_rite(0, rite)), "Второй заговор на тот же идол")
	for index: int in 4:
		panel.trial.execute(RitualCommand.new(RitualCommand.Action.RITE, 0))
	assert_false(slot._can_drop_data(Vector2.ZERO, DragPayload.for_rite(0, rite)), "Предел 5")
	var enchant: RiteData = RitualTrialPanel.SETTINGS.enchants[0]
	assert_false(slot._can_drop_data(Vector2.ZERO, DragPayload.for_rite(0, enchant)), "Чара не кладётся на идол")

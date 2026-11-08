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

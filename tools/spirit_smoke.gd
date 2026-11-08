extends SceneTree
## Настоящий попап Духа: выбор, отмена и уход из подготовки без случайной покупки.

var _failures: int = 0


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var config: GameConfig = load("res://data/game_config.tres") as GameConfig
	var sim: MatchSim = MatchSim.new(config, 73, 2, 2)
	sim.start()
	var player: PlayerState = sim.players[0]
	player.shop.level = 2
	player.gold = 100
	var index: int = -1
	for i: int in config.army_upgrades.size():
		if config.army_upgrades[i].id == &"army_spirit":
			index = i
	player.army.offers.assign([index])
	var panel: ShopPanel = ShopPanel.new()
	root.add_child(panel)
	panel.setup(sim, player)
	var field_panel: Control = Control.new()
	root.add_child(field_panel)
	panel.mount_selection(field_panel)
	panel.command_requested.connect(func(command: SimCommand) -> void:
		_expect(sim.execute_command(0, command) == "", "команда покупки принята"))
	panel.refresh(null)
	await process_frame
	panel._on_army(0)
	await process_frame
	_expect(panel._spirit_popup.visible, "попап открыт")
	_expect(player.army.get_total_upgrades() == 0, "открытие не покупает духа")
	var choices: Array[Node] = panel._spirit_popup.find_children("*", "Button", true, false)
	_expect(choices.size() == sim.active_gods.size(), "только активные боги матча")
	for i: int in choices.size():
		var button: Button = choices[i] as Button
		_expect(button.text.begins_with(GodSymbols.get_power_name(sim.active_gods[i])),
				"подпись стихии")
		_expect(button.text.contains(str(config.resist_percent)), "конкретная сила резиста")
	(choices[1] as Button).pressed.emit()
	_expect(player.army.added_mobs.size() == 1, "ровно одна покупка")
	_expect(player.army.added_mobs[0].resist == sim.active_gods[1], "выбранный резист")
	_expect(not panel._spirit_popup.visible, "выбор закрывает попап")
	panel._on_army(0)
	panel._spirit_popup.hide()
	_expect(panel._spirit_choice_index == -1, "отмена сбрасывает выбор")
	_expect(player.army.get_total_upgrades() == 1, "отмена не покупает")
	panel._on_army(0)
	player.army.offers.assign([0])
	panel._on_spirit_picked(sim.active_gods[0])
	_expect(player.army.get_total_upgrades() == 1, "старая кнопка после реролла не покупает")
	player.army.offers.assign([index])
	panel._on_army(0)
	sim.phase = MatchSim.Phase.WAVE
	panel.refresh(null)
	_expect(not panel._spirit_popup.visible, "при начале волны попап закрыт")
	_expect(panel._spirit_choice_index == -1, "волна сбрасывает выбор")
	print("SPIRIT_SMOKE: %s" % ("OK" if _failures == 0 else "FAIL"))
	panel.queue_free()
	field_panel.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	call_deferred("quit", 0 if _failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)

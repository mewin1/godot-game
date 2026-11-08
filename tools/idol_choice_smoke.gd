extends SceneTree
## Проверка окна идола в настоящем матче на 1280×720; --capture сохраняет кадр.


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var packed: PackedScene = load("res://scenes/match.tscn") as PackedScene
	var scene: MatchScreen = packed.instantiate() as MatchScreen
	scene.is_logging_enabled = false
	seed(771)
	root.add_child(scene)
	await process_frame
	var sim: MatchSim = scene._sim
	assert(sim.choose_hero(0, 0) == "")
	sim.tick()
	scene.set_process(false)
	var player: PlayerState = sim.players[0]
	player.gold = 1000
	assert(sim.execute_command(0, UpgradeShopCommand.new()) == "")
	scene._refresh_views()
	await process_frame
	await process_frame
	var popup: IdolChoicePopup = scene._idol_choice
	assert(popup.visible)
	assert(popup._buttons.size() == player.get_idol_base_rites().size() + 1)
	for child: Control in popup._panel.get_children():
		assert(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(child.get_global_rect()))
	if OS.get_cmdline_user_args().has("--capture"):
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://.godot/checks")
		var picture: Image = root.get_texture().get_image()
		assert(picture.save_png("res://.godot/checks/idol_choice.png") == OK)
	var rite: RiteData = player.get_idol_base_rites()[0]
	popup._buttons[0].pressed.emit()
	sim.tick()
	scene._refresh_views()
	assert(player.field.idols[0].god == rite.god)
	assert(not popup.visible)
	assert(sim.execute_command(0, UpgradeShopCommand.new()) == "")
	assert(sim.execute_command(0, UpgradeShopCommand.new()) == "")
	scene._refresh_views()
	assert(popup.visible)
	popup._buttons[0].pressed.emit()
	popup._buttons[0].pressed.emit()
	sim.tick()
	scene._refresh_views()
	assert(player.idol_choices_left == 1, "Двойной клик расходует только одно право")
	assert(popup.visible)
	popup._buttons[-1].pressed.emit()
	sim.tick()
	scene._refresh_views()
	assert(player.idol_choices_left == 0)
	assert(not popup.visible)
	var bases: Array[RiteData] = player.get_idol_base_rites()
	for slot: int in 3:
		player.field.idols[slot].god = bases[slot].god
	player.idol_choices_left = 1
	scene._refresh_views()
	assert(popup._buttons[3].disabled)
	assert(popup._buttons[3].text.contains("Все три основы заняты"))
	assert(not popup._buttons[0].disabled)
	print("IDOL UI SMOKE OK: 1280x720, choice, decline, double click, full bases")
	scene.queue_free()
	await process_frame
	quit()

extends "res://tools/capture_match.gd"
## Замер подвисаний 3D-матча: открытие сцены и первая постройка каждого вида (загрузка модели и
## сборка шейдеров происходят в момент постройки). Только локальная проверка, в окне (не headless).
## godot --path . -s res://tools/stutter_probe.gd -- [--direct — без экрана загрузки] [--load-first]

const SETTLE_FRAMES: int = 4

var _open_ms: float = 0.0


func _run() -> void:
	if _capture_size.x > 0 and _capture_size.y > 0:
		root.mode = Window.MODE_WINDOWED
		root.size = _capture_size
	var start: int = Time.get_ticks_usec()
	if OS.get_cmdline_user_args().has("--direct"):
		var packed: PackedScene = load(ScenePaths.MATCH) as PackedScene
		_scene = packed.instantiate() as MatchScreen
		root.add_child(_scene)
	else:
		# как из меню: через экран загрузки; худший кадр на нём — замирает ли полоса
		ScenePaths.go_to(self, ScenePaths.MATCH)
		var loading_worst: float = 0.0
		var last: int = Time.get_ticks_usec()
		while not current_scene is MatchScreen:
			await process_frame
			var now: int = Time.get_ticks_usec()
			loading_worst = maxf(loading_worst, (now - last) / 1000.0)
			if now - last > 50000:
				print("STUTTER:   долгий кадр загрузки %.0f мс на %.0f мс, сцена %s" % [(now - last) / 1000.0, (now - start) / 1000.0, current_scene.name if current_scene else "—"])
			last = now
		print("STUTTER: экран загрузки %.0f мс, худший кадр на нём %.0f мс" % [(Time.get_ticks_usec() - start) / 1000.0, loading_worst])
		_scene = current_scene as MatchScreen
	_scene.is_logging_enabled = false
	for frame: int in 3:
		await process_frame
	_open_ms = (Time.get_ticks_usec() - start) / 1000.0
	var sim: MatchSim = _scene._sim
	for player: PlayerState in sim.players:
		if player.hero == null:
			assert(sim.choose_hero(player.index, 0) == "")
	sim.tick()
	_scene.set_process(false)
	for player: PlayerState in sim.players:
		while player.idol_choices_left > 0:
			assert(sim.execute_command(player.index, ChooseIdolCommand.new()) == "")
	_scene._refresh_views()
	await _frames(30)
	var baseline: float = await _frames(60)
	var player: PlayerState = sim.players[0]
	player.gold = 900
	for upgrade: int in 3:
		assert(sim.execute_command(player.index, UpgradeShopCommand.new()) == "")
	if OS.get_cmdline_user_args().has("--load-first"):
		var load_start: int = Time.get_ticks_usec()
		for data: TowerData in sim.config.towers:
			NoirModels.tower(data.id)
			NoirModels.tower_plate(data.id)
			for tier: int in 3:
				NoirModels.plate(tier + 1, data.god)
		print("STUTTER: чтение моделей построек %.0f мс" % ((Time.get_ticks_usec() - load_start) / 1000.0))
	var worst: float = 0.0
	var total: float = 0.0
	var lines: PackedStringArray = []
	for data: TowerData in sim.config.towers:
		if not _fits_somewhere(player, data):
			for tower: TowerState in player.field.towers.duplicate():
				player.gold = 900
				assert(sim.execute_command(player.index, SellTowerCommand.new(tower.id)) == "")
			_scene._refresh_views()
			await _frames(SETTLE_FRAMES)
		player.gold = 900
		_place_one(sim, player, data)
		var before: int = Time.get_ticks_usec()
		_scene._refresh_views()
		var sync_ms: float = (Time.get_ticks_usec() - before) / 1000.0
		var spike: float = maxf(sync_ms, await _frames(SETTLE_FRAMES))
		worst = maxf(worst, spike)
		total += spike
		lines.append("%s %.0f" % [data.id, spike])
	print("STUTTER: открытие матча %.0f мс; кадр в покое %.1f мс" % [_open_ms, baseline])
	print("STUTTER: постройка — худший %.0f мс, средний %.0f мс (%d видов)" % [worst, total / lines.size(), lines.size()])
	print("STUTTER: ", ", ".join(lines))
	# волна: первые юниты каждого вида появляются на поле
	for each: PlayerState in sim.players:
		assert(sim.execute_command(each.index, ReadyCommand.new()) == "")
	_scene.set_process(true)
	print("STUTTER: волна — худший кадр за 10 с %.0f мс" % await _frames(600))
	_scene.queue_free()
	await process_frame
	quit()


## Худший кадр за count кадров, мс.
func _frames(count: int) -> float:
	var worst: float = 0.0
	var last: int = Time.get_ticks_usec()
	for frame: int in count:
		await process_frame
		var now: int = Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
	return worst


func _fits_somewhere(player: PlayerState, data: TowerData) -> bool:
	for y: int in player.field.layout.height:
		for x: int in player.field.layout.width:
			if player.field.can_place_tower_data(data, Vector2i(x, y), 0):
				return true
	return false

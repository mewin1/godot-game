extends SceneTree
## Кадр настоящего матча с расстановкой через команды. Только локальная визуальная проверка.
## godot --path . -s res://tools/capture_match.gd -- --out=res://output/match.png --wave

var _scene: MatchScreen
var _first_round: bool = false
var _crowded: bool = false
var _wave: bool = false
var _hero_select: bool = false
var _shop_level: int = 4
var _output: String = "res://output/dusk_match.png"
var _motion_seconds: float = 0.0
var _capture_size: Vector2i = Vector2i.ZERO


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_output = argument.trim_prefix("--out=")
		if argument.begins_with("--motion="):
			_motion_seconds = clampf(argument.trim_prefix("--motion=").to_float(), 0.0, 30.0)
		if argument.begins_with("--size="):
			var parts: PackedStringArray = argument.trim_prefix("--size=").split("x")
			assert(parts.size() == 2)
			_capture_size = Vector2i(parts[0].to_int(), parts[1].to_int())
		_first_round = _first_round or argument == "--first-round"
		_crowded = _crowded or argument == "--crowded"
		_wave = _wave or argument == "--wave"
		_hero_select = _hero_select or argument == "--hero-select"
		if argument.begins_with("--level="):
			_shop_level = clampi(argument.trim_prefix("--level=").to_int(), 1, 4)
	seed(1701)
	_run.call_deferred()


func _run() -> void:
	var packed: PackedScene = load("res://scenes/match.tscn") as PackedScene
	_scene = packed.instantiate() as MatchScreen
	_scene.is_logging_enabled = false
	root.add_child(_scene)
	if _capture_size.x > 0 and _capture_size.y > 0:
		root.mode = Window.MODE_WINDOWED
		root.size = _capture_size
	await process_frame
	var sim: MatchSim = _scene._sim
	if _hero_select:
		_scene.set_process(false)
		_scene._refresh_views()
		await create_timer(3.0).timeout
		await _save_picture()
		return
	if _crowded:
		for hero: HeroData in sim.config.heroes:
			if hero.id == &"vasilisa":
				sim.players[0].hero_offers[0] = hero
	for player: PlayerState in sim.players:
		if player.hero == null:
			assert(sim.choose_hero(player.index, 0) == "")
	sim.tick()
	_scene.set_process(false)
	if _first_round or _crowded:
		_buy_pair(sim, sim.players[0])
		if _crowded:
			_fill_preparation(sim, sim.players[0])
	else:
		for player: PlayerState in sim.players:
			_prepare_player(sim, player)
	for frame: int in 8:
		await process_frame
	if _wave:
		for player: PlayerState in sim.players:
			assert(sim.execute_command(player.index, ReadyCommand.new()) == "")
		sim.tick()
		for tick: int in 20:
			sim.tick()
		assert(sim.phase == MatchSim.Phase.WAVE)
	_scene._refresh_views()
	_scene._my_view.interpolation = 1.0
	_scene._opponent_view.interpolation = 1.0
	for frame: int in 15:
		await process_frame
	if _wave and _motion_seconds > 0.0:
		_scene.set_process(true)
	await create_timer(maxf(3.0, _motion_seconds)).timeout
	await _save_picture()


func _save_picture() -> void:
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	assert(picture.save_png(_output) == OK)
	print("CAPTURE: ", _output, " · ", picture.get_size())
	_scene.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	quit()


func _prepare_player(sim: MatchSim, player: PlayerState) -> void:
	player.gold = 500
	for upgrade: int in _shop_level - 1:
		assert(sim.execute_command(player.index, UpgradeShopCommand.new()) == "")
	for data: TowerData in sim.config.towers:
		if not sim.active_gods.has(data.god) or data.tier > player.shop.level:
			continue
		_place_one(sim, player, data)
	player.gold = 48
	assert(player.reroll_shop() == "")


func _place_one(sim: MatchSim, player: PlayerState, data: TowerData) -> void:
	for y: int in player.field.layout.height:
		for x: int in player.field.layout.width:
			var anchor: Vector2i = Vector2i(x, y)
			if not player.field.can_place_tower_data(data, anchor, 0):
				continue
			player.shop.offers[0] = data
			player.shop.rite_offers[0] = null
			assert(sim.execute_command(player.index, BuyTowerCommand.new(0, anchor, 0)) == "")
			return


## Две доступные покупки и обновление за стартовое золото обычного первого раунда.
func _buy_pair(sim: MatchSim, player: PlayerState) -> void:
	var brain: BotBrain = BotBrain.new(player.index)
	for index: int in player.shop.offers.size():
		var data: TowerData = player.shop.get_offer(index)
		if data == null or player.field.towers.size() == 2:
			continue
		var spot: Vector3i = brain.find_best_spot(player.field, data)
		assert(spot.x >= 0)
		var buy: BuyTowerCommand = BuyTowerCommand.new(index, Vector2i(spot.x, spot.y), spot.z)
		assert(sim.execute_command(player.index, buy) == "")
	assert(player.field.towers.size() == 2)
	assert(sim.execute_command(player.index, RerollShopCommand.new()) == "")


## Только нагрузочный кадр получает дополнительное золото и оба выбора.
func _fill_preparation(sim: MatchSim, player: PlayerState) -> void:
	player.gold = 400
	for upgrade: int in 3:
		assert(sim.execute_command(0, UpgradeShopCommand.new()) == "")
	for slot: int in player.get_reserve_capacity():
		var index: int = 0
		while index < player.shop.offers.size() and player.shop.get_offer(index) == null:
			index += 1
		if index == player.shop.offers.size():
			assert(sim.execute_command(0, RerollShopCommand.new()) == "")
			index = 0
		assert(sim.execute_command(0, ReserveCommand.new(ReserveCommand.Action.BUY, index)) == "")
	assert(sim.execute_command(0, RerollShopCommand.new()) == "")
	player.gold = 48
	player.gift_towers.append(player.reserve[0].data)
	player.buff_offers = sim.config.send_buffs.slice(0, 3)
	player.discover_offers = sim.config.towers.slice(0, 3)
	_scene._selected_tower_id = player.field.towers[0].id
	assert(player.shop.offers.size() == 7)

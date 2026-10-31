extends SceneTree
## Реальные сцены: заполненная лавка, drag-and-drop, ПКМ и границы экрана без скролла.


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	root.size = Vector2i(1600, 900)
	var packed: PackedScene = load("res://scenes/match.tscn") as PackedScene
	assert(packed != null)
	var scene: MatchScreen = packed.instantiate() as MatchScreen
	assert(scene != null)
	scene.is_logging_enabled = false
	root.add_child(scene)
	await process_frame
	var value: Variant = scene.get("_sim")
	if not (value is MatchSim):
		quit(1)
		return
	var sim: MatchSim = value
	for i: int in 4:
		await process_frame
	var selector_value: Variant = scene.get("_hero_select")
	if not (selector_value is HeroSelectPanel):
		quit(1)
		return
	var selector: HeroSelectPanel = selector_value
	assert(selector != null and selector.visible)
	assert(sim.active_gods.size() == 4)
	for god: StringName in sim.active_gods:
		assert(selector._draft_label.text.contains(IdolSlot.god_name(god)))
	_check_layout(scene)
	var player: PlayerState = sim.players[0]
	# Худший случай по месту: Василиса, магазин 4, семь карточек, полный резерв и оба выбора.
	for hero: HeroData in sim.config.heroes:
		if hero.id == &"vasilisa":
			player.hero_offers[0] = hero
	assert(sim.choose_hero(0, 0) == "")
	sim.tick()
	player.gold = 10000
	player.income = 999
	player.hero_hp = 999
	sim.siege_leader = 0
	sim.siege_attackers.assign([1, 2])
	for i: int in 3:
		assert(sim.execute_command(0, UpgradeShopCommand.new()) == "")
	for i: int in player.get_reserve_capacity():
		player.shop.offers[0] = sim.config.towers[0]
		player.shop.rite_offers[0] = null
		assert(sim.execute_command(0, ReserveCommand.new(ReserveCommand.Action.BUY, 0)) == "")
	player.gift_towers.append(sim.config.towers[0])
	player.buff_offers = sim.config.send_buffs.slice(0, 3)
	player.discover_offers = sim.config.towers.slice(0, 3)
	player.shop.offers[2] = null
	player.shop.rite_offers[2] = load("res://data/rites/perun_charge.tres") as RiteData
	for i: int in 5:
		await process_frame
	_check_layout(scene)
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = resolution
		for i: int in 4:
			await process_frame
		_check_layout(scene)
	root.size = Vector2i(1600, 900)
	for i: int in 3:
		await process_frame
	var idol: IdolSlot = null
	var offer: OfferCard = null
	var reserve_card: OfferCard = null
	var shop: ShopPanel = null
	for child: Node in scene.find_children("*", "Control", true, false):
		if child is IdolSlot and (child as IdolSlot).slot_index == 0:
			idol = child as IdolSlot
		elif child is ShopPanel:
			shop = child as ShopPanel
		elif child is OfferCard:
			var card: OfferCard = child as OfferCard
			if card.is_reserve_slot and card.offer_index == 0:
				reserve_card = card
			elif not card.is_reserve_slot and not card.is_gift and card.offer_index == 2:
				offer = card
	assert(idol != null and offer != null and reserve_card != null and shop != null)
	var rite_payload: DragPayload = DragPayload.for_rite(2, player.shop.get_rite(2))
	assert(idol._can_drop_data(Vector2.ZERO, rite_payload))
	idol._drop_data(Vector2.ZERO, rite_payload)
	sim.tick()
	assert(player.field.idols[0].god == &"perun", "Перетаскивание заговора в идол")
	player.shop.rite_offers[2] = load("res://data/rites/enchant_damage.tres") as RiteData
	var enchant: DragPayload = DragPayload.for_rite(2, player.shop.get_rite(2))
	assert(reserve_card._can_drop_data(Vector2.ZERO, enchant))
	reserve_card._drop_data(Vector2.ZERO, enchant)
	sim.tick()
	assert(player.reserve[0].enchantment == RiteData.Effect.ENCHANT_DAMAGE)
	var gift: DragPayload = DragPayload.for_gift(0, player.gift_towers[0], 0)
	assert(reserve_card._can_drop_data(Vector2.ZERO, gift))
	reserve_card._drop_data(Vector2.ZERO, gift)
	sim.tick()
	assert(player.reserve[0].level == 2 and player.gift_towers.is_empty())
	var right: InputEventMouseButton = InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = Vector2(20, 20)
	var before_rotation: int = player.reserve[0].rotation
	reserve_card._gui_input(right)
	sim.tick()
	assert(player.reserve[0].rotation == (before_rotation + 1) % 4)

	# Реальный механизм drag Godot: ПКМ должен поворачивать, сохраняя перенос активным.
	var held: DragPayload = DragPayload.for_offer(0, sim.config.towers[0], 0)
	held.preview = ShapePreview.create_drag_preview(held.data, 0, 1, 32)
	offer.force_drag(held, held.preview)
	assert(root.gui_is_dragging())
	right.position = offer.get_global_rect().get_center()
	root.push_input(right)
	assert(root.gui_is_dragging(), "ПКМ не должен отменять перенос")
	assert(held.rotation == 1, "ПКМ в переносе поворачивает фигуру")
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(-20, -20)
	root.push_input(release)
	assert(not root.gui_is_dragging())

	# Проверяет источник заговора через ввод Viewport, а не только готовый payload.
	player.shop.offers[2] = null
	player.shop.rite_offers[2] = load("res://data/rites/perun_power.tres") as RiteData
	await process_frame
	await process_frame
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	press.position = offer.get_global_rect().get_center()
	root.push_input(press)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = press.position + Vector2(25, 0)
	motion.relative = Vector2(25, 0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion)
	await process_frame
	assert(root.gui_is_dragging(), "Карточка заговора должна начинать перенос мышью")
	var dragged_value: Variant = root.gui_get_drag_data()
	assert(dragged_value is DragPayload)
	if dragged_value is DragPayload:
		var dragged: DragPayload = dragged_value
		assert(dragged.kind == DragPayload.Kind.RITE)
	motion.position = idol.get_global_rect().get_center()
	root.push_input(motion)
	release.position = idol.get_global_rect().get_center()
	root.push_input(release)
	sim.tick()
	assert(player.field.idols[0].damage_percent == 10,
			"Полный перенос из лавки на идол должен применять усиление")


	var owned: DragPayload = DragPayload.for_tower(player.reserve[0])
	owned.kind = DragPayload.Kind.RESERVE
	assert(shop._can_drop_data(Vector2.ZERO, owned))
	var before_count: int = player.reserve.size()
	shop._drop_data(Vector2.ZERO, owned)
	sim.tick()
	assert(player.reserve.size() == before_count - 1, "Сброс из резерва на лавку продаёт")

	var before_trial: int = sim.state_hash()
	shop._on_trial()
	assert(sim.state_hash() == before_trial, "Проба не меняет настоящий матч")
	assert(shop._strategy_summary.text.begins_with("Проба:"))
	_check_layout(scene)

	# Даже при завершённых своём и встречном полях камера не прыгает на третьего игрока.
	player.is_ready = true
	sim.tick()
	assert(sim.phase == MatchSim.Phase.WAVE)
	player.field.retreat_remaining()
	var opponent_index: int = sim.opponent_of[0]
	var original_opponent: FieldState
	if opponent_index == MatchSim.GHOST:
		original_opponent = sim.ghost_field
	else:
		original_opponent = sim.players[opponent_index].field
	original_opponent.retreat_remaining()
	for other: PlayerState in sim.players:
		if other.index == 0 or other.index == opponent_index:
			continue
		var tank: MobState = MobState.create(sim.config.army_mob)
		tank.hp = 1000000
		tank.max_hp = tank.hp
		tank.speed = 1
		other.field.schedule_spawn(tank, 0)
		break
	await process_frame
	await process_frame
	for child: Node in scene.find_children("*", "Control", true, false):
		if child is FieldView and not (child as FieldView).is_own_field:
			assert((child as FieldView).field == original_opponent,
					"После боя должно оставаться выбранное поле без автоматической вспышки")

	print("SMOKE: seven offers, full reserve, choices, idol/tower drag, gift merge, RMB and sale OK")
	scene.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	quit()


func _check_layout(scene: Control) -> void:
	var bounds: Rect2 = scene.get_global_rect().grow(2)
	for child: Node in scene.find_children("*", "Control", true, false):
		var control: Control = child as Control
		if not control.is_visible_in_tree():
			continue
		assert(not (control is ScrollContainer), "В матче не должно быть прокрутки")
		if control is OfferCard or control is IdolSlot or control is Button:
			var rect: Rect2 = control.get_global_rect()
			if not bounds.encloses(rect):
				push_error("За экраном: %s %s, экран %s" % [control.get_class(), rect, bounds])
				assert(false, "Все игровые действия должны помещаться на экране")
	print("LAYOUT: all visible cards/buttons/idols fit ", bounds.size)

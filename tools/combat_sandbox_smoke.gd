extends SceneTree
## Вкладки, реальные переносы карточки/башни, ПКМ и три простые кнопки.


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	root.size = Vector2i(1600, 900)
	var packed: PackedScene = load("res://scenes/combat_sandbox.tscn") as PackedScene
	var scene: CombatSandboxPanel = packed.instantiate() as CombatSandboxPanel
	root.add_child(scene)
	for index: int in 4:
		await process_frame
	assert(scene._tabs.tab_count == 7)
	assert(scene.sandbox.mob_count() == 3)
	for index: int in 7:
		scene._tabs.current_tab = index
		for card_index: int in 3:
			var card_control: Control = scene._catalog.get_child(card_index) as Control
			assert(_card_data(card_control).god == scene.sandbox.config.gods[index])
		assert(scene._catalog.get_child_count() == 4)
	scene._tabs.current_tab = 0
	scene._add_mob()
	assert(scene.sandbox.mob_count() == 4)
	scene._remove_mob()
	assert(scene.sandbox.mob_count() == 3)
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = resolution
		for index: int in 4:
			await process_frame
		for tab: int in 7:
			assert(scene._tabs.get_tab_rect(tab).end.x <= scene._tabs.size.x,
					"Все семь вкладок видны одновременно")
		var bounds: Rect2 = scene.get_global_rect().grow(2)
		for child: Node in scene.find_children("*", "Control", true, false):
			var control: Control = child as Control
			if not control.is_visible_in_tree():
				continue
			assert(not (control is SpinBox or control is OptionButton or control is CheckBox))
			if control is Button or control is TabBar or control.get_parent() == scene._catalog:
				assert(bounds.encloses(control.get_global_rect()), "Действия помещаются в экран")
	root.size = Vector2i(1600, 900)
	for index: int in 4:
		await process_frame
	var card: Control = scene._catalog.get_child(0) as Control
	var anchor: Vector2i = Vector2i(2, 5)
	assert(scene.sandbox.field.can_place_tower_data(_card_data(card), anchor, 0))
	var center_cell: Vector2i = anchor
	var destination: Vector2 = scene._view.global_position + \
			scene._view._cell_rect(center_cell).get_center()
	await _drag(card.get_global_rect().get_center(), destination)
	assert(scene.sandbox.field.towers.size() == 1, "Перенос из карточки ставит башню")
	var tower: TowerState = scene.sandbox.field.towers[0]
	var before_rotation: int = tower.rotation
	var right: InputEventMouseButton = InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = scene._view.global_position + scene._view._cell_rect(tower.anchor).get_center()
	right.global_position = right.position
	Input.parse_input_event(right)
	await process_frame
	assert(tower.rotation == (before_rotation + 1) % 4, "ПКМ поворачивает башню")
	right.pressed = false
	Input.parse_input_event(right)
	await process_frame
	var from: Vector2 = scene._view.global_position + scene._view._cell_rect(tower.anchor).get_center()
	var candidate: Vector2i = Vector2i(2, 4)
	center_cell = candidate
	destination = scene._view.global_position + scene._view._cell_rect(center_cell).get_center()
	await _drag(from, destination)
	assert(tower.anchor == candidate, "Башня переносится по полю")
	scene._toggle()
	assert(scene._running)
	scene._process(1.0)
	assert(scene.sandbox.field.wave_tick > 0)
	scene._toggle()
	assert(not scene._running)
	scene._toggle()
	assert(scene.sandbox.field.wave_tick == 0, "Новый запуск восстанавливает опыт")
	assert(scene.sandbox.field.towers[0].anchor == candidate)
	scene._toggle()
	tower = scene.sandbox.field.towers[0]
	from = scene._view.global_position + scene._view._cell_rect(tower.anchor).get_center()
	await _drag(from, scene._catalog.get_global_rect().get_center())
	assert(scene.sandbox.field.towers.is_empty(), "Возврат в каталог убирает башню")
	print("SMOKE: 7 tabs x 3 cards, add/remove mob, real drag/move/RMB, restart and layout OK")
	scene.queue_free()
	tower = null
	packed = null
	await process_frame
	await process_frame
	await create_timer(0.1).timeout
	quit.call_deferred()


func _drag(from: Vector2, to: Vector2) -> void:
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	press.position = from
	press.global_position = from
	Input.parse_input_event(press)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = from + Vector2(25, 0)
	motion.global_position = motion.position
	motion.relative = Vector2(25, 0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion)
	await process_frame
	assert(root.gui_is_dragging(), "Перенос начинается мышью")
	motion.relative = to - motion.position
	motion.position = to
	motion.global_position = to
	Input.parse_input_event(motion)
	await process_frame

	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = to
	release.global_position = to
	Input.parse_input_event(release)
	await process_frame



func _card_data(card: Control) -> TowerData:
	var value: Variant = card.get("data")
	if value is TowerData:
		var data: TowerData = value
		return data
	return null

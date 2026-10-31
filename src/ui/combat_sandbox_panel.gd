class_name CombatSandboxPanel
extends Control
## Простая песочница: семь вкладок, перетаскивание построек, число целей и запуск.

var sandbox: CombatSandbox
var _view: SandboxFieldView
var _tabs: TabBar
var _catalog: SandboxCatalog
var _cards: Array[OfferCard] = []
var _play: Button
var _minus: Button
var _count: Label
var _summary: Label
var _notice: Label
var _running: bool = false
var _elapsed: float = 0.0


func _ready() -> void:
	ScreenFit.apply(get_window())
	sandbox = CombatSandbox.new(load("res://data/game_config.tres") as GameConfig)
	_build_ui()
	for index: int in 3:
		_add_mob()
	_show_god(0)
	_refresh()


func _build_ui() -> void:
	var margin: MarginContainer = MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	var main: VBoxContainer = VBoxContainer.new()
	main.add_theme_constant_override("separation", 10)
	margin.add_child(main)
	var header: HBoxContainer = HBoxContainer.new()
	main.add_child(header)
	var title: Label = _label(header, "Песочница боя", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(header, "В меню", _back)
	var actions: HBoxContainer = HBoxContainer.new()
	main.add_child(actions)
	_button(actions, "+1 моб", _add_mob)
	_minus = _button(actions, "−1 моб", _remove_mob)
	_count = _label(actions, "", 20)
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play = _button(actions, "Запуск ▶", _toggle)
	_play.custom_minimum_size.x = 220
	_play.theme_type_variation = &"AccentButton"
	_label(main, "Постройки", 22)
	_tabs = TabBar.new()
	_tabs.add_theme_font_size_override("font_size", 18)
	_tabs.scrolling_enabled = false
	for god: StringName in sandbox.config.gods:
		_tabs.add_tab(IdolSlot.god_name(god))
	_tabs.tab_changed.connect(_show_god)
	main.add_child(_tabs)
	var body: HBoxContainer = HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(body)
	_catalog = SandboxCatalog.new()
	_catalog.custom_minimum_size.x = 300
	_catalog.add_theme_constant_override("separation", 12)
	_catalog.tower_returned.connect(_remove_tower)
	body.add_child(_catalog)
	for index: int in 3:
		var card: OfferCard = OfferCard.new()
		card.is_free_catalog = true
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		card.custom_minimum_size = Vector2(300, 160)
		_catalog.add_child(card)
		_cards.append(card)
	_label(_catalog, "Перетащите постройку на поле.\nПКМ — поворот.\nВерните сюда, чтобы убрать.", 16)
	_view = SandboxFieldView.new()
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.custom_minimum_size = Vector2(450, 400)
	_view.can_edit = true
	_view.show_target_labels = true
	_view.interpolation = 1.0
	_view.sandbox_command_requested.connect(_on_field_command)
	_view.tower_tapped.connect(_select_tower)
	body.add_child(_view)
	_summary = _label(main, "", 17)
	_summary.max_lines_visible = 2
	_summary.custom_minimum_size.y = 48
	_notice = _label(main, "", 15)
	_notice.custom_minimum_size.y = 24


func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	var interval: float = 1.0 / sandbox.config.ticks_per_second
	var ticks: int = mini(5, int(_elapsed / interval))
	if ticks > 0:
		_elapsed -= ticks * interval
		var command: SandboxCommand = SandboxCommand.new(SandboxCommand.Action.STEP)
		command.ticks = ticks
		sandbox.execute(command)
		if sandbox.field.is_wave_done():
			_running = false
		_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		_running = false
		if _play != null:
			_refresh()


func _input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_RIGHT:
		return
	if not get_viewport().gui_is_dragging():
		return
	var value: Variant = get_viewport().gui_get_drag_data()
	if value is DragPayload:
		var payload: DragPayload = value
		payload.rotate_preview()
		get_viewport().set_input_as_handled()


func _show_god(index: int) -> void:
	if _cards.is_empty():
		return
	var god: StringName = sandbox.config.gods[index]
	var choices: Array[TowerData] = []
	for data: TowerData in sandbox.config.towers:
		if data.god == god:
			choices.append(data)
	choices.sort_custom(func(a: TowerData, b: TowerData) -> bool: return a.tier < b.tier)
	for card_index: int in _cards.size():
		var card: OfferCard = _cards[card_index]
		card.show_offer(choices[card_index])
		card.offer_index = sandbox.config.towers.find(choices[card_index])


func _add_mob() -> void:
	_running = false
	var command: SandboxCommand = SandboxCommand.new(SandboxCommand.Action.MOB)
	command.mob = sandbox.config.training_mob
	command.progress = 3000 + sandbox.mob_count() * 500
	sandbox.execute(command)
	sandbox.execute(SandboxCommand.new(SandboxCommand.Action.RESET))
	_view.selected_tower_id = 0
	_notice.text = ""
	_refresh()


func _remove_mob() -> void:
	_running = false
	sandbox.execute(SandboxCommand.new(SandboxCommand.Action.REMOVE_MOB))
	_view.selected_tower_id = 0
	_notice.text = ""
	_refresh()


func _toggle() -> void:
	if _running:
		_running = false
	else:
		sandbox.execute(SandboxCommand.new(SandboxCommand.Action.RESET))
		_view.selected_tower_id = 0
		_elapsed = 0.0
		_running = true
	_notice.text = ""
	_refresh()


func _on_field_command(command: SandboxCommand) -> void:
	_running = false
	_notice.text = sandbox.execute(command)
	_refresh()


func _select_tower(id: int) -> void:
	_view.selected_tower_id = id


func _remove_tower(id: int) -> void:
	_running = false
	var command: SandboxCommand = SandboxCommand.new(SandboxCommand.Action.REMOVE)
	command.tower_id = id
	_notice.text = sandbox.execute(command)
	_view.selected_tower_id = 0
	_refresh()


func _refresh() -> void:
	_view.show_field(sandbox.field, sandbox.config, "Поле боя")
	_count.text = "Мобов: %d" % sandbox.mob_count()
	_minus.disabled = sandbox.mob_count() == 0
	_play.text = "Стоп Ⅱ" if _running else "Запуск ▶"
	var damage: int = 0
	for amount: int in sandbox.field.battle_report.damage_by_kind.values():
		damage += amount
	_summary.text = "Урон: %d · Убито: %d · Переносов проклятия: %d\n%s" % [damage,
			sandbox.field.battle_report.killed, sandbox.field.battle_report.curse_transfers,
			ReactionGuide.battle_report(sandbox.config, sandbox.field.reaction_counts)]


func _button(parent: Node, title: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(130, 44)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _label(parent: Node, title: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = title
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _back() -> void:
	ScenePaths.go_to(get_tree(), ScenePaths.MAIN_MENU)

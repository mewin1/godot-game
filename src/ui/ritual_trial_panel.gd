class_name RitualTrialPanel
extends Control
## Основной режим «Обряд»: бесконечный забег (endless.tres). Прежний 4-суточный опыт (trial.tres)
## остаётся для тестов и инструментов: задать `settings = TRIAL` до добавления в дерево.

const TRIAL: RitualTrialConfig = preload("res://data/ritual/trial.tres")
const ENDLESS: RitualTrialConfig = preload("res://data/ritual/endless.tres")
const MAX_FRAME_TICKS: int = 8
var settings: RitualTrialConfig = ENDLESS
var trial: RitualTrial
var board: RitualBoard
var _hud: RitualMatchHud
var _shop: RitualShopPanel
var _idol_slots: Array[IdolSlot] = []
var _preset: OptionButton
var _branch: OptionButton
var _clock: Label
var _status: Label
var _selection: Label
var _threat: Label
var _message: Label
var _history: Label
var _idols: Label
var _pause_button: Button
var _start_button: Button
var _skill_button: Button
var _palisade_button: Button
var _checkpoint: Dictionary = {}
var _accumulator: float = 0.0
var _paused: bool = true
var _pause_count: int = 0
var _paused_seconds: float = 0.0
var _saved_result: bool = false
var _attempts: PackedStringArray = []
var _schedule: PanelContainer
var _schedule_was_paused: bool = true
var _enchant_index: int = -1
var _repair_button: Button
var _defeat: PanelContainer
var _scout: RitualScoutQueue
var _repair_all_button: Button
## Пристроить улицу (docs/34 §3); нет улиц в данных — кнопки нет.
var _street_button: Button
var _gift_panel: PanelContainer
var _gift_buttons: VBoxContainer
var _gift_key: String = ""
var _repair_house_button: Button
var _defeat_text: Label


func _ready() -> void:
	ScreenFit.apply(get_window())
	theme = DuskTheme.create()
	_build_ui()
	_reset(0)


func _build_ui() -> void:
	board = RitualBoard.new()
	add_child(board)
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.cell_clicked.connect(_on_cell)
	board.command_requested.connect(_issue)
	var root_box: VBoxContainer = VBoxContainer.new()
	add_child(root_box)
	root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud = RitualMatchHud.new()
	root_box.add_child(_hud)
	_hud.pause_pressed.connect(_pause)
	_hud.skill_pressed.connect(_choose_skill)
	_hud.reserve_pressed.connect(_choose_palisade)
	_hud.speed_pressed.connect(_toggle_tools)
	_hud.set_preparation(true)
	_hud._speed_button.show()
	_hud._speed_button.text = "Проверки"
	_hud._speed_button.custom_minimum_size.x = 90
	_hud._speed_button.tooltip_text = "Настройки опыта, расписание и снимки"
	var body: HBoxContainer = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_box.add_child(body)
	var left: VBoxContainer = VBoxContainer.new()
	left.custom_minimum_size.x = 324
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(left)
	_shop = RitualShopPanel.new()
	_shop.custom_minimum_size.x = 324
	left.add_child(_shop)
	_shop.setup_ritual(settings)
	_shop.purchase_chosen.connect(_choose_purchase)
	_shop.rite_chosen.connect(_buy_rite)
	_shop.start_requested.connect(_start)
	_shop.sell_requested.connect(_sell_tower)
	_shop.enchant_chosen.connect(_choose_enchant)
	_shop.reroll_requested.connect(_reroll)
	var edit: HBoxContainer = HBoxContainer.new()
	left.add_child(edit)
	_button(edit, "Перенести", _choose_move)
	_button(edit, "Продать", _sell)
	_button(edit, "Отмена", _cancel_move)
	var upkeep: HBoxContainer = HBoxContainer.new()
	left.add_child(upkeep)
	_repair_button = _button(upkeep, "Починить терем +%d · %d" % [settings.repair_hp, settings.repair_cost], _repair)
	_repair_button.tooltip_text = "Терем +%d HP за %d золота (не выше %d)" % [
		settings.repair_hp, settings.repair_cost, settings.hero_hp]
	if settings.is_endless():
		_repair_button.text = "Лечить Илью +%d · %d" % [settings.repair_hp, settings.repair_cost]
		_repair_button.tooltip_text = "Илья в сторожке +%d HP за %d золота (не выше %d). Враг, дошедший до сторожки, бьёт Илью." % [
			settings.repair_hp, settings.repair_cost, settings.hero_hp]
	if not settings.streets.is_empty():
		_street_button = _button(upkeep, "", _grow)
	if settings.wear_ticks > 0:
		var houses: HBoxContainer = HBoxContainer.new()
		left.add_child(houses)
		_repair_all_button = _button(houses, "Починить всё", _repair_houses.bind(0))
		_repair_all_button.tooltip_text = "Вернуть полную прочность всем домам. Ремонт дешевле новой постройки."
		_repair_house_button = _button(houses, "Починить дом", _repair_selected)
	var gap: Control = Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(gap)
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(right)
	var field_space: Control = Control.new()
	field_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(field_space)
	_shop.mount_selection(field_space)
	_selection = _shop._selection
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 12)
	right.add_child(bottom)
	var idols: PanelContainer = PanelContainer.new()
	idols.add_theme_stylebox_override("panel", DuskTheme.glass(0.62, 6))
	bottom.add_child(idols)
	var idol_row: HBoxContainer = HBoxContainer.new()
	idols.add_child(idol_row)
	_label(idol_row, "ИДОЛЫ", 13)
	for index: int in 3:
		var slot: RitualIdolSlot = RitualIdolSlot.new()
		slot.rite_chosen.connect(_buy_rite)
		slot.slot_index = index
		slot.custom_minimum_size = Vector2(78, 72)
		idol_row.add_child(slot)
		_idol_slots.append(slot)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(spacer)
	var hero_dock: PanelContainer = PanelContainer.new()
	hero_dock.add_theme_stylebox_override("panel", DuskTheme.glass(0.66, 6))
	bottom.add_child(hero_dock)
	var hero_row: HBoxContainer = HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 10)
	hero_dock.add_child(hero_row)
	_hud.move_hero_controls(hero_row)
	_skill_button = _hud._skill_button
	_palisade_button = _hud._reserve_button
	_pause_button = _hud._pause_button
	_start_button = _shop._ready
	_clock = _hud._phase_label
	_status = _hud._hp_label
	_idols = _label(self, "", 10)
	_idols.hide()
	# Временный счётчик кадров: справа под кнопками «Пауза» и «Проверки».
	var fps: FpsLabel = FpsLabel.new()
	fps.viewport = board.stage._viewport if board.stage != null else null
	add_child(fps)
	fps.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps.offset_left = -190.0
	fps.offset_right = -16.0
	fps.offset_top = 52.0
	# Техническая строка опыта сохранена отдельно от интерфейса PvP.
	var tools: VBoxContainer = VBoxContainer.new()
	root_box.add_child(tools)
	var controls: HFlowContainer = HFlowContainer.new()
	controls.name = "TrialTools"
	controls.visible = false
	tools.add_child(controls)
	_preset = OptionButton.new()
	_preset.focus_mode = Control.FOCUS_NONE
	for loadout: RitualLoadout in settings.loadouts:
		_preset.add_item(loadout.title)
	controls.add_child(_preset)
	_button(controls, "Заново", _reset_selected)
	_button(controls, "Один тик", _step)
	_button(controls, "Снимок", _capture)
	_button(controls, "Открыть снимок", _load_checkpoint)
	_branch = OptionButton.new()
	_branch.focus_mode = Control.FOCUS_NONE
	for text: String in ["Свободное продолжение", "Без команд", "Только приёмы", "Приёмы + переносы"]:
		_branch.add_item(text)
	controls.add_child(_branch)
	_button(controls, "Ветка из снимка", _restore_branch)
	_button(controls, "Сохранить итог", _save_result)
	_button(controls, "Расписание · все сутки", _show_schedule).visible = not settings.is_endless()
	_button(controls, "В меню", _back)
	_threat = _hud._siege_label
	_hud._siege_panel.show()
	if settings.is_endless():
		# Очередь ближайшей ночи — своя полоса сверху над полем: пачек много, карточки шире.
		_scout = RitualScoutQueue.new()
		_hud._siege_panel.hide()
		var strip: PanelContainer = PanelContainer.new()
		strip.add_theme_stylebox_override("panel", DuskTheme.glass(0.62, 6))
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(strip)
		strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		strip.offset_left = 430
		strip.offset_right = -230
		strip.offset_top = 8
		strip.add_child(_scout)
	_threat.visible = not settings.is_endless()
	var toast: PanelContainer = PanelContainer.new()
	toast.add_theme_stylebox_override("panel", DuskTheme.glass(0.82, 8))
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast)
	toast.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	toast.offset_left = 356
	toast.offset_right = -20
	# Над панелью выбора постройки, чтобы не закрывать её строку.
	toast.offset_top = -258
	toast.offset_bottom = -228
	_message = _label(toast, "", 12)
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_history = _label(controls, "", 10)
	_history.hide()
	_build_schedule()
	_build_defeat()
	_build_gifts()


## Экран поражения бесконечного забега: ночи, рекорд на устройстве, убитые боссы.
func _build_defeat() -> void:
	_defeat = PanelContainer.new()
	_defeat.add_theme_stylebox_override("panel", DuskTheme.panel(Color("101b23"), DuskTheme.GOLD, 20))
	_defeat.z_index = 10
	add_child(_defeat)
	_defeat.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	_defeat.add_child(content)
	_defeat_text = _label(content, "", 20)
	_defeat_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(buttons)
	_button(buttons, "Ещё забег", _reset.bind(0))
	_button(buttons, "В меню", _back)
	_defeat.hide()


## Выбор дара за босса: игра стоит (симуляция не идёт), пока не выбран один из трёх.
func _build_gifts() -> void:
	_gift_panel = PanelContainer.new()
	_gift_panel.add_theme_stylebox_override("panel", DuskTheme.panel(Color("101b23"), DuskTheme.GOLD, 20))
	_gift_panel.z_index = 10
	add_child(_gift_panel)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	_gift_panel.add_child(content)
	_label(content, "Босс повержен! Выберите дар:", 22).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gift_buttons = VBoxContainer.new()
	_gift_buttons.add_theme_constant_override("separation", 8)
	content.add_child(_gift_buttons)
	_gift_panel.hide()


func _refresh_gifts() -> void:
	var key: String = str(trial.gift_choice)
	if key == _gift_key:
		return
	_gift_key = key
	for child: Node in _gift_buttons.get_children():
		child.queue_free()
	_gift_panel.visible = not trial.gift_choice.is_empty()
	for index: int in trial.gift_choice:
		var gift: RitualGiftData = settings.gifts[index]
		var button: Button = _button(_gift_buttons, "%s — %s" % [gift.display_name, gift.description],
			_choose_gift.bind(index))
		button.custom_minimum_size = Vector2(560, 44)
		button.add_theme_font_size_override("font_size", 18)
	_gift_panel.reset_size()
	_gift_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


func _choose_gift(index: int) -> void:
	_issue(RitualCommand.new(RitualCommand.Action.GIFT, index))


func _show_defeat() -> void:
	var nights: int = trial.nights_survived()
	var record: bool = RitualRunRecord.submit(nights, trial.bosses_killed)
	var best: Dictionary[String, int] = RitualRunRecord.best()
	_defeat_text.text = "%s\nПродержались ночей: %d\nРекорд: %d%s\nБоссов убито: %d" % [
		trial.result, nights, best["nights"], " — новый!" if record else "", trial.bosses_killed]
	_defeat.reset_size()
	_defeat.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_defeat.show()


func _build_schedule() -> void:
	_schedule = PanelContainer.new()
	add_child(_schedule)
	_schedule.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_schedule.offset_left = 24
	_schedule.offset_top = 24
	_schedule.offset_right = -24
	_schedule.offset_bottom = -24
	_schedule.z_index = 10
	_schedule.add_theme_stylebox_override("panel", DuskTheme.panel(Color("101b23"), DuskTheme.GOLD, 20))
	var content: VBoxContainer = VBoxContainer.new()
	_schedule.add_child(content)
	var header: HBoxContainer = HBoxContainer.new()
	content.add_child(header)
	var title: Label = _label(header, "Полное расписание · время от начала опыта", 23)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(header, "Закрыть", _hide_schedule)
	_label(content, "Бой на паузе. Все появления известны заранее; оставшиеся враги переходят в следующий день.", 16)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	content.add_child(columns)
	for cycle: int in 0 if settings.is_endless() else settings.cycles:
		var column: VBoxContainer = VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 3)
		columns.add_child(column)
		_label(column, "Сутки %d" % (cycle + 1), 21)
		for spawn: RitualSpawn in settings.spawns:
			if spawn.at_tick / settings.cycle_ticks != cycle:
				continue
			var seconds: int = spawn.at_tick / settings.combat.ticks_per_second
			var row: Label = _label(column, "%d:%02d  %s" % [seconds / 60, seconds % 60,
				settings.enemies[spawn.mob_index].display_name], 15)
			row.tooltip_text = settings.enemies[spawn.mob_index].description
	_schedule.visible = false


func _show_schedule() -> void:
	if _schedule.visible:
		return
	_schedule_was_paused = _paused
	if not _paused and trial.phase == RitualTrial.Phase.RUNNING:
		_pause_count += 1
	_paused = true
	_accumulator = 0.0
	_schedule.show()
	_refresh()


func _hide_schedule() -> void:
	_schedule.hide()
	_paused = _schedule_was_paused
	_accumulator = 0.0
	_refresh()


func _label(parent: Node, text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 30
	# Без фокуса: иначе пробел (пауза) повторно нажимает последнюю кнопку, например «Продать».
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 15)
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		var style: StyleBox = theme.get_stylebox(state, &"Button").duplicate() as StyleBox
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _reset_selected() -> void:
	_reset(_preset.selected)


func _reset(index: int) -> void:
	# Сид выбирает интерфейс (не симуляция): каждый забег — новые ночи, сид виден в записи.
	trial = RitualTrial.new(settings, index, randi() % 1000000 if settings.is_endless() else -1)
	if index < _preset.item_count:
		_preset.select(index)
	_board_reset()
	if settings.is_endless():
		_message.text = "Вечер: поставьте первые постройки, ночью придёт нежить. Пробел — пауза."
		return
	_message.text = "Подготовка: перетащите постройки из лавки. Башня на такую же — слияние, ПКМ — поворот, сброс на лавку — продажа." \
		if trial.phase == RitualTrial.Phase.PREP else "Контрольный старт на паузе: перенос требует времени, продажа возвращает половину цены."


func _board_reset() -> void:
	board.trial = trial
	board.selected_id = 0
	board.preview_index = -1
	board.preview_rotation = 0
	board.action = &""
	_paused = true
	_pause_count = 0
	_paused_seconds = 0.0
	_saved_result = false
	_accumulator = 0.0
	if _defeat != null:
		_defeat.hide()
	# Бесконечный забег идёт сразу: вечер и есть время на подготовку (docs/34 §8).
	_paused = not settings.is_endless()
	_refresh()


func _issue(command: RitualCommand) -> bool:
	var error: String = trial.execute(command)
	_message.text = error if not error.is_empty() else "Приказ принят"
	_refresh()
	return error.is_empty()


func _start() -> void:
	if _issue(RitualCommand.new(RitualCommand.Action.START)):
		_paused = false
		_accumulator = 0.0
	_refresh()


func _pause() -> void:
	if trial.phase == RitualTrial.Phase.PREP:
		_start()
		return
	_paused = not _paused
	if _paused:
		_pause_count += 1
	_accumulator = 0.0
	_refresh()


func _step() -> void:
	if trial.phase == RitualTrial.Phase.PREP:
		if not _issue(RitualCommand.new(RitualCommand.Action.START)):
			return
	_paused = true
	trial.tick()
	_refresh()


func _process(delta: float) -> void:
	if trial == null:
		return
	if _paused and trial.phase == RitualTrial.Phase.RUNNING:
		_paused_seconds += delta
	if not _paused and trial.phase == RitualTrial.Phase.RUNNING:
		_accumulator += delta * settings.combat.ticks_per_second
		var steps: int = mini(MAX_FRAME_TICKS, int(_accumulator))
		for index: int in steps:
			trial.tick()
		_accumulator -= steps
	if trial.phase == RitualTrial.Phase.OVER and not _saved_result:
		_save_result()
		if settings.is_endless():
			_show_defeat()
	_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.keycode == KEY_Q and not _skill_button.disabled:
			_choose_skill()
		elif key.keycode == KEY_F and not _palisade_button.disabled:
			_choose_palisade()
		elif key.keycode == KEY_SPACE:
			_pause()
	if event.is_action_pressed(&"ui_cancel"):
		if _schedule.visible:
			_hide_schedule()
			get_viewport().set_input_as_handled()
			return
		board.preview_index = -1
		board.action = &""
		board.selected_id = 0
		_refresh()


func _choose_purchase(index: int) -> void:
	board.preview_index = index
	board.selected_id = 0
	board.preview_rotation = 0
	board.action = &"buy"
	_message.text = "Выберите свободные клетки. ПКМ поворачивает фигуру."


func _buy_rite(index: int) -> void:
	_issue(RitualCommand.new(RitualCommand.Action.RITE, index))


func _choose_enchant(index: int) -> void:
	_enchant_index = index
	board.action = &"enchant"
	board.preview_index = -1
	_message.text = "Выберите башню для чары «%s». ПКМ — отмена." % settings.enchants[index].display_name


## Состояние лавки для проверок (smoke не обращается к лавке напрямую: так при выходе
## оставались в памяти статические кэши иконок).
func shop_report() -> Dictionary[String, Variant]:
	return {"cards": _shop.visible_offer_count(), "reroll": _shop._reroll.is_visible_in_tree(),
		"enchants": _shop.has_enchants()}


func _reroll() -> void:
	_issue(RitualCommand.new(RitualCommand.Action.REROLL))


func _repair_houses(tower_id: int) -> void:
	_issue(RitualCommand.new(RitualCommand.Action.REPAIR_HOUSE, 0, Vector2i.ZERO, 0, tower_id))


func _repair_selected() -> void:
	_repair_houses(board.selected_id)


func _refresh_wear(selected: TowerState) -> void:
	if _repair_all_button == null:
		return
	var total: int = trial.repair_all_cost()
	_repair_all_button.text = "Починить всё · %d" % total
	_repair_all_button.disabled = total == 0 or trial.gold < total
	var one: int = trial.repair_cost(selected) if selected != null else 0
	_repair_house_button.visible = one > 0
	_repair_house_button.text = "Починить дом · %d" % one
	_repair_house_button.disabled = trial.gold < one


func _repair() -> void:
	_issue(RitualCommand.new(RitualCommand.Action.REPAIR))


func _grow() -> void:
	if _issue(RitualCommand.new(RitualCommand.Action.STREET)):
		var street: RitualStreetData = settings.streets[trial.street_nights.size() - 1]
		_message.text = "%s пристроена: места под дома уже открыты, вход для нежити — с ночи %d" % [
			street.title, trial.street_nights[-1]]


## Кнопка улицы: цена следующей; город упёрся в предел — серая.
func _refresh_streets() -> void:
	if _street_button == null:
		return
	if not trial.can_grow():
		_street_button.text = "Проклятая земля"
		_street_button.tooltip_text = "Дальше — проклятая земля: больше улиц не пристроить."
		_street_button.disabled = true
		return
	var street: RitualStreetData = settings.streets[trial.street_nights.size()]
	_street_button.text = "Новая улица · %d" % street.cost
	_street_button.tooltip_text = "%s: места под дома — сразу, новый вход для нежити — со следующей ночи.\nКвартал пустой: застройте его, иначе враги прорвутся." % street.title
	_street_button.disabled = trial.phase != RitualTrial.Phase.RUNNING or trial.gold < street.cost


func _choose_skill() -> void:
	board.action = &"skill"
	board.preview_index = -1
	_message.text = "Укажите точку дороги. Число у врага — текущий прогноз урона; замах 1 с."


func _choose_palisade() -> void:
	board.action = &"palisade"
	board.preview_index = -1
	_message.text = "Укажите дорогу: установка 2 с, первый тяжёлый расходует частокол."


func _choose_move() -> void:
	var tower: TowerState = trial.field.get_tower(board.selected_id)
	if tower == null:
		_message.text = "Сначала выберите башню"
		return
	board.preview_rotation = tower.rotation
	board.preview_index = -1
	board.action = &"move"
	_message.text = "Выберите место переноса. Во время установки башня не работает."


func _sell() -> void:
	if _issue(RitualCommand.new(RitualCommand.Action.SELL, 0, Vector2i.ZERO, 0, board.selected_id)):
		board.selected_id = 0
		board.action = &""


func _cancel_move() -> void:
	_issue(RitualCommand.new(RitualCommand.Action.CANCEL_MOVE, 0, Vector2i.ZERO, 0, board.selected_id))


func _on_cell(cell: Vector2i, right: bool) -> void:
	if right:
		if board.action in [&"buy", &"move"]:
			board.preview_rotation = (board.preview_rotation + 1) % TowerState.ROTATIONS
		elif board.action in [&"skill", &"palisade", &"enchant"]:
			# ПКМ при прицеливании — отмена, а не поворот башни под курсором.
			board.action = &""
			_message.text = "Отменено"
		else:
			var tower: TowerState = trial.field.get_tower_at(cell)
			if tower != null:
				_issue(RitualCommand.new(RitualCommand.Action.MOVE, 0, tower.anchor,
					tower.rotation + 1, tower.id))
		board.queue_redraw()
		return
	match board.action:
		&"buy":
			var twin: TowerState = trial.field.get_tower_at(cell)
			var into: int = twin.id if twin != null and twin.level == 1 \
					and twin.data == settings.combat.towers[board.preview_index] else 0
			if _issue(RitualCommand.new(RitualCommand.Action.BUY, board.preview_index, cell,
					board.preview_rotation, into)):
				board.action = &""
				board.preview_index = -1
		&"move":
			var twin: TowerState = trial.field.get_tower_at(cell)
			var moving: TowerState = trial.field.get_tower(board.selected_id)
			var command: RitualCommand = RitualCommand.new(RitualCommand.Action.MOVE, 0, cell,
				board.preview_rotation, board.selected_id)
			if twin != null and moving != null and twin != moving and twin.data == moving.data:
				command = RitualCommand.new(RitualCommand.Action.MERGE, twin.id, Vector2i.ZERO, 0, moving.id)
			if _issue(command):
				board.action = &""
				board.selected_id = twin.id if command.action == RitualCommand.Action.MERGE else board.selected_id
		&"enchant":
			var target: TowerState = trial.field.get_tower_at(cell)
			if target == null:
				_message.text = "Выберите башню для чары"
			elif _issue(RitualCommand.new(RitualCommand.Action.ENCHANT, _enchant_index, Vector2i.ZERO, 0, target.id)):
				board.action = &""
				board.selected_id = target.id
		&"skill", &"palisade":
			var spot: Vector2i = board.road_spot(cell)
			var kind: RitualCommand.Action = RitualCommand.Action.SKILL if board.action == &"skill" \
					else RitualCommand.Action.PALISADE
			if _issue(RitualCommand.new(kind, spot.x, Vector2i.ZERO, 0, 0, spot.y)):
				board.action = &""
		_:
			var tower: TowerState = trial.field.get_tower_at(cell)
			board.selected_id = tower.id if tower != null else 0
	_refresh()


func _capture(path: String = RitualTrialRecord.SNAPSHOT_PATH) -> void:
	_checkpoint = trial.snapshot()
	var error: String = RitualTrialRecord.save_checkpoint(trial, path)
	_message.text = "Снимок сохранён: " + path.trim_prefix("res://") if error.is_empty() else error


func _load_checkpoint() -> void:
	var loaded: RitualTrial = RitualTrialRecord.load_checkpoint(settings)
	if loaded == null:
		_message.text = "Нет подходящего сохранённого снимка"
		return
	_checkpoint = loaded.snapshot()
	_message.text = "Снимок открыт; выберите ветку и нажмите «Ветка из снимка»"


func _restore_branch() -> void:
	if _checkpoint.is_empty():
		_message.text = "Сначала сделайте или откройте снимок"
		return
	var restored: RitualTrial = RitualTrial.from_snapshot(settings, _checkpoint)
	if restored == null:
		_message.text = "Снимок несовместим"
		return
	trial = restored if _branch.selected == 0 else restored.fork_control(_branch.selected as RitualTrial.ControlMode)
	_board_reset()
	_message.text = "Восстановлено исходное состояние. Продолжите бой; новые ветки не наследуют изменения друг друга."


func _save_result() -> void:
	var path: String = RitualTrialRecord.save_result(trial,
		{"pause_count": _pause_count, "paused_seconds": snappedf(_paused_seconds, 0.1)})
	if path.is_empty():
		_message.text = "Не удалось сохранить запись опыта"
		return
	_saved_result = trial.phase == RitualTrial.Phase.OVER
	_attempts.append("%s: HP %d, живых %d" % [trial.title, trial.hp, trial.field.count_alive_mobs()])
	if _attempts.size() > 3:
		_attempts.remove_at(0)
	_history.text = " | ".join(_attempts)
	_message.text = "Запись: " + path.trim_prefix("res://")


func _refresh() -> void:
	if trial == null:
		return
	_hud.refresh_ritual(trial, _paused)
	_refresh_gifts()
	_shop.refresh_ritual(trial)
	for index: int in _idol_slots.size():
		var slot: RitualIdolSlot = _idol_slots[index] as RitualIdolSlot
		slot.trial = trial
		slot.refresh(trial.field.idols[index], true, settings.combat.ticks_per_second)
	var selected: TowerState = trial.field.get_tower(board.selected_id)
	_selection.text = "Башня: не выбрана" if selected == null else _selection_text(selected)
	_refresh_wear(selected)
	_refresh_streets()
	_repair_button.disabled = trial.phase != RitualTrial.Phase.RUNNING or trial.hp >= settings.hero_hp \
			or trial.gold < settings.repair_cost
	_shop._selection_panel.visible = selected != null
	if settings.is_endless():
		_scout.refresh(trial)
	var threats: PackedStringArray = _threat_names()
	_threat.text = trial.result if trial.phase == RitualTrial.Phase.OVER else "Далее: " + " · ".join(threats)
	board.queue_redraw()


## Выбранная постройка: материал (уровень) и что он даёт, вложения и готовность.
func _selection_text(tower: TowerState) -> String:
	var behavior: RitualLevelBehavior = settings.level_behavior(tower)
	var level: String = "ур. %d" % tower.level if behavior == null \
			else "%s (%d)" % [settings.level_name(tower.level), tower.level]
	var lines: PackedStringArray = ["#%d %s · %s%s" % [tower.id, tower.data.display_name, level,
		_enchant_names(tower)]]
	var state: String = "устанавливается" if tower.is_action_blocked() else "готова"
	if behavior == null:
		lines.append("Вложено %d · %s" % [tower.invested_total, state])
		return "\n".join(lines)
	# Одной строкой: вторая строка панели выбора уходит под всплывающее сообщение внизу поля.
	var wear: String = ""
	if tower.durability >= 0:
		var full: int = settings.max_durability(tower.level)
		wear = " · прочность %d%%%s" % [tower.durability * 100 / full,
			" — молчит" if tower.durability == 0 else " — ослаб" if tower.durability * 2 <= full else ""]
	return "%s — %s%s · вложено %d%s" % [lines[0], behavior.note, wear, tower.invested_total,
		" · устанавливается" if tower.is_action_blocked() else ""]


func _threat_names() -> PackedStringArray:
	var threats: PackedStringArray = []
	if settings.is_endless():
		for pack: RitualPack in trial.night_queue():
			threats.append("%s ×%d" % [settings.enemies[pack.leader].display_name, pack.members.size()])
		return threats
	for index: int in range(trial.next_spawn, mini(trial.next_spawn + 3, settings.spawns.size())):
		var spawn: RitualSpawn = settings.spawns[index]
		threats.append("%d:%02d %s" % [spawn.at_tick / 1200, (spawn.at_tick / 20) % 60,
			settings.enemies[spawn.mob_index].display_name])
	return threats


func _enchant_names(tower: TowerState) -> String:
	var names: PackedStringArray = []
	for rite: RiteData in settings.enchants:
		if tower.has_enchantment(rite.effect):
			names.append(rite.display_name)
	return "" if names.is_empty() else "\n" + ", ".join(names)


func _back() -> void:
	ScenePaths.go_to(get_tree(), ScenePaths.MAIN_MENU)


func _toggle_tools() -> void:
	var controls: Control = find_child("TrialTools", true, false) as Control
	controls.visible = not controls.visible


func _sell_tower(tower_id: int) -> void:
	board.selected_id = tower_id
	_sell()

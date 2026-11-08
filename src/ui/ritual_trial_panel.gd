class_name RitualTrialPanel
extends Control
## Отдельный проверочный режим; основной матч не загружается и не изменяется.

const SETTINGS: RitualTrialConfig = preload("res://data/ritual/trial.tres")
const MAX_FRAME_TICKS: int = 8
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
	_shop.setup_ritual(SETTINGS)
	_shop.purchase_chosen.connect(_choose_purchase)
	_shop.rite_chosen.connect(_buy_rite)
	_shop.start_requested.connect(_start)
	_shop.sell_requested.connect(_sell_tower)
	var edit: HBoxContainer = HBoxContainer.new()
	left.add_child(edit)
	_button(edit, "Перенести", _choose_move)
	_button(edit, "Продать", _sell)
	_button(edit, "Отмена", _cancel_move)
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
	# Техническая строка опыта сохранена отдельно от интерфейса PvP.
	var tools: VBoxContainer = VBoxContainer.new()
	root_box.add_child(tools)
	var controls: HFlowContainer = HFlowContainer.new()
	controls.name = "TrialTools"
	controls.visible = false
	tools.add_child(controls)
	_preset = OptionButton.new()
	for loadout: RitualLoadout in SETTINGS.loadouts:
		_preset.add_item(loadout.title)
	controls.add_child(_preset)
	_button(controls, "Заново", _reset_selected)
	_button(controls, "Один тик", _step)
	_button(controls, "Снимок", _capture)
	_button(controls, "Открыть снимок", _load_checkpoint)
	_branch = OptionButton.new()
	for text: String in ["Свободное продолжение", "Без команд", "Только приёмы", "Приёмы + переносы"]:
		_branch.add_item(text)
	controls.add_child(_branch)
	_button(controls, "Ветка из снимка", _restore_branch)
	_button(controls, "Сохранить итог", _save_result)
	_button(controls, "Расписание · все сутки", _show_schedule)
	_button(controls, "В меню", _back)
	_threat = _hud._siege_label
	_hud._siege_panel.show()
	var toast: PanelContainer = PanelContainer.new()
	toast.add_theme_stylebox_override("panel", DuskTheme.glass(0.82, 8))
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast)
	toast.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	toast.offset_left = 356
	toast.offset_right = -20
	toast.offset_top = -152
	toast.offset_bottom = -122
	_message = _label(toast, "", 12)
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_history = _label(controls, "", 10)
	_history.hide()
	_build_schedule()


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
	for cycle: int in SETTINGS.cycles:
		var column: VBoxContainer = VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 3)
		columns.add_child(column)
		_label(column, "Сутки %d" % (cycle + 1), 21)
		for spawn: RitualSpawn in SETTINGS.spawns:
			if spawn.at_tick / SETTINGS.cycle_ticks != cycle:
				continue
			var seconds: int = spawn.at_tick / SETTINGS.combat.ticks_per_second
			var row: Label = _label(column, "%d:%02d  %s" % [seconds / 60, seconds % 60,
				SETTINGS.enemies[spawn.mob_index].display_name], 15)
			row.tooltip_text = SETTINGS.enemies[spawn.mob_index].description
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
	trial = RitualTrial.new(SETTINGS, index)
	_preset.select(index)
	_board_reset()
	_message.text = "Подготовка: перетащите постройки из лавки. ПКМ — поворот, сброс на лавку — продажа." \
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
		_accumulator += delta * SETTINGS.combat.ticks_per_second
		var steps: int = mini(MAX_FRAME_TICKS, int(_accumulator))
		for index: int in steps:
			trial.tick()
		_accumulator -= steps
	if trial.phase == RitualTrial.Phase.OVER and not _saved_result:
		_save_result()
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
		else:
			var tower: TowerState = trial.field.get_tower_at(cell)
			if tower != null:
				_issue(RitualCommand.new(RitualCommand.Action.MOVE, 0, tower.anchor,
					tower.rotation + 1, tower.id))
		board.queue_redraw()
		return
	match board.action:
		&"buy":
			if _issue(RitualCommand.new(RitualCommand.Action.BUY, board.preview_index, cell, board.preview_rotation)):
				board.action = &""
				board.preview_index = -1
		&"move":
			if _issue(RitualCommand.new(RitualCommand.Action.MOVE, 0, cell, board.preview_rotation, board.selected_id)):
				board.action = &""
		&"skill", &"palisade":
			var progress: int = board.path_progress(cell)
			var kind: RitualCommand.Action = RitualCommand.Action.SKILL if board.action == &"skill" \
					else RitualCommand.Action.PALISADE
			if _issue(RitualCommand.new(kind, 0, Vector2i.ZERO, 0, 0, progress)):
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
	var loaded: RitualTrial = RitualTrialRecord.load_checkpoint(SETTINGS)
	if loaded == null:
		_message.text = "Нет подходящего сохранённого снимка"
		return
	_checkpoint = loaded.snapshot()
	_message.text = "Снимок открыт; выберите ветку и нажмите «Ветка из снимка»"


func _restore_branch() -> void:
	if _checkpoint.is_empty():
		_message.text = "Сначала сделайте или откройте снимок"
		return
	var restored: RitualTrial = RitualTrial.from_snapshot(SETTINGS, _checkpoint)
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
	_shop.refresh_ritual(trial)
	for index: int in _idol_slots.size():
		var slot: RitualIdolSlot = _idol_slots[index] as RitualIdolSlot
		slot.trial = trial
		slot.refresh(trial.field.idols[index], true, SETTINGS.combat.ticks_per_second)
	var selected: TowerState = trial.field.get_tower(board.selected_id)
	_selection.text = "Башня: не выбрана" if selected == null else "#%d %s\nВложено %d · %s" % [
		selected.id, selected.data.display_name, selected.invested_total,
		"устанавливается" if selected.is_action_blocked() else "готова"]
	_shop._selection_panel.visible = selected != null
	var threats: PackedStringArray = []
	for index: int in range(trial.next_spawn, mini(trial.next_spawn + 3, SETTINGS.spawns.size())):
		var spawn: RitualSpawn = SETTINGS.spawns[index]
		threats.append("%d:%02d %s" % [spawn.at_tick / 1200, (spawn.at_tick / 20) % 60,
			SETTINGS.enemies[spawn.mob_index].display_name])
	_threat.text = trial.result if trial.phase == RitualTrial.Phase.OVER else "Далее: " + " · ".join(threats)
	board.queue_redraw()


func _back() -> void:
	ScenePaths.go_to(get_tree(), ScenePaths.MAIN_MENU)


func _toggle_tools() -> void:
	var controls: Control = find_child("TrialTools", true, false) as Control
	controls.visible = not controls.visible


func _sell_tower(tower_id: int) -> void:
	board.selected_id = tower_id
	_sell()

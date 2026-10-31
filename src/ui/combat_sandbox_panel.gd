class_name CombatSandboxPanel
extends Control
## Админская песочница: свободная расстановка, настоящие тики и ручные попадания.

var sandbox: CombatSandbox
var _view: FieldView
var _tower: OptionButton
var _level: SpinBox
var _rotation: OptionButton
var _enchant: OptionButton
var _awaken: OptionButton
var _mob: OptionButton
var _mob_types: Array[MobData] = []
var _hp: SpinBox
var _stationary: CheckBox
var _auto: CheckBox
var _mode: OptionButton
var _target: OptionButton
var _inspector: Label
var _metrics: Label
var _journal: Label
var _notice: Label
var _play: Button
var _running: bool = false
var _elapsed: float = 0.0
var _selected_tower: int = 0
var _selected_mob: int = 0


func _ready() -> void:
	ScreenFit.apply(get_window())
	sandbox = CombatSandbox.new(load("res://data/game_config.tres") as GameConfig)
	_build_ui()
	_refresh()


func _build_ui() -> void:
	var margin: MarginContainer = MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	var body: HBoxContainer = HBoxContainer.new()
	margin.add_child(body)
	var controls: VBoxContainer = VBoxContainer.new()
	controls.custom_minimum_size.x = 430
	body.add_child(controls)
	_label(controls, "Песочница боя · без золота и драфта", 23)
	_button(controls, "В меню", _back)
	_mode = _options(controls, ["ЛКМ: поставить башню", "ЛКМ по дороге: поставить юнита",
			"ЛКМ: выбрать башню / цель", "ЛКМ: удалить башню"])
	_tower = OptionButton.new()
	controls.add_child(_tower)
	for data: TowerData in sandbox.config.towers:
		_tower.add_item("%s · %s" % [IdolSlot.god_name(data.god), data.display_name])
	var row: HBoxContainer = HBoxContainer.new()
	controls.add_child(row)
	_label(row, "Уровень", 16)
	_level = _spin(row, 1, sandbox.config.max_tower_level, 1)
	_rotation = _options(row, ["↑ 0°", "→ 90°", "↓ 180°", "← 270°"])
	_enchant = _options(controls, ["Чары: нет", "Чары: сила", "Чары: ритм", "Чары: дальность"])
	_awaken = _options(controls, ["Пробуждение: нет", "Пробуждение: размах", "Пробуждение: сила"])
	_label(controls, "Юниты: любые ресурсы из data/mobs", 16)
	_mob = OptionButton.new()
	controls.add_child(_mob)
	var names: PackedStringArray = DirAccess.get_files_at("res://data/mobs")
	names.sort()
	for name: String in names:
		if not name.ends_with(".tres"):
			continue
		var data: MobData = load("res://data/mobs/" + name) as MobData
		if data != null:
			_mob_types.append(data)
			_mob.add_item(data.display_name)
	row = HBoxContainer.new()
	controls.add_child(row)
	_label(row, "HP (0 = из ресурса)", 16)
	_hp = _spin(row, 0, 1000000, 0)
	_stationary = CheckBox.new()
	_stationary.text = "Неподвижные цели"
	_stationary.button_pressed = true
	controls.add_child(_stationary)
	_button(controls, "Добавить 5 целей в начале дороги", _pack)
	_target = OptionButton.new()
	controls.add_child(_target)
	_target.item_selected.connect(_choose_target)
	_button(controls, "Выбранная башня → удар по выбранной цели", _strike)
	_label(controls, "Ручной удар игнорирует дальность и перезарядку.\n" +
			"Ветер работает при ходе времени.", 14)
	_auto = CheckBox.new()
	_auto.text = "Автострельба (обычные радиусы и темп)"
	_auto.button_pressed = true
	controls.add_child(_auto)
	row = HBoxContainer.new()
	controls.add_child(row)
	_play = _button(row, "▶ Пуск", _toggle)
	_button(row, "+1 тик", _advance.bind(1))
	_button(row, "+1 сек", _advance.bind(sandbox.config.ticks_per_second))
	row = HBoxContainer.new()
	controls.add_child(row)
	_button(row, "Повторить расстановку", _reset)
	_button(row, "Очистить всё", _clear)
	_button(controls, "Пример: Вода → Проклятие", infection_example)
	_notice = _label(controls, "", 15)
	_notice.custom_minimum_size.y = 48
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	_view = FieldView.new()
	_view.custom_minimum_size = Vector2(450, 350)
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.cell_tapped.connect(_on_cell)
	_view.interpolation = 1.0
	right.add_child(_view)
	_inspector = _label(right, "", 16)
	_inspector.custom_minimum_size.y = 78
	_metrics = _label(right, "", 16)
	_metrics.custom_minimum_size.y = 48
	_journal = _label(right, "", 14)
	_journal.custom_minimum_size.y = 210
	_label(right, "Зараза: взрыв → ближайший МОКРЫЙ сосед до 1,5 клетки.\n" +
			"Смерть носителя до взрыва прерывает перенос. Порядок: вода, затем проклятие.", 15)


func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	var interval: float = 1.0 / sandbox.config.ticks_per_second
	var count: int = mini(5, int(_elapsed / interval))
	if count > 0:
		_elapsed -= count * interval
		_step(count)


func _on_cell(cell: Vector2i) -> void:
	_running = false
	var tower: TowerState = sandbox.field.get_tower_at(cell)
	if _mode.selected == 2:
		if tower != null:
			_selected_tower = tower.id
		for mob: MobState in sandbox.field.mobs:
			if sandbox.field.layout.path_cells[mob.progress / FieldState.MILLI] == cell:
				_selected_mob = mob.id
		_refresh()
		return
	var command: SandboxCommand
	match _mode.selected:
		0:
			command = SandboxCommand.new(SandboxCommand.Action.TOWER)
			command.tower = sandbox.config.towers[_tower.selected]
			command.cell = cell
			command.level = int(_level.value)
			command.rotation = _rotation.selected
			command.enchantment = -1 if _enchant.selected == 0 else (
					RiteData.Effect.ENCHANT_DAMAGE + _enchant.selected - 1)
			command.awakening = -1 if _awaken.selected == 0 else (
					RiteData.Effect.AWAKEN_WIDE + _awaken.selected - 1)
		1:
			var index: int = sandbox.field.get_active_path().find(cell)
			if index < 0:
				_notice.text = "Юнита ставим на дорогу"
				return
			command = _mob_command(index * FieldState.MILLI)
		3:
			command = SandboxCommand.new(SandboxCommand.Action.REMOVE)
			command.tower_id = tower.id if tower != null else 0
	_send(command)
	if command.action == SandboxCommand.Action.TOWER and _notice.text == "":
		_selected_tower = sandbox.field.towers[-1].id
	_refresh()


func _mob_command(progress: int) -> SandboxCommand:
	var command: SandboxCommand = SandboxCommand.new(SandboxCommand.Action.MOB)
	command.mob = _mob_types[_mob.selected]
	command.progress = progress
	command.hp = int(_hp.value)
	command.stationary = _stationary.button_pressed
	return command


func _pack() -> void:
	_running = false
	for index: int in 5:
		_send(_mob_command(1000 + index * 500))


func _strike() -> void:
	_running = false
	var command: SandboxCommand = SandboxCommand.new(SandboxCommand.Action.STRIKE)
	command.tower_id = _selected_tower
	command.mob_id = _selected_mob
	_send(command)


func _choose_target(index: int) -> void:
	_selected_mob = _target.get_item_id(index)
	_refresh()


func _toggle() -> void:
	_running = not _running
	_elapsed = 0.0
	_refresh()


func _advance(ticks: int) -> void:
	_running = false
	_step(ticks)


func _step(ticks: int) -> void:
	var command: SandboxCommand = SandboxCommand.new(SandboxCommand.Action.STEP)
	command.ticks = ticks
	command.automatic_fire = _auto.button_pressed
	_send(command)


func _reset() -> void:
	_running = false
	_selected_tower = 0
	_selected_mob = 0
	_send(SandboxCommand.new(SandboxCommand.Action.RESET))


func _clear() -> void:
	_running = false
	_selected_tower = 0
	_selected_mob = 0
	_send(SandboxCommand.new(SandboxCommand.Action.CLEAR))


func _send(command: SandboxCommand) -> void:
	_notice.text = sandbox.execute(command)
	_refresh()


## Готовый эксперимент: две мокрые мишени и один заразный заряд, автострельба отключена.
func infection_example() -> void:
	_clear()
	_auto.button_pressed = false
	for id: StringName in [&"water", &"hex"]:
		var command: SandboxCommand = SandboxCommand.new(SandboxCommand.Action.TOWER)
		command.tower = load("res://data/towers/%s.tres" % id) as TowerData
		command.cell = Vector2i(2, 5) if id == &"water" else Vector2i(0, 5)
		_send(command)
	for index: int in 2:
		var command: SandboxCommand = SandboxCommand.new(SandboxCommand.Action.MOB)
		command.mob = sandbox.config.training_mob
		command.progress = 3000 + index * 500
		_send(command)
	for id: int in [1, 2]:
		var command: SandboxCommand = SandboxCommand.new(SandboxCommand.Action.STRIKE)
		command.tower_id = 1
		command.mob_id = id
		_send(command)
	_selected_tower = 2
	_selected_mob = 1
	_strike()
	_notice.text = "Обе цели мокрые. Проклятие на #1. Нажмите +1 сек трижды и осмотрите #2."
	_refresh()


func _refresh() -> void:
	_view.show_field(sandbox.field, sandbox.config, "ЛКМ: " + _mode.get_item_text(_mode.selected))
	_view.selected_tower_id = _selected_tower
	_play.text = "Ⅱ Пауза" if _running else "▶ Пуск"
	_target.clear()
	if sandbox.find_mob(_selected_mob) == null:
		_selected_mob = 0
	for mob: MobState in sandbox.field.mobs:
		_target.add_item("#%d · %s · HP %d/%d" % [mob.id, mob.data.display_name,
				maxi(0, mob.hp), mob.max_hp], mob.id)
		if _selected_mob == 0:
			_selected_mob = mob.id
		if mob.id == _selected_mob:
			_target.select(_target.item_count - 1)
	var tower: TowerState = sandbox.field.get_tower(_selected_tower)
	var mob: MobState = sandbox.find_mob(_selected_mob)
	_inspector.text = "Башня: " + ("выберите в режиме осмотра" if tower == null else
			"#%d %s ур.%d" % [tower.id, tower.data.display_name, tower.level])
	if mob != null:
		_inspector.text += "\nЦель #%d · HP %d/%d · броня %d · щит %d\n%s" % [
				mob.id, maxi(0, mob.hp), mob.max_hp, mob.armor, mob.shield_left, _statuses(mob)]
	else:
		_inspector.text += "\nЦель погибла/ушла или ещё не выбрана"
	var damage: int = 0
	for value: int in sandbox.field.battle_report.damage_by_kind.values():
		damage += value
	_metrics.text = "Тик %d · урон %d · убито %d\n%s" % [sandbox.field.wave_tick,
			damage, sandbox.field.battle_report.killed,
			ReactionGuide.battle_report(sandbox.config, sandbox.field.reaction_counts)]
	_journal.text = "СОБЫТИЯ · последние 10\n" + "\n".join(sandbox.journal)


func _statuses(mob: MobState) -> String:
	var parts: PackedStringArray = []
	for pair: Array in [["мокрота", mob.wet_ticks_left], ["горение", mob.burn_ticks_left],
			["заряд", mob.charge_ticks_left], ["холод", mob.cold_ticks_left],
			["заморозка", mob.freeze_ticks_left], ["стан", mob.stun_ticks_left]]:
		var ticks: int = pair[1]
		if ticks > 0:
			parts.append("%s %.2fс" % [pair[0], float(ticks) / sandbox.config.ticks_per_second])
	if mob.burn_ticks_left > 0:
		parts.append("огонь %d/с" % mob.burn_damage)
	if mob.curse_ticks_left > 0:
		parts.append("Проклятие %d через %.2fс · заразное: %s" % [mob.curse_damage,
				float(mob.curse_ticks_left) / sandbox.config.ticks_per_second,
				"да" if mob.is_contagious else "нет"])
	return "Без статусов" if parts.is_empty() else " · ".join(parts)


func _button(parent: Node, title: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = title
	button.custom_minimum_size.y = 32
	button.add_theme_font_size_override("font_size", 15)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _label(parent: Node, title: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if parent is HBoxContainer:
		label.custom_minimum_size.x = 160
	parent.add_child(label)
	return label


func _options(parent: Node, titles: Array[String]) -> OptionButton:
	var options: OptionButton = OptionButton.new()
	options.add_theme_font_size_override("font_size", 16)
	for title: String in titles:
		options.add_item(title)
	parent.add_child(options)
	return options


func _spin(parent: Node, minimum: int, maximum: int, initial: int) -> SpinBox:
	var spin: SpinBox = SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.value = initial
	parent.add_child(spin)
	return spin


func _back() -> void:
	ScenePaths.go_to(get_tree(), ScenePaths.MAIN_MENU)

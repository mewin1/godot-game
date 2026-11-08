class_name SiegeTrialPanel
extends Control
## Короткая дуэль с готовыми сборками и двумя осмысленными приказами.

const SETTINGS: SiegeTrialConfig = preload("res://data/siege_trial.tres")
const FIRST_SEED: int = 137
const MAX_FRAME_TICKS: int = 8
const HEROES: Array[StringName] = [SiegeTrial.YAGA, SiegeTrial.GORYNYCH, SiegeTrial.DOMOVOY]

var trial: SiegeTrial
var _own: SiegeFieldView
var _enemy: SiegeFieldView
var _hero: OptionButton
var _reserve: OptionButton
var _start_button: Button
var _release_button: Button
var _skill_button: Button
var _pause_button: Button
var _repeat_button: Button
var _new_button: Button
var _guide: Label
var _clock: Label
var _event: Label
var _own_status: Label
var _enemy_status: Label
var _result: Label
var _comparison: Label
var _previous_trial: SiegeTrial
var _battle_log: SiegeTrialLog
var _log_path: String = ""
var _log_attempted: bool = false
var _accumulator: float = 0.0
var _paused: bool = false
var _seed: int = FIRST_SEED
var _swap_pick_second: bool = false


func _ready() -> void:
	ScreenFit.apply(get_window())
	theme = DuskTheme.create()
	_build_ui()
	_rebuild()


func _build_ui() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.035, 0.055, 0.075)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin: MarginContainer = MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 14)
	var main: VBoxContainer = VBoxContainer.new()
	margin.add_child(main)
	main.add_theme_constant_override("separation", 8)
	var header: HBoxContainer = HBoxContainer.new()
	main.add_child(header)
	var title: Label = _label(header, "Дуэль волхвов · прототип", 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clock = _label(header, "", 21)
	_button(header, "В меню", _back)
	var setup: HBoxContainer = HBoxContainer.new()
	main.add_child(setup)
	_label(setup, "Ваш герой", 18)
	_hero = OptionButton.new()
	_hero.add_item("Баба-Яга")
	_hero.add_item("Змей Горыныч")
	_hero.add_item("Домовой")
	setup.add_child(_hero)
	_hero.item_selected.connect(_on_hero_selected)
	_label(setup, "Подкрепление", 18)
	_reserve = OptionButton.new()
	for plan: SiegeReservePlan in SETTINGS.reserve_plans:
		_reserve.add_item(plan.display_name)
	setup.add_child(_reserve)
	_reserve.item_selected.connect(_on_reserve_selected)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setup.add_child(spacer)
	_repeat_button = _button(setup, "Повторить", _repeat)
	_new_button = _button(setup, "Другой замысел", _new_plan)
	_guide = _label(main, "", 18)
	_guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_guide.custom_minimum_size.y = 50
	var fields: HBoxContainer = HBoxContainer.new()
	fields.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fields.add_theme_constant_override("separation", 14)
	main.add_child(fields)
	var left: VBoxContainer = _column(fields)
	_enemy_status = _label(left, "", 19)
	_enemy = _field(left, 1)
	_enemy.cell_tapped.connect(_on_enemy_cell)
	var right: VBoxContainer = _column(fields)
	_own_status = _label(right, "", 19)
	_own = _field(right, 0)
	_own.cell_tapped.connect(_on_own_cell)
	_result = _label(main, "", 22)
	_result.custom_minimum_size.y = 30
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_comparison = _label(main, "", 18)
	_comparison.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_comparison.visible = false
	var actions: HBoxContainer = HBoxContainer.new()
	main.add_child(actions)
	_release_button = _button(actions, "", _release)
	_release_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_button = _button(actions, "Начать бой", _start)
	_start_button.custom_minimum_size.x = 210
	_start_button.theme_type_variation = &"AccentButton"
	_pause_button = _button(actions, "Пауза", _pause)
	_skill_button = _button(actions, "", _skill)
	_skill_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_event = _label(main, "", 17)
	_event.custom_minimum_size.y = 28


func _field(parent: Container, index: int) -> SiegeFieldView:
	var view: SiegeFieldView = SiegeFieldView.new()
	view.use_arena_3d = true
	view.side_index = index
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.custom_minimum_size = Vector2(350, 320)
	parent.add_child(view)
	return view


func _column(parent: Container) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.0
	parent.add_child(column)
	return column


func _label(parent: Node, value: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _button(parent: Node, title: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = title
	button.custom_minimum_size.y = 44
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _rebuild() -> void:
	var hero: StringName = HEROES[_hero.selected]
	trial = SiegeTrial.new(SETTINGS, hero, _seed)
	_battle_log = SiegeTrialLog.new()
	_log_path = ""
	_log_attempted = false
	var reserve: SiegeTrialCommand = SiegeTrialCommand.new(SiegeTrialCommand.Action.RESERVE, 0, Vector2i.ZERO, _reserve.selected)
	trial.execute(reserve)
	_battle_log.record(reserve, 0)
	_own.trial = trial
	_enemy.trial = trial
	_own.show_field(trial.sides[0].field, SETTINGS.game, "Ваша застава")
	_enemy.show_field(trial.sides[1].field, SETTINGS.game, "Ваша армия атакует здесь")
	_accumulator = 0.0
	_paused = false
	_swap_pick_second = false
	_event.text = "Один бой — до %d с. Победит застава, потерявшая меньше здоровья." % (SETTINGS.max_ticks / SETTINGS.game.ticks_per_second)
	_refresh()


func _process(delta: float) -> void:
	if trial == null or trial.phase != SiegeTrial.Phase.BATTLE or _paused:
		return
	_accumulator += delta
	var interval: float = 1.0 / SETTINGS.game.ticks_per_second
	var ticks: int = mini(MAX_FRAME_TICKS, int(_accumulator / interval))
	if ticks > 0:
		_accumulator -= ticks * interval
		for index: int in ticks:
			trial.tick()
		_refresh()
	_own.interpolation = clampf(_accumulator / interval, 0.0, 1.0)
	_enemy.interpolation = _own.interpolation


func _refresh() -> void:
	var me: SiegeTrialSide = trial.sides[0]
	var foe: SiegeTrialSide = trial.sides[1]
	var prep: bool = trial.phase == SiegeTrial.Phase.PREP
	var battle: bool = trial.phase == SiegeTrial.Phase.BATTLE
	var yaga: bool = me.hero == SiegeTrial.YAGA
	_hero.disabled = not prep
	_reserve.disabled = not prep
	_start_button.visible = prep
	_pause_button.visible = battle
	_pause_button.text = "Продолжить" if _paused else "Пауза"
	_repeat_button.disabled = battle
	_new_button.disabled = battle
	_release_button.disabled = not battle or me.released or _paused
	_skill_button.disabled = not battle or me.skill_used or _paused
	var remaining: int = maxi(0, SETTINGS.reserve_deadline - trial.tick_count)
	var seconds: int = (remaining + SETTINGS.game.ticks_per_second - 1) / SETTINGS.game.ticks_per_second
	var held: int = SETTINGS.reserve_plans[me.reserve_kind].held_count()
	_release_button.text = "Подкрепление вышло" if me.released else "Выпустить %d бойцов · авто через %d с" % [held, seconds]
	_skill_button.text = _skill_status(me) if me.skill_used else _skill_title(me.hero)
	_clock.text = "Подготовка" if prep else "%d с · обычная скорость" % (trial.tick_count / SETTINGS.game.ticks_per_second)
	_own_status.text = "Вы · %s · %d/%d HP" % [_hero_name(me.hero), me.hp, SETTINGS.hero_hp]
	_enemy_status.text = "%s · %d/%d HP · %s" % [_hero_name(foe.hero), foe.hp,
			SETTINGS.hero_hp, _skill_status(foe)]
	_enemy_status.tooltip_text = ""
	if trial.bot_defense_index >= 0:
		var defense: SiegeDefensePlan = SETTINGS.bot_defenses[trial.bot_defense_index]
		_enemy_status.tooltip_text = "%s: %s" % [defense.display_name, defense.description]
	var reserve_name: String = SETTINGS.reserve_plans[foe.reserve_kind].display_name
	_reserve.tooltip_text = SETTINGS.reserve_plans[me.reserve_kind].description
	var instruction: String = "Яга: до боя выберите свою башню, затем свободную площадку справа. Зелёная башня шагает %.1f с без стрельбы." % (float(SETTINGS.walk_ticks) / SETTINGS.game.ticks_per_second) if yaga else "Горыныч: нажмите на поле слева — центр налёта. После предупреждения башни в круге замолчат на %.1f с." % (float(SETTINGS.fire_ticks) / SETTINGS.game.ticks_per_second)
	if me.hero == SiegeTrial.DOMOVOY:
		instruction = "Домовой: до боя нажмите две свои башни по очереди. Обмен занимает %.1f с без стрельбы обеих." % (float(SETTINGS.swap_ticks) / SETTINGS.game.ticks_per_second)
	_guide.text = "%s\nСоперник: %d копейщиков + %s. Подкрепление: %s." % [instruction,
			SETTINGS.main_count, reserve_name,
			"уже вышло" if foe.released else "ждёт приказа"]
	_result.text = trial.result_text() if trial.phase == SiegeTrial.Phase.OVER else ""
	if trial.phase == SiegeTrial.Phase.OVER:
		_guide.text = "%s\n%s" % [_battle_summary(0), _battle_summary(1)]
		if not _log_attempted:
			_log_attempted = true
			_log_path = _battle_log.save(trial)
			if _log_path.is_empty():
				push_warning("Не удалось сохранить журнал дуэли")
	_refresh_comparison()
	if not trial.journal.is_empty():
		_event.text = trial.journal[trial.journal.size() - 1]
	_event.tooltip_text = "\n".join(trial.journal)
	_own.queue_redraw()
	_enemy.queue_redraw()


func _hero_name(hero: StringName) -> String:
	match hero:
		SiegeTrial.YAGA: return "Баба-Яга"
		SiegeTrial.DOMOVOY: return "Домовой"
	return "Горыныч"


func _skill_title(hero: StringName) -> String:
	match hero:
		SiegeTrial.YAGA: return "Избушка, шагай!"
		SiegeTrial.DOMOVOY: return "Домовой, поменяй башни!"
	return "Налёт Горыныча!"


func _skill_status(side: SiegeTrialSide) -> String:
	if trial.phase == SiegeTrial.Phase.OVER:
		return "Приём потрачен" if side.skill_used else "Приём сохранён"
	if side.swap_left > 0:
		return "Обмен · %.1f с" % (float(side.swap_left) / SETTINGS.game.ticks_per_second)
	if side.walk_left > 0:
		return "Шагает · %.1f с" % (float(side.walk_left) / SETTINGS.game.ticks_per_second)
	if side.warning_left > 0:
		return "До налёта · %.1f с" % (float(side.warning_left) / SETTINGS.game.ticks_per_second)
	if side.fire_left > 0:
		return "Налёт · %.1f с" % (float(side.fire_left) / SETTINGS.game.ticks_per_second)
	return "Приём потрачен" if side.skill_used else "Приём готов"


func _battle_summary(index: int) -> String:
	var side: SiegeTrialSide = trial.sides[index]
	var release: String = _order_time(side.released_tick)
	if side.released_automatically:
		release += " (авто)"
	var skill: String = _order_time(side.skill_tick)
	return "%s: приказ — %s; герой — %s; прорывы: первый заход %d, подкрепление %d." % [
			trial.side_name(index), release, skill, side.attack.breaches(false), side.attack.breaches(true)]


func _order_time(tick: int) -> String:
	return "не использовано" if tick < 0 else "%.1f с" % (float(tick) / SETTINGS.game.ticks_per_second)


func _refresh_comparison() -> void:
	_comparison.visible = _previous_trial != null and trial.phase == SiegeTrial.Phase.OVER
	_repeat_button.tooltip_text = "Повторить с тем же сидом, сохранив подготовку"
	if _previous_trial == null:
		return
	var before: SiegeTrialSide = _previous_trial.sides[0]
	_repeat_button.tooltip_text += "\nПрошлая попытка: ваше HP %d, соперника %d.\nПодкрепление: %s; герой: %s." % [
			before.hp, _previous_trial.sides[1].hp, _order_time(before.released_tick), _order_time(before.skill_tick)]
	if _comparison.visible:
		_comparison.text = "Изменение HP к прошлой попытке: ваша застава %+d · соперник %+d" % [
				trial.sides[0].hp - before.hp, trial.sides[1].hp - _previous_trial.sides[1].hp]


func _send(command: SiegeTrialCommand) -> bool:
	var error: String = trial.execute(command)
	if error.is_empty():
		_battle_log.record(command, trial.tick_count)
	_refresh()
	if error != "":
		_event.text = error
	return error.is_empty()


func _on_hero_selected(_index: int) -> void:
	_previous_trial = null
	_rebuild()


func _on_reserve_selected(index: int) -> void:
	_send(SiegeTrialCommand.new(SiegeTrialCommand.Action.RESERVE, 0, Vector2i.ZERO, index))


func _on_own_cell(cell: Vector2i) -> void:
	if trial.sides[0].hero == SiegeTrial.DOMOVOY and trial.phase == SiegeTrial.Phase.PREP:
		var tower: TowerState = trial.sides[0].field.get_tower_at(cell)
		if _swap_pick_second:
			if _send(SiegeTrialCommand.new(SiegeTrialCommand.Action.TARGET, 0, cell)):
				_swap_pick_second = false
		elif tower != null:
			_swap_pick_second = _send(SiegeTrialCommand.new(SiegeTrialCommand.Action.HUT, 0, Vector2i.ZERO, tower.id))
		return
	if trial.sides[0].hero == SiegeTrial.YAGA and trial.phase == SiegeTrial.Phase.PREP:
		var tower: TowerState = trial.sides[0].field.get_tower_at(cell)
		if tower != null:
			_send(SiegeTrialCommand.new(SiegeTrialCommand.Action.HUT, 0, Vector2i.ZERO, tower.id))
		else:
			_send(SiegeTrialCommand.new(SiegeTrialCommand.Action.TARGET, 0, cell))


func _on_enemy_cell(cell: Vector2i) -> void:
	if trial.sides[0].hero == SiegeTrial.GORYNYCH and not trial.sides[0].skill_used:
		_send(SiegeTrialCommand.new(SiegeTrialCommand.Action.TARGET, 0, cell))


func _start() -> void:
	_send(SiegeTrialCommand.new(SiegeTrialCommand.Action.START))


func _release() -> void:
	_send(SiegeTrialCommand.new(SiegeTrialCommand.Action.RELEASE))


func _skill() -> void:
	_send(SiegeTrialCommand.new(SiegeTrialCommand.Action.SKILL))


func _pause() -> void:
	_paused = not _paused
	_refresh()


func _repeat() -> void:
	if trial.phase == SiegeTrial.Phase.OVER:
		_previous_trial = trial
	var previous: SiegeTrialSide = trial.sides[0]
	var target: Vector2i = previous.destination if previous.hero == SiegeTrial.YAGA else previous.target
	_rebuild()
	if previous.hero == SiegeTrial.YAGA:
		_send(SiegeTrialCommand.new(SiegeTrialCommand.Action.HUT, 0, Vector2i.ZERO, previous.walk_tower_id))
	elif previous.hero == SiegeTrial.DOMOVOY:
		_send(SiegeTrialCommand.new(SiegeTrialCommand.Action.HUT, 0, Vector2i.ZERO, previous.walk_tower_id))
		target = trial.sides[0].field.get_tower(previous.swap_tower_id).anchor
	_send(SiegeTrialCommand.new(SiegeTrialCommand.Action.TARGET, 0, target))


func _new_plan() -> void:
	_previous_trial = null
	_seed += 1
	_rebuild()


func _back() -> void:
	ScenePaths.go_to(get_tree(), ScenePaths.MAIN_MENU)


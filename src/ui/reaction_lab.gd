class_name ReactionLab
extends Control
## Пошаговый стенд: кнопки меняют учебный снимок, настоящего матча здесь нет.

const STEP_NAMES: Array[String] = ["0 · Мишени", "1 · Метки", "2 · Реакция", "3 · Последствия"]

var _config: GameConfig
var _selected: int = 0
var _step: int = 0
var _field_view: FieldView
var _explanation: Label
var _report: Label
var _lesson_buttons: Array[Button] = []
var _step_buttons: Array[Button] = []


func _ready() -> void:
	ScreenFit.apply(get_window())
	_config = load("res://data/game_config.tres") as GameConfig
	_build_ui()
	_show_current()


func _build_ui() -> void:
	var margin: MarginContainer = MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	var main: VBoxContainer = VBoxContainer.new()
	margin.add_child(main)
	var header: HBoxContainer = HBoxContainer.new()
	main.add_child(header)
	var title: Label = _label("Стенд реакций · изучайте без спешки", 27)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_button("В меню", _back))
	var body: HBoxContainer = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(body)
	var sidebar: VBoxContainer = VBoxContainer.new()
	sidebar.custom_minimum_size.x = 350
	body.add_child(sidebar)
	_build_lessons(sidebar)
	var steps: GridContainer = GridContainer.new()
	steps.columns = 2
	sidebar.add_child(steps)
	for index: int in STEP_NAMES.size():
		var button: Button = _button(STEP_NAMES[index], show_step.bind(index))
		steps.add_child(button)
		_step_buttons.append(button)
	var explanation: VBoxContainer = VBoxContainer.new()
	explanation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	explanation.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(explanation)
	_explanation = _label("", 19)
	_explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.add_child(_explanation)
	_field_view = FieldView.new()
	_field_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_field_view.custom_minimum_size = Vector2(400, 400)
	_field_view.can_edit = false
	explanation.add_child(_field_view)
	_report = _label("", 17)
	_report.custom_minimum_size.y = 90
	_report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.add_child(_report)


func _build_lessons(sidebar: VBoxContainer) -> void:
	sidebar.add_child(_label("Выберите сочетание", 20))
	for index: int in _config.lessons.size():
		var button: Button = _button(_config.lessons[index].title, _choose_lesson.bind(index))
		sidebar.add_child(button)
		_lesson_buttons.append(button)
	sidebar.add_child(_label("Порядок: метки → удар → последствия", 16))


func _choose_lesson(index: int) -> void:
	_selected = index
	_step = 0
	_show_current()


## Каждый шаг можно повторить и вернуть назад; случайный бросок примера повторяется.
func show_step(step: int) -> void:
	_step = clampi(step, 0, STEP_NAMES.size() - 1)
	_show_current()


func _show_current() -> void:
	var lesson: ReactionLessonData = _config.lessons[_selected]
	var field: FieldState = ReactionLesson.build(_config, lesson, _step)
	_field_view.show_field(field, _config, lesson.title + " · " + STEP_NAMES[_step])
	_field_view.hero_hp = _config.hero_hp
	_field_view.selected_tower_id = field.towers[-1].id
	_explanation.text = lesson.explanation
	var lines: PackedStringArray = []
	for mob: MobState in field.mobs:
		lines.append(_mob_report(mob))
	lines.append(ReactionGuide.battle_report(_config, field.reaction_counts))
	lines.append("Один пример без повторных выстрелов. Время остановлено; шаги можно повторять.")
	_report.text = "\n".join(lines)
	for index: int in _lesson_buttons.size():
		_lesson_buttons[index].disabled = index == _selected
	for index: int in _step_buttons.size():
		_step_buttons[index].disabled = index == _step


func _mob_report(mob: MobState) -> String:
	var parts: PackedStringArray = []
	if mob.wet_ticks_left > 0:
		parts.append("мокрота")
	if mob.charge_ticks_left > 0:
		parts.append("заряд")
	if mob.burn_ticks_left > 0:
		parts.append("горение %d/с" % mob.burn_damage)
	if mob.freeze_ticks_left > 0:
		parts.append("заморозка %.1f с" % (float(mob.freeze_ticks_left) / _config.ticks_per_second))
	elif mob.cold_ticks_left > 0:
		parts.append("холод −%d%% скорости" % mob.cold_slow_percent)
	if mob.curse_ticks_left > 0:
		parts.append("проклятие %d урона через %.1f с" % [mob.curse_damage,
				float(mob.curse_ticks_left) / _config.ticks_per_second])
	if mob.slow_ticks_left > 0:
		parts.append("замедление −%d%%" % mob.slow_percent)
	if mob.stun_ticks_left > 0:
		parts.append("оглушение")
	return "Мишень %d · HP %d/%d · %s" % [mob.id, mob.hp, mob.max_hp,
			"без меток" if parts.is_empty() else " + ".join(parts)]


func _button(text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 34
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	return button


func _label(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _back() -> void:
	ScenePaths.go_to(get_tree(), ScenePaths.MAIN_MENU)

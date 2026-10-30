class_name MatchHud
extends VBoxContainer
## Верх экрана матча: раунд и фаза с таймером, HP / золото / доход с иконками, кнопки паузы,
## скорости и звука; ниже — фишки всех игроков с HP и строка про осаду.
## Только показывает состояние симуляции; нажатия кнопок отдаёт наверх сигналами.

signal pause_pressed()
signal speed_pressed()
signal sound_pressed()
signal skill_pressed()
## Нажали на портрет героя — показать, что он умеет (на телефоне нет наведения).
signal hero_info_pressed()
## Нажали на фишку игрока — показать его героя.
signal player_chip_pressed(player_index: int)

const HEART_ICON: Texture2D = preload("res://assets/ui/icon_heart.svg")
const GOLD_ICON: Texture2D = preload("res://assets/ui/icon_gold.svg")
const INCOME_ICON: Texture2D = preload("res://assets/ui/icon_income.svg")
const SOUND_ON_ICON: Texture2D = preload("res://assets/ui/icon_sound_on.svg")
const SOUND_OFF_ICON: Texture2D = preload("res://assets/ui/icon_sound_off.svg")
const ICON_SIZE: float = 30.0
const VALUE_FONT_SIZE: int = 24
const CHIP_FONT_SIZE: int = 16
const BUTTON_SIZE: Vector2 = Vector2(52, 48)
const DANGER_PULSE_SPEED: float = 5.0
const COLOR_ELIMINATED: Color = Color(1, 1, 1, 0.4)
const PORTRAIT_SIZE: float = 44.0
const CHIP_PORTRAIT_SIZE: float = 26.0

var _round_label: Label
var _phase_label: Label
var _hp_label: Label
var _gold_label: Label
var _income_label: Label
var _pause_button: Button
var _speed_button: Button
var _sound_button: Button
var _chips: Array[PanelContainer] = []
var _chip_labels: Array[Label] = []
var _chip_portraits: Array[TextureRect] = []
var _hero_portrait: TextureRect
var _skill_button: Button
var _siege_panel: PanelContainer
var _siege_label: Label
var _time: float = 0.0
var _player_colors: FieldStyle = VisualCatalog.get_default().field


func _init() -> void:
	add_theme_constant_override("separation", 4)
	var bar: PanelContainer = PanelContainer.new()
	bar.theme_type_variation = &"HudPanel"
	add_child(bar)
	# Flow-контейнер переносит элементы на новую строку на узком (вертикальном) экране.
	var row: HFlowContainer = HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 14)
	row.add_theme_constant_override("v_separation", 2)
	bar.add_child(row)
	_round_label = _add_label(row, VALUE_FONT_SIZE)
	_round_label.theme_type_variation = &"HeaderLabel"
	_round_label.add_theme_font_size_override("font_size", VALUE_FONT_SIZE)
	_phase_label = _add_label(row, 20)
	_phase_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hero_portrait = _make_portrait(PORTRAIT_SIZE)
	_hero_portrait.mouse_filter = Control.MOUSE_FILTER_STOP
	_hero_portrait.gui_input.connect(_on_hero_portrait_gui_input)
	row.add_child(_hero_portrait)
	_skill_button = _add_button(row, "", "Навык героя")
	_skill_button.theme_type_variation = &"AccentButton"
	_skill_button.add_theme_font_size_override("font_size", 17)
	_skill_button.pressed.connect(func() -> void: skill_pressed.emit())
	_hp_label = _add_value(row, HEART_ICON, "HP героя")
	_gold_label = _add_value(row, GOLD_ICON, "Золото")
	_income_label = _add_value(row, INCOME_ICON, "Доход за раунд")
	_pause_button = _add_button(row, "II", "Пауза")
	_pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	_speed_button = _add_button(row, "×1", "Скорость")
	_speed_button.pressed.connect(func() -> void: speed_pressed.emit())
	_sound_button = _add_button(row, "", "Звук")
	_sound_button.icon = SOUND_ON_ICON
	_sound_button.expand_icon = true
	_sound_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sound_button.pressed.connect(func() -> void: sound_pressed.emit())
	_build_lobby_row()
	_siege_panel = PanelContainer.new()
	_siege_panel.theme_type_variation = &"DangerPanel"
	_siege_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_siege_panel.visible = false
	add_child(_siege_panel)
	_siege_label = _add_label(_siege_panel, 20)
	_siege_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _process(delta: float) -> void:
	_time += delta
	if _siege_panel.visible and _siege_panel.theme_type_variation == &"DangerPanel":
		_siege_panel.modulate.a = 0.75 + 0.25 * sin(_time * DANGER_PULSE_SPEED)
	else:
		_siege_panel.modulate.a = 1.0


## Обновляет все надписи по состоянию матча (каждый кадр).
func refresh(sim: MatchSim, human_index: int) -> void:
	var me: PlayerState = sim.players[human_index]
	_round_label.text = "Раунд %d" % sim.round_number
	_phase_label.text = _phase_text(sim)
	_hp_label.text = str(maxi(0, me.hero_hp))
	_gold_label.text = str(me.gold)
	_income_label.text = "+%d" % me.get_total_income()
	_refresh_hero(sim, me)
	_refresh_chips(sim, human_index)
	_refresh_siege(sim, human_index)


func set_paused(is_paused: bool) -> void:
	_pause_button.text = "▶" if is_paused else "II"


func set_speed(speed: int) -> void:
	_speed_button.text = "×%d" % speed


func set_muted(is_muted: bool) -> void:
	_sound_button.icon = SOUND_OFF_ICON if is_muted else SOUND_ON_ICON


## Портрет героя и кнопка навыка: цена, доступность, подсказка с описанием.
func _refresh_hero(sim: MatchSim, me: PlayerState) -> void:
	_hero_portrait.texture = HeroPortraits.get_portrait(me.hero)
	_hero_portrait.visible = me.hero != null
	if me.hero != null:
		_hero_portrait.tooltip_text = "%s: %s" % [me.hero.display_name, me.hero.description]
	var skill: HeroSkillData = me.hero.skill if me.hero != null else null
	_skill_button.visible = skill != null
	if skill == null:
		return
	var reason: String = me.check_skill_available(sim.phase)
	var cost: int = me.get_skill_cost()
	_skill_button.text = "%s · %d зол." % [skill.display_name, cost]
	_skill_button.disabled = reason != "" or me.gold < cost or not me.is_alive
	# Навык можно нажать — кнопка мягко «дышит», чтобы про неё не забывали.
	var pulse: float = 0.85 + 0.15 * sin(_time * DANGER_PULSE_SPEED)
	var brightness: float = pulse if not _skill_button.disabled else 1.0
	_skill_button.modulate = Color(brightness, brightness, brightness, 1.0)
	_skill_button.tooltip_text = "%s (%s)%s" % [skill.description, skill.get_timing_text(),
			"\n" + reason if reason != "" else ""]


func _phase_text(sim: MatchSim) -> String:
	match sim.phase:
		MatchSim.Phase.PREP:
			var ticks_left: float = float(sim.get_phase_ticks_left())
			var seconds: int = ceili(ticks_left / sim.config.ticks_per_second)
			return "Подготовка · %d с" % seconds
		MatchSim.Phase.WAVE:
			return _wave_text(sim)
		MatchSim.Phase.HERO_SELECT:
			return "Выбор героя"
	return "Матч окончен"


## Волна: сколько осталось до ярости; в ярости — сколько до прорыва всех оставшихся.
func _wave_text(sim: MatchSim) -> String:
	var config: GameConfig = sim.config
	var ticks_left: int = config.wave_max_ticks - sim.phase_tick
	if config.synchronized_battle:
		return "Бой · %d с · темп ×%d" % [
				ceili(float(maxi(0, ticks_left)) / config.ticks_per_second), sim.get_battle_speed()]
	if ticks_left > 0:
		return "Волна · %d с" % ceili(float(ticks_left) / config.ticks_per_second)
	ticks_left = maxi(0, ticks_left + config.wave_enrage_extra_ticks)
	return "ЯРОСТЬ! мобы ускорились · %d с" % ceili(float(ticks_left) / config.ticks_per_second)


func _refresh_chips(sim: MatchSim, human_index: int) -> void:
	var opponent_index: int = MatchSim.GHOST
	if human_index < sim.opponent_of.size():
		opponent_index = sim.opponent_of[human_index]
	var ghost_index: int = sim.ghost_source if sim.ghost_target == human_index else -1
	for player: PlayerState in sim.players:
		var chip: PanelContainer = _chips[player.index]
		var label: Label = _chip_labels[player.index]
		var display_name: String = "Вы" if player.index == human_index else player.display_name
		label.add_theme_color_override("font_color", _player_colors.get_player_color(player.index))
		_chip_portraits[player.index].texture = HeroPortraits.get_portrait(player.hero)
		if player.hero != null:
			chip.tooltip_text = "%s — %s" % [player.hero.display_name, player.hero.description]
		if not player.is_alive:
			label.text = "%s · %d место" % [display_name, player.place]
			chip.modulate = COLOR_ELIMINATED
			chip.theme_type_variation = &"CardPanel"
			continue
		var mark: String = ""
		if player.index == ghost_index:
			mark = " (призрак)"
		label.text = "%s ♥%d%s" % [display_name, maxi(0, player.hero_hp), mark]
		chip.modulate = Color.WHITE
		var is_rival: bool = player.index == opponent_index or player.index == ghost_index \
				or (sim.siege_leader == human_index and sim.siege_attackers.has(player.index))
		chip.theme_type_variation = &"CardPanelActive" if is_rival else &"CardPanel"


## Осада: красное мигающее предупреждение, если двое идут на вас; спокойная строка — иначе.
func _refresh_siege(sim: MatchSim, human_index: int) -> void:
	_siege_panel.visible = sim.phase != MatchSim.Phase.OVER and sim.players[human_index].is_alive
	if not _siege_panel.visible:
		return
	if sim.siege_leader == human_index:
		var names: PackedStringArray = []
		for index: int in sim.siege_attackers:
			names.append(sim.players[index].display_name)
		_siege_panel.theme_type_variation = &"DangerPanel"
		_siege_label.text = "⚠ ОСАДА! На вас идут сразу двое: %s" % " и ".join(names)
		return
	_siege_panel.theme_type_variation = &"CardPanel"
	if sim.siege_attackers.has(human_index):
		_siege_label.text = "Осада: вы вместе с союзником атакуете лидера — %s" % \
				sim.players[sim.siege_leader].display_name
	elif sim.siege_leader >= 0:
		_siege_label.text = "Осада: двое слабейших атакуют лидера — %s" % \
				sim.players[sim.siege_leader].display_name
	elif sim.phase != MatchSim.Phase.OVER and sim.is_siege_round(sim.round_number + 1):
		_siege_label.text = "Следующий раунд — осада: двое слабейших атакуют сильнейшего"
	else:
		_siege_panel.visible = false


func _build_lobby_row() -> void:
	var row: HFlowContainer = HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 4)
	add_child(row)
	for i: int in 8:
		var chip: PanelContainer = PanelContainer.new()
		chip.theme_type_variation = &"CardPanel"
		chip.visible = false
		row.add_child(chip)
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		chip.gui_input.connect(_on_chip_gui_input.bind(i))
		var chip_box: HBoxContainer = HBoxContainer.new()
		chip_box.add_theme_constant_override("separation", 4)
		chip.add_child(chip_box)
		var portrait: TextureRect = _make_portrait(CHIP_PORTRAIT_SIZE)
		chip_box.add_child(portrait)
		var label: Label = _add_label(chip_box, CHIP_FONT_SIZE)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_chips.append(chip)
		_chip_labels.append(label)
		_chip_portraits.append(portrait)


## Показывает столько фишек, сколько игроков в матче.
func set_player_count(count: int) -> void:
	for i: int in _chips.size():
		_chips[i].visible = i < count


func _on_hero_portrait_gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		hero_info_pressed.emit()


func _on_chip_gui_input(event: InputEvent, player_index: int) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		player_chip_pressed.emit(player_index)


func _make_portrait(portrait_size: float) -> TextureRect:
	var portrait: TextureRect = TextureRect.new()
	portrait.custom_minimum_size = Vector2.ONE * portrait_size
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return portrait


func _add_label(parent: Control, font_size: int) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label


func _add_value(parent: Control, icon: Texture2D, hint: String) -> Label:
	var box: HBoxContainer = HBoxContainer.new()
	box.tooltip_text = hint
	box.add_theme_constant_override("separation", 4)
	parent.add_child(box)
	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.texture = icon
	icon_rect.custom_minimum_size = Vector2.ONE * ICON_SIZE
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(icon_rect)
	return _add_label(box, VALUE_FONT_SIZE)


func _add_button(parent: Control, text: String, hint: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.tooltip_text = hint
	button.custom_minimum_size = BUTTON_SIZE
	button.focus_mode = Control.FOCUS_NONE
	UiFx.add_press_feedback(button)
	parent.add_child(button)
	return button

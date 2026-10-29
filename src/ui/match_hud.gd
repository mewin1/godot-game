class_name MatchHud
extends VBoxContainer
## Верх экрана матча: раунд и фаза с таймером, HP / золото / доход с иконками, кнопки паузы,
## скорости и звука; ниже — фишки всех игроков с HP и строка про осаду.
## Только показывает состояние симуляции; нажатия кнопок отдаёт наверх сигналами.

signal pause_pressed()
signal speed_pressed()
signal sound_pressed()

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
var _siege_panel: PanelContainer
var _siege_label: Label
var _time: float = 0.0


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
	_income_label.text = "+%d" % me.income
	_refresh_chips(sim, human_index)
	_refresh_siege(sim, human_index)


func set_paused(is_paused: bool) -> void:
	_pause_button.text = "▶" if is_paused else "II"


func set_speed(speed: int) -> void:
	_speed_button.text = "×%d" % speed


func set_muted(is_muted: bool) -> void:
	_sound_button.icon = SOUND_OFF_ICON if is_muted else SOUND_ON_ICON


func _phase_text(sim: MatchSim) -> String:
	match sim.phase:
		MatchSim.Phase.PREP:
			var seconds: int = ceili(float(sim.get_phase_ticks_left()) / sim.config.ticks_per_second)
			return "Подготовка · %d с" % seconds
		MatchSim.Phase.WAVE:
			return "Волна"
	return "Матч окончен"


func _refresh_chips(sim: MatchSim, human_index: int) -> void:
	var opponent_index: int = sim.opponent_of[human_index]
	var ghost_index: int = sim.ghost_source if sim.ghost_target == human_index else -1
	for player: PlayerState in sim.players:
		var chip: PanelContainer = _chips[player.index]
		var label: Label = _chip_labels[player.index]
		var display_name: String = "Вы" if player.index == human_index else player.display_name
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
	_siege_panel.visible = true
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
		var label: Label = _add_label(chip, CHIP_FONT_SIZE)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_chips.append(chip)
		_chip_labels.append(label)


## Показывает столько фишек, сколько игроков в матче.
func set_player_count(count: int) -> void:
	for i: int in _chips.size():
		_chips[i].visible = i < count


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

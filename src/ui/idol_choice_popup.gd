class_name IdolChoicePopup
extends Control
## Добровольный выбор бесплатного усиления; права сохраняются между подготовками.

signal command_requested(command: SimCommand)

var _panel: VBoxContainer
var _signature: int = -1
var _waiting_for_command: bool = false
var _submitted_tick: int = -1
var _last_tick: int = 0
var _ticks_per_second: int = 20
var _buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center: CenterContainer = CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame: PanelContainer = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", DuskTheme.glass(0.96, 12))
	center.add_child(frame)
	_panel = VBoxContainer.new()
	_panel.add_theme_constant_override("separation", 10)
	frame.add_child(_panel)
	visible = false


## Состояние читает из симуляции; новое посвящение использует первую свободную основу.
func refresh(player: PlayerState, can_choose: bool, current_tick: int,
		ticks_per_second: int) -> void:
	visible = can_choose and player.idol_choices_left > 0
	if not visible:
		return
	_last_tick = current_tick
	_ticks_per_second = ticks_per_second
	if _waiting_for_command and _submitted_tick == current_tick:
		return
	var hasher: StateHasher = StateHasher.new()
	hasher.add(player.idol_choices_left)
	for idol: IdolState in player.field.idols:
		idol.add_to_hash(hasher)
	for rite: RiteData in player.get_idol_base_rites():
		hasher.add_string(rite.id)
	if _signature == hasher.value:
		if not _waiting_for_command or _submitted_tick == current_tick:
			return
	_signature = hasher.value
	_waiting_for_command = false
	_buttons.clear()
	for child: Node in _panel.get_children():
		_panel.remove_child(child)
		child.queue_free()
	var title: Label = Label.new()
	title.text = "Магазин вырос — усильте идол бесплатно (%d)" % player.idol_choices_left
	title.add_theme_font_size_override("font_size", 23)
	_panel.add_child(title)
	var hint: Label = Label.new()
	hint.text = "Выберите силу. Повтор усиливает её идол. Заговоры остаются сверху."
	_panel.add_child(hint)
	for rite: RiteData in player.get_idol_base_rites():
		var slot: int = _find_slot(player, rite.god)
		var button: Button = Button.new()
		button.text = "%s — %s" % [IdolSlot.god_name(rite.god), _base_effect(rite)]
		button.custom_minimum_size = Vector2(700, 54)
		button.tooltip_text = "Бесплатно: " + rite.description
		button.disabled = slot < 0
		if slot < 0:
			button.text += "\nВсе три основы заняты другими силами"
		button.pressed.connect(_choose.bind(rite.god, slot))
		_buttons.append(button)
		_panel.add_child(button)
	var skip: Button = Button.new()
	skip.text = "Отказаться от этого усиления"
	skip.pressed.connect(_choose.bind(&"", -1))
	_buttons.append(skip)
	_panel.add_child(skip)


func _find_slot(player: PlayerState, god: StringName) -> int:
	for slot: int in player.field.idols.size():
		if player.check_idol_choice(god, slot) == "":
			return slot
	return -1


func _base_effect(rite: RiteData) -> String:
	match rite.effect:
		RiteData.Effect.DAMAGE:
			return "+%d%% урона её построек" % rite.value
		RiteData.Effect.CHAIN_CHANCE:
			return "+%d п.п. к шансу цепи" % rite.value
		RiteData.Effect.WIND_POWER:
			return "+%d%% силы потока" % rite.value
		RiteData.Effect.WET_DURATION:
			return "+%.1f с мокроты" % (float(rite.value) / _ticks_per_second)
	return rite.description


func _choose(god: StringName, slot: int) -> void:
	if _waiting_for_command:
		return
	_waiting_for_command = true
	_submitted_tick = _last_tick
	for button: Button in _buttons:
		button.disabled = true
	command_requested.emit(ChooseIdolCommand.new(god, slot))

class_name ReservePlanPicker
extends HBoxContainer
## Одна строка: тип купленного бойца и число удерживаемых бойцов.

signal command_requested(command: SimCommand)
var _kind: OptionButton
var _count: SpinBox
var _types: Array[MobData] = []
var _player: PlayerState
var _refreshing: bool = false
var _key: String = ""


func _init() -> void:
	_kind = OptionButton.new()
	_kind.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kind.custom_minimum_size.x = 190
	_kind.clip_text = true
	_kind.add_theme_font_size_override("font_size", 13)
	_kind.item_selected.connect(_on_type)
	_kind.tooltip_text = "Подкрепление из купленной армии. Базовые бойцы всегда выходят сразу."
	add_child(_kind)
	_count = SpinBox.new()
	_count.custom_minimum_size.x = 75
	_count.min_value = 0
	_count.step = 1
	_count.value_changed.connect(_on_count)
	_count.tooltip_text = "Сколько бойцов удержать до приказа; 0 — отправить всех сразу"
	add_child(_count)


func refresh(player: PlayerState) -> void:
	_player = player
	_refreshing = true
	var purchased: Array[MobData] = player.army.purchased_mobs()
	var key: String = ""
	for data: MobData in purchased:
		key += "%s:%s;" % [data.id, data.resist]
	if key != _key or _kind.item_count == 0:
		_key = key
		_types.clear()
		_kind.clear()
		_kind.add_item("Подкрепление · не назначено")
		for data: MobData in purchased:
			var exists: bool = false
			for previous: MobData in _types:
				exists = exists or (previous.id == data.id and previous.resist == data.resist)
			if not exists:
				_types.append(data)
				_kind.add_item(data.display_name + (" · " + String(data.resist) if data.resist != &"" else ""))
	var selected: int = 0
	for i: int in _types.size():
		if _types[i].id == player.army.reserve_kind and _types[i].resist == player.army.reserve_resist:
			selected = i + 1
	_kind.select(selected)
	_count.max_value = player.army.available_reserve_count(player.army.reserve_kind, player.army.reserve_resist)
	_count.set_value_no_signal(player.army.reserve_count)
	_count.editable = selected > 0
	_refreshing = false


func _on_type(index: int) -> void:
	if _refreshing:
		return
	if index == 0:
		command_requested.emit(PlanReserveCommand.new())
	else:
		var data: MobData = _types[index - 1]
		command_requested.emit(PlanReserveCommand.new(data.id, data.resist, 1))


func _on_count(value: float) -> void:
	if _refreshing or _kind.selected <= 0:
		return
	var data: MobData = _types[_kind.selected - 1]
	command_requested.emit(PlanReserveCommand.new(data.id, data.resist, int(value)))

class_name ShopPanel
extends PanelContainer
## Лавка и улучшения армии слева, без прокрутки. Сброс своей фигуры сюда продаёт её.

signal command_requested(command: SimCommand)

var _sim: MatchSim
var _player: PlayerState
var _offer_grid: GridContainer
var _cards: Array[OfferCard] = []
var _army_grid: GridContainer
var _army_buttons: Array[Button] = []
var _army_title: Label
var _selection: Label
var _buff_box: VBoxContainer
var _discover_box: VBoxContainer
var _buff_buttons: Array[Button] = []
var _discover_buttons: Array[Button] = []
var _ready: Button
var _reroll: Button
var _upgrade: Button


func _init() -> void:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var actions: HBoxContainer = HBoxContainer.new()
	box.add_child(actions)
	_reroll = _button("Обновить", _on_reroll)
	_upgrade = _button("Магазин", _on_upgrade)
	actions.add_child(_reroll)
	actions.add_child(_upgrade)
	_offer_grid = GridContainer.new()
	_offer_grid.columns = 3
	_offer_grid.add_theme_constant_override("h_separation", 5)
	_offer_grid.add_theme_constant_override("v_separation", 5)
	box.add_child(_offer_grid)
	_army_title = _label("Армия", 17)
	box.add_child(_army_title)
	_army_grid = GridContainer.new()
	_army_grid.columns = 3
	_army_grid.add_theme_constant_override("h_separation", 5)
	_army_grid.add_theme_constant_override("v_separation", 5)
	box.add_child(_army_grid)
	var choices: HBoxContainer = HBoxContainer.new()
	box.add_child(choices)
	_buff_box = _choice_row(choices, "Баф армии", _buff_buttons, _on_buff)
	_discover_box = _choice_row(choices, "Подарок", _discover_buttons, _on_discover)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	_selection = _label("", 15)
	box.add_child(_selection)
	box.add_child(_label("ПКМ — поворот · на лавку — продажа", 14))
	_ready = _button("Готов ▶", _on_ready)
	_ready.theme_type_variation = &"AccentButton"
	box.add_child(_ready)


## Настраивает каталог армии один раз при начале матча.
func setup(sim: MatchSim, player: PlayerState) -> void:
	_sim = sim
	_player = player
	for i: int in sim.config.army_upgrades.size():
		var button: Button = _button("", _on_army.bind(i))
		_army_grid.add_child(button)
		_army_buttons.append(button)


## Компактные карточки и кнопки всегда остаются в своих местах.
func refresh(selected_tower: TowerState) -> void:
	if _player == null:
		return
	_offer_grid.columns = 4 if _player.shop.offers.size() > 6 else 3
	while _cards.size() < _player.shop.offers.size():
		var card: OfferCard = OfferCard.new()
		card.offer_index = _cards.size()
		card.clicked.connect(_on_offer)
		_offer_grid.add_child(card)
		_cards.append(card)
	for i: int in _cards.size():
		var card: OfferCard = _cards[i]
		card.visible = i < _player.shop.offers.size()
		if not card.visible:
			continue
		var rite: RiteData = _player.shop.get_rite(i)
		card.is_active = _player.gold >= (rite.cost if rite != null else _sim.config.tower_cost)
		card.show_offer(_player.shop.get_offer(i))
		if rite != null:
			card.show_rite(rite)
	var reroll_price: int = _player.get_reroll_price()
	_reroll.text = "Обновить · %d" % reroll_price
	_reroll.disabled = _player.gold < reroll_price
	var upgrade_price: int = _player.get_shop_upgrade_price()
	_upgrade.text = "Магазин %d → %d · %d" % [_player.shop.level,
			_player.shop.level + 1, upgrade_price] if _player.shop.can_upgrade() else "Магазин 4"
	_upgrade.disabled = not _player.shop.can_upgrade() or _player.gold < upgrade_price
	_army_title.text = "Армия: %d бойцов · доход %d" % [
			_player.army.get_unit_count(), _player.get_total_income()]
	for i: int in _army_buttons.size():
		var army: ArmyState = _player.army
		var cost: int = army.get_upgrade_cost(i)
		var locked: String = army.check_upgrade_available(i, _player.shop.level)
		_army_buttons[i].text = "%s\n%d · +%d доход" % [
				army.get_upgrade(i).display_name, cost, army.get_upgrade_income(i)]
		_army_buttons[i].disabled = locked != "" or _player.gold < cost
		_army_buttons[i].tooltip_text = locked
	_refresh_choices()
	_selection.visible = selected_tower != null
	if selected_tower != null:
		_selection.text = "%s · ур.%d · продажа %d" % [selected_tower.data.display_name,
				selected_tower.level, _player.get_sell_price(selected_tower)]
	_ready.disabled = _player.is_ready
	_ready.text = "Ждём остальных…" if _player.is_ready else "Готов ▶"


func _refresh_choices() -> void:
	_buff_box.visible = not _player.buff_offers.is_empty()
	_discover_box.visible = not _player.discover_offers.is_empty()
	for i: int in 3:
		_buff_buttons[i].visible = i < _player.buff_offers.size()
		if _buff_buttons[i].visible:
			_buff_buttons[i].text = _player.buff_offers[i].display_name
		_discover_buttons[i].visible = i < _player.discover_offers.size()
		if _discover_buttons[i].visible:
			_discover_buttons[i].text = _player.discover_offers[i].display_name


func _can_drop_data(_at_position: Vector2, value: Variant) -> bool:
	if _sim == null or _sim.phase != MatchSim.Phase.PREP or not (value is DragPayload):
		return false
	var payload: DragPayload = value
	return payload.kind in [DragPayload.Kind.TOWER, DragPayload.Kind.RESERVE, DragPayload.Kind.GIFT]


func _drop_data(_at_position: Vector2, value: Variant) -> void:
	var payload: DragPayload = value
	if payload.kind == DragPayload.Kind.GIFT:
		command_requested.emit(GiftCommand.new(GiftCommand.Action.SELL, payload.offer_index))
	else:
		command_requested.emit(SellTowerCommand.new(payload.tower_id))


func _button(text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 40)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 15)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	return button


func _label(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _choice_row(parent: Container, title: String, buttons: Array[Button],
		callback: Callable) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	box.add_child(_label(title, 14))
	var row: HBoxContainer = HBoxContainer.new()
	box.add_child(row)
	for i: int in 3:
		var button: Button = _button("", callback.bind(i))
		button.add_theme_font_size_override("font_size", 13)
		row.add_child(button)
		buttons.append(button)
	return box


func _on_offer(index: int) -> void:
	# Заговоры применяются только перетаскиванием на видимую цель.
	if _player.shop.get_rite(index) == null:
		command_requested.emit(ReserveCommand.new(ReserveCommand.Action.BUY, index))


func _on_reroll() -> void:
	command_requested.emit(RerollShopCommand.new())


func _on_upgrade() -> void:
	command_requested.emit(UpgradeShopCommand.new())


func _on_ready() -> void:
	command_requested.emit(ReadyCommand.new())


func _on_army(index: int) -> void:
	command_requested.emit(BuyArmyUpgradeCommand.new(index))


func _on_buff(index: int) -> void:
	command_requested.emit(ChooseBuffCommand.new(index))


func _on_discover(index: int) -> void:
	command_requested.emit(ChooseDiscoverCommand.new(index))

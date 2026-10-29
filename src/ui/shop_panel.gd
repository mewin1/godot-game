class_name ShopPanel
extends PanelContainer
## Меню фазы подготовки: выбор бафа, витрина, рерол, уровень магазина, скилл отправки,
## действия с выбранной башней и кнопка «Готов». Команды отдаёт наверх сигналом.
## Сюда же можно перетащить свою башню с поля — она продаётся.

signal command_requested(command: SimCommand)

const FONT_SIZE: int = 20
const BUTTON_HEIGHT: float = 56.0
const OFFER_COLUMNS: int = 3

var _sim: MatchSim
var _player: PlayerState
var _selected_tower: TowerState

var _buff_box: VBoxContainer
var _buff_buttons: Array[Button] = []
var _offer_grid: GridContainer
var _offer_cards: Array[OfferCard] = []
var _reroll_button: Button
var _upgrade_button: Button
var _send_button: Button
var _tower_box: HBoxContainer
var _tower_label: Label
var _rotate_button: Button
var _sell_button: Button
var _ready_button: Button
var _hint_label: Label


func _init() -> void:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_build_buff_box(box)
	_offer_grid = GridContainer.new()
	_offer_grid.columns = OFFER_COLUMNS
	_offer_grid.add_theme_constant_override("h_separation", 8)
	_offer_grid.add_theme_constant_override("v_separation", 8)
	box.add_child(_offer_grid)
	_build_action_row(box)
	_build_tower_box(box)
	_hint_label = _make_label("Перетащи башню на поле. На такую же — слияние. Нажми на свою башню — выделишь, ещё раз — повернёшь.", 16)
	box.add_child(_hint_label)
	_ready_button = _make_button("Готов ▶", _on_ready_button_pressed)
	_ready_button.add_theme_stylebox_override("normal", _make_ready_style(Color(0.2, 0.5, 0.28)))
	_ready_button.add_theme_stylebox_override("hover", _make_ready_style(Color(0.25, 0.6, 0.33)))
	box.add_child(_ready_button)


func setup(sim: MatchSim, player: PlayerState) -> void:
	_sim = sim
	_player = player


## Обновляет тексты и доступность кнопок из состояния симуляции (каждый кадр).
func refresh(selected_tower: TowerState) -> void:
	if _player == null:
		return
	_selected_tower = selected_tower
	_refresh_buffs()
	_refresh_offers()
	_refresh_actions()
	_refresh_tower_box()
	_ready_button.disabled = _player.is_ready
	_ready_button.text = "Ждём соперника…" if _player.is_ready else "Готов ▶"


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is DragPayload):
		return false
	var payload: DragPayload = data
	return payload.kind == DragPayload.Kind.TOWER


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var payload: DragPayload = data
	command_requested.emit(SellTowerCommand.new(payload.tower_id))


#region Построение

func _build_buff_box(parent: Container) -> void:
	_buff_box = VBoxContainer.new()
	_buff_box.add_child(_make_label("Выбери баф отправки (на весь матч):", FONT_SIZE))
	var row: HBoxContainer = HBoxContainer.new()
	_buff_box.add_child(row)
	for i: int in 3:
		var button: Button = _make_button("", _on_buff_button_pressed.bind(i))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT + 20)
		row.add_child(button)
		_buff_buttons.append(button)
	parent.add_child(_buff_box)


func _build_action_row(parent: Container) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)
	_reroll_button = _make_button("", _on_command_button_pressed.bind(RerollShopCommand.new()))
	_upgrade_button = _make_button("", _on_command_button_pressed.bind(UpgradeShopCommand.new()))
	_send_button = _make_button("", _on_command_button_pressed.bind(SendUnitsCommand.new()))
	for button: Button in [_reroll_button, _upgrade_button, _send_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT + 12)
		row.add_child(button)


func _build_tower_box(parent: Container) -> void:
	_tower_box = HBoxContainer.new()
	parent.add_child(_tower_box)
	_tower_label = _make_label("", 18)
	_tower_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tower_box.add_child(_tower_label)
	_rotate_button = _make_button("⟳ Повернуть", _on_rotate_button_pressed)
	_tower_box.add_child(_rotate_button)
	_sell_button = _make_button("", _on_sell_button_pressed)
	_tower_box.add_child(_sell_button)


func _make_button(text: String, on_pressed: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	button.pressed.connect(on_pressed)
	return button


func _make_ready_style(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	return style


func _make_label(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label

#endregion


#region Обновление

func _refresh_buffs() -> void:
	var offers: Array[SendBuffData] = _player.buff_offers
	_buff_box.visible = not offers.is_empty()
	for i: int in _buff_buttons.size():
		var button: Button = _buff_buttons[i]
		button.visible = i < offers.size()
		if button.visible:
			var buff: SendBuffData = offers[i]
			button.text = ("★ " if buff.is_rare else "") + buff.display_name


func _refresh_offers() -> void:
	var offers: Array[TowerData] = _player.shop.offers
	while _offer_cards.size() < offers.size():
		var card: OfferCard = OfferCard.new()
		card.offer_index = _offer_cards.size()
		card.ticks_per_second = _sim.config.ticks_per_second
		_offer_grid.add_child(card)
		_offer_cards.append(card)
	for i: int in _offer_cards.size():
		var card: OfferCard = _offer_cards[i]
		card.visible = i < offers.size()
		if card.visible:
			card.show_offer(offers[i])
			card.is_active = _player.gold >= _sim.config.tower_cost


func _refresh_actions() -> void:
	var config: GameConfig = _sim.config
	_reroll_button.text = "Обновить\n%d зол." % config.reroll_cost
	_reroll_button.disabled = _player.gold < config.reroll_cost
	var shop: ShopState = _player.shop
	if shop.can_upgrade():
		_upgrade_button.text = "Магазин → ур.%d\n%d зол." % [shop.level + 1, shop.upgrade_cost]
	else:
		_upgrade_button.text = "Магазин\nмакс. уровень"
	_upgrade_button.disabled = not shop.can_upgrade() or _player.gold < shop.upgrade_cost
	var send_cost: int = _sim.get_send_cost(_player)
	if _player.has_sent_this_round:
		_send_button.text = "Отправлено!\n%d юнитов" % _player.pending_pack.size()
	else:
		_send_button.text = "Отправить %d юн.\n%d зол. · +%d доход" % [
				_player.army.get_pack_size(), send_cost, _player.army.get_income_gain()]
	_send_button.disabled = _player.has_sent_this_round or _player.gold < send_cost


func _refresh_tower_box() -> void:
	var tower: TowerState = _selected_tower
	_tower_box.visible = tower != null
	_hint_label.visible = tower == null
	if tower == null:
		return
	_tower_label.text = "%s, ур. %d" % [tower.data.display_name, tower.level]
	_sell_button.text = "Продать +%d" % _player.get_sell_price(tower)

#endregion


func _on_buff_button_pressed(index: int) -> void:
	command_requested.emit(ChooseBuffCommand.new(index))


func _on_command_button_pressed(command: SimCommand) -> void:
	command_requested.emit(command)


func _on_rotate_button_pressed() -> void:
	if _selected_tower == null:
		return
	command_requested.emit(RotateTowerCommand.new(_selected_tower.id))


func _on_sell_button_pressed() -> void:
	if _selected_tower != null:
		command_requested.emit(SellTowerCommand.new(_selected_tower.id))


func _on_ready_button_pressed() -> void:
	command_requested.emit(ReadyCommand.new())

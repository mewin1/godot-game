class_name ShopPanel
extends PanelContainer
## Меню фазы подготовки. Сверху — выбор бафа армии (после битвы), затем две вкладки:
## «Башни» (витрина, рерол, уровень магазина, выбранная башня) и «Армия»
## (состав армии и её прокачка). Внизу — «Готов». Команды отдаёт наверх сигналом.
## Сюда же можно перетащить свою башню с поля — она продаётся.

signal command_requested(command: SimCommand)

const FONT_SIZE: int = 20
const BUTTON_HEIGHT: float = 56.0
const OFFER_COLUMNS: int = 3
const ARMY_COLUMNS: int = 2
const ARMY_FONT_SIZE: int = 18

var _sim: MatchSim
var _player: PlayerState
var _selected_tower: TowerState

var _buff_box: VBoxContainer
var _buff_buttons: Array[Button] = []
var _towers_tab: Button
var _army_tab: Button
var _towers_page: VBoxContainer
var _army_page: VBoxContainer
var _offer_grid: GridContainer
var _offer_cards: Array[OfferCard] = []
var _reroll_button: Button
var _upgrade_button: Button
var _hint_label: Label
var _tower_box: HBoxContainer
var _tower_label: Label
var _rotate_button: Button
var _sell_button: Button
var _army_label: Label
var _army_grid: GridContainer
var _army_buttons: Array[Button] = []
var _ready_button: Button


func _init() -> void:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	_build_buff_box(box)
	_build_tabs(box)
	_build_towers_page(box)
	_army_page = VBoxContainer.new()
	_army_page.add_theme_constant_override("separation", 8)
	box.add_child(_army_page)
	_army_label = _make_label("", 18)
	_army_page.add_child(_army_label)
	_army_grid = GridContainer.new()
	_army_grid.columns = ARMY_COLUMNS
	_army_grid.add_theme_constant_override("h_separation", 8)
	_army_grid.add_theme_constant_override("v_separation", 8)
	_army_page.add_child(_army_grid)
	_ready_button = _make_button("Готов ▶", _on_ready_button_pressed)
	_ready_button.theme_type_variation = &"AccentButton"
	box.add_child(_ready_button)
	_show_page(true)


## Кнопки прокачки армии создаются по списку улучшений из конфига.
func setup(sim: MatchSim, player: PlayerState) -> void:
	_sim = sim
	_player = player
	for i: int in sim.config.army_upgrades.size():
		var button: Button = _make_button("", _on_army_button_pressed.bind(i))
		button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT + 8)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", ARMY_FONT_SIZE)
		_army_grid.add_child(button)
		_army_buttons.append(button)


## Обновляет тексты и доступность кнопок из состояния симуляции (каждый кадр).
func refresh(selected_tower: TowerState) -> void:
	if _player == null:
		return
	_selected_tower = selected_tower
	_refresh_buffs()
	_refresh_offers()
	_refresh_shop_actions()
	_refresh_tower_box()
	_refresh_army()
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
	_buff_box.add_child(_make_label("Выбери баф армии (бесплатно, на весь матч):", FONT_SIZE))
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


func _build_tabs(parent: Container) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)
	_towers_tab = _make_button("Башни", _show_page.bind(true))
	_army_tab = _make_button("Армия", _show_page.bind(false))
	for tab: Button in [_towers_tab, _army_tab]:
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(tab)


func _build_towers_page(parent: Container) -> void:
	_towers_page = VBoxContainer.new()
	_towers_page.add_theme_constant_override("separation", 10)
	parent.add_child(_towers_page)
	_offer_grid = GridContainer.new()
	_offer_grid.columns = OFFER_COLUMNS
	_offer_grid.add_theme_constant_override("h_separation", 8)
	_offer_grid.add_theme_constant_override("v_separation", 8)
	_towers_page.add_child(_offer_grid)
	var row: HBoxContainer = HBoxContainer.new()
	_towers_page.add_child(row)
	_reroll_button = _make_button("", _on_command_button_pressed.bind(RerollShopCommand.new()))
	_upgrade_button = _make_button("", _on_command_button_pressed.bind(UpgradeShopCommand.new()))
	for button: Button in [_reroll_button, _upgrade_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, BUTTON_HEIGHT + 12)
		row.add_child(button)
	_hint_label = _make_label("Перетащи карточку на поле — купить. На такую же башню — слияние.\n"
			+ "Нажми на свою башню — выделишь: появятся «Повернуть» и «Продать». "
			+ "Ещё нажатие — поворот. Продать можно и перетащив башню сюда, в меню.", 16)
	_towers_page.add_child(_hint_label)
	_build_tower_box(_towers_page)


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
	UiFx.add_press_feedback(button)
	return button


func _make_label(text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label

#endregion


#region Обновление

func _show_page(is_towers: bool) -> void:
	_towers_page.visible = is_towers
	_army_page.visible = not is_towers
	_towers_tab.theme_type_variation = &"TabActiveButton" if is_towers else &""
	_army_tab.theme_type_variation = &"" if is_towers else &"TabActiveButton"


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


func _refresh_shop_actions() -> void:
	var config: GameConfig = _sim.config
	_reroll_button.text = "Обновить\n%d зол." % config.reroll_cost
	_reroll_button.disabled = _player.gold < config.reroll_cost
	var shop: ShopState = _player.shop
	if shop.can_upgrade():
		_upgrade_button.text = "Магазин → ур.%d\n%d зол." % [shop.level + 1, shop.upgrade_cost]
	else:
		_upgrade_button.text = "Магазин\nмакс. уровень"
	_upgrade_button.disabled = not shop.can_upgrade() or _player.gold < shop.upgrade_cost


func _refresh_tower_box() -> void:
	var tower: TowerState = _selected_tower
	_tower_box.visible = tower != null
	_hint_label.visible = tower == null
	if tower == null:
		return
	_tower_label.text = "%s, ур. %d" % [tower.data.display_name, tower.level]
	_sell_button.text = "Продать +%d" % _player.get_sell_price(tower)


func _refresh_army() -> void:
	var army: ArmyState = _player.army
	_army_label.text = _army_summary(army)
	for i: int in _army_buttons.size():
		var button: Button = _army_buttons[i]
		var upgrade: ArmyUpgradeData = army.get_upgrade(i)
		var cost: int = army.get_upgrade_cost(i)
		var locked: String = army.check_upgrade_available(i, _player.shop.level)
		var bought: String = "есть %d" % army.upgrade_counts[i]
		if upgrade.max_purchases > 0:
			bought += "/%d" % upgrade.max_purchases
		var details: String = locked
		if locked == "":
			details = "%d зол. · +%d доход · %s" % [cost, army.get_upgrade_income(i), bought]
		button.text = "%s\n%s" % [upgrade.display_name, details]
		button.disabled = locked != "" or _player.gold < cost


## Состав армии: сколько и каких юнитов, бонусы HP и скорости.
func _army_summary(army: ArmyState) -> String:
	var counts: Dictionary[String, int] = {}
	counts[_sim.config.army_mob.display_name] = _sim.config.army_base_units + army.extra_units
	for mob: MobData in army.added_mobs:
		counts[mob.display_name] = counts.get(mob.display_name, 0) + 1
	var parts: PackedStringArray = []
	for unit_name: String in counts:
		parts.append("%s ×%d" % [unit_name, counts[unit_name]])
	return "Армия сама идёт к сопернику каждый раунд. Прокачка — навсегда и +доход.\nСостав: %s · HP +%d%% · скорость +%d%%" % [
			", ".join(parts), army.hp_percent, army.speed_percent]

#endregion


func _on_buff_button_pressed(index: int) -> void:
	command_requested.emit(ChooseBuffCommand.new(index))


func _on_command_button_pressed(command: SimCommand) -> void:
	command_requested.emit(command)


func _on_army_button_pressed(index: int) -> void:
	command_requested.emit(BuyArmyUpgradeCommand.new(index))


func _on_rotate_button_pressed() -> void:
	if _selected_tower != null:
		command_requested.emit(RotateTowerCommand.new(_selected_tower.id))


func _on_sell_button_pressed() -> void:
	if _selected_tower != null:
		command_requested.emit(SellTowerCommand.new(_selected_tower.id))


func _on_ready_button_pressed() -> void:
	command_requested.emit(ReadyCommand.new())

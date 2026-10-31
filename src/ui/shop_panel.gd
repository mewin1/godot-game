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
var _trial_button: Button
var _reroll: Button
var _upgrade: Button
var _reaction_help: Label
var _strategy_summary: Label
var _recipe_hint: String = ""
var _last_reaction_report: String = ""
var _first_recipe: String = ""
var _has_trial_report: bool = false


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
	_trial_button = _button("Проба", _on_trial)
	_trial_button.tooltip_text = "Бесплатно испытать текущую защиту без потери HP и золота. Активные навыки не учитываются."
	actions.add_child(_trial_button)
	_reaction_help = _label("Реакции ⓘ", 15)
	_reaction_help.autowrap_mode = TextServer.AUTOWRAP_OFF
	_reaction_help.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_reaction_help.mouse_filter = Control.MOUSE_FILTER_STOP
	actions.add_child(_reaction_help)
	_strategy_summary = _label("", 14)
	_strategy_summary.mouse_filter = Control.MOUSE_FILTER_STOP
	_strategy_summary.max_lines_visible = 2
	box.add_child(_strategy_summary)
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
	_recipe_hint = ReactionGuide.draft_text(sim.config, sim.active_gods)
	_reaction_help.text = "Сочетания ⓘ"
	_reaction_help.tooltip_text = _recipe_hint
	var recipes: PackedStringArray = ReactionGuide.draft_recipes(sim.config, sim.active_gods)
	_first_recipe = recipes[0] if not recipes.is_empty() else "Соберите пару богов"
	_strategy_summary.text = _first_recipe
	_strategy_summary.tooltip_text = _recipe_hint
	for i: int in sim.config.army_upgrades.size():
		var button: Button = _button("", _on_army.bind(i))
		_army_grid.add_child(button)
		_army_buttons.append(button)


## Компактные карточки и кнопки всегда остаются в своих местах.
func refresh(selected_tower: TowerState) -> void:
	if _player == null:
		return
	_trial_button.disabled = _sim.phase != MatchSim.Phase.PREP
	var report: String = ReactionGuide.battle_report(_sim.config, _player.field.reaction_counts)
	if _sim.phase == MatchSim.Phase.WAVE:
		_has_trial_report = false
	if report != _last_reaction_report:
		_last_reaction_report = report
		var total_count: int = 0
		for count: int in _player.field.reaction_counts.values():
			total_count += count
		_reaction_help.text = "Комбо · %d" % total_count
		if not _has_trial_report:
			_strategy_summary.text = _first_recipe + "\nБой: " + report
		_reaction_help.tooltip_text = _recipe_hint + "\n\nЭТОТ БОЙ: " + report
		_strategy_summary.tooltip_text = _reaction_help.tooltip_text
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
		card.tower_cost = _sim.config.tower_cost
		var rite: RiteData = _player.shop.get_rite(i)
		card.is_active = _player.gold >= (rite.cost if rite != null else _sim.config.tower_cost)
		card.show_offer(_player.shop.get_offer(i))
		if rite != null:
			card.show_rite(rite, _rite_context(rite))
	var reroll_price: int = _player.get_reroll_price()
	_reroll.text = "Обновить · %d" % reroll_price
	_reroll.disabled = _player.gold < reroll_price
	var upgrade_price: int = _player.get_shop_upgrade_price()
	_upgrade.text = "Магазин %d → %d · %d" % [_player.shop.level,
			_player.shop.level + 1, upgrade_price] if _player.shop.can_upgrade() else "Магазин 4"
	_upgrade.disabled = not _player.shop.can_upgrade() or _player.gold < upgrade_price
	_upgrade.tooltip_text = _upgrade_context()
	_army_title.text = "Армия: %d бойцов · доход %d" % [
			_player.army.get_unit_count(), _player.get_total_income()]
	for i: int in _army_buttons.size():
		var army: ArmyState = _player.army
		var cost: int = army.get_upgrade_cost(i)
		var locked: String = army.check_upgrade_available(i, _player.shop.level)
		_army_buttons[i].text = "%s\n%d · +%d доход" % [
				army.get_upgrade(i).display_name, cost, army.get_upgrade_income(i)]
		_army_buttons[i].disabled = locked != "" or _player.gold < cost
		var mob: MobData = army.get_upgrade(i).mob
		var detail: String = mob.description if mob != null else "Постоянное усиление армии и дохода"
		_army_buttons[i].tooltip_text = locked if locked != "" else detail
	_refresh_choices()
	_selection.visible = selected_tower != null
	if selected_tower != null:
		_selection.text = "%s · ур.%d · продажа %d" % [selected_tower.data.display_name,
				selected_tower.level, _player.get_sell_price(selected_tower)]
		_selection.tooltip_text = _tower_details(selected_tower)
	_ready.disabled = _player.is_ready
	_ready.text = "Ждём остальных…" if _player.is_ready else "Готов ▶"


func _tower_details(tower: TowerState) -> String:
	var field: FieldState = _player.field
	var lines: PackedStringArray = [tower.data.description]
	if _player.reserve.has(tower):
		return "\n".join(lines) + "\nВ резерве постройка не участвует в обороне."
	if tower.data.attacks:
		lines.append("Удар %d · период %.2f с · радиус %.1f клетки" % [
				field.get_tower_damage(tower),
				float(field.get_tower_cooldown(tower)) / _sim.config.ticks_per_second,
				field.get_tower_range(tower) / 1000.0])
	if tower.data.wind_length_milli > 0:
		lines.append("Длина потока сейчас: %.1f клетки" % (DivineCombat.wind_length(field, tower)
				/ 1000.0))
	if tower.level == _sim.config.max_tower_level and tower.awakening < 0:
		lines.append("Дальше: чары и пробуждение в магазине 4.")
	return "\n".join(lines)


func _rite_context(rite: RiteData) -> String:
	var on_field: int = 0
	var in_reserve: int = 0
	for tower: TowerState in _player.get_all_towers():
		var useful: bool = tower.data.god == rite.god if rite.target == RiteData.Target.IDOL \
				else _player.check_tower_rite(rite, tower.id) == ""
		if not useful:
			continue
		if _player.reserve.has(tower):
			in_reserve += 1
		else:
			on_field += 1
	if on_field == 0 and in_reserve == 0:
		return "Сейчас нет подходящих построек"
	return "%s: поле %d · запас %d" % [
			"Усилит" if rite.target == RiteData.Target.IDOL else "Цели", on_field, in_reserve]


func _upgrade_context() -> String:
	if not _player.shop.can_upgrade():
		return "Максимальный магазин: доступны пробуждения зачарованных построек ур.3"
	var next_level: int = _player.shop.level + 1
	var before: int = _player.field.path_length
	var after: int = _sim.config.board.get_path_length(next_level)
	var text: String = "Путь %d → %d клеток · резерв %d → %d" % [before, after,
			_player.get_reserve_capacity(), _sim.config.reserve_capacity_by_level[next_level - 1]]
	text += "\nБольше предложений и доступ к заговорам следующего тира."
	if next_level == 4:
		text += "\nПробуждение: постройка ур.3 с чарами получает силу или размах."
	return text


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


func _on_trial() -> void:
	if _sim == null or _sim.phase != MatchSim.Phase.PREP:
		return
	_has_trial_report = true
	var trial: DefenseTrial = DefenseTrial.run(_sim, _player.index)
	_strategy_summary.text = "Проба: %d убито · %d прорвалось · %d отступило\n%s" % [
			trial.killed, trial.breached, trial.retreated,
			ReactionGuide.battle_report(_sim.config, trial.reactions)]
	_strategy_summary.tooltip_text = _recipe_hint + "\n\nПОСЛЕДНЯЯ ПРОБА: " + \
			ReactionGuide.battle_report(_sim.config, trial.reactions) + \
			"\nБез активных навыков. После перестановки повторите пробу."

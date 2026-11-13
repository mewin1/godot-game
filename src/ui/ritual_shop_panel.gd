class_name RitualShopPanel
extends ShopPanel
## Существующая лавка PvP в «Обряде»: прежний опыт — все постройки сразу; бесконечный забег —
## мало случайных карточек и платное «Обновить» (лавка с азартом, docs/34 §13).

signal purchase_chosen(index: int)
signal rite_chosen(index: int)
signal start_requested()
signal sell_requested(tower_id: int)
signal enchant_chosen(index: int)
signal reroll_requested()
signal placement_cancelled()
var _ritual_rites: Array[MarketOffer] = []
## Карточки-заговоры прилавка (в конце, после построек).
var _market_rites: Array[MarketOffer] = []
var _ritual_enchants: Array[MarketOffer] = []
var _enchant_grid: GridContainer
var _market: bool = false
var _catalogue: bool = false
var _catalogue_god: StringName = &"war"
var _god_buttons: Dictionary[StringName, Button] = {}

func _init() -> void:
	super()
	var box: VBoxContainer = get_child(0) as VBoxContainer
	for child: Node in box.get_children():
		if child is Control:
			(child as Control).hide()
	(box.get_child(0) as Control).show()
	_reroll.hide()
	_upgrade.hide()
	_offer_grid.show()
	(_army_title.get_parent() as Control).show()
	_army_title.text = "Заговоры"
	_army_reroll.hide()
	_army_grid.columns = 3
	_army_grid.show()
	(_ready.get_parent() as Control).show()
	_ready.show()
	_ready.text = "Начать обряд"
	_trial_button.hide()
	_battle_summary.hide()


func setup_ritual(settings: RitualTrialConfig) -> void:
	_catalogue = settings.uses_plots()
	_market = settings.market_offers > 0
	if _catalogue:
		_setup_god_buttons(settings)
		_offer_grid.columns = 3
	# Лавка с азартом: карточка — место прилавка; что на нём, решает refresh_ritual.
	var count: int = settings.market_offers if _market else settings.combat.towers.size()
	for index: int in count:
		var card: MarketOffer = MarketOffer.new()
		card.offer_index = index
		card.tower_cost = settings.costs[index]
		card.custom_minimum_size = Vector2(96, 138)
		card.show_offer(settings.combat.towers[index])
		card.plot_card = _catalogue
		if _catalogue:
			card.name = "CatalogueCard_%s" % card.data.id
			card.placement_cancelled.connect(placement_cancelled.emit)
		card.clicked.connect(_on_offer)
		_offer_grid.add_child(card)
		_cards.append(card)
	if _catalogue:
		_army_grid.columns = 2
		_setup_rites(settings, Vector2(96, 84))
		_show_catalogue_god(_catalogue_god)
		return
	if _market:
		_offer_grid.columns = 2
		_reroll.show()
		(_reroll.get_parent() as Control).show()
		_reroll.tooltip_text = "Новые карточки за золото. Дорожает с каждым обновлением; на рассвете — сброс и новый прилавок бесплатно."
	if _market and settings.market_rite_slots > 0:
		# Заговор выпадает крайней карточкой прилавка (плейтест 9 ноября); отдельной сетки нет.
		for slot: int in settings.market_rite_slots:
			var card: MarketOffer = MarketOffer.new()
			card.custom_minimum_size = Vector2(96, 138)
			card.show_rite(settings.rites[0].duplicate() as RiteData)
			card.clicked.connect(func(chosen: int) -> void: rite_chosen.emit(chosen))
			_offer_grid.add_child(card)
			_market_rites.append(card)
		(_army_title.get_parent() as Control).hide()
		_army_grid.hide()
		return
	if settings.enchants.is_empty():
		# Бесконечный забег: заговоров больше, карточки мельче — всё на одном экране.
		_army_grid.columns = 4
		_setup_rites(settings, Vector2(72, 84))
		return
	_setup_rites(settings)
	_setup_enchants(settings)


func _setup_rites(settings: RitualTrialConfig, card_size: Vector2 = Vector2(96, 96)) -> void:
	for index: int in settings.rites.size():
		var card: MarketOffer = MarketOffer.new()
		card.offer_index = index
		card.custom_minimum_size = card_size
		# Копия ресурса: цена на карточке растёт с каждой покупкой, общий .tres не меняется.
		card.show_rite(settings.rites[index].duplicate() as RiteData)
		card.clicked.connect(func(chosen: int) -> void: rite_chosen.emit(chosen))
		_army_grid.add_child(card)
		_ritual_rites.append(card)


## Ряд «Чары на башню» — только у прежнего опыта (в бесконечном забеге чары убраны).
func _setup_enchants(settings: RitualTrialConfig) -> void:
	var box: Node = _army_grid.get_parent()
	var title: Label = Label.new()
	title.text = "Чары на башню"
	title.add_theme_font_size_override("font_size", 17)
	title.tooltip_text = "Перетащите на башню или нажмите и выберите башню. Одна чара каждого вида на башню."
	title.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(title)
	box.move_child(title, _army_grid.get_index() + 1)
	_enchant_grid = GridContainer.new()
	_enchant_grid.columns = 4
	box.add_child(_enchant_grid)
	box.move_child(_enchant_grid, title.get_index() + 1)
	for index: int in settings.enchants.size():
		var enchant: RiteData = settings.enchants[index].duplicate() as RiteData
		enchant.cost = settings.enchant_costs[index]
		var card: MarketOffer = MarketOffer.new()
		card.offer_index = index
		card.custom_minimum_size = Vector2(72, 84)
		card.show_rite(enchant)
		card.clicked.connect(func(chosen: int) -> void: enchant_chosen.emit(chosen))
		_enchant_grid.add_child(card)
		_ritual_enchants.append(card)


func refresh_ritual(trial: RitualTrial) -> void:
	var limit: int = trial.settings.tower_limit
	_level_title.text = "Лавка · %d/%d" % [trial.field.towers.size(), limit] if limit > 0 else "Лавка"
	_gold_label.text = str(trial.gold)
	_ready.visible = trial.phase == RitualTrial.Phase.PREP
	var has_room: bool = limit <= 0 or trial.field.towers.size() < limit
	if _catalogue:
		_refresh_catalogue(trial)
	elif _market:
		_refresh_market(trial)
	else:
		for index: int in _cards.size():
			_cards[index].is_active = has_room and trial.gold >= trial.settings.costs[index]
			_cards[index].queue_redraw()
	for index: int in _ritual_rites.size():
		var card: MarketOffer = _ritual_rites[index]
		var count: int = trial.rite_count(index)
		var maxed: bool = trial.settings.rite_purchase_limit \
				and count >= trial.settings.rites[index].max_purchases
		card.rite.cost = trial.rite_cost(index)
		card.is_active = not maxed and trial.gold >= card.rite.cost \
			and (not _catalogue or trial.has_idol_for(index))
		card.tooltip_text = rite_tooltip(trial, index)
		card.queue_redraw()
	for index: int in _ritual_enchants.size():
		_ritual_enchants[index].is_active = trial.gold >= trial.settings.enchant_costs[index]
		_ritual_enchants[index].queue_redraw()


func _setup_god_buttons(settings: RitualTrialConfig) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var parent: Node = _offer_grid.get_parent()
	parent.add_child(row)
	parent.move_child(row, _offer_grid.get_index())
	for data: TowerData in settings.combat.towers:
		if _god_buttons.has(data.god):
			continue
		var button: Button = Button.new()
		button.name = "Catalogue_%s" % data.god
		button.icon = GodSymbols.get_icon(data.god)
		button.expand_icon = true
		button.custom_minimum_size = Vector2(36, 34)
		button.tooltip_text = GodSymbols.get_power_name(data.god)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_show_catalogue_god.bind(data.god))
		row.add_child(button)
		_god_buttons[data.god] = button


func _show_catalogue_god(god: StringName) -> void:
	_catalogue_god = god
	for key: StringName in _god_buttons:
		_god_buttons[key].set_pressed_no_signal(key == god)
	for card: MarketOffer in _cards:
		card.visible = card.data != null and card.data.god == god
	for card: MarketOffer in _ritual_rites:
		card.visible = card.rite.god == god


func _refresh_catalogue(trial: RitualTrial) -> void:
	_level_title.text = "Каталог · город %d" % trial.city_level()
	var free: bool = false
	for cell: Vector2i in trial.field.get_buildable_cells():
		if trial.field.get_tower_at(cell) == null:
			free = true
			break
	for index: int in _cards.size():
		var card: MarketOffer = _cards[index] as MarketOffer
		var unlock: String = trial.building_unlock_error(index)
		var levels: RitualBuildingLevels = trial.settings.levels_for(card.data)
		card.tower_cost = trial.building_cost(index)
		card.is_active = free and unlock.is_empty() and trial.gold >= card.tower_cost
		card.set_night_surcharge(trial.settings.is_night(trial.tick_count),
			trial.settings.night_cost_percent - 100,
			trial.settings.night_install_ticks / trial.settings.combat.ticks_per_second)
		var lines: PackedStringArray = [card.data.display_name, levels.role, card.data.description,
			"Цена %d · один дом на свободный участок" % card.tower_cost]
		if not unlock.is_empty():
			lines.append(unlock)
		card.tooltip_text = "\n".join(lines)
		card.queue_redraw()


## Подсказка заговора: прежний опыт — «куплено n из предела»; забег — текущий и следующий бонус.
static func rite_tooltip(trial: RitualTrial, index: int) -> String:
	var rite: RiteData = trial.settings.rites[index]
	var count: int = trial.rite_count(index)
	var curve: RitualRiteCurve = trial.settings.rite_curve(rite.id)
	if curve == null:
		return "%s\nКуплено %d из %d, +%d%% урона за покупку" % [rite.display_name, count,
			rite.max_purchases, rite.value]
	var lines: PackedStringArray = [rite.display_name, rite.description]
	if curve.cap <= 0:
		lines.append("Куплено %d: +%d%% урона, следующий +%d%% (без предела, цена растёт)" % [
			count, rite.value * count, rite.value])
	else:
		lines.append("Куплено %d: сейчас %s, со следующим %s (предел %s)" % [count,
			_amount(rite.effect, RitualRiteCurve.decay(curve.cap, curve.step_bp, count)),
			_amount(rite.effect, RitualRiteCurve.decay(curve.cap, curve.step_bp, count + 1)),
			_amount(rite.effect, curve.cap)])
	var discount: int = trial.discount_bp(rite.god)
	if discount > 0:
		lines.append("Скидка на постройки этой стихии: −%d%%" % (discount / 100))
	return "\n".join(lines)


## Величина бонуса в понятных единицах: клетки, цели, секунды, проценты.
static func _amount(effect: RiteData.Effect, value: int) -> String:
	match effect:
		RiteData.Effect.ENCHANT_RANGE:
			return "+%.2f клетки" % (value / 1000.0)
		RiteData.Effect.TARGETS:
			return "+%.2f цели" % (value / 1000.0)
		RiteData.Effect.STATUS_DURATION, RiteData.Effect.WET_DURATION:
			return "+%.1f с" % (value / 20.0)
	return "+%d%%" % value


## Описание постройки общее с PvP; в "Обряде" сразу под названием - что она делает на 1-м уровне
## (у ветра и воды главное действие иное, чем в общем описании).
static func _lead_with_level_note(card: MarketOffer, settings: RitualTrialConfig) -> void:
	var levels: RitualBuildingLevels = settings.levels_for(card.data)
	var first: RitualLevelBehavior = levels.at_level(1) if levels != null else null
	if first == null:
		return
	var parts: PackedStringArray = card.tooltip_text.split("\n", true, 1)
	card.tooltip_text = "%s\n%s\n%s" % [parts[0], first.note, parts[1] if parts.size() > 1 else ""]


## Место прилавка показывает свою постройку; купленное место пустое до обновления или рассвета.
func _refresh_market(trial: RitualTrial) -> void:
	for slot: int in _cards.size():
		var card: MarketOffer = _cards[slot] as MarketOffer
		var index: int = trial.offers[slot] if slot < trial.offers.size() else -1
		card.visible = index >= 0
		if index < 0:
			continue
		var price: int = trial.building_cost(index)
		if card.offer_index != index or card.data != trial.settings.combat.towers[index] \
				or card.tower_cost != price:
			card.offer_index = index
			# Цена со скидкой своей стихии (docs/34 §7).
			card.tower_cost = price
			card.show_offer(trial.settings.combat.towers[index])
			_lead_with_level_note(card, trial.settings)
		card.is_active = trial.gold >= price
		card.queue_redraw()
	for slot: int in _market_rites.size():
		var rite_card: MarketOffer = _market_rites[slot]
		var rite_index: int = trial.rite_offers[slot] if slot < trial.rite_offers.size() else -1
		rite_card.visible = rite_index >= 0
		if rite_index < 0:
			continue
		if rite_card.offer_index != rite_index or rite_card.rite.id != trial.settings.rites[rite_index].id:
			rite_card.offer_index = rite_index
			rite_card.show_rite(trial.settings.rites[rite_index].duplicate() as RiteData)
		rite_card.rite.cost = trial.rite_cost(rite_index)
		rite_card.is_active = trial.gold >= rite_card.rite.cost and trial.has_idol_for(rite_index)
		rite_card.tooltip_text = rite_tooltip(trial, rite_index) if trial.has_idol_for(rite_index) \
				else rite_tooltip(trial, rite_index) + "\nВсе три идола уже посвящены другим богам"
		rite_card.queue_redraw()
	var cost: int = trial.reroll_cost()
	_reroll.text = "Обновить · %d" % cost
	_reroll.disabled = trial.gold < cost


## Подсветить карточку постройки, выбранной для покупки (-1 - ни одной).
func mark_chosen(index: int) -> void:
	for card: OfferCard in _cards:
		var offer: MarketOffer = card as MarketOffer
		var chosen: bool = index >= 0 and card.visible and card.offer_index == index
		if offer != null and offer.is_chosen != chosen:
			offer.is_chosen = chosen
			offer.queue_redraw()


## Сколько карточек сейчас на прилавке (для проверок без доступа к самим карточкам).
func visible_offer_count() -> int:
	var count: int = 0
	for card: OfferCard in _cards:
		count += int(card.visible)
	return count


## Есть ли ряд «Чары на башню».
func has_enchants() -> bool:
	return _enchant_grid != null


## Карточка отдаёт индекс постройки в каталоге (и в лавке с азартом тоже).
func _on_offer(index: int) -> void:
	purchase_chosen.emit(index)


func _on_reroll() -> void:
	reroll_requested.emit()


func _on_ready() -> void:
	start_requested.emit()


func _can_drop_data(_at_position: Vector2, value: Variant) -> bool:
	if not value is DragPayload:
		return false
	var payload: DragPayload = value
	return payload.kind == DragPayload.Kind.TOWER


func _drop_data(_at_position: Vector2, value: Variant) -> void:
	if value is DragPayload:
		var payload: DragPayload = value
		sell_requested.emit(payload.tower_id)

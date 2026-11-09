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
var _ritual_rites: Array[MarketOffer] = []
var _ritual_enchants: Array[MarketOffer] = []
var _enchant_grid: GridContainer
var _market: bool = false

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
	_market = settings.market_offers > 0
	# Лавка с азартом: карточка — место прилавка; что на нём, решает refresh_ritual.
	var count: int = settings.market_offers if _market else settings.combat.towers.size()
	for index: int in count:
		var card: MarketOffer = MarketOffer.new()
		card.offer_index = index
		card.tower_cost = settings.costs[index]
		card.custom_minimum_size = Vector2(96, 138)
		card.show_offer(settings.combat.towers[index])
		card.clicked.connect(_on_offer)
		_offer_grid.add_child(card)
		_cards.append(card)
	if _market:
		_offer_grid.columns = 2
		_reroll.show()
		(_reroll.get_parent() as Control).show()
		_reroll.tooltip_text = "Новые карточки за золото. Дорожает с каждым обновлением; на рассвете — сброс и новый прилавок бесплатно."
	if settings.enchants.is_empty():
		_army_grid.columns = 3
		_setup_rites(settings)
		return
	_setup_rites(settings)
	_setup_enchants(settings)


func _setup_rites(settings: RitualTrialConfig) -> void:
	for index: int in settings.rites.size():
		var card: MarketOffer = MarketOffer.new()
		card.offer_index = index
		card.custom_minimum_size = Vector2(96, 96)
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
	if _market:
		_refresh_market(trial)
	else:
		for index: int in _cards.size():
			_cards[index].is_active = has_room and trial.gold >= trial.settings.costs[index]
			_cards[index].queue_redraw()
	for index: int in _ritual_rites.size():
		var card: MarketOffer = _ritual_rites[index]
		var count: int = trial.rite_count(index)
		var maxed: bool = count >= trial.settings.rites[index].max_purchases
		card.rite.cost = trial.rite_cost(index)
		card.is_active = not maxed and trial.gold >= card.rite.cost
		card.tooltip_text = "%s\nКуплено %d из %d, +%d%% урона за покупку" % [
			trial.settings.rites[index].display_name, count,
			trial.settings.rites[index].max_purchases, trial.settings.rites[index].value]
		card.queue_redraw()
	for index: int in _ritual_enchants.size():
		_ritual_enchants[index].is_active = trial.gold >= trial.settings.enchant_costs[index]
		_ritual_enchants[index].queue_redraw()


## Место прилавка показывает свою постройку; купленное место пустое до обновления или рассвета.
func _refresh_market(trial: RitualTrial) -> void:
	for slot: int in _cards.size():
		var card: MarketOffer = _cards[slot] as MarketOffer
		var index: int = trial.offers[slot] if slot < trial.offers.size() else -1
		card.visible = index >= 0
		if index < 0:
			continue
		if card.offer_index != index or card.data != trial.settings.combat.towers[index]:
			card.offer_index = index
			card.tower_cost = trial.settings.costs[index]
			card.show_offer(trial.settings.combat.towers[index])
		card.is_active = trial.gold >= trial.settings.costs[index]
		card.queue_redraw()
	var cost: int = trial.reroll_cost()
	_reroll.text = "Обновить · %d" % cost
	_reroll.disabled = trial.gold < cost


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

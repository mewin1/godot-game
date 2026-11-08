class_name RitualShopPanel
extends ShopPanel
## Существующая лавка PvP с фиксированным ассортиментом «Обряда».

signal purchase_chosen(index: int)
signal rite_chosen(index: int)
signal start_requested()
signal sell_requested(tower_id: int)
var _ritual_rites: Array[MarketOffer] = []

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
	for index: int in settings.combat.towers.size():
		var card: MarketOffer = MarketOffer.new()
		card.offer_index = index
		card.tower_cost = settings.costs[index]
		card.custom_minimum_size = Vector2(96, 138)
		card.show_offer(settings.combat.towers[index])
		card.clicked.connect(_on_offer)
		_offer_grid.add_child(card)
		_cards.append(card)
	for index: int in settings.rites.size():
		var card: MarketOffer = MarketOffer.new()
		card.offer_index = index
		card.custom_minimum_size = Vector2(96, 96)
		card.show_rite(settings.rites[index])
		card.clicked.connect(func(chosen: int) -> void: rite_chosen.emit(chosen))
		_army_grid.add_child(card)
		_ritual_rites.append(card)


func refresh_ritual(trial: RitualTrial) -> void:
	_level_title.text = "Лавка · %d/%d" % [trial.field.towers.size(), trial.settings.tower_limit]
	_gold_label.text = str(trial.gold)
	_ready.visible = trial.phase == RitualTrial.Phase.PREP
	for index: int in _cards.size():
		_cards[index].is_active = trial.gold >= trial.settings.costs[index]
		_cards[index].queue_redraw()
	for index: int in _ritual_rites.size():
		_ritual_rites[index].is_active = trial.gold >= trial.settings.rites[index].cost
		_ritual_rites[index].queue_redraw()


func _on_offer(index: int) -> void:
	purchase_chosen.emit(index)


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

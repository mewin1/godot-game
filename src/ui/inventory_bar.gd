class_name InventoryBar
extends PanelContainer
## Инвентарь всегда внизу экрана, вне лавки. Один подарок виден рядом, остальные ждут.

signal command_requested(command: SimCommand)
signal tower_selected(tower_id: int)

var _player: PlayerState
var _cards: Array[OfferCard] = []
var _grid: GridContainer
var _gift: OfferCard
var _title: Label


func _init() -> void:
	custom_minimum_size = Vector2(0, 104)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	_title = Label.new()
	_title.custom_minimum_size = Vector2(96, 0)
	_title.add_theme_font_size_override("font_size", 15)
	row.add_child(_title)
	_grid = GridContainer.new()
	_grid.columns = 14
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 4)
	row.add_child(_grid)
	_gift = OfferCard.new()
	_gift.is_gift = true
	_gift.custom_minimum_size = Vector2(100, 82)
	_gift.clicked.connect(_on_gift_clicked)
	row.add_child(_gift)


## Состав меняется только командами; инвентарь остаётся виден и во время боя.
func refresh(player: PlayerState, editable: bool) -> void:
	_player = player
	var capacity: int = player.get_reserve_capacity()
	_title.text = "Инвентарь\n%d/%d" % [player.reserve.size(), capacity]
	while _cards.size() < capacity:
		var card: OfferCard = OfferCard.new()
		card.offer_index = _cards.size()
		card.is_reserve_slot = true
		card.custom_minimum_size = Vector2(70, 82)
		card.clicked.connect(_on_card_clicked)
		card.item_dropped.connect(_on_item_dropped)
		card.rotation_requested.connect(_on_rotate)
		_grid.add_child(card)
		_cards.append(card)
	for i: int in _cards.size():
		var card: OfferCard = _cards[i]
		card.visible = i < capacity
		card.is_active = editable
		card.stored_tower = player.reserve[i] if i < player.reserve.size() else null
		card.show_offer(card.stored_tower.data if card.stored_tower != null else null)
		if card.stored_tower != null:
			card.rotation_turns = card.stored_tower.rotation
	_gift.visible = not player.gift_towers.is_empty()
	_gift.is_active = editable
	if _gift.visible:
		_gift.show_offer(player.gift_towers[0])
		_gift.tooltip_text = "Подарков: %d. Перетащите на поле, в инвентарь или на копию." % (
				player.gift_towers.size())


func _on_card_clicked(index: int) -> void:
	if index < _player.reserve.size():
		tower_selected.emit(_player.reserve[index].id)


func _on_gift_clicked(_index: int) -> void:
	command_requested.emit(ReserveCommand.new(ReserveCommand.Action.GIFT, 0))


func _on_rotate(tower_id: int) -> void:
	command_requested.emit(RotateTowerCommand.new(tower_id))


func _on_item_dropped(payload: DragPayload, target_id: int) -> void:
	if payload.kind == DragPayload.Kind.RITE:
		command_requested.emit(BuyRiteCommand.new(payload.offer_index, target_id))
	elif target_id > 0:
		match payload.kind:
			DragPayload.Kind.OFFER:
				command_requested.emit(BuyIntoTowerCommand.new(payload.offer_index, target_id))
			DragPayload.Kind.GIFT:
				command_requested.emit(GiftCommand.new(GiftCommand.Action.MERGE,
						payload.offer_index, target_id))
			_:
				command_requested.emit(MergeTowersCommand.new(payload.tower_id, target_id))
	else:
		match payload.kind:
			DragPayload.Kind.OFFER:
				command_requested.emit(ReserveCommand.new(ReserveCommand.Action.BUY,
						payload.offer_index))
			DragPayload.Kind.GIFT:
				command_requested.emit(ReserveCommand.new(ReserveCommand.Action.GIFT,
						payload.offer_index))
			DragPayload.Kind.TOWER:
				command_requested.emit(ReserveCommand.new(ReserveCommand.Action.STORE,
						payload.tower_id))

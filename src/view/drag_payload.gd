class_name DragPayload
extends RefCounted
## Что перетаскивают: предложение витрины или уже поставленную башню.

## GIFT — подарок «тройки» (offer_index — номер подарка).
enum Kind { OFFER, TOWER, GIFT, RESERVE, RITE }

var kind: Kind = Kind.OFFER
var rite: RiteData
var preview: ShapePreview
var data: TowerData
var rotation: int = 0
var level: int = 1
var offer_index: int = -1
var tower_id: int = 0


static func for_offer(index: int, tower_data: TowerData, turns: int) -> DragPayload:
	var payload: DragPayload = DragPayload.new()
	payload.kind = Kind.OFFER
	payload.offer_index = index
	payload.data = tower_data
	payload.rotation = turns
	return payload


static func for_gift(index: int, tower_data: TowerData, turns: int) -> DragPayload:
	var payload: DragPayload = for_offer(index, tower_data, turns)
	payload.kind = Kind.GIFT
	return payload


static func for_tower(tower: TowerState) -> DragPayload:
	var payload: DragPayload = DragPayload.new()
	payload.kind = Kind.TOWER
	payload.tower_id = tower.id
	payload.data = tower.data
	payload.rotation = tower.rotation
	payload.level = tower.level
	return payload


## Заговор из общей витрины, без оплаты до успешного сброса.
static func for_rite(index: int, rite_data: RiteData) -> DragPayload:
	var payload: DragPayload = DragPayload.new()
	payload.kind = Kind.RITE
	payload.offer_index = index
	payload.rite = rite_data
	return payload


## Поворот в руке не меняет исходную башню до успешного размещения.
func rotate_preview() -> void:
	if data == null:
		return
	rotation = (rotation + 1) % TowerState.ROTATIONS
	if is_instance_valid(preview):
		preview.rotation_turns = rotation
		preview.queue_redraw()

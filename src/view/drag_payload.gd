class_name DragPayload
extends RefCounted
## Что перетаскивают: предложение витрины или уже поставленную башню.

enum Kind { OFFER, TOWER }

var kind: Kind = Kind.OFFER
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


static func for_tower(tower: TowerState) -> DragPayload:
	var payload: DragPayload = DragPayload.new()
	payload.kind = Kind.TOWER
	payload.tower_id = tower.id
	payload.data = tower.data
	payload.rotation = tower.rotation
	payload.level = tower.level
	return payload

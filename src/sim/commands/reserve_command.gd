class_name ReserveCommand
extends SimCommand
## Действия резерва проходят через тот же поток команд, что и действия поля.

enum Action { BUY, STORE, PLACE, GIFT }

var action: Action
var item_id: int
var anchor: Vector2i
var rotation: int


func _init(kind: Action, id_value: int, at_anchor: Vector2i = Vector2i.ZERO,
		turns: int = 0) -> void:
	action = kind
	item_id = id_value
	anchor = at_anchor
	rotation = turns


func execute(_sim: MatchSim, player: PlayerState) -> String:
	match action:
		Action.BUY:
			return player.buy_to_reserve(item_id)
		Action.STORE:
			return player.store_tower(item_id)
		Action.PLACE:
			return player.place_from_reserve(item_id, anchor, rotation)
		Action.GIFT:
			return player.gift_to_reserve(item_id)
	return "Неизвестное действие резерва"


func to_log(_sim: MatchSim, _player: PlayerState) -> Dictionary:
	return {"type": "reserve", "action": int(action), "item": item_id,
			"x": anchor.x, "y": anchor.y, "rotation": rotation}

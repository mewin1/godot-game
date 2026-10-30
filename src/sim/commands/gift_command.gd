class_name GiftCommand
extends SimCommand
## Подарок можно сразу слить с башней на поле/в резерве или продать, без установки.

enum Action { MERGE, SELL }

var action: Action
var gift_index: int
var target_id: int


func _init(kind: Action, index: int, target: int = 0) -> void:
	action = kind
	gift_index = index
	target_id = target


func execute(_sim: MatchSim, player: PlayerState) -> String:
	if action == Action.MERGE:
		return player.gift_into(gift_index, target_id)
	return player.sell_gift(gift_index)


func to_log(_sim: MatchSim, _player: PlayerState) -> Dictionary:
	return {"type": "gift", "action": int(action), "gift": gift_index, "target": target_id}

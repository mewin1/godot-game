class_name HeroEffect
extends Resource
## Особенность героя (пассивка или действие навыка). Один ресурс общий для всех игроков
## с этим героем, поэтому своё состояние эффект хранит в PlayerState, а не в себе.
## Наследники переопределяют нужные методы, остальные ничего не делают.


## Герой выбран: постоянные изменения (золото, правила поля…).
func on_picked(_player: PlayerState) -> void:
	pass


## Герой потерял HP (вызывается после уменьшения HP).
func on_hp_lost(_sim: MatchSim, _player: PlayerState) -> void:
	pass


## Особые условия эффекта; общие фаза/цена проверяются игроком. Не меняет состояние.
func check_activation(_sim: MatchSim, _player: PlayerState) -> String:
	return ""


## Действие навыка. Возвращает "" при успехе (тогда золото списывается) или причину отказа.
## Текст для игрока — в player.hero_message.
func activate(_sim: MatchSim, _player: PlayerState) -> String:
	return "Навык ничего не делает"


## Задевает ли эффект соперников (их стоит предупредить на экране).
func affects_opponents() -> bool:
	return false


## Подсказка боту: стоит ли жать навык сейчас (проверки цены и фазы — снаружи).
func bot_wants_to_use(_sim: MatchSim, _player: PlayerState) -> bool:
	return true

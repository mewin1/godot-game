class_name SimCommand
extends RefCounted
## Действие игрока (паттерн «Команда»). Симуляция меняется только через команды и тики:
## по сети и в реплеях передаются именно они. Внутри — только целые числа.


## Можно ли выполнять команду только в фазе подготовки.
func requires_prep() -> bool:
	return true


## Выполняет команду. Возвращает "" при успехе или причину отказа.
func execute(_sim: MatchSim, _player: PlayerState) -> String:
	return "Команда не реализована"


## Описание команды для лога матча. Вызывается до выполнения (витрина ещё не изменилась).
func to_log(_sim: MatchSim, _player: PlayerState) -> Dictionary:
	return {"type": "unknown"}

class_name QueuedCommand
extends RefCounted
## Команда игрока, ждущая следующего тика.

var player_index: int
var command: SimCommand


func _init(index: int, queued: SimCommand) -> void:
	player_index = index
	command = queued

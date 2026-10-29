class_name SpawnEntry
extends RefCounted
## Моб, который появится на поле на тике волны spawn_tick.

var spawn_tick: int = 0
var mob: MobState


func _init(at_tick: int, spawned_mob: MobState) -> void:
	spawn_tick = at_tick
	mob = spawned_mob

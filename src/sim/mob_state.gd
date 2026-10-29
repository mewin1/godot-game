class_name MobState
extends RefCounted
## Один моб на поле. Позиция — прогресс по пути в тысячных долях клетки (только целые числа).

var id: int = 0
var data: MobData
var max_hp: int = 0
var hp: int = 0
var speed: int = 0
var armor: int = 0
var kill_reward: int = 0
var breach_damage: int = 0
## Чья армия: индекс игрока (-1 — базовая волна или армия призрака).
var sender_index: int = -1
var progress: int = 0
## Прогресс на прошлом тике — отображение плавно рисует моба между тиками.
var previous_progress: int = 0
var slow_percent: int = 0
var slow_ticks_left: int = 0
var is_breached: bool = false


## Создаёт моба по данным с бонусами к HP и скорости в процентах.
static func create(mob_data: MobData, hp_bonus_percent: int = 0,
		speed_bonus_percent: int = 0) -> MobState:
	var mob: MobState = MobState.new()
	mob.data = mob_data
	mob.max_hp = mob_data.hp * (100 + hp_bonus_percent) / 100
	mob.hp = mob.max_hp
	mob.speed = mob_data.speed_milli_per_tick * (100 + speed_bonus_percent) / 100
	mob.armor = mob_data.armor
	mob.kill_reward = mob_data.kill_reward
	mob.breach_damage = mob_data.breach_damage
	return mob


func is_alive() -> bool:
	return hp > 0 and not is_breached


## Наносит урон с учётом брони (не меньше 1). Возвращает true, если моб от этого умер.
func take_damage(amount: int) -> bool:
	if not is_alive():
		return false
	hp -= maxi(1, amount - armor)
	return hp <= 0


## Замедление не складывается: действует самое сильное, время обновляется.
func apply_slow(percent: int, ticks: int) -> void:
	if percent >= slow_percent:
		slow_percent = percent
		slow_ticks_left = maxi(slow_ticks_left, ticks)


func current_speed() -> int:
	return speed * (100 - slow_percent) / 100


## Сдвигает моба по пути на один тик.
func advance() -> void:
	previous_progress = progress
	progress += current_speed()
	if slow_ticks_left > 0:
		slow_ticks_left -= 1
		if slow_ticks_left == 0:
			slow_percent = 0

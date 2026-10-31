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
## Начало общего шага отображения: не влияет на исход боя и не входит в хэш.
var visual_start_progress: int = 0
var slow_percent: int = 0
var slow_ticks_left: int = 0
var is_breached: bool = false
## Леший уже «водил» этого моба (отбрасывает только один раз).
var was_knocked_back: bool = false
## Сколько попаданий ещё поглотит щит.
var shield_left: int = 0
## Тиков до следующего лечения (лекарь).
var heal_cooldown: int = 0
## Общее окно лечения цели: в секунду учитывается сильнейший процент, без сложения.
var heal_window_ticks: int = 0
var heal_window_percent: int = 0
## Юнит злой армии (для отображения; HP уже учтено при создании).
var is_angry: bool = false
var curse_ticks_left: int = 0
var curse_damage: int = 0
var curse_delay: int = 0
var is_contagious: bool = false
var is_conserved: bool = false
var wind_reaction_cooldown: int = 0
var cold_ticks_left: int = 0
var cold_slow_percent: int = 0
var freeze_ticks_left: int = 0
var stun_ticks_left: int = 0
var wet_ticks_left: int = 0
var charges: int = 0
var charge_ticks_left: int = 0
var burn_damage: int = 0
var burn_ticks_left: int = 0
var burn_cooldown: int = 0
var wind_slow_percent: int = 0
var wind_boost_percent: int = 0
var is_in_wind: bool = false


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
	mob.shield_left = mob_data.shield_hits
	mob.heal_cooldown = mob_data.heal_interval_ticks
	return mob


func is_alive() -> bool:
	return hp > 0 and not is_breached


## Наносит урон с учётом брони (не меньше 1). Возвращает true, если моб от этого умер.
func take_damage(amount: int) -> bool:
	if not is_alive():
		return false
	if shield_left > 0:
		shield_left -= 1
		return false
	if amount <= 0:
		return false
	hp -= maxi(1, amount - armor)
	return hp <= 0


## Замедление не складывается: действует самое сильное, время обновляется.
func apply_slow(percent: int, ticks: int) -> void:
	if percent >= slow_percent:
		slow_percent = percent
		slow_ticks_left = maxi(slow_ticks_left, ticks)


func current_speed() -> int:
	if stun_ticks_left > 0 or freeze_ticks_left > 0:
		return 0
	var cold: int = cold_slow_percent if cold_ticks_left > 0 else 0
	return speed * (100 - maxi(maxi(slow_percent, cold), wind_slow_percent) \
			+ wind_boost_percent) / 100


## Сдвигает моба по пути на один тик.
func advance() -> void:
	previous_progress = progress
	progress += current_speed()
	if freeze_ticks_left > 0:
		freeze_ticks_left -= 1
	if cold_ticks_left > 0:
		cold_ticks_left -= 1
	if stun_ticks_left > 0:
		stun_ticks_left -= 1
	if slow_ticks_left > 0:
		slow_ticks_left -= 1
		if slow_ticks_left == 0:
			slow_percent = 0


## Активные статусы в стабильном порядке. Ветер не занимает слот.
func status_tags() -> Array[StringName]:
	var result: Array[StringName] = []
	if wet_ticks_left > 0:
		result.append(&"wet")
	if burn_ticks_left > 0:
		result.append(&"burn")
	if charge_ticks_left > 0:
		result.append(&"charge")
	if curse_ticks_left > 0:
		result.append(&"curse")
	if freeze_ticks_left > 0:
		result.append(&"frozen")
	elif cold_ticks_left > 0:
		result.append(&"cold")
	return result


## Удаляет статус вместе с накопленной силой.
func remove_status(tag: StringName) -> void:
	match tag:
		&"curse":
			curse_ticks_left = 0
			curse_damage = 0
			curse_delay = 0
			is_contagious = false
			is_conserved = false
		&"cold", &"frozen":
			cold_ticks_left = 0
			freeze_ticks_left = 0
			cold_slow_percent = 0
		&"wet":
			wet_ticks_left = 0
		&"burn":
			burn_ticks_left = 0
			burn_damage = 0
			burn_cooldown = 0
		&"charge":
			charge_ticks_left = 0
			charges = 0


## Третий статус не вытесняет два действующих; обновление разрешено.
func can_apply_status(tag: StringName) -> bool:
	var active: Array[StringName] = status_tags()
	if tag == &"cold" or tag == &"frozen":
		if active.has(&"cold") or active.has(&"frozen"):
			return true
	return active.has(tag) or active.size() < 2


## Накопленный взрыв и оставшиеся обычные тики огня; без ещё не полученных бонусов ветра.
func get_stored_damage(ticks_per_second: int) -> int:
	var amount: int = curse_damage if curse_ticks_left > 0 else 0
	var first_burn_tick: int = maxi(1, burn_cooldown)
	if burn_ticks_left >= first_burn_tick:
		var pulses: int = 1 + (burn_ticks_left - first_burn_tick) / ticks_per_second
		amount += burn_damage * pulses
	return amount

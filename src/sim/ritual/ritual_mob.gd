class_name RitualMob
extends MobState
## Отдельные оберег/разгон и дробный остаток движения, без изменения MobState.

enum BossPhase { APPROACH, WARNING, RUSH, SPENT }
var ward_hp: int = 0
var boss_phase: BossPhase = BossPhase.APPROACH
var warning_until: int = -1
var immune_until: int = -1
var vulnerable_until: int = -1
var clock_tick: int = 0
var aura_percent: int = 100
var movement_remainder: int = 0
## Полный целочисленный шаг до ограничения на повороте/преграде.
var step_distance: int = 0


static func from_data(mob_data: MobData, settings: RitualTrialConfig) -> RitualMob:
	var mob: RitualMob = RitualMob.new()
	mob.data = mob_data
	mob.max_hp = mob_data.hp
	mob.hp = mob_data.hp
	mob.speed = mob_data.speed_milli_per_tick
	mob.kill_reward = mob_data.kill_reward
	mob.breach_damage = mob_data.breach_damage
	mob.resist = mob_data.resist
	mob.armor = mob_data.armor
	if mob_data.tags.has(settings.ward_tag):
		mob.ward_hp = settings.ward_hp
	return mob


func can_apply_status(tag: StringName) -> bool:
	if ward_hp > 0 or (tag == &"frozen" and immune_until > clock_tick):
		return false
	return super.can_apply_status(tag)


func movement_numerator() -> int:
	if stun_ticks_left > 0 or freeze_ticks_left > 0:
		return 0
	var cold: int = cold_slow_percent if cold_ticks_left > 0 else 0
	return speed * aura_percent * (100 - maxi(maxi(slow_percent, cold),
			wind_slow_percent) + wind_boost_percent)


func current_speed() -> int:
	return movement_numerator() / 10000


func advance() -> void:
	previous_progress = progress
	var numerator: int = movement_numerator()
	if numerator > 0:
		movement_remainder += numerator
		progress += movement_remainder / 10000
		movement_remainder %= 10000
	step_distance = progress - previous_progress
	freeze_ticks_left = maxi(0, freeze_ticks_left - 1)
	stun_ticks_left = maxi(0, stun_ticks_left - 1)
	cold_ticks_left = maxi(0, cold_ticks_left - 1)
	if slow_ticks_left > 0:
		slow_ticks_left -= 1
		if slow_ticks_left == 0:
			slow_percent = 0

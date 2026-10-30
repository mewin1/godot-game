class_name CurseCombat
extends RefCounted
## Отложенный взрыв и однократная консервация. Награды и броня обрабатываются полем.

## Повторное попадание усиливает заряд, но не отодвигает взрыв бесконечно.
static func apply(tower: TowerState, mob: MobState, damage: int) -> void:
	if not mob.is_alive() or not mob.can_apply_status(&"curse"):
		return
	if mob.curse_ticks_left <= 0:
		mob.curse_ticks_left = tower.data.curse_ticks
		mob.curse_delay = tower.data.curse_ticks
	mob.curse_damage = maxi(mob.curse_damage, damage * tower.data.curse_percent / 100)


## Лёд один раз продлевает задержку и усиливает накопленный взрыв.
static func conserve(mob: MobState, rule: ReactionData) -> void:
	if mob.is_conserved or mob.curse_ticks_left <= 0:
		return
	mob.is_conserved = true
	mob.curse_ticks_left += rule.curse_extra_ticks
	mob.curse_damage = mob.curse_damage * rule.curse_damage_percent / 100


## Взрыв перескакивает на ближайшего мокрого в радиусе; равенство решает id.
static func tick(field: FieldState, mob: MobState) -> void:
	if not mob.is_alive() or mob.curse_ticks_left <= 0:
		return
	mob.curse_ticks_left -= 1
	if mob.curse_ticks_left > 0:
		return
	var damage: int = mob.curse_damage
	var delay: int = mob.curse_delay
	var next_target: MobState = _find_wet(field, mob) if mob.is_contagious else null
	mob.remove_status(&"curse")
	field.effect_played.emit(&"curse_burst", mob)
	field.deal_mob_damage(mob, damage)
	if next_target != null:
		next_target.remove_status(&"wet")
		next_target.curse_damage = maxi(next_target.curse_damage, damage)
		if next_target.curse_ticks_left <= 0:
			next_target.curse_ticks_left = delay
			next_target.curse_delay = delay
		next_target.is_contagious = true
		field.effect_played.emit(&"infection", next_target)


static func _find_wet(field: FieldState, origin: MobState) -> MobState:
	var best: MobState = null
	var best_distance: int = field.config.curse_spread_radius_milli * field.config.curse_spread_radius_milli + 1
	var point: Vector2i = field.get_mob_position(origin)
	for candidate: MobState in field.mobs:
		if candidate == origin or not candidate.is_alive() or candidate.wet_ticks_left <= 0:
			continue
		var offset: Vector2i = field.get_mob_position(candidate) - point
		var distance: int = offset.x * offset.x + offset.y * offset.y
		if distance < best_distance or (distance == best_distance and best != null
				and candidate.id < best.id):
			best = candidate
			best_distance = distance
	return best

class_name WindReactions
extends RefCounted
## Ветер остаётся геометрией. Статусы разносятся ограниченным импульсом без рекурсии.

## Один импульс на интервал, независимо от числа перекрывающихся потоков.
static func apply(field: FieldState, mob: MobState) -> void:
	if not mob.is_alive() or not mob.is_in_wind or mob.wind_reaction_cooldown > 0:
		return
	var rule: ReactionData = ReactionResolver.resolve(&"wind", mob.status_tags(),
			field.config.reactions)
	if rule == null or rule.interval_ticks <= 0:
		return
	mob.wind_reaction_cooldown = rule.interval_ticks
	var point: Vector2i = field.get_mob_position(mob)
	var status: StringName = &"cold" if rule.required == &"frozen" else rule.required
	for target: MobState in field.mobs:
		if target == mob or not target.is_alive() or target.shield_left > 0:
			continue
		var offset: Vector2i = field.get_mob_position(target) - point
		if offset.x * offset.x + offset.y * offset.y > rule.spread_radius_milli \
				* rule.spread_radius_milli:
			continue
		if not target.can_apply_status(status):
			continue
		_spread(mob, target, status, rule.spread_duration_ticks, rule.spread_slow_percent,
				field.config.resist_percent)
		# Получатель не разносит только что полученное дальше в тот же тик.
		target.wind_reaction_cooldown = maxi(target.wind_reaction_cooldown, rule.interval_ticks)
	if rule.id == &"surge":
		var idol: IdolState = field.get_idol(&"stribog")
		if idol != null and idol.surge_slow_percent > 0:
			mob.apply_slow(idol.surge_slow_percent, rule.interval_ticks)
	if mob.freeze_ticks_left <= 0 and mob.stun_ticks_left <= 0:
		# Толчок: положительный push_milli — вперёд, отрицательный — назад (не раньше старта).
		if rule.push_milli >= 0:
			mob.progress = mini(field.get_mob_end_progress(mob), mob.progress + rule.push_milli)
		else:
			mob.progress = maxi(0, mob.progress + rule.push_milli)
	field.trigger_reaction(rule.id, mob)


static func _spread(source: MobState, target: MobState, status: StringName,
		ticks: int, slow: int, resist_percent: int) -> void:
	match status:
		&"wet":
			var duration: int = target.reduce_by_resist(
					mini(source.wet_ticks_left, ticks), &"water", resist_percent)
			target.wet_ticks_left = maxi(target.wet_ticks_left, duration)
		&"burn":
			target.burn_ticks_left = maxi(target.burn_ticks_left,
					mini(source.burn_ticks_left, ticks))
			target.burn_damage = maxi(target.burn_damage, source.burn_damage)
		&"cold":
			target.cold_ticks_left = maxi(target.cold_ticks_left, ticks)
			target.cold_slow_percent = maxi(target.cold_slow_percent,
					maxi(source.cold_slow_percent, slow))

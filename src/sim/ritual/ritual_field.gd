class_name RitualField
extends FieldState
## Изолированные порядок тика, обереги и воевода; обычный FieldState не меняется.

signal trial_event(kind: StringName, mob: RitualMob, amount: int)
signal movement_completed()
signal hit_observed(details: Dictionary)
var settings: RitualTrialConfig
var stopped: bool = false


func _init(rules: RitualTrialConfig) -> void:
	settings = rules
	super(rules.combat)


func is_buildable(cell: Vector2i) -> bool:
	for region: Rect2i in settings.build_regions:
		if region.has_point(cell):
			return true
	return false


func get_buildable_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for region: Rect2i in settings.build_regions:
		for y: int in range(region.position.y, region.end.y):
			for x: int in range(region.position.x, region.end.x):
				result.append(Vector2i(x, y))
	return result


## hp_percent < 0 — здоровье по суткам прежнего опыта; resist — стихийная неуязвимость пачки.
func spawn_mob(index: int, hp_percent: int = -1, resist: StringName = &"") -> RitualMob:
	var mob: RitualMob = RitualMob.from_data(settings.enemies[index], settings)
	if hp_percent < 0:
		var cycle: int = clampi(wave_tick / settings.cycle_ticks, 0, settings.cycle_hp_percent.size() - 1)
		hp_percent = settings.cycle_hp_percent[cycle]
	mob.max_hp = maxi(1, mob.max_hp * hp_percent / 100)
	if resist != &"":
		mob.resist = resist
	mob.hp = mob.max_hp
	mob.id = _next_mob_id
	_next_mob_id += 1
	mob.clock_tick = wave_tick
	mobs.append(mob)
	return mob


func prepare_tick(at_tick: int) -> void:
	wave_tick = at_tick
	for tower: TowerState in towers:
		var period: int = tower.data.wind_on_ticks + tower.data.wind_off_ticks
		if period > 0:
			tower.wind_cycle_ticks = at_tick % period
	for base: MobState in mobs:
		var mob: RitualMob = base as RitualMob
		mob.clock_tick = at_tick
		mob.aura_percent = settings.aura_percent if settings.is_night(at_tick) else 100
		if not mob.data.tags.has(settings.boss_tag):
			continue
		if mob.boss_phase == RitualMob.BossPhase.APPROACH and mob.progress >= settings.boss_start:
			mob.boss_phase = RitualMob.BossPhase.WARNING
			mob.warning_until = at_tick + settings.boss_warning
			trial_event.emit(&"boss_warning", mob, settings.boss_warning)
		if mob.boss_phase == RitualMob.BossPhase.WARNING and at_tick >= mob.warning_until:
			mob.boss_phase = RitualMob.BossPhase.RUSH
			trial_event.emit(&"boss_rush", mob, 0)


func fire_trial_towers() -> void:
	_fire_towers()


func finish_tick() -> void:
	# Все ауры/периодические эффекты видят позиции до обычного движения.
	for base: MobState in mobs:
		if base.is_alive() and not stopped:
			_apply_trial_wind(base as RitualMob)
	for base: MobState in mobs:
		if base.is_alive() and not stopped:
			DivineCombat.tick_effects(self, base)
	_advance_all_mobs()
	# Выбор первого пересечения должен видеть шаги всех кандидатов.
	movement_completed.emit()
	for base: MobState in mobs:
		var mob: RitualMob = base as RitualMob
		if not mob.is_alive() or stopped:
			continue
		if mob.boss_phase == RitualMob.BossPhase.RUSH and mob.progress >= settings.boss_end:
			mob.boss_phase = RitualMob.BossPhase.SPENT
		if mob.progress >= get_path_end_progress():
			mob.progress = get_path_end_progress()
			_breach(mob)
	_remove_finished_mobs()


func _advance_all_mobs() -> void:
	for base: MobState in mobs:
		var mob: RitualMob = base as RitualMob
		if not mob.is_alive() or stopped:
			continue
		var boss: bool = mob.data.tags.has(settings.boss_tag)
		mob.speed = settings.boss_speed if boss and mob.boss_phase == RitualMob.BossPhase.RUSH \
				else mob.data.speed_milli_per_tick
		if boss and mob.boss_phase == RitualMob.BossPhase.WARNING:
			mob.speed = 0
		mob.advance()
		if boss and mob.boss_phase == RitualMob.BossPhase.APPROACH:
			mob.progress = mini(mob.progress, settings.boss_start)
		if boss and mob.boss_phase == RitualMob.BossPhase.RUSH:
			mob.progress = mini(mob.progress, settings.boss_end)


func _target_priority(tower: TowerState, mob: MobState) -> int:
	return int(tower.data.burning_target_bonus_percent > 0 and mob.burn_ticks_left > 0)


func _hit(base: MobState, damage: int, data: TowerData, tower: TowerState = null) -> void:
	var mob: RitualMob = base as RitualMob
	if mob.ward_hp > 0:
		var percent: int = settings.ward_fire_percent if data.tags.has(&"fire") \
				else settings.ward_physical_percent if data.tags.has(&"physical") else 0
		damage_ward(mob, damage, percent, tower.id if tower != null else 0)
		return
	var old_stun: int = mob.stun_ticks_left
	var old_freeze: int = mob.freeze_ticks_left
	var immune: bool = mob.immune_until > wave_tick
	super._hit(mob, damage, data, tower)
	if immune:
		# Раскол потребляет frozen, но его новый стан не обходит иммунитет.
		mob.stun_ticks_left = old_stun
	elif mob.stun_ticks_left > old_stun or mob.freeze_ticks_left > old_freeze:
		interrupt_boss(mob)


func damage_ward(mob: RitualMob, damage: int, percent: int, tower_id: int = 0,
		kind: StringName = &"hit") -> void:
	if damage <= 0 or percent <= 0 or not mob.is_alive():
		return
	var removed: int = mini(mob.ward_hp, maxi(1, damage * percent / 100))
	mob.ward_hp -= removed
	trial_event.emit(&"ward_damage", mob, removed)
	if mob.ward_hp == 0:
		mob.stun_ticks_left = maxi(mob.stun_ticks_left, settings.ward_break_stun)
		trial_event.emit(&"ward_broken", mob, 0)
	hit_observed.emit(_hit_details(mob, tower_id, kind, damage, 0, removed, []))


func deal_mob_damage(base: MobState, damage: int, tower_id: int = 0,
		kind: StringName = &"other", armor_pierce: int = 0) -> void:
	var mob: RitualMob = base as RitualMob
	if damage <= 0 or not mob.is_alive():
		return
	if mob.ward_hp > 0:
		damage_ward(mob, damage, settings.ward_physical_percent if kind == &"hero" else 0, tower_id, kind)
		return
	var raw: int = damage
	var before: int = mob.hp
	var sources: Array[int] = banner_sources(mob)
	damage = _modified_body_damage(mob, raw, not sources.is_empty())
	super.deal_mob_damage(mob, damage, tower_id, kind, armor_pierce)
	hit_observed.emit(_hit_details(mob, tower_id, kind, raw,
		before - maxi(0, mob.hp), 0, sources))


func _hit_details(mob: RitualMob, tower_id: int, kind: StringName, raw: int,
		hp_damage: int, ward_damage: int, sources: Array[int]) -> Dictionary[String, Variant]:
	return {"mob": mob.id, "mob_kind": String(mob.data.id), "tower": tower_id,
		"damage_kind": String(kind), "raw": raw, "hp_damage": hp_damage,
		"ward_damage": ward_damage, "hp_after": maxi(0, mob.hp), "ward_after": mob.ward_hp,
		"protected_by": sources}


func body_damage(mob: RitualMob, raw: int) -> int:
	return _modified_body_damage(mob, raw, has_banner(mob))


func _modified_body_damage(mob: RitualMob, raw: int, protected: bool) -> int:
	var numerator: int = raw
	var denominator: int = 1
	if protected:
		numerator *= settings.banner_damage_percent
		denominator *= 100
	if mob.vulnerable_until > wave_tick:
		numerator *= settings.boss_damage_percent
		denominator *= 100
	return maxi(1, numerator / denominator) if raw > 0 else 0


func has_banner(mob: RitualMob) -> bool:
	for banner: MobState in mobs:
		if banner != mob and banner.is_alive() and banner.data.tags.has(settings.banner_tag) \
				and _is_in_range(get_mob_position(mob), get_mob_position(banner), settings.banner_radius):
			return true
	return false


func banner_sources(mob: MobState) -> Array[int]:
	var sources: Array[int] = []
	for banner: MobState in mobs:
		if banner != mob and banner.is_alive() and banner.data.tags.has(settings.banner_tag) \
				and _is_in_range(get_mob_position(mob), get_mob_position(banner), settings.banner_radius):
			sources.append(banner.id)
	sources.sort()
	return sources


func stop_mob(mob: RitualMob, duration: int) -> bool:
	if mob.immune_until > wave_tick:
		return false
	mob.stun_ticks_left = maxi(mob.stun_ticks_left, duration)
	interrupt_boss(mob)
	return true


func interrupt_boss(mob: RitualMob) -> void:
	if not mob.data.tags.has(settings.boss_tag) or mob.immune_until > wave_tick:
		return
	if mob.boss_phase not in [RitualMob.BossPhase.WARNING, RitualMob.BossPhase.RUSH]:
		return
	mob.boss_phase = RitualMob.BossPhase.SPENT
	mob.vulnerable_until = wave_tick + settings.boss_vulnerability_ticks
	mob.immune_until = wave_tick + settings.boss_immunity_ticks
	trial_event.emit(&"boss_interrupted", mob, mob.progress)


func _refresh_bonuses() -> void:
	_are_bonuses_dirty = false
	for tower: TowerState in towers:
		tower.bonus_damage_percent = 0
		tower.bonus_fire_rate_percent = 0
		tower.bonus_range_milli = 0
	for support: TowerState in towers:
		if support.is_action_blocked():
			continue
		for neighbor: TowerState in get_neighbors(support):
			neighbor.bonus_damage_percent += support.data.neighbor_damage_percent
			neighbor.bonus_fire_rate_percent += support.data.neighbor_fire_rate_percent
			neighbor.bonus_range_milli += support.data.neighbor_range_milli


## У контрольного Ветродуя нулевая стрелка влево, фигура остаётся 1×2.
func wind_direction(tower: TowerState) -> Vector2i:
	return DivineCombat.DIRECTIONS[(tower.rotation + 3) % 4]


func in_wind(tower: TowerState, point: Vector2i) -> bool:
	var offset: Vector2i = point - tower.center_milli()
	var direction: Vector2i = wind_direction(tower)
	var along: int = offset.x * direction.x + offset.y * direction.y
	var across: int = absi(offset.x * direction.y - offset.y * direction.x)
	return along >= 0 and along <= DivineCombat.wind_length(self, tower) \
			and across <= DivineCombat.wind_width(self, tower)


func _apply_trial_wind(mob: RitualMob) -> void:
	mob.wind_slow_percent = 0
	mob.wind_boost_percent = 0
	mob.is_in_wind = false
	var index: int = clampi(mob.progress / MILLI, 0, path_length - 2)
	var movement: Vector2i = layout.path_cells[index + 1] - layout.path_cells[index]
	for tower: TowerState in towers:
		if tower.is_action_blocked() or tower.data.wind_length_milli <= 0 \
				or not DivineCombat.is_wind_blowing(tower) or not in_wind(tower, get_mob_position(mob)):
			continue
		mob.is_in_wind = true
		var direction: Vector2i = wind_direction(tower)
		var alignment: int = direction.x * movement.x + direction.y * movement.y
		var power: int = mini(tower.data.wind_power_percent, config.max_wind_slow_percent)
		if alignment > 0:
			mob.wind_boost_percent = maxi(mob.wind_boost_percent, power)
		else:
			mob.wind_slow_percent = maxi(mob.wind_slow_percent, power if alignment < 0 else power / 2)
	WindReactions.apply(self, mob)


func counters() -> Array[int]:
	return [_next_tower_id, _next_mob_id]


func restore_counters(values: Array) -> void:
	_next_tower_id = RitualStateCodec.integer(values[0])
	_next_mob_id = RitualStateCodec.integer(values[1])

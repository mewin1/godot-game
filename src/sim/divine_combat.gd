class_name DivineCombat
extends RefCounted
## Взаимодействия божеств: целочисленная геометрия ветра, горение и общие заряды.

const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]


## Направление ветра связано с видимым поворотом фигуры.
static func wind_direction(tower: TowerState) -> Vector2i:
	return DIRECTIONS[tower.rotation]


## Пригодно и для подсветки в отображении: одна геометрия у картинки и симуляции.
static func is_in_wind(field: FieldState, tower: TowerState, point: Vector2i) -> bool:
	var offset: Vector2i = point - tower.center_milli()
	var direction: Vector2i = wind_direction(tower)
	var along: int = offset.x * direction.x + offset.y * direction.y
	var across: int = absi(offset.x * direction.y - offset.y * direction.x)
	return along >= 0 and along <= wind_length(field, tower) \
			and across <= wind_width(field, tower)


## Полуширина потока с пробуждением размаха.
static func wind_width(field: FieldState, tower: TowerState) -> int:
	var extra: int = 0
	if tower.awakening == RiteData.Effect.AWAKEN_WIDE:
		extra = field.config.enchant_range_milli
	return tower.data.wind_half_width_milli + extra


## Длина потока с заговором идола, чарами и выбранным пробуждением.
static func wind_length(field: FieldState, tower: TowerState) -> int:
	var length: int = tower.data.wind_length_milli \
			+ (tower.level - 1) * tower.data.wind_length_per_level_milli
	var idol: IdolState = field.get_idol(tower.data.god)
	if idol != null:
		length += idol.wind_length_milli
	if tower.enchantment == RiteData.Effect.ENCHANT_RANGE:
		length += field.config.enchant_range_milli
	if tower.awakening == RiteData.Effect.AWAKEN_FOCUS:
		length += field.config.enchant_range_milli * 2
	return length


## Сбрасывает временный ветер и выбирает сильнейший встречный/попутный поток.
static func apply_wind(field: FieldState, mob: MobState) -> void:
	mob.wind_slow_percent = 0
	mob.wind_boost_percent = 0
	mob.is_in_wind = false
	if field.silence_ticks_left > 0:
		return
	var path_index: int = clampi(mob.progress / FieldState.MILLI, 0, field.path_length - 2)
	var movement: Vector2i = field.layout.path_cells[path_index + 1] \
			- field.layout.path_cells[path_index]
	for tower: TowerState in field.towers:
		if tower.data.wind_length_milli <= 0 or not is_in_wind(field, tower,
				field.get_mob_position(mob)):
			continue
		mob.is_in_wind = true
		var power: int = tower.data.wind_power_percent \
				+ (tower.level - 1) * tower.data.wind_power_per_level
		var idol: IdolState = field.get_idol(tower.data.god)
		if idol != null:
			power += idol.wind_power
		if tower.enchantment == RiteData.Effect.ENCHANT_DAMAGE:
			power += field.config.enchant_damage_percent / 3
		power = mini(power, field.config.max_wind_slow_percent)
		var direction: Vector2i = wind_direction(tower)
		var alignment: int = direction.x * movement.x + direction.y * movement.y
		if alignment > 0:
			mob.wind_boost_percent = maxi(mob.wind_boost_percent, power)
		else:
			var slowdown: int = power if alignment < 0 else power / 2
			mob.wind_slow_percent = maxi(mob.wind_slow_percent, slowdown)


## Горение тикает раз в секунду симуляции, заряд имеет срок жизни.
static func tick_effects(field: FieldState, mob: MobState) -> void:
	if mob.wet_ticks_left > 0:
		mob.wet_ticks_left -= 1
	if mob.charge_ticks_left > 0:
		mob.charge_ticks_left -= 1
		if mob.charge_ticks_left == 0:
			mob.charges = 0
	if mob.burn_ticks_left <= 0 or not mob.is_alive():
		return
	mob.burn_ticks_left -= 1
	mob.burn_cooldown -= 1
	if mob.burn_cooldown <= 0:
		mob.burn_cooldown = field.config.ticks_per_second
		var damage: int = mob.burn_damage
		if mob.is_in_wind:
			damage += damage * field.config.wind_fire_bonus_percent / 100
		field.deal_mob_damage(mob, damage)


## Обычный удар может поджечь и вызвать ограниченную цепь, без рекурсивных срабатываний.
static func hit(field: FieldState, tower: TowerState, mob: MobState, damage: int) -> void:
	if not mob.is_alive():
		return
	var was_shielded: bool = mob.shield_left > 0
	var reaction: ReactionData = null
	if not was_shielded:
		for tag: StringName in tower.data.tags:
			reaction = ReactionResolver.resolve(tag, mob.status_tags(), field.config.reactions)
			if reaction != null:
				break
	if reaction != null:
		damage = damage * reaction.damage_percent / 100
		for status: StringName in reaction.consume:
			mob.remove_status(status)
		mob.stun_ticks_left = maxi(mob.stun_ticks_left, reaction.stun_ticks)
		if reaction.freeze_ticks > 0 and mob.can_apply_status(&"frozen"):
			mob.freeze_ticks_left = maxi(mob.freeze_ticks_left, reaction.freeze_ticks)
		field.effect_played.emit(reaction.id, mob)
	var was_burning: bool = mob.burn_ticks_left > 0
	if was_burning:
		damage += damage * tower.data.burning_target_bonus_percent / 100
	field.deal_mob_damage(mob, damage)
	if was_shielded:
		return
	if tower.data.wet_ticks > 0 and mob.is_alive() and mob.can_apply_status(&"wet"):
		var duration: int = tower.data.wet_ticks \
				+ (tower.level - 1) * tower.data.wet_ticks_per_level
		var water_idol: IdolState = field.get_idol(tower.data.god)
		if water_idol != null:
			duration += water_idol.wet_ticks
		mob.wet_ticks_left = maxi(mob.wet_ticks_left, duration)
	if tower.data.burn_percent > 0 and mob.is_alive() and mob.can_apply_status(&"burn") \
			and (reaction == null or not reaction.suppress_status):
		var percent: int = tower.data.burn_percent
		var idol: IdolState = field.get_idol(tower.data.god)
		if idol != null:
			percent += idol.burn_percent
		var burn: int = maxi(1, field.get_tower_damage(tower) * percent / 100)
		mob.burn_damage = maxi(mob.burn_damage, burn)
		mob.burn_ticks_left = maxi(mob.burn_ticks_left, tower.data.burn_ticks)
	if tower.data.cold_ticks > 0 and mob.is_alive() \
			and (reaction == null or not reaction.suppress_status) \
			and (mob.can_apply_status(&"cold") or mob.freeze_ticks_left > 0):
		mob.cold_ticks_left = maxi(mob.cold_ticks_left, tower.data.cold_ticks)
		mob.cold_slow_percent = maxi(mob.cold_slow_percent, tower.data.cold_slow_percent)
	if tower.data.god == &"perun":
		if field.config.chain_chance_percent < 0:
			_charge(field, tower, mob, damage)
		elif field.roll_chance(chain_chance(field, mob)):
			_chain(field, tower, mob, damage)


## Шанс запуска определяется основной целью; мокрые дополнительные цели не бросают снова.
static func chain_chance(field: FieldState, mob: MobState) -> int:
	var chance: int = field.config.wet_chain_chance_percent if mob.wet_ticks_left > 0 \
			else field.config.chain_chance_percent
	var idol: IdolState = field.get_idol(&"perun")
	if idol != null:
		chance += idol.chain_chance_bonus
	return clampi(chance, 0, 100)


## Историческая модель зарядов остаётся только для старых фикстур.
static func _charge(field: FieldState, tower: TowerState, mob: MobState, damage: int) -> void:
	var required: int = field.config.chain_hits
	var idol: IdolState = field.get_idol(&"perun")
	if idol != null:
		required = maxi(2, required - idol.chain_reduction)
	mob.charges += 1
	mob.charge_ticks_left = field.config.chain_lifetime_ticks
	if mob.charges >= required:
		mob.charges = 0
		_chain(field, tower, mob, damage)


static func _chain(field: FieldState, tower: TowerState, mob: MobState, damage: int) -> void:
	var transitions: int = 1
	var idol: IdolState = field.get_idol(&"perun")
	if idol != null:
		transitions += idol.chain_targets
	if tower.awakening == RiteData.Effect.AWAKEN_WIDE:
		transitions += field.config.awakening_extra_targets
	var visited: Array[MobState] = [mob]
	var previous: MobState = mob
	for i: int in transitions:
		var next_target: MobState = _nearest_target(field, previous, visited)
		if next_target == null:
			return
		visited.append(next_target)
		field.lightning_fired.emit(field.get_mob_position(previous),
				field.get_mob_position(next_target))
		field.deal_mob_damage(next_target, maxi(1, damage * field.config.chain_percent / 100))
		previous = next_target


static func _nearest_target(field: FieldState, origin: MobState,
		visited: Array[MobState]) -> MobState:
	var best: MobState = null
	var best_distance: int = field.config.chain_range_milli * field.config.chain_range_milli + 1
	var point: Vector2i = field.get_mob_position(origin)
	for candidate: MobState in field.mobs:
		if not candidate.is_alive() or visited.has(candidate):
			continue
		var offset: Vector2i = field.get_mob_position(candidate) - point
		var distance: int = offset.x * offset.x + offset.y * offset.y
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best

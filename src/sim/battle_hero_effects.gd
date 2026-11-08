class_name BattleHeroEffects
extends RefCounted
## Эффекты приёмов; целочисленная геометрия и стабильный порядок целей.


static func begin(sim: MatchSim, order: BattleHeroOrder) -> void:
	var field: FieldState = BattleHeroes.field_for(sim, order.target)
	var tower: TowerState = field.get_tower(order.tower_id)
	match order.skill.kind:
		BattleSkillData.Kind.WALK, BattleSkillData.Kind.SWAP:
			order.origin = tower.anchor
			tower.action_lock_ticks = order.skill.duration_ticks
			if order.skill.kind == BattleSkillData.Kind.SWAP:
				order.cell = field.get_tower(order.second_id).anchor
				field.get_tower(order.second_id).action_lock_ticks = order.skill.duration_ticks
		BattleSkillData.Kind.CHARGE:
			tower.action_lock_ticks = order.skill.warning_ticks
	field.play_effect(&"hero_skill")


static func tick(sim: MatchSim, order: BattleHeroOrder) -> void:
	var field: FieldState = BattleHeroes.field_for(sim, order.target)
	if field == null:
		order.resolved = true
		return
	var skill: BattleSkillData = order.skill
	match skill.kind:
		BattleSkillData.Kind.WALK, BattleSkillData.Kind.SWAP:
			_tick_move(field, order)
		BattleSkillData.Kind.TRAP:
			_tick_trap(field, order)
		BattleSkillData.Kind.SUPPRESS:
			for tower: TowerState in affected_towers(field, order):
				if tower.ward_ticks == 0:
					tower.suppressed_ticks = maxi(tower.suppressed_ticks, skill.duration_ticks)
			order.resolved = true
		BattleSkillData.Kind.WARD:
			for tower: TowerState in affected_towers(field, order):
				tower.ward_ticks = maxi(tower.ward_ticks, skill.duration_ticks)
				tower.suppressed_ticks = 0
			order.resolved = true
		BattleSkillData.Kind.STRIKE:
			for mob: MobState in field.mobs:
				if mob.is_alive() and not mob.is_decoy and in_circle(field.get_mob_position(mob), order):
					field.deal_mob_damage(mob, mini(skill.cap, mob.hp * skill.power / 100),
							0, &"hero_strike", mob.armor)
			order.resolved = true
		BattleSkillData.Kind.RUSH, BattleSkillData.Kind.HEAL, BattleSkillData.Kind.REVIVE:
			_apply_army(field, order)
			order.resolved = true
		BattleSkillData.Kind.CHARGE:
			var tower: TowerState = field.get_tower(order.tower_id)
			if tower != null:
				tower.haste_percent = skill.power
				tower.haste_ticks = skill.duration_ticks
			order.resolved = true
		BattleSkillData.Kind.DECOY:
			_spawn_decoy(field, order)
			order.resolved = true


static func affected_towers(field: FieldState, order: BattleHeroOrder) -> Array[TowerState]:
	var result: Array[TowerState] = []
	for tower: TowerState in field.towers:
		if in_circle(tower.center_milli(), order):
			result.append(tower)
	return result


static func in_circle(point: Vector2i, order: BattleHeroOrder) -> bool:
	var center: Vector2i = order.cell * FieldState.MILLI + Vector2i.ONE * (FieldState.MILLI / 2)
	var delta: Vector2i = point - center
	return delta.x * delta.x + delta.y * delta.y <= order.skill.radius_milli * order.skill.radius_milli


static func _tick_move(field: FieldState, order: BattleHeroOrder) -> void:
	order.active_left -= 1
	if order.active_left > 0:
		return
	var tower: TowerState = field.get_tower(order.tower_id)
	if order.skill.kind == BattleSkillData.Kind.WALK:
		if tower != null:
			field.move_tower(tower, order.cell, tower.rotation)
	else:
		var other: TowerState = field.get_tower(order.second_id)
		if SiegeTowerSwap.can_swap(field, tower, other):
			SiegeTowerSwap.apply(field, tower, other)
	order.resolved = true


static func _tick_trap(field: FieldState, order: BattleHeroOrder) -> void:
	for mob: MobState in field.mobs:
		if not mob.is_alive() or mob.is_decoy or order.caught.has(mob.id):
			continue
		if in_circle(field.get_mob_position(mob), order):
			order.caught.append(mob.id)
			mob.progress = maxi(0, mob.progress - order.skill.power)
			mob.previous_progress = mob.progress
			field.play_effect(&"knockback")
	order.active_left -= 1
	order.resolved = order.active_left <= 0


static func _apply_army(field: FieldState, order: BattleHeroOrder) -> void:
	var sender: int = -2 if order.owner == MatchSim.GHOST else order.owner
	for mob: MobState in field.mobs:
		if not mob.is_alive() or mob.is_decoy or mob.sender_index != sender:
			continue
		match order.skill.kind:
			BattleSkillData.Kind.RUSH:
				mob.rush_ticks = order.skill.duration_ticks
				mob.rush_percent = order.skill.power
			BattleSkillData.Kind.HEAL:
				mob.hp = mini(mob.max_hp, mob.hp + mob.max_hp * order.skill.power / 100)
			BattleSkillData.Kind.REVIVE:
				mob.revive_until = field.wave_tick + order.skill.duration_ticks - 1
				mob.revive_percent = order.skill.power


static func _spawn_decoy(field: FieldState, order: BattleHeroOrder) -> void:
	if order.skill.decoy == null:
		return
	var mob: MobState = MobState.create(order.skill.decoy)
	mob.is_decoy = true
	mob.decoy_ticks = order.skill.duration_ticks
	mob.sender_index = order.owner
	# Приманка стоит на ближайшей открытой клетке пути, не телепортирует армию.
	var best: int = 0
	var distance: int = 2147483647
	for i: int in field.path_length:
		var delta: Vector2i = field.layout.path_cells[i] - order.cell
		var squared: int = delta.x * delta.x + delta.y * delta.y
		if squared < distance:
			best = i
			distance = squared
	field.add_battle_decoy(mob, best * FieldState.MILLI)

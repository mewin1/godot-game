class_name ActiveBattleFieldView
extends FieldView
## Прицелы, предупреждения и переносы приёмов на основном поле.

var sim: MatchSim
var human_index: int = 0


func _process(delta: float) -> void:
	super._process(delta)
	if sim == null or sim.config.active_battle == null or field == null or _stage == null:
		return
	for order: BattleHeroOrder in sim.battle_heroes.orders:
		if order.skill == null or order.used_tick < 0 or order.resolved \
				or BattleHeroes.field_for(sim, order.target) != field:
			continue
		if order.skill.kind not in [BattleSkillData.Kind.WALK, BattleSkillData.Kind.SWAP]:
			continue
		var fraction: float = 1.0 - float(order.active_left) / maxi(1, order.skill.duration_ticks)
		_stage.show_tower_transfer(order.tower_id, order.origin, order.cell, fraction)
		if order.skill.kind == BattleSkillData.Kind.SWAP:
			_stage.show_tower_transfer(order.second_id, order.cell, order.origin, fraction)


func _draw() -> void:
	super._draw()
	if sim == null or sim.config.active_battle == null or field == null:
		return
	for order: BattleHeroOrder in sim.battle_heroes.orders:
		if order.skill == null or BattleHeroes.field_for(sim, order.target) != field:
			continue
		if order.owner != human_index and order.used_tick < 0:
			continue
		var remaining: int = order.skill.duration_ticks + order.skill.warning_ticks \
				- (sim.phase_tick - order.used_tick)
		if order.used_tick >= 0 and remaining <= 0 and order.resolved:
			continue
		var color: Color = Color("ffad5c") if order.skill.offensive else Color("74e2b3")
		if order.used_tick < 0:
			color.a = 0.5
		if order.skill.radius_milli > 0 and order.cell.x >= 0:
			_draw_range(order.cell * 1000 + Vector2i(500, 500), order.skill.radius_milli, color)
			for tower: TowerState in BattleHeroEffects.affected_towers(field, order):
				for cell: Vector2i in tower.cells():
					_outline_cell(cell, color, 3.0)
		for id: int in [order.tower_id, order.second_id]:
			var tower: TowerState = field.get_tower(id)
			if tower != null:
				for cell: Vector2i in tower.cells():
					_outline_cell(cell, color, 3.0)
		if order.skill.kind == BattleSkillData.Kind.WALK and order.cell.x >= 0:
			_outline_cell(order.cell, color, 4.0)
		if order.used_tick >= 0:
			var position: Vector2 = _cell_rect(order.cell).get_center()
			var text: String = ("! " if order.warning_left > 0 else "◆ ") + order.skill.title
			text += " · %d с" % ceili(float(maxi(0, remaining)) / sim.config.ticks_per_second)
			draw_string(ThemeDB.fallback_font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)

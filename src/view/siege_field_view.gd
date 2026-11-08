class_name SiegeFieldView
extends FieldView
## Зоны приказов поверх действующей лесной арены.

const WALK_COLOR: Color = Color(0.5, 1.0, 0.7)
const FIRE_COLOR: Color = Color(1.0, 0.35, 0.12)
var trial: SiegeTrial
var side_index: int = 0


func _process(delta: float) -> void:
	super._process(delta)
	if trial == null or _stage == null:
		return
	var side: SiegeTrialSide = trial.sides[side_index]
	if side.walk_left > 0:
		var fraction: float = 1.0 - float(side.walk_left) / trial.settings.walk_ticks
		_stage.show_tower_transfer(side.walk_tower_id, side.walk_origin,
				side.destination, fraction)
	if side.swap_left > 0:
		var fraction: float = 1.0 - float(side.swap_left) / trial.settings.swap_ticks
		_stage.show_tower_transfer(side.walk_tower_id, side.walk_origin, side.destination, fraction)
		_stage.show_tower_transfer(side.swap_tower_id, side.destination, side.walk_origin, fraction)


func _draw() -> void:
	super._draw()
	if trial == null or field == null:
		return
	var side: SiegeTrialSide = trial.sides[side_index]
	if side.hero != SiegeTrial.GORYNYCH:
		var tower: TowerState = side.walking_tower()
		if side.hero == SiegeTrial.DOMOVOY:
			var other: TowerState = side.field.get_tower(side.swap_tower_id)
			for cell: Vector2i in TowerState.shape_cells_at(other.data.shape, side.walk_origin, other.rotation):
				_outline_cell(cell, WALK_COLOR, 3.0)
		for cell: Vector2i in TowerState.shape_cells_at(tower.data.shape, side.destination, 0):
			_outline_cell(cell, WALK_COLOR, 3.0)
		if not side.skill_used:
			for cell: Vector2i in tower.cells():
				_outline_cell(cell, WALK_COLOR, 3.0)
			var start: Vector2 = _to_screen(Vector2(side.walk_origin * 1000 + Vector2i(500, 500)))
			var finish: Vector2 = _to_screen(Vector2(side.destination * 1000 + Vector2i(500, 500)))
			draw_dashed_line(start, finish, Color(WALK_COLOR, 0.65), 2.0, 8.0)
	var enemy: SiegeTrialSide = trial.sides[1 - side_index]
	if enemy.hero != SiegeTrial.GORYNYCH:
		return
	if enemy.skill_used and enemy.warning_left <= 0 and enemy.fire_left <= 0:
		return
	var tint: Color = FIRE_COLOR
	tint.a = 0.8 if enemy.warning_left > 0 or enemy.fire_left > 0 else 0.3
	_draw_range(enemy.target * 1000 + Vector2i(500, 500),
			trial.settings.fire_radius_milli, tint)
	for tower: TowerState in field.towers:
		if trial.in_fire_zone(1 - side_index, tower):
			for cell: Vector2i in tower.cells():
				_outline_cell(cell, tint, 3.0)
			if enemy.fire_left > 0:
				_draw_scorched(tower)


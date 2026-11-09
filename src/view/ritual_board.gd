class_name RitualBoard
extends Control
## PvP-арена и проецируемый слой управления отдельного опыта.

signal command_requested(command: RitualCommand)
signal cell_clicked(cell: Vector2i, right: bool)
var trial: RitualTrial
var selected_id: int = 0
var preview_index: int = -1
var preview_rotation: int = 0
var action: StringName = &""
var hover_cell: Vector2i = Vector2i(-1, -1)
var _cell: float = 32.0
var _origin: Vector2 = Vector2.ZERO
var stage: RitualStage3D
var effects: RitualBattleLayer
var _shown_field: RitualField
class Hit:
	var start: Vector2
	var finish: Vector2
	var life: float
	var color: Color
	var amount: String

	func _init(from: Vector2, to: Vector2, seconds: float, tint: Color, text: String) -> void:
		start = from
		finish = to
		life = seconds
		color = tint
		amount = text

var _hits: Array[Hit] = []
var _next_hit_text: Dictionary[int, int] = {}
var _last_hero_due: int = -1


func _process(delta: float) -> void:
	if trial == null or stage == null or size.x < 1:
		return
	if _shown_field != trial.field:
		_shown_field = trial.field
		stage.show_field(_shown_field, Callable())
		_shown_field.tower_fired.connect(_tower_fired)
		_shown_field.hit_observed.connect(_hit)
		_hits.clear()
		effects.set_field(_shown_field)
		_next_hit_text.clear()
		_last_hero_due = -1
	stage.size = size
	stage.frame_board(Rect2(Vector2(338, 76), size - Vector2(358, 210)))
	stage.update_ritual(trial, delta)
	if _last_hero_due >= 0 and trial.hero_due < 0 and trial.tick_count >= _last_hero_due:
		effects.play_burst(_point(trial.field.lane_point(trial.hero_lane, trial.hero_progress)), Color("ffe1a0"))
	_last_hero_due = trial.hero_due
	for index: int in range(_hits.size() - 1, -1, -1):
		_hits[index].life -= delta
		if _hits[index].life <= 0:
			_hits.remove_at(index)
	_geometry()
	effects.size = size
	effects.set_layout(Vector2.ZERO, _cell)
	queue_redraw()


func _tower_fired(tower: TowerState, _mob: MobState) -> void:
	stage.pulse_tower(tower.id)



func _hit(details: Dictionary) -> void:
	for mob: MobState in trial.field.mobs:
		if mob.id == details["mob"]:
			if trial.tick_count < _next_hit_text.get(mob.id, 0):
				return
			_next_hit_text[mob.id] = trial.tick_count + 5
			var ward: int = RitualStateCodec.integer(details["ward_damage"])
			var damage: int = RitualStateCodec.integer(details["hp_damage"]) + ward
			_hits.append(Hit.new(Vector2.ZERO, Vector2(trial.field.get_mob_position(mob)),
				0.5, Color("a6e7ff") if ward > 0 else Color("ffe4a5"), str(damage)))
			return


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	if DisplayServer.get_name() == "headless":
		return
	stage = RitualStage3D.new()
	add_child(stage)
	stage.show_behind_parent = true
	effects = RitualBattleLayer.new()
	effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects.bodies_3d = true
	effects.interpolation = 1.0
	effects.point_projector = func(point: Vector2) -> Vector2: return stage.project_milli(point, 0.3)
	effects.mob_feet_projector = func(mob: MobState) -> Vector2: return stage.mob_feet(mob, 1.0)
	effects.mob_head_projector = func(mob: MobState) -> Vector2: return stage.mob_head(mob, 1.0)
	effects.tower_top_projector = stage.tower_top
	add_child(effects)
	mouse_exited.connect(_clear_hover)


func _clear_hover() -> void:
	hover_cell = Vector2i(-1, -1)
	queue_redraw()


func _geometry() -> void:
	if stage == null or stage.layout == null:
		return
	_cell = stage.project_milli(Vector2(11000, 7000)).distance_to(stage.project_milli(Vector2(10000, 7000)))
	_origin = Vector2(12, 12)


func _gui_input(event: InputEvent) -> void:
	_geometry()
	if event is InputEventMouseMotion:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		hover_cell = stage.cell_at(motion.position)
		queue_redraw()
	elif event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.pressed and button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			var cell: Vector2i = stage.cell_at(button.position)
			cell_clicked.emit(cell, button.button_index == MOUSE_BUTTON_RIGHT)
			accept_event()


func _point(point: Vector2i) -> Vector2:
	return stage.project_milli(Vector2(point), 0.15)


func _tile(cell: Vector2i, color: Color, filled: bool = true) -> void:
	var points: PackedVector2Array = []
	for corner: Vector2 in [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]:
		points.append(stage.project_cell_corner(cell, corner, 0.13))
	if filled:
		draw_colored_polygon(points, color)
	else:
		points.append(points[0])
		draw_polyline(points, color, 2, true)


func _ring(center: Vector2i, radius: int, color: Color, width: float = 2.0) -> void:
	var points: PackedVector2Array = []
	for index: int in 65:
		var offset: Vector2 = Vector2.from_angle(TAU * index / 64.0) * radius
		points.append(stage.project_milli(Vector2(center) + offset, 0.16))
	draw_polyline(points, color, width, true)


## Точка открытой дороги под клеткой: (вход, прогресс) или (-1, -1).
func road_spot(cell: Vector2i) -> Vector2i:
	return trial.field.locate_road(cell) if trial != null else Vector2i(-1, -1)


func _text(at: Vector2, text: String, color: Color, font_size: int = 14) -> void:
	draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw() -> void:
	if trial == null or stage == null or stage.layout == null:
		return
	_geometry()
	var field: RitualField = trial.field
	if action in [&"buy", &"move"]:
		for cell: Vector2i in field.get_buildable_cells():
			_tile(cell, Color(0.6, 0.8, 0.75, 0.13), false)
	for tower: TowerState in field.towers:
		_draw_tower(tower)
	for base: MobState in field.mobs:
		_draw_mob(base as RitualMob)
	if trial.hero_due >= 0:
		_ring(field.lane_point(trial.hero_lane, trial.hero_progress), trial.settings.hero_radius, Color("f7d886"), 3)
	for hit: Hit in _hits:
		var endpoint: Vector2 = stage.project_milli(hit.finish, 1.0)
		if hit.amount == "":
			draw_line(stage.project_milli(hit.start, 2.0), endpoint, hit.color, 2, true)
		else:
			_text(endpoint + Vector2(0, -18 * (1.0 - hit.life / 0.5)), hit.amount, hit.color, 14)
	_draw_preview()


func _draw_tower(tower: TowerState) -> void:
	var color: Color = GodSymbols.get_color(tower.data.god)
	for cell: Vector2i in tower.cells():
		if tower.id == selected_id:
			_tile(cell, Color("ffe4a5"), false)
		if tower.is_action_blocked():
			_tile(cell, Color(0.1, 0.15, 0.2, 0.65))
	var center: Vector2 = _point(tower.center_milli())
	if tower.data.wind_length_milli > 0:
		var direction: Vector2i = trial.field.wind_direction(tower)
		var wind_end: Vector2i = tower.center_milli() + direction * tower.data.wind_length_milli
		var end: Vector2 = _point(wind_end)
		var arrow: Vector2 = (end - center).normalized()
		draw_line(center, end, Color(0.7, 0.95, 1, 0.6), 2, true)
		draw_colored_polygon(PackedVector2Array([end, end - arrow * 10 + arrow.orthogonal() * 5,
			end - arrow * 10 - arrow.orthogonal() * 5]), Color("b3f2ff"))
		if tower.id == selected_id:
			var side: Vector2i = Vector2i(-direction.y, direction.x) * DivineCombat.wind_width(trial.field, tower)
			var strip: PackedVector2Array = []
			for point: Vector2i in [tower.center_milli() + side, wind_end + side, wind_end - side, tower.center_milli() - side]:
				strip.append(_point(point))
			draw_colored_polygon(strip, Color(0.6, 0.85, 1, 0.12))
	if tower.is_action_blocked():
		_text(stage.tower_top(tower.id), "Установка…", Color.WHITE, 14)
	if tower.id == selected_id:
		_ring(tower.center_milli(), trial.field.get_tower_range(tower), Color(color, 0.6), 1.5)


func _draw_mob(mob: RitualMob) -> void:
	var center: Vector2 = _point(trial.field.get_mob_position(mob))
	var boss: bool = mob.data.tags.has(trial.settings.boss_tag)
	var radius: float = _cell * 0.19
	var color: Color = Color("e1c49c")
	# Буква — первая буква имени (нежить и прежние враги), облик — по роли модели-заглушки.
	var glyph: String = mob.data.display_name.left(1)
	match RitualStage3D.UNIT_IDS.get(mob.data.id, &"basic"):
		&"fast":
			radius = _cell * 0.23
			color = Color("afd587")
		&"armored", &"knight":
			radius = _cell * 0.28
			color = Color("c89868")
		&"courier":
			radius = _cell * 0.22
			color = Color("aa80ce")
		&"boss":
			radius = _cell * 0.34
			color = Color("d46c50")
	if mob.data.tags.has(trial.settings.banner_tag):
		_ring(trial.field.get_mob_position(mob), trial.settings.banner_radius, Color(color, 0.35), 1.0)
	if mob.freeze_ticks_left > 0:
		color = Color("a1e8f5")
	_text(stage.mob_head(mob, 1.0) + Vector2(-5, -13), glyph, color, 13)
	if mob.stun_ticks_left > 0:
		_text(center + Vector2(-3, -radius), "*", Color.WHITE, 18)
	if boss:
		if mob.boss_phase == RitualMob.BossPhase.WARNING:
			_text(stage.mob_head(mob, 1.0) + Vector2(-55, -31), "РЫВОК!", Color("ffab65"), 20)
			var lane: int = RitualField.lane_of(mob)
			var ahead: int = mini(mob.progress + 3000, trial.field.lane_end_progress(lane))
			draw_line(center, _point(trial.field.lane_point(lane, ahead)), Color("ffab65"), 4, true)
		if mob.immune_until > trial.tick_count:
			draw_arc(center, radius + 3, 0, TAU, 24, Color("e9ba63"), 2)
	if trial.field.has_banner(mob):
		draw_arc(center, radius + 1, 0, TAU, 24, Color("c291eb"), 1)
	var bar: Rect2 = Rect2(stage.mob_head(mob, 1.0) + Vector2(-14, -8), Vector2(28, 3))
	draw_rect(bar, Color("18222b"))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * maxf(0, float(mob.hp) / mob.max_hp), 3)), Color("85c777"))
	if mob.ward_hp > 0:
		_ring(trial.field.get_mob_position(mob), 430, Color("9de3f5"), 3)
		draw_rect(Rect2(bar.position - Vector2(0, 4), Vector2(bar.size.x * float(mob.ward_hp) / trial.settings.ward_hp, 3)), Color("9de3f5"))


func _draw_preview() -> void:
	if not trial.field.layout.is_inside(hover_cell):
		return
	if action in [&"skill", &"palisade"]:
		var spot: Vector2i = road_spot(hover_cell)
		if spot.y >= 0:
			var point: Vector2i = trial.field.lane_point(spot.x, spot.y)
			_ring(point, trial.settings.hero_radius if action == &"skill" else 450, Color("f4dca0"))
			if action == &"skill":
				for base: MobState in trial.field.mobs:
					var mob: RitualMob = base as RitualMob
					if trial.field._is_in_range(point,
							trial.field.get_mob_position(mob), trial.settings.hero_radius):
						_text(_point(trial.field.get_mob_position(mob)) + Vector2(8, -12),
							"−%d%s" % [trial.hero_damage(mob), " щит" if mob.ward_hp > 0 else ""], Color.WHITE)
			else:
				var candidate: MobState = null
				var candidate_gap: int = 0
				for mob: MobState in trial.field.mobs:
					var mark: int = trial.spot_on_route(spot.x, spot.y, mob)
					if mob.is_alive() and trial.eligible_for_palisade(mob) and mark >= 0 and mob.progress <= mark \
							and (candidate == null or mark - mob.progress < candidate_gap):
						candidate = mob
						candidate_gap = mark - mob.progress
				var hint: String = "Пока нет тяжёлых перед точкой"
				if candidate != null:
					hint = "Ближайший: %s #%d" % [candidate.data.display_name, candidate.id]
					if candidate is RitualMob:
						var target: RitualMob = candidate as RitualMob
						if target.immune_until > trial.tick_count:
							hint += " · сейчас иммунитет"
				_text(Vector2(_origin.x + 8, _origin.y + 18), hint, Color.WHITE, 14)
				_text(Vector2(_origin.x + 8, _origin.y + 36), "Разгон и новые отряды могут изменить порядок", Color("dfc8a1"), 13)
		return
	var data: TowerData = null
	if preview_index >= 0:
		data = trial.settings.combat.towers[preview_index]
	elif action == &"move":
		var tower: TowerState = trial.field.get_tower(selected_id)
		if tower != null:
			data = tower.data
	if data == null:
		return
	var twin: TowerState = trial.field.get_tower_at(hover_cell)
	if twin != null and twin.data == data and twin.id != selected_id \
			and twin.level < trial.settings.combat.max_tower_level:
		var moving: TowerState = trial.field.get_tower(selected_id) if action == &"move" else null
		var level_ok: bool = twin.level == 1 if moving == null else moving.level == twin.level
		if level_ok:
			for cell: Vector2i in twin.cells():
				_tile(cell, Color(1, 0.82, 0.35, 0.55))
			_text(Vector2(_origin.x + 8, _origin.y + 18), "Слияние → уровень %d" % (twin.level + 1),
				Color("f4dca0"), 15)
			return
	var cells: Array[Vector2i] = TowerState.shape_cells_at(data.shape, hover_cell, preview_rotation)
	var valid: bool = trial.field.can_place(cells, selected_id if action == &"move" else 0)
	for cell: Vector2i in cells:
		_tile(cell, Color(0.5, 1, 0.65, 0.5) if valid else Color(1, 0.25, 0.2, 0.5))


func _get_tooltip(at_position: Vector2) -> String:
	if trial == null or stage == null or stage.layout == null:
		return ""
	var tower: TowerState = trial.field.get_tower_at(stage.cell_at(at_position))
	if tower != null:
		return "%s #%d · ур. %d\n%s\nЛКМ: выбор · ПКМ: поворот · перетащить на такую же — слияние" % [
			tower.data.display_name, tower.id, tower.level, tower.data.description]
	var closest: RitualMob = null
	var distance: float = _cell * _cell * 0.25
	for base: MobState in trial.field.mobs:
		var mob: RitualMob = base as RitualMob
		var squared: float = at_position.distance_squared_to(_point(trial.field.get_mob_position(mob)))
		if mob.is_alive() and squared < distance:
			closest = mob
			distance = squared
	if closest == null:
		return ""
	return "%s #%d\nHP %d/%d · оберег %d\nПрорыв: %d HP терема" % [closest.data.display_name,
		closest.id, closest.hp, closest.max_hp, closest.ward_hp, closest.breach_damage]


func _get_drag_data(at_position: Vector2) -> Variant:
	if trial == null or stage == null:
		return null
	var tower: TowerState = trial.field.get_tower_at(stage.cell_at(at_position))
	if tower == null:
		return null
	selected_id = tower.id
	var payload: DragPayload = DragPayload.for_tower(tower)
	payload.preview = ShapePreview.create_drag_preview(tower.data, tower.rotation, tower.level, 38)
	set_drag_preview(payload.preview)
	return payload


func _can_drop_data(at_position: Vector2, value: Variant) -> bool:
	if trial == null or stage == null or not value is DragPayload:
		return false
	var payload: DragPayload = value
	hover_cell = stage.cell_at(at_position)
	var under: TowerState = trial.field.get_tower_at(hover_cell)
	if payload.kind == DragPayload.Kind.RITE:
		# На поле кладут только чары; заговоры идолов — на идолы.
		if payload.rite == null or payload.rite.target != RiteData.Target.TOWER:
			return false
		var reason: String = "Наведите на башню" if under == null \
				else trial.enchant_error(payload.offer_index, under.id)
		selected_id = under.id if under != null else 0
		payload.show_rite_feedback(reason)
		queue_redraw()
		return reason.is_empty()
	if payload.kind not in [DragPayload.Kind.OFFER, DragPayload.Kind.TOWER] or payload.data == null:
		return false
	preview_rotation = payload.rotation
	preview_index = payload.offer_index if payload.kind == DragPayload.Kind.OFFER else -1
	selected_id = payload.tower_id
	action = &"buy" if payload.kind == DragPayload.Kind.OFFER else &"move"
	queue_redraw()
	if merge_target(payload, under) != null:
		return true
	var cells: Array[Vector2i] = TowerState.shape_cells_at(payload.data.shape, hover_cell, payload.rotation)
	return trial.field.can_place(cells, selected_id)


## Башня под курсором, с которой сольётся перетаскиваемое (или null).
func merge_target(payload: DragPayload, under: TowerState) -> TowerState:
	if under == null or under.data != payload.data or under.id == payload.tower_id \
			or under.level >= trial.settings.combat.max_tower_level:
		return null
	if payload.kind == DragPayload.Kind.OFFER:
		return under if under.level == 1 else null
	var dragged: TowerState = trial.field.get_tower(payload.tower_id)
	return under if dragged != null and dragged.level == under.level else null


func _drop_data(at_position: Vector2, value: Variant) -> void:
	if not value is DragPayload:
		return
	var payload: DragPayload = value
	var cell: Vector2i = stage.cell_at(at_position)
	var under: TowerState = trial.field.get_tower_at(cell)
	var command: RitualCommand
	if payload.kind == DragPayload.Kind.RITE:
		command = RitualCommand.new(RitualCommand.Action.ENCHANT, payload.offer_index,
			Vector2i.ZERO, 0, under.id if under != null else 0)
	elif payload.kind == DragPayload.Kind.TOWER and merge_target(payload, under) != null:
		command = RitualCommand.new(RitualCommand.Action.MERGE, under.id, Vector2i.ZERO, 0, payload.tower_id)
	elif payload.kind == DragPayload.Kind.OFFER:
		var twin: TowerState = merge_target(payload, under)
		command = RitualCommand.new(RitualCommand.Action.BUY, payload.offer_index, cell, payload.rotation,
			twin.id if twin != null else 0)
	else:
		command = RitualCommand.new(RitualCommand.Action.MOVE, payload.offer_index, cell, payload.rotation,
			payload.tower_id)
	command_requested.emit(command)
	action = &""
	preview_index = -1


func _input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_RIGHT and get_viewport().gui_is_dragging():
		var value: Variant = get_viewport().gui_get_drag_data()
		if value is DragPayload:
			var payload: DragPayload = value
			payload.rotate_preview()
			preview_rotation = payload.rotation
			queue_redraw()
			get_viewport().set_input_as_handled()

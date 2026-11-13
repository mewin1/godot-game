class_name RitualBoard
extends Control
## PvP-арена и проецируемый слой управления отдельного опыта.

signal command_requested(command: RitualCommand)
signal cell_clicked(cell: Vector2i, right: bool)
## Щелчок по идолу на площади (docs/37 IDL-2): номер идола.
signal idol_clicked(index: int)

const ELITE_CROWN: Texture2D = preload("res://assets/ui/elite_crown.svg")

var trial: RitualTrial
var selected_id: int = 0
var preview_index: int = -1
var preview_rotation: int = 0
var action: StringName = &""
## Припас под прицелом (RitualTrial.Supply) при action == &"supply".
var supply_kind: int = 0
var hover_cell: Vector2i = Vector2i(-1, -1)
## Отступы карты от краёв окна: слева/сверху — position, справа/снизу — size. По умолчанию —
## прежняя раскладка с лавкой слева; док забега задаёт свои (RitualTrialPanel).
var map_inset: Rect2 = Rect2(338, 76, 20, 134)
## Тип постройки, наведённой в каталоге (docs/37 UI-9): все такие дома обводятся, участки мерцают.
var highlight_data: TowerData
## Alt зажат: уровень и стихия над каждым домом (docs/37 UI-10).
var show_all_marks: bool = false
var _pulse: float = 0.0
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
## Числа урона (docs/37 RX-8, решение D11): 0 — нет, 1 — важные (по умолчанию), 2 — все.
enum Numbers { NONE, IMPORTANT, ALL }
const NUMBER_NAMES: Array[String] = ["нет", "важные", "все"]
const NUMBERS_CAP: int = 12
## Важный удар без реакции и не по боссу: не меньше этой доли наибольшего здоровья врага, %.
const BIG_HIT_PERCENT: int = 25
const SETTINGS_PATH: String = "user://settings.cfg"
var damage_numbers: Numbers = Numbers.IMPORTANT
## Урон по врагу, накопленный до следующего числа (одно число на врага за 0,5 с).
var _pending_damage: Dictionary[int, int] = {}
var _pending_ward: Dictionary[int, bool] = {}
## Враг, по которому только что сработала реакция: следующий удар — «важный».
var _reaction_until: Dictionary[int, int] = {}
var _last_hero_due: int = -1


func _process(delta: float) -> void:
	if trial == null or stage == null or size.x < 1:
		return
	if _shown_field != trial.field:
		_shown_field = trial.field
		stage.show_field(_shown_field, Callable())
		_shown_field.tower_fired.connect(_tower_fired)
		_shown_field.hit_observed.connect(_hit)
		_shown_field.effect_played.connect(_on_reaction)
		_pending_damage.clear()
		_reaction_until.clear()
		_hits.clear()
		effects.set_field(_shown_field)
		_next_hit_text.clear()
		_last_hero_due = -1
	stage.size = size
	stage.frame_board(Rect2(map_inset.position, size - map_inset.position - map_inset.size))
	_pulse = fmod(_pulse + delta, 1.6)
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



func _on_reaction(_effect_id: StringName, mob: MobState) -> void:
	if mob != null:
		_reaction_until[mob.id] = trial.tick_count + 3


## Число над врагом: копится по врагу и всплывает раз в 0,5 с; в режиме «важные» — только после
## реакции, по боссу или крупный удар (docs/37 RX-8).
func _hit(details: Dictionary) -> void:
	if damage_numbers == Numbers.NONE:
		return
	var id: int = RitualStateCodec.integer(details["mob"])
	var ward: int = RitualStateCodec.integer(details["ward_damage"])
	var damage: int = RitualStateCodec.integer(details["hp_damage"]) + ward
	if damage <= 0:
		return
	for mob: MobState in trial.field.mobs:
		if mob.id != id:
			continue
		if damage_numbers == Numbers.IMPORTANT:
			var boss: bool = mob.data.tags.has(trial.settings.boss_tag)
			var reacted: bool = trial.tick_count <= _reaction_until.get(id, -1)
			if not boss and not reacted and damage * 100 < mob.max_hp * BIG_HIT_PERCENT:
				return
		_pending_damage[id] = _pending_damage.get(id, 0) + damage
		_pending_ward[id] = _pending_ward.get(id, false) or ward > 0
		if trial.tick_count < _next_hit_text.get(id, 0):
			return
		_next_hit_text[id] = trial.tick_count + 10
		var reacted_now: bool = trial.tick_count <= _reaction_until.get(id, -1)
		var color: Color = Color("a6e7ff") if _pending_ward[id] else Color("ffb36b") if reacted_now \
			else Color("ffe4a5")
		if _hits.size() >= NUMBERS_CAP:
			_hits.remove_at(0)
		_hits.append(Hit.new(Vector2.ZERO, Vector2(trial.field.get_mob_position(mob)),
			0.6, color, str(_pending_damage[id])))
		_pending_damage[id] = 0
		_pending_ward[id] = false
		return


## Следующий режим чисел урона; запоминается в настройках игрока.
func cycle_damage_numbers() -> String:
	damage_numbers = ((damage_numbers + 1) % 3) as Numbers
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("ritual", "damage_numbers", int(damage_numbers))
	config.save(SETTINGS_PATH)
	return NUMBER_NAMES[damage_numbers]


func _load_damage_numbers() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		var saved: int = RitualStateCodec.integer(config.get_value("ritual", "damage_numbers", 1), 1)
		damage_numbers = clampi(saved, 0, 2) as Numbers


func _ready() -> void:
	_load_damage_numbers()
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
		stage.idol_hovered = stage.idol_at(motion.position) if action == &"" else -1
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if stage.idol_hovered >= 0 \
			else Control.CURSOR_ARROW
		queue_redraw()
	elif event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.pressed and button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			var idol: int = stage.idol_at(button.position) if action == &"" else -1
			if idol >= 0 and button.button_index == MOUSE_BUTTON_LEFT:
				idol_clicked.emit(idol)
				accept_event()
				return
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
	if trial.settings.uses_plots():
		var wanted: bool = action == &"buy" or highlight_data != null
		var glow: float = 0.55 + 0.45 * absf(sin(_pulse / 1.6 * TAU)) if wanted else 1.0
		for cell: Vector2i in field.get_buildable_cells():
			if field.get_tower_at(cell) == null:
				_tile(cell, Color(0.3, 0.34, 0.33, 0.45))
				_tile(cell, Color(Color("f0c27a"), glow) if wanted else Color("7f8a85"), false)
	elif action in [&"buy", &"move"]:
		for cell: Vector2i in field.get_buildable_cells():
			_tile(cell, Color(0.6, 0.8, 0.75, 0.13), false)
	for tower: TowerState in field.towers:
		_draw_tower(tower)
	if trial.settings.uses_plots():
		for tower: TowerState in field.towers:
			_draw_kin(tower)
		_draw_combo_links()
	for base: MobState in field.mobs:
		_draw_mob(base as RitualMob)
	if trial.hero_due >= 0:
		_ring(field.lane_point(trial.hero_lane, trial.hero_progress), trial.skill_radius(), Color("f7d886"), 3)
	if trial.tar_until > trial.tick_count:
		_ring(field.lane_point(trial.tar_lane, trial.tar_progress), trial.settings.tar_radius_milli, Color("8a5a2b"), 4)
	if trial.rain_tick >= 0 and trial.tick_count - trial.rain_tick < 20:
		_ring(field.lane_point(trial.rain_lane, trial.rain_progress), trial.settings.rain_radius_milli, Color("6fb6e8"), 4)
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
		if tower.id == selected_id and not trial.settings.uses_plots():
			_tile(cell, Color("ffe4a5"), false)
		if tower.is_action_blocked():
			_tile(cell, Color(0.1, 0.15, 0.2, 0.65))
	var center: Vector2 = _point(tower.center_milli())
	if trial.settings.uses_plots() and tower.durability >= 0:
		var full: int = trial.settings.max_durability(tower.level)
		if tower.durability * 2 <= full:
			var roof: Vector2 = stage.tower_top(tower.id)
			var worn: Color = Color("ff6555") if tower.durability == 0 else Color("ffc36b")
			_ring(tower.center_milli(), 480, worn, 2.5)
			_text(roof + Vector2(-4, -5), "!" if tower.durability > 0 else "X", worn, 20)
			draw_polyline(PackedVector2Array([roof + Vector2(-7, 5), roof + Vector2(0, 9),
				roof + Vector2(-2, 15), roof + Vector2(6, 19)]), Color("271e18"), 2.5, true)
	# Стрелка ветра - у выбранной, под курсором и пока ищем место: пять домов ветра иначе
	# расчерчивают всю карту (docs/37 BUG-18).
	var wind_shown: bool = tower.id == selected_id or action in [&"buy", &"move"] \
			or tower.cells().has(hover_cell)
	if tower.data.wind_length_milli > 0 and wind_shown:
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
		var width: float = 2.5 if trial.settings.uses_plots() else 1.5
		_ring(tower.center_milli(), trial.field.get_tower_range(tower), Color(color, 0.7), width)


## Дома того же типа, что выбранный или наведённый в каталоге (docs/37 UI-8, UI-9): обводка,
## уровень и стрелка улучшения (золотая — хватает золота, серая — нет). С Alt — над всеми домами.
func _draw_kin(tower: TowerState) -> void:
	var selected: TowerState = trial.field.get_tower(selected_id)
	var kin: bool = (selected != null and selected.data == tower.data) \
		or (highlight_data != null and highlight_data == tower.data)
	if tower.id == selected_id:
		for cell: Vector2i in tower.cells():
			_tile(cell, Color(1, 0.86, 0.5, 0.18))
			_tile_outline(cell, Color("ffe4a5"), 4.0)
	elif kin:
		for cell: Vector2i in tower.cells():
			_tile_outline(cell, Color(GodSymbols.get_color(tower.data.god), 0.95), 3.0)
	if not (kin or show_all_marks):
		return
	var top: Vector2 = stage.tower_top(tower.id) + Vector2(0, -6)
	_level_pips(top, tower.level, GodSymbols.get_color(tower.data.god))
	if tower.level < trial.settings.combat.max_tower_level and kin:
		var ready: bool = trial.upgrade_error(tower, 0 if tower.level == 2 else -1).is_empty() \
			and trial.gold >= trial.upgrade_cost(tower)
		_text(top + Vector2(20, 6), "↑", Color("ffd36b") if ready else Color(0.6, 0.6, 0.6, 0.8), 18)


## Связки реакций (docs/37 RX-5): от выбранного дома или от участка под покупку — линии к соседям
## в досягаемости, с которыми он даёт реакцию, и её название посередине.
func _draw_combo_links() -> void:
	var data: TowerData = null
	var center: Vector2i = Vector2i.ZERO
	var reach: int = 0
	var self_id: int = 0
	var selected: TowerState = trial.field.get_tower(selected_id)
	if action == &"buy" and preview_index >= 0 and trial.field.is_buildable(hover_cell) \
			and trial.field.get_tower_at(hover_cell) == null:
		data = trial.settings.combat.towers[preview_index]
		center = TowerState.center_of([hover_cell])
		reach = data.range_milli
	elif selected != null and action == &"":
		data = selected.data
		center = selected.center_milli()
		reach = trial.field.get_tower_range(selected)
		self_id = selected.id
	if data == null:
		return
	var from: Vector2 = _point(center) + Vector2(0, -_cell * 0.6)
	for other: TowerState in trial.field.towers:
		if other.id == self_id:
			continue
		var gap: Vector2 = Vector2(other.center_milli() - center)
		if gap.length() > reach + trial.field.get_tower_range(other):
			continue
		var reaction: ReactionData = reaction_between(data, other.data, trial.settings.combat.reactions)
		if reaction == null:
			continue
		var to: Vector2 = _point(other.center_milli()) + Vector2(0, -_cell * 0.6)
		var tint: Color = GodSymbols.get_color(data.god).lerp(GodSymbols.get_color(other.data.god), 0.5)
		draw_line(from, to, Color(tint, 0.85), 3.0, true)
		var middle: Vector2 = (from + to) * 0.5
		var font: Font = ThemeDB.fallback_font
		var width: float = font.get_string_size(reaction.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_rect(Rect2(middle - Vector2(width * 0.5 + 4, 11), Vector2(width + 8, 16)), Color(0.03, 0.05, 0.08, 0.85))
		draw_string(font, middle + Vector2(-width * 0.5, 2), reaction.display_name, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 13, tint.lightened(0.45))


## Статус, который ставит постройка (для подсказок о реакциях), или пусто.
static func applied_status(data: TowerData) -> StringName:
	if data.wet_ticks > 0:
		return &"wet"
	if data.burn_percent > 0:
		return &"burn"
	if data.cold_ticks > 0:
		return &"cold"
	if data.curse_ticks > 0:
		return &"curse"
	if data.charge_ticks > 0:
		return &"charge"
	return &""


## Реакция пары построек: стихия одной по статусу другой (в любую сторону); null — нет.
static func reaction_between(a: TowerData, b: TowerData, reactions: Array[ReactionData]) -> ReactionData:
	var rule: ReactionData = _one_way(a, b, reactions)
	return rule if rule != null else _one_way(b, a, reactions)


## Стихия incoming по статусу, который ставит holder.
static func _one_way(incoming: TowerData, holder: TowerData, reactions: Array[ReactionData]) -> ReactionData:
	var status: StringName = applied_status(holder)
	if status == &"":
		return null
	var statuses: Array[StringName] = [status]
	for tag: StringName in incoming.tags:
		var rule: ReactionData = ReactionResolver.resolve(tag, statuses, reactions)
		if rule != null:
			return rule
	return null


## Четыре ступени уровня (дерево, камень, кирпич, белый камень): закрашено столько, сколько уровень.
func _level_pips(at: Vector2, level: int, color: Color) -> void:
	var count: int = trial.settings.combat.max_tower_level
	var step: float = 9.0
	var x: float = at.x - step * (count - 1) * 0.5
	draw_rect(Rect2(Vector2(x - 7, at.y - 6), Vector2(step * count + 5, 12)), Color(0.02, 0.04, 0.06, 0.75))
	for index: int in count:
		var point: Vector2 = Vector2(x + step * index, at.y)
		if index < level:
			draw_circle(point, 3.4, Color("ffe4a5"))
		else:
			draw_arc(point, 3.0, 0, TAU, 12, Color(color, 0.7), 1.2)


func _tile_outline(cell: Vector2i, color: Color, width: float) -> void:
	var points: PackedVector2Array = []
	for corner: Vector2 in [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN, Vector2.ZERO]:
		points.append(stage.project_cell_corner(cell, corner, 0.13))
	draw_polyline(points, color, width, true)


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
	if mob.elite_rank > 0:
		draw_texture_rect(ELITE_CROWN,
			Rect2(stage.mob_head(mob, 1.0) + Vector2(-10, -43), Vector2(20, 16)), false)
	if mob.stun_ticks_left > 0:
		_text(center + Vector2(-3, -radius), "*", Color.WHITE, 18)
	if boss:
		if mob.boss_phase == RitualMob.BossPhase.WARNING:
			_text(stage.mob_head(mob, 1.0) + Vector2(-55, -51 if mob.elite_rank > 0 else -31),
				"РЫВОК!", Color("ffab65"), 20)
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
	_draw_statuses(mob, Vector2(bar.get_center().x, bar.end.y + 5))


## Статусы под полоской здоровья: форма своя у каждого (не только цвет) - мокрый капля,
## горит треугольник, заряд ромб, холод/лед квадрат, проклятие крест (docs/37 BUG-25).
func _draw_statuses(mob: MobState, at: Vector2) -> void:
	var marks: Array[StringName] = []
	if mob.wet_ticks_left > 0:
		marks.append(&"wet")
	if mob.burn_ticks_left > 0:
		marks.append(&"burn")
	if mob.charge_ticks_left > 0:
		marks.append(&"charge")
	if mob.cold_ticks_left > 0 or mob.freeze_ticks_left > 0:
		marks.append(&"cold")
	if mob.curse_ticks_left > 0:
		marks.append(&"curse")
	var step: float = 9.0
	var x: float = at.x - step * (marks.size() - 1) * 0.5
	for mark: StringName in marks:
		var point: Vector2 = Vector2(x, at.y)
		match mark:
			&"wet":
				draw_circle(point + Vector2(0, 1), 3.2, Color("4fc3f7"))
				draw_colored_polygon(PackedVector2Array([point + Vector2(0, -4), point + Vector2(-2.6, 0),
					point + Vector2(2.6, 0)]), Color("4fc3f7"))
			&"burn":
				draw_colored_polygon(PackedVector2Array([point + Vector2(0, -4), point + Vector2(-4, 3),
					point + Vector2(4, 3)]), Color("ff8a3d"))
			&"charge":
				draw_colored_polygon(PackedVector2Array([point + Vector2(0, -4), point + Vector2(3.5, 0),
					point + Vector2(0, 4), point + Vector2(-3.5, 0)]), Color("ffe066"))
			&"cold":
				draw_rect(Rect2(point - Vector2(3.5, 3.5), Vector2(7, 7)),
					Color("e6fbff") if mob.freeze_ticks_left > 0 else Color("a1e8f5"))
			&"curse":
				draw_line(point + Vector2(-3.5, -3.5), point + Vector2(3.5, 3.5), Color("d070f0"), 2.5, true)
				draw_line(point + Vector2(-3.5, 3.5), point + Vector2(3.5, -3.5), Color("d070f0"), 2.5, true)
		x += step


func _draw_preview() -> void:
	if not trial.field.layout.is_inside(hover_cell):
		return
	if action == &"supply":
		var supply_spot: Vector2i = road_spot(hover_cell)
		if supply_spot.y >= 0:
			_ring(trial.field.lane_point(supply_spot.x, supply_spot.y), trial.supply_radius(supply_kind),
				Color("8a5a2b") if supply_kind == RitualTrial.Supply.TAR else Color("6fb6e8"))
		return
	if action in [&"skill", &"palisade"]:
		var spot: Vector2i = road_spot(hover_cell)
		if spot.y >= 0:
			var point: Vector2i = trial.field.lane_point(spot.x, spot.y)
			_ring(point, trial.skill_radius() if action == &"skill" else 450, Color("f4dca0"))
			if action == &"skill":
				var whistle: bool = trial.hero() != null and trial.hero().skill == RitualHeroData.Skill.WHISTLE
				for base: MobState in trial.field.mobs:
					var mob: RitualMob = base as RitualMob
					if mob.is_alive() and trial.field._is_in_range(point,
							trial.field.get_mob_position(mob), trial.skill_radius()):
						var note: String = "назад" if whistle \
								else "−%d%s" % [trial.hero_damage(mob), " щит" if mob.ward_hp > 0 else ""]
						_text(_point(trial.field.get_mob_position(mob)) + Vector2(8, -12), note, Color.WHITE)
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
	if not trial.settings.uses_plots() and twin != null and twin.data == data and twin.id != selected_id \
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
	if stage.idol_at(at_position) >= 0:
		return "Идол: щёлкните — посвятить богу или купить заговор"
	var tower: TowerState = trial.field.get_tower_at(stage.cell_at(at_position))
	if tower != null and trial.settings.uses_plots():
		var levels: RitualBuildingLevels = trial.settings.levels_for(tower.data)
		return "%s · %s\n%s\nЛКМ: выбрать · Tab: следующий такой же · Alt: уровни всех домов" % [
			tower.data.display_name, trial.settings.level_name(tower.level),
			levels.role if levels != null else tower.data.description]
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
	if trial == null or stage == null or trial.settings.uses_plots():
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
	if trial.settings.uses_plots():
		return null
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
	if trial != null and trial.settings.uses_plots():
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_RIGHT and get_viewport().gui_is_dragging():
		var value: Variant = get_viewport().gui_get_drag_data()
		if value is DragPayload:
			var payload: DragPayload = value
			payload.rotate_preview()
			preview_rotation = payload.rotation
			queue_redraw()
			get_viewport().set_input_as_handled()

class_name BattleLayer
extends Control
## Боевой слой поверх поля: мобы, летящие снаряды, вспышки попаданий, «пых» при смерти,
## всплывающее золото и красная вспышка прорыва. Чисто визуальный: только читает симуляцию.
## Снаряд летит доли секунды, хотя в симуляции попадание мгновенное, — это нормально.

signal sound_requested(sound_id: StringName)

const MILLI: float = 1000.0
const IMPACT_SECONDS: float = 0.28
const FLOAT_TEXT_SECONDS: float = 1.0
const BREACH_FLASH_SECONDS: float = 0.5
const PUFF_SECONDS: float = 0.6
const SHADOW_COLOR: Color = Color(0.0, 0.0, 0.0, 0.35)
const HP_BACK_COLOR: Color = Color(0.05, 0.04, 0.03, 0.85)
const HP_GOOD_COLOR: Color = Color(0.56, 0.74, 0.4)
const HP_LOW_COLOR: Color = Color(0.85, 0.36, 0.25)
const BREACH_TEXT_COLOR: Color = Color(1.0, 0.45, 0.35)
## Моб проявляется из ворот на первых долях клетки пути (в тысячных).
const FADE_IN_MILLI: float = 400.0
const HP_TEXT_COLOR: Color = Color(0.94, 0.89, 0.81)
const SHOT_SOUNDS: Array[StringName] = [
	&"shot_fire", &"shot_ice", &"shot_mech", &"shot_mech", &"shot_ice"]
const STRIKE_COLOR: Color = Color(1.0, 0.85, 0.5)
const SILENCE_TEXT_COLOR: Color = Color(1.0, 0.55, 0.3)
const KNOCKBACK_COLOR: Color = Color(0.55, 0.8, 0.35)
const HEAL_COLOR: Color = Color(0.56, 0.82, 0.42)
const ANGRY_COLOR: Color = Color(0.95, 0.3, 0.2)
const SHIELD_COLOR: Color = Color(0.77, 0.6, 0.32)
## Летающие рисуются выше земли (в долях своего размера), невидимки — полупрозрачными.
const FLY_LIFT: float = 0.45
const STEALTH_ALPHA: float = 0.45

var interpolation: float = 0.0
var playback_speed: int = 1
var is_own_field: bool = false
var hero_hp: int = 0
## Центр таблички HP героя на экране (её место задаёт FieldView: там же терем).
var hero_plate_center: Vector2 = Vector2.ZERO
var hero_shake: Vector2 = Vector2.ZERO

static var _puff_texture: Texture2D

var _field: FieldState
var show_target_labels: bool = false
var selected_mob_id: int = 0
var draw_world_towers: bool = false
var is_preparation_court: bool = false
var has_atmosphere: bool = false
var tower_pulses: Dictionary[int, float] = {}
var tower_pops: Dictionary[int, float] = {}
var point_projector: Callable
var _style: FieldStyle
var _catalog: VisualCatalog
var _origin: Vector2 = Vector2.ZERO
var _cell_size: float = 32.0
var _time: float = 0.0
var _flashes: Array[ReactionFlash] = []
var _reaction_next_text: Dictionary[StringName, float] = {}
var _breach_flash_left: float = 0.0
var _projectiles: Array[Projectile] = []
var _impacts: Array[Impact] = []
var _texts: Array[FloatText] = []
var _lightning: Array[LightningArc] = []
## Куда смотрит моб (true — влево): сохраняем, чтобы он не «моргал» на вертикальных участках.
var _facing_left: Dictionary[int, bool] = {}
var _living_flame: LivingFlame


func _init() -> void:
	_catalog = VisualCatalog.get_default()
	_style = _catalog.field
	_living_flame = LivingFlame.new()
	add_child(_living_flame)


func _process(delta: float) -> void:
	delta *= playback_speed
	_time += delta
	_living_flame.set_time(_time)
	_living_flame.render_target_update_mode = (SubViewport.UPDATE_ALWAYS
			if has_atmosphere and is_visible_in_tree() else SubViewport.UPDATE_DISABLED)
	_breach_flash_left = maxf(0.0, _breach_flash_left - delta)
	for i: int in range(_flashes.size() - 1, -1, -1):
		_flashes[i].age += delta
		if _flashes[i].age >= ReactionFlash.LIFETIME:
			_flashes.remove_at(i)
	_update_projectiles(delta)
	_impacts = _impacts.filter(func(impact: Impact) -> bool:
		impact.age += delta
		return impact.age < IMPACT_SECONDS)
	_texts = _texts.filter(func(text: FloatText) -> bool:
		text.age += delta
		return text.age < FLOAT_TEXT_SECONDS)
	_lightning = _lightning.filter(func(arc: LightningArc) -> bool:
		arc.age += delta
		return arc.age < arc.lifetime)
	queue_redraw()


## Подключает поле (сбрасывает эффекты прошлого поля).
func set_field(field: FieldState) -> void:
	if _field != null:
		_field.lightning_fired.disconnect(_on_lightning_fired)
		_field.curse_transferred.disconnect(_on_curse_transferred)
		_field.tower_fired.disconnect(_on_field_tower_fired)
		_field.mob_killed.disconnect(_on_field_mob_killed)
		_field.breach_resolved.disconnect(_on_breach_resolved)
		_field.effect_played.disconnect(_on_field_effect_played)
		_field.tower_pulsed.disconnect(_on_field_tower_pulsed)
	_field = field
	_projectiles.clear()
	_impacts.clear()
	_texts.clear()
	_reaction_next_text.clear()
	_flashes.clear()
	_facing_left.clear()
	_lightning.clear()
	_field.lightning_fired.connect(_on_lightning_fired)
	_field.curse_transferred.connect(_on_curse_transferred)
	_field.tower_fired.connect(_on_field_tower_fired)
	_field.mob_killed.connect(_on_field_mob_killed)
	_field.breach_resolved.connect(_on_breach_resolved)
	_field.effect_played.connect(_on_field_effect_played)
	_field.tower_pulsed.connect(_on_field_tower_pulsed)


## Вспышка частиц в точке экрана (покупка, слияние, продажа — их замечает FieldView).
func play_burst(at: Vector2, color: Color) -> void:
	_spawn_puff(at, color)


## Положение и размер клетки поля на экране (их считает FieldView).
func set_layout(origin: Vector2, cell_size: float) -> void:
	_origin = origin
	_cell_size = cell_size


#region Рисование

func _draw() -> void:
	if _field == null:
		return
	_draw_mobs()
	for arc: LightningArc in _lightning:
		var start: Vector2 = _milli_to_screen(Vector2(arc.from_milli))
		var end: Vector2 = _milli_to_screen(Vector2(arc.to_milli))
		var middle: Vector2 = (start + end) * 0.5 + Vector2(5, -7)
		draw_polyline(PackedVector2Array([start, middle, end]), arc.color, 3, true)
		if arc.is_transfer:
			var direction: Vector2 = (end - middle).normalized()
			var side: Vector2 = direction.orthogonal() * 5
			draw_colored_polygon(PackedVector2Array([end, end - direction * 12 + side,
					end - direction * 12 - side]), arc.color)
	for projectile: Projectile in _projectiles:
		_draw_projectile(projectile)
	for impact: Impact in _impacts:
		_draw_impact(impact)
	if not is_preparation_court:
		_draw_hero_hp(hero_plate_center)
	for flash: ReactionFlash in _flashes:
		flash.draw(self, _milli_to_screen(Vector2(flash.position_milli)), _cell_size)
	for text: FloatText in _texts:
		_draw_float_text(text)
	if _breach_flash_left > 0.0:
		var alpha: float = _breach_flash_left / BREACH_FLASH_SECONDS
		draw_rect(Rect2(Vector2.ZERO, size), Color(_style.breach_color, 0.16 * alpha))
		draw_rect(Rect2(Vector2.ZERO, size).grow(-4.0), Color(_style.breach_color, 0.7 * alpha),
				false, 8.0)


func _draw_mobs() -> void:
	if not draw_world_towers:
		for mob: MobState in _field.mobs:
			_draw_mob(mob)
		return
	var towers: Array[TowerState] = _field.towers.duplicate()
	towers.sort_custom(func(first: TowerState, second: TowerState) -> bool:
		return first.center_milli().y < second.center_milli().y)
	var mobs: Array[MobState] = _field.mobs.duplicate()
	mobs.sort_custom(func(first: MobState, second: MobState) -> bool:
		return _mob_screen_position(first).y < _mob_screen_position(second).y)
	var tower_index: int = 0
	for mob: MobState in mobs:
		var foot: Vector2 = _mob_screen_position(mob)
		while tower_index < towers.size() and _tower_foot(towers[tower_index]).y <= foot.y:
			_draw_world_tower(towers[tower_index])
			tower_index += 1
		_draw_mob(mob)
	while tower_index < towers.size():
		_draw_world_tower(towers[tower_index])
		tower_index += 1
	var path: Array[Vector2i] = _field.get_active_path()
	var gate: Vector2 = _milli_to_screen((Vector2(path[-1]) + Vector2.ONE * 0.5) * MILLI)
	if has_atmosphere:
		var foot: Vector2 = gate + hero_shake + Vector2(0, _cell_size * 0.15)
		PlantedSprite.draw(self, CourtyardPainter.EXIT_WEAPON, foot,
				Vector2.ONE * _cell_size, Color("bd9469"), 0.84)
	else:
		CourtyardPainter.draw_exit(self, gate + hero_shake, _cell_size)
	if mobs.is_empty():
		_facing_left.clear()


func _tower_foot(tower: TowerState) -> Vector2:
	return _milli_to_screen(Vector2(tower.center_milli()))


func _draw_world_tower(tower: TowerState) -> void:
	var pulse: float = tower_pulses.get(tower.id, 0.0) / TowerPainter.FIRE_PULSE_SECONDS
	var pop: float = tower_pops.get(tower.id, 0.0) / TowerPainter.POP_SECONDS
	TowerPainter.draw_world_tower(self, tower, _tower_foot(tower), _cell_size, pulse, pop,
			has_atmosphere)
	_draw_tower_embers(tower, pulse, pop)


func _draw_tower_embers(tower: TowerState, pulse: float, pop: float) -> void:
	if not has_atmosphere:
		return
	var visual: TowerVisual = _catalog.get_tower(tower.data.id)
	if not visual.has_embers:
		return
	var dimensions: Vector2 = TowerPainter.world_dimensions(tower, _cell_size, pulse, pop)
	var height: float = dimensions.y
	var foot: Vector2 = _tower_foot(tower) + Vector2(0, _cell_size * 0.23)
	var anchor: Vector2 = Vector2(0.5, 0.89)
	var source: Vector2 = foot + (visual.ember_source - anchor) * dimensions
	var flame_size: Vector2 = Vector2(0.25, 0.30) * height
	draw_texture_rect(_living_flame.get_texture(),
			Rect2(source - flame_size * Vector2(0.5, 0.90), flame_size), false)
	CourtAtmosphere.draw_embers(self, source, height, _time, float(tower.id))


## Моб: тень, картинка с покачиванием (повёрнута по ходу), синий оттенок под замедлением, HP.
func _draw_mob(mob: MobState) -> void:
	var visual: MobVisual = _catalog.get_mob(mob.data.id)
	var previous: Vector2 = _milli_to_screen(Vector2(_field.get_path_point(mob.previous_progress)))
	var feet: Vector2 = _mob_screen_position(mob)
	var step_x: float = feet.x - previous.x
	if absf(step_x) > 0.01:
		_facing_left[mob.id] = step_x < 0.0
	var sprite_size: float = visual.size_cells * _cell_size
	if has_atmosphere:
		sprite_size *= 1.12
	if not draw_world_towers:
		feet.y += sprite_size * 0.3
	var bob_speed: float = visual.bob_speed * (2.0 if _field.is_enraged else 1.0)
	var phase: float = _time * bob_speed * PI + mob.id
	var bob: float = absf(sin(phase)) * visual.bob_height * sprite_size
	var tilt: float = sin(phase) * 0.07
	draw_set_transform(feet, 0.0, Vector2(1.0, 0.32))
	if has_atmosphere:
		# Мягкая тень между сапогами, чтобы пехота держалась на камне при шаге.
		var shadow_size: Vector2 = Vector2.ONE * sprite_size * 0.66
		draw_texture_rect(preload("res://data/visuals/soft_light.tres"),
				Rect2(-shadow_size * 0.5, shadow_size), false, Color(0.02, 0.03, 0.05, 0.8))
		if not mob.data.is_flying:
			bob *= 0.35
			tilt *= 0.55
	else:
		draw_circle(Vector2.ZERO, sprite_size * 0.36, SHADOW_COLOR)
	if mob.sender_index >= 0:
		# Чья армия: кольцо цвета игрока под юнитом.
		draw_arc(Vector2.ZERO, sprite_size * 0.36, 0.0, TAU, 24,
				_style.get_player_color(mob.sender_index), 5.0, true)
	if mob.is_angry:
		# Злая армия: красноватое «пламя» под ногами.
		draw_circle(Vector2.ZERO, sprite_size * 0.5, Color(ANGRY_COLOR, 0.25 + 0.15 * sin(phase * 2.0)))
	if mob.slow_percent > 0 or mob.wind_slow_percent > 0 or mob.cold_ticks_left > 0:
		draw_arc(Vector2.ZERO, sprite_size * 0.42, 0.0, TAU, 24, _style.slow_tint, 3.0, true)
	var flip: float = -1.0 if _facing_left.get(mob.id, false) else 1.0
	if mob.data.is_flying:
		# Летун парит над дорогой: тень на земле, сам выше.
		bob += sprite_size * FLY_LIFT
	draw_set_transform(feet - Vector2(0, bob), tilt, Vector2(flip, 1.0))
	var tint: Color = Color(1, 1, 1, clampf(mob.progress / FADE_IN_MILLI, 0.0, 1.0))
	if mob.data.reveal_radius_milli > 0:
		tint.a *= STEALTH_ALPHA
	if _field.is_enraged:
		tint = Color(_style.enrage_tint, tint.a)
	if mob.slow_percent > 0 or mob.wind_slow_percent > 0 or mob.cold_ticks_left > 0:
		tint = tint * _style.slow_tint
	var dimensions: Vector2 = Vector2(visual.texture.get_size())
	dimensions *= sprite_size / dimensions.y
	draw_texture_rect(visual.texture, Rect2(Vector2(-dimensions.x * 0.5, -sprite_size),
			dimensions), false, tint)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if mob.shield_left > 0:
		draw_arc(feet - Vector2(0, bob + sprite_size * 0.5), sprite_size * 0.55, -2.4, -0.7, 16,
				SHIELD_COLOR, 3.0, true)
	if mob.burn_ticks_left > 0:
		draw_circle(feet - Vector2(0, sprite_size * 0.55), sprite_size * 0.18,
				Color(1, 0.4, 0.08, 0.6))
	if mob.wet_ticks_left > 0:
		draw_arc(feet - Vector2(0, sprite_size * 0.5), sprite_size * 0.58, 0, TAU,
				16, Color(0.2, 0.85, 0.95, 0.9), 2.0, true)
	if mob.charge_ticks_left > 0:
		draw_arc(feet - Vector2(0, sprite_size * 0.5), sprite_size * 0.5, 0, TAU,
				16, Color(0.55, 0.85, 1), float(maxi(2, mob.charges + 1)), true)
	if mob.freeze_ticks_left > 0:
		draw_rect(Rect2(feet - Vector2(sprite_size * 0.5, sprite_size),
				Vector2.ONE * sprite_size), Color(0.5, 0.85, 1, 0.32))
	if mob.curse_ticks_left > 0:
		draw_arc(feet - Vector2(0, sprite_size * 0.5), sprite_size * 0.62, 0, TAU,
				16, Color(0.8, 0.3, 0.9), 3.0, true)
	if mob.hp < mob.max_hp:
		_draw_hp_bar(Vector2(feet.x, feet.y - sprite_size - bob - 4.0), sprite_size * 0.7,
				float(mob.hp) / mob.max_hp)
	if show_target_labels:
		if mob.id == selected_mob_id:
			draw_arc(feet, sprite_size * 0.45, 0, TAU, 20, Color(1, 0.85, 0.4), 3, true)
		var font: Font = get_theme_default_font()
		var at: Vector2 = feet - Vector2(sprite_size * 0.5, sprite_size + 12)
		var caption: String = "#%d · %d" % [mob.id, maxi(0, mob.hp)]
		draw_string_outline(font, at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3,
				Color(0.08, 0.05, 0.1))
		draw_string(font, at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


func _draw_hero_hp(center: Vector2) -> void:
	var font: Font = get_theme_default_font()
	var font_size: int = maxi(12, int(_cell_size * 0.34))
	var text: String = str(maxi(0, hero_hp))
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var icon_size: float = font_size * 1.1
	var plate_size: Vector2 = Vector2(icon_size + text_width + 14.0, font_size * 1.45)
	var plate: Rect2 = Rect2(center - plate_size * 0.5, plate_size)
	draw_rect(plate.grow(2.0), Color(0.07, 0.05, 0.04, 0.9))
	draw_rect(plate, Color(0.2, 0.14, 0.1, 0.95))
	draw_texture_rect(_style.heart_icon, Rect2(plate.position + Vector2(4.0,
			(plate_size.y - icon_size) * 0.5), Vector2.ONE * icon_size), false)
	draw_string(font, Vector2(plate.position.x + icon_size + 8.0, center.y + font_size * 0.36),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, HP_TEXT_COLOR)


func _draw_hp_bar(top_center: Vector2, width: float, ratio: float) -> void:
	var height: float = maxf(3.0, _cell_size * 0.07)
	var bar: Rect2 = Rect2(top_center - Vector2(width * 0.5, height), Vector2(width, height))
	draw_rect(bar.grow(1.0), HP_BACK_COLOR)
	var color: Color = HP_GOOD_COLOR if ratio > 0.4 else HP_LOW_COLOR
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(ratio, 0.0, 1.0), height)), color)


func _draw_projectile(projectile: Projectile) -> void:
	var t: float = projectile.age / projectile.visual.projectile_seconds
	var from: Vector2 = _milli_to_screen(projectile.from_milli)
	if draw_world_towers:
		from.y -= _cell_size * 0.6
	var to: Vector2 = _projectile_target(projectile)
	var point: Vector2 = from.lerp(to, t)
	var direction: Vector2 = (to - from).normalized()
	var color: Color = projectile.visual.projectile_color
	match projectile.visual.projectile:
		TowerVisual.Projectile.FIREBALL:
			# Огненный шар летит дугой и тянет за собой хвост.
			point.y -= sin(t * PI) * _cell_size * 0.35
			for i: int in 3:
				var trail: Vector2 = point - direction * _cell_size * 0.1 * (i + 1)
				draw_circle(trail, _cell_size * (0.09 - 0.02 * i), Color(color, 0.45 - 0.12 * i))
			draw_circle(point, _cell_size * 0.16, Color(color, 0.35))
			draw_circle(point, _cell_size * 0.1, color)
			draw_circle(point, _cell_size * 0.05, Color(1.0, 0.95, 0.8))
		TowerVisual.Projectile.SHARD:
			var length: float = _cell_size * 0.26
			var side: Vector2 = direction.orthogonal() * _cell_size * 0.06
			var shard: PackedVector2Array = [point + direction * length, point + side,
					point - direction * length * 0.6, point - side]
			draw_colored_polygon(shard, color)
			draw_polyline(shard + PackedVector2Array([shard[0]]), Color(0.2, 0.35, 0.45), 1.5)
		TowerVisual.Projectile.LIGHTNING:
			var tail: Vector2 = point - direction * _cell_size * 0.55
			var zigzag: PackedVector2Array = [tail,
					tail.lerp(point, 0.35) + direction.orthogonal() * _cell_size * 0.12,
					tail.lerp(point, 0.65) - direction.orthogonal() * _cell_size * 0.12, point]
			draw_polyline(zigzag, Color(1, 0.92, 0.4), 3.0, true)
		TowerVisual.Projectile.CURSE:
			draw_circle(point, _cell_size * 0.16, Color(color, 0.3))
			draw_arc(point, _cell_size * 0.13, _time * 5, _time * 5 + TAU * 0.8,
					12, color, 3.0, true)
		TowerVisual.Projectile.BOLT:
			var tail: Vector2 = point - direction * _cell_size * 0.4
			draw_line(tail, point, Color(0.15, 0.1, 0.07), 4.0)
			draw_line(tail, point, color, 2.0)
			draw_circle(point, 2.5, Color(0.75, 0.78, 0.8))


func _draw_impact(impact: Impact) -> void:
	var t: float = impact.age / IMPACT_SECONDS
	var alpha: float = 1.0 - t
	var core: float = _cell_size * 0.14 * alpha
	draw_circle(impact.position, core, Color(1.0, 0.94, 0.83, alpha), true, -1, true)
	for ray: int in 5:
		var angle: float = TAU * ray / 5.0 + impact.position.x
		var direction: Vector2 = Vector2.from_angle(angle) * Vector2(1, 0.72)
		var reach: float = _cell_size * (0.12 + 0.26 * t)
		draw_line(impact.position + direction * (reach - core),
				impact.position + direction * reach, Color(impact.color, alpha), 2, true)
	if impact.is_area:
		draw_arc(impact.position, impact.radius * (0.5 + 0.5 * t), 0.0, TAU, 40,
				Color(impact.color, 0.8 * alpha), 3.0, true)


func _draw_float_text(text: FloatText) -> void:
	var t: float = text.age / FLOAT_TEXT_SECONDS
	var font: Font = get_theme_default_font()
	var font_size: int = maxi(14, int(_cell_size * 0.38))
	var width: float = font.get_string_size(text.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var point: Vector2 = text.position - Vector2(width * 0.5, _cell_size * 0.8 * t)
	var color: Color = Color(text.color, clampf(2.0 - 2.0 * t, 0.0, 1.0))
	draw_string_outline(font, point, text.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5,
			Color(0, 0, 0, color.a * 0.8))
	draw_string(font, point, text.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

#endregion


func _update_projectiles(delta: float) -> void:
	var flying: Array[Projectile] = []
	for projectile: Projectile in _projectiles:
		projectile.age += delta
		if projectile.target.is_alive():
			projectile.target_milli = Vector2(_field.get_mob_position(projectile.target))
		if projectile.age < projectile.visual.projectile_seconds:
			flying.append(projectile)
			continue
		_add_impact(projectile)
	_projectiles = flying


func _add_impact(projectile: Projectile) -> void:
	var impact: Impact = Impact.new()
	impact.position = _projectile_target(projectile)
	impact.color = projectile.visual.impact_color
	impact.is_area = projectile.splash_radius_milli > 0
	impact.radius = _cell_size * 0.3
	if impact.is_area:
		impact.radius = projectile.splash_radius_milli / MILLI * _cell_size
	_impacts.append(impact)


func _projectile_target(projectile: Projectile) -> Vector2:
	var lift: float = 0.35 if draw_world_towers else 0.15
	return _milli_to_screen(projectile.target_milli) - Vector2(0, _cell_size * lift)


## Мягкий «пых» дыма цвета моба. Частицы сами удаляются после проигрыша.
func _spawn_puff(at: Vector2, color: Color) -> void:
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.position = at
	particles.texture = _get_puff_texture()
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = 14
	particles.lifetime = PUFF_SECONDS
	particles.spread = 180.0
	particles.gravity = Vector2(0, -_cell_size * 0.8)
	particles.initial_velocity_min = _cell_size * 0.5
	particles.initial_velocity_max = _cell_size * 1.5
	particles.damping_min = _cell_size * 1.5
	particles.damping_max = _cell_size * 2.5
	var base_scale: float = _cell_size / 64.0
	particles.scale_amount_min = base_scale * 0.4
	particles.scale_amount_max = base_scale * 0.9
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(color.lightened(0.3), 0.9))
	ramp.set_color(1, Color(color.darkened(0.3), 0.0))
	particles.color_ramp = ramp
	particles.emitting = true
	add_child(particles)
	get_tree().create_timer(PUFF_SECONDS + 0.2).timeout.connect(particles.queue_free)


static func _get_puff_texture() -> Texture2D:
	if _puff_texture == null:
		var gradient: Gradient = Gradient.new()
		gradient.set_color(0, Color.WHITE)
		gradient.set_color(1, Color(1, 1, 1, 0))
		var texture: GradientTexture2D = GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(0.5, 0.0)
		texture.width = 32
		texture.height = 32
		_puff_texture = texture
	return _puff_texture


func _add_text(at: Vector2, text: String, color: Color) -> void:
	var float_text: FloatText = FloatText.new()
	float_text.position = at
	float_text.text = text
	float_text.color = color
	_texts.append(float_text)


func _mob_screen_position(mob: MobState) -> Vector2:
	var previous: Vector2 = Vector2(_field.get_path_point(mob.previous_progress))
	var current: Vector2 = Vector2(_field.get_path_point(mob.progress))
	return _milli_to_screen(previous.lerp(current, interpolation))


func _milli_to_screen(milli: Vector2) -> Vector2:
	if point_projector.is_valid():
		var projected: Vector2 = point_projector.call(milli)
		return projected
	return _origin + milli / MILLI * _cell_size


func _hero_screen_position() -> Vector2:
	var path: Array[Vector2i] = _field.get_active_path()
	var cell: Vector2i = path[path.size() - 1]
	return _milli_to_screen((Vector2(cell) + Vector2(0.5, 0.2)) * MILLI)


func _on_field_tower_fired(tower: TowerState, mob: MobState) -> void:
	var projectile: Projectile = Projectile.new()
	projectile.visual = _catalog.get_tower(tower.data.id)
	projectile.from_milli = Vector2(tower.center_milli()) - Vector2(0, MILLI * 0.25)
	projectile.target = mob
	projectile.target_milli = Vector2(_field.get_mob_position(mob))
	projectile.splash_radius_milli = _field.get_tower_splash_radius(tower)
	_projectiles.append(projectile)
	sound_requested.emit(SHOT_SOUNDS[projectile.visual.projectile])


func _on_field_mob_killed(mob: MobState) -> void:
	var at: Vector2 = _milli_to_screen(Vector2(_field.get_mob_position(mob)))
	_spawn_puff(at - Vector2(0, _cell_size * 0.2), _catalog.get_mob(mob.data.id).death_color)
	if is_own_field and mob.kill_reward > 0:
		_add_text(at, "+%d" % mob.kill_reward, _style.gold_text_color)
	sound_requested.emit(&"death")


func _on_breach_resolved(_mob: MobState, actual_damage: int) -> void:
	if actual_damage <= 0:
		return
	_breach_flash_left = BREACH_FLASH_SECONDS
	_add_text(_hero_screen_position(), "−%d" % actual_damage,
			BREACH_TEXT_COLOR)
	sound_requested.emit(&"breach")


## Особые события поля: удар палицы — волна по всему полю, опалённые башни — дым,
## леший отбросил моба — зелёный «пых» из листьев.
func _on_field_effect_played(effect_id: StringName, mob: MobState) -> void:
	if mob != null and _show_reaction(effect_id, mob):
		return
	match effect_id:
		&"strike":
			var center: Vector2 = _origin + Vector2(_field.layout.width, _field.layout.height) \
					* _cell_size * 0.5
			var impact: Impact = Impact.new()
			impact.position = center
			impact.color = STRIKE_COLOR
			impact.is_area = true
			impact.radius = _cell_size * _field.layout.height * 0.6
			_impacts.append(impact)
			_add_text(center, "ПАЛИЦА!", STRIKE_COLOR)
			sound_requested.emit(&"breach")
		&"chest":
			var chest_at: Vector2 = _hero_screen_position() + Vector2(0, _cell_size)
			_add_text(chest_at, "СУНДУК РАЗБИТ!", STRIKE_COLOR)
			for tower: TowerState in _field.towers:
				_spawn_puff(_milli_to_screen(Vector2(tower.center_milli())), STRIKE_COLOR)
			sound_requested.emit(&"merge")
		&"hero_heal":
			_add_text(_hero_screen_position(), "+HP", HEAL_COLOR)
			_spawn_puff(_hero_screen_position(), HEAL_COLOR)
		&"hero_skill":
			_spawn_puff(_hero_screen_position(), STRIKE_COLOR)
		&"silence":
			var middle: Vector2 = _origin + Vector2(_field.layout.width * 0.5, 1.0) * _cell_size
			_add_text(middle, "ОПАЛЕНО!", SILENCE_TEXT_COLOR)
		&"heal":
			if mob != null:
				var spot: Vector2 = _milli_to_screen(Vector2(_field.get_mob_position(mob)))
				_spawn_puff(spot - Vector2(0, _cell_size * 0.3), HEAL_COLOR)
		&"knockback":
			if mob != null:
				var at: Vector2 = _milli_to_screen(Vector2(_field.get_mob_position(mob)))
				_spawn_puff(at, KNOCKBACK_COLOR)


## Пар бани / сказки кота: кольцо по всему радиусу.
func _on_field_tower_pulsed(tower: TowerState) -> void:
	var impact: Impact = Impact.new()
	impact.position = _milli_to_screen(Vector2(tower.center_milli()))
	impact.color = _catalog.get_tower(tower.data.id).impact_color
	impact.is_area = true
	impact.radius = _field.get_tower_range(tower) / MILLI * _cell_size
	_impacts.append(impact)


## Снаряд в полёте. Цель — моб; если он умер раньше, снаряд летит в последнюю точку.
class Projectile:
	var visual: TowerVisual
	var from_milli: Vector2
	var target: MobState
	var target_milli: Vector2
	var splash_radius_milli: int = 0
	var age: float = 0.0


class Impact:
	var position: Vector2
	var radius: float
	var color: Color
	var is_area: bool = false
	var age: float = 0.0


class FloatText:
	var position: Vector2
	var text: String
	var color: Color
	var age: float = 0.0


func _on_lightning_fired(from_milli: Vector2i, to_milli: Vector2i) -> void:
	var arc: LightningArc = LightningArc.new()
	arc.from_milli = from_milli
	arc.to_milli = to_milli
	_lightning.append(arc)


class LightningArc:
	var from_milli: Vector2i
	var to_milli: Vector2i
	var age: float = 0.0
	var lifetime: float = 0.18
	var color: Color = Color(0.55, 0.85, 1)
	var is_transfer: bool = false


func _on_curse_transferred(source: MobState, target: MobState) -> void:
	var arc: LightningArc = LightningArc.new()
	arc.from_milli = _field.get_mob_position(source)
	arc.to_milli = _field.get_mob_position(target)
	arc.color = Color(0.85, 0.4, 0.95)
	arc.lifetime = 0.6
	arc.is_transfer = true
	_lightning.append(arc)


func _show_reaction(effect_id: StringName, mob: MobState) -> bool:
	for rule: ReactionData in _field.config.reactions:
		if rule.id != effect_id:
			continue
		var position_milli: Vector2i = _field.get_mob_position(mob)
		var flash: ReactionFlash = ReactionFlash.new(rule, position_milli)
		if _flashes.size() >= 24:
			_flashes.pop_front()
		_flashes.append(flash)
		if _time >= _reaction_next_text.get(effect_id, 0.0):
			var spot: Vector2 = _milli_to_screen(Vector2(position_milli))
			_add_text(spot - Vector2(0, _cell_size * 0.6), rule.display_name,
					flash.color.lightened(0.35))
			_reaction_next_text[effect_id] = _time + 0.7
		return true
	return false

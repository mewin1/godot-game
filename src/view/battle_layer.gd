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
const SHOT_SOUNDS: Array[StringName] = [&"shot_fire", &"shot_ice", &"shot_mech"]
const STRIKE_COLOR: Color = Color(1.0, 0.85, 0.5)
const SILENCE_TEXT_COLOR: Color = Color(1.0, 0.55, 0.3)
const KNOCKBACK_COLOR: Color = Color(0.55, 0.8, 0.35)
const HEAL_COLOR: Color = Color(0.56, 0.82, 0.42)
const SHIELD_COLOR: Color = Color(0.77, 0.6, 0.32)
## Летающие рисуются выше земли (в долях своего размера), невидимки — полупрозрачными.
const FLY_LIFT: float = 0.45
const STEALTH_ALPHA: float = 0.45

var interpolation: float = 0.0
var is_own_field: bool = false
var breach_multiplier: int = 1
var hero_hp: int = 0
## Центр таблички HP героя на экране (её место задаёт FieldView: там же терем).
var hero_plate_center: Vector2 = Vector2.ZERO

static var _puff_texture: Texture2D

var _field: FieldState
var _style: FieldStyle
var _catalog: VisualCatalog
var _origin: Vector2 = Vector2.ZERO
var _cell_size: float = 32.0
var _time: float = 0.0
var _breach_flash_left: float = 0.0
var _projectiles: Array[Projectile] = []
var _impacts: Array[Impact] = []
var _texts: Array[FloatText] = []
## Куда смотрит моб (true — влево): сохраняем, чтобы он не «моргал» на вертикальных участках.
var _facing_left: Dictionary[int, bool] = {}


func _init() -> void:
	_catalog = VisualCatalog.get_default()
	_style = _catalog.field


func _process(delta: float) -> void:
	_time += delta
	_breach_flash_left = maxf(0.0, _breach_flash_left - delta)
	_update_projectiles(delta)
	_impacts = _impacts.filter(func(impact: Impact) -> bool:
		impact.age += delta
		return impact.age < IMPACT_SECONDS)
	_texts = _texts.filter(func(text: FloatText) -> bool:
		text.age += delta
		return text.age < FLOAT_TEXT_SECONDS)
	queue_redraw()


## Подключает поле (сбрасывает эффекты прошлого поля).
func set_field(field: FieldState) -> void:
	if _field != null:
		_field.tower_fired.disconnect(_on_field_tower_fired)
		_field.mob_killed.disconnect(_on_field_mob_killed)
		_field.mob_breached.disconnect(_on_field_mob_breached)
		_field.effect_played.disconnect(_on_field_effect_played)
		_field.tower_pulsed.disconnect(_on_field_tower_pulsed)
	_field = field
	_projectiles.clear()
	_impacts.clear()
	_texts.clear()
	_facing_left.clear()
	_field.tower_fired.connect(_on_field_tower_fired)
	_field.mob_killed.connect(_on_field_mob_killed)
	_field.mob_breached.connect(_on_field_mob_breached)
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
	for projectile: Projectile in _projectiles:
		_draw_projectile(projectile)
	for impact: Impact in _impacts:
		_draw_impact(impact)
	_draw_hero_hp(hero_plate_center)
	for text: FloatText in _texts:
		_draw_float_text(text)
	if _breach_flash_left > 0.0:
		var alpha: float = _breach_flash_left / BREACH_FLASH_SECONDS
		draw_rect(Rect2(Vector2.ZERO, size), Color(_style.breach_color, 0.16 * alpha))
		draw_rect(Rect2(Vector2.ZERO, size).grow(-4.0), Color(_style.breach_color, 0.7 * alpha),
				false, 8.0)


func _draw_mobs() -> void:
	if _field.mobs.is_empty():
		_facing_left.clear()
		return
	for mob: MobState in _field.mobs:
		_draw_mob(mob)


## Моб: тень, картинка с покачиванием (повёрнута по ходу), синий оттенок под замедлением, HP.
func _draw_mob(mob: MobState) -> void:
	var visual: MobVisual = _catalog.get_mob(mob.data.id)
	var previous: Vector2 = _milli_to_screen(Vector2(_field.get_path_point(mob.previous_progress)))
	var feet: Vector2 = _mob_screen_position(mob)
	var step_x: float = feet.x - previous.x
	if absf(step_x) > 0.01:
		_facing_left[mob.id] = step_x < 0.0
	var sprite_size: float = visual.size_cells * _cell_size
	feet.y += sprite_size * 0.3
	var bob_speed: float = visual.bob_speed * (2.0 if _field.is_enraged else 1.0)
	var phase: float = _time * bob_speed * PI + mob.id
	var bob: float = absf(sin(phase)) * visual.bob_height * sprite_size
	var tilt: float = sin(phase) * 0.07
	draw_set_transform(feet, 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, sprite_size * 0.36, SHADOW_COLOR)
	if mob.sender_index >= 0:
		# Чья армия: кольцо цвета игрока под юнитом.
		draw_arc(Vector2.ZERO, sprite_size * 0.36, 0.0, TAU, 24,
				_style.get_player_color(mob.sender_index), 5.0, true)
	if mob.slow_percent > 0:
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
	if mob.slow_percent > 0:
		tint = tint * _style.slow_tint
	draw_texture_rect(visual.texture, Rect2(Vector2(-sprite_size * 0.5, -sprite_size),
			Vector2.ONE * sprite_size), false, tint)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if mob.shield_left > 0:
		draw_arc(feet - Vector2(0, bob + sprite_size * 0.5), sprite_size * 0.55, -2.4, -0.7, 16,
				SHIELD_COLOR, 3.0, true)
	if mob.hp < mob.max_hp:
		_draw_hp_bar(Vector2(feet.x, feet.y - sprite_size - bob - 4.0), sprite_size * 0.7,
				float(mob.hp) / mob.max_hp)


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
		TowerVisual.Projectile.BOLT:
			var tail: Vector2 = point - direction * _cell_size * 0.4
			draw_line(tail, point, Color(0.15, 0.1, 0.07), 4.0)
			draw_line(tail, point, color, 2.0)
			draw_circle(point, 2.5, Color(0.75, 0.78, 0.8))


func _draw_impact(impact: Impact) -> void:
	var t: float = impact.age / IMPACT_SECONDS
	var alpha: float = 1.0 - t
	draw_circle(impact.position, impact.radius * (0.4 + 0.3 * t), Color(impact.color, 0.45 * alpha))
	if impact.is_area:
		draw_arc(impact.position, impact.radius * (0.5 + 0.5 * t), 0.0, TAU, 40,
				Color(impact.color, 0.8 * alpha), 3.0, true)


func _draw_float_text(text: FloatText) -> void:
	var t: float = text.age / FLOAT_TEXT_SECONDS
	var font: Font = get_theme_default_font()
	var font_size: int = maxi(14, int(_cell_size * 0.38))
	var point: Vector2 = text.position - Vector2(30, _cell_size * 0.8 * t)
	var color: Color = Color(text.color, clampf(2.0 - 2.0 * t, 0.0, 1.0))
	draw_string_outline(font, point, text.text, HORIZONTAL_ALIGNMENT_CENTER, 60, font_size, 5,
			Color(0, 0, 0, color.a * 0.8))
	draw_string(font, point, text.text, HORIZONTAL_ALIGNMENT_CENTER, 60, font_size, color)

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
	return _milli_to_screen(projectile.target_milli) - Vector2(0, _cell_size * 0.15)


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
	return _origin + milli / MILLI * _cell_size


func _hero_screen_position() -> Vector2:
	var path: Array[Vector2i] = _field.get_active_path()
	var cell: Vector2i = path[path.size() - 1]
	return _origin + (Vector2(cell) + Vector2(0.5, 0.2)) * _cell_size


func _on_field_tower_fired(tower: TowerState, mob: MobState) -> void:
	var projectile: Projectile = Projectile.new()
	projectile.visual = _catalog.get_tower(tower.data.id)
	projectile.from_milli = Vector2(tower.center_milli()) - Vector2(0, MILLI * 0.25)
	projectile.target = mob
	projectile.target_milli = Vector2(_field.get_mob_position(mob))
	projectile.splash_radius_milli = tower.data.splash_radius_milli
	_projectiles.append(projectile)
	sound_requested.emit(SHOT_SOUNDS[projectile.visual.projectile])


func _on_field_mob_killed(mob: MobState) -> void:
	var at: Vector2 = _milli_to_screen(Vector2(_field.get_mob_position(mob)))
	_spawn_puff(at - Vector2(0, _cell_size * 0.2), _catalog.get_mob(mob.data.id).death_color)
	if is_own_field and mob.kill_reward > 0:
		_add_text(at, "+%d" % mob.kill_reward, _style.gold_text_color)
	sound_requested.emit(&"death")


func _on_field_mob_breached(mob: MobState) -> void:
	_breach_flash_left = BREACH_FLASH_SECONDS
	_add_text(_hero_screen_position(), "−%d" % (mob.breach_damage * breach_multiplier),
			BREACH_TEXT_COLOR)
	sound_requested.emit(&"breach")


## Особые события поля: удар палицы — волна по всему полю, опалённые башни — дым,
## леший отбросил моба — зелёный «пых» из листьев.
func _on_field_effect_played(effect_id: StringName, mob: MobState) -> void:
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

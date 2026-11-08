class_name ArenaBearCub3D
extends Node3D
## Медвежонок на опушке — только отображение. Бродит по полосе без деревьев вокруг двора, обнюхивает
## землю, иногда идёт пить к ручью. Модель — по концепту автора (new_concept/creatures/sheets/bear_cub_sheet.png).

const SCENE: PackedScene = preload("res://assets/noir/creatures/bear_cub.glb")
## Крупнее модели из Blender (1,15 м): с высоты камеры иначе не читается.
const MODEL_SCALE: float = 1.5
const SPEED: float = 0.7
## Скорость шага, при которой анимация «walk» (цикл 1 с) не скользит по земле, м/с.
const STRIDE_SPEED: float = 0.5 * MODEL_SCALE
## Часть кадра (доли вьюпорта), куда медвежонок ходит: без лавки слева и панелей снизу/сверху.
const SAFE_SCREEN: Rect2 = Rect2(0.3, 0.15, 0.66, 0.58)
const TURN_RATE: float = 1.7
const BODY_RADIUS: float = 0.8
## Насколько близко к ручью подходит пить, м от середины русла.
const DRINK_OFFSET: float = 1.7

enum State { WALK, IDLE, SNIFF }

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _anim: AnimationPlayer
var _zone: Rect2
var _blocked: Rect2
## Препятствия: x, y — центр (мировые x, z), z — радиус.
var _obstacles: PackedVector3Array = PackedVector3Array()
var _stream: PackedVector2Array = PackedVector2Array()
var _target: Vector2
var _face_after: float = NAN
var _state: State = State.IDLE
var _wait: float = 1.0
var _yaw: float = 0.0


## zone — где бродить (x, z); blocked — двор (туда не заходит); stream — середина русла.
func setup(seed_value: int, zone: Rect2, blocked: Rect2, obstacles: PackedVector3Array,
		stream: PackedVector2Array) -> void:
	_rng.seed = seed_value
	_zone = zone
	_blocked = blocked
	_obstacles = obstacles
	_stream = stream
	var model: Node3D = SCENE.instantiate() as Node3D
	model.scale = Vector3.ONE * MODEL_SCALE
	add_child(model)
	_anim = model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for id: String in ["walk", "idle", "sniff"]:
		_anim.get_animation(id).loop_mode = Animation.LOOP_LINEAR
	_yaw = _rng.randf() * TAU
	rotation.y = _yaw
	_rest(State.IDLE, 2.0)
	visible = false  # место — в первом кадре, когда камера уже наведена на двор


## Где сейчас (мировые x, z) — стая ворон по этому спугивает сидящих на земле.
func ground_position() -> Vector2:
	return Vector2(position.x, position.z)


func _process(delta: float) -> void:
	if not visible:
		var start: Vector2 = _random_spot()
		position = Vector3(start.x, 0.0, start.y)
		visible = true
	if _state != State.WALK:
		_wait -= delta
		if _wait <= 0.0:
			_choose_next()
		return
	var at: Vector2 = ground_position()
	var to: Vector2 = _target - at
	if to.length() < 0.15:
		if is_nan(_face_after):
			_rest(State.SNIFF if _rng.randf() < 0.55 else State.IDLE, _rng.randf_range(3.0, 7.0))
		else:
			# у ручья: повернуться к воде и «пить» подольше
			_yaw = _face_after
			rotation.y = _yaw
			_face_after = NAN
			_rest(State.SNIFF, _rng.randf_range(6.0, 10.0))
		return
	var want: float = atan2(-to.x, -to.y)
	var diff: float = wrapf(want - _yaw, -PI, PI)
	_yaw += clampf(diff, -TURN_RATE * delta, TURN_RATE * delta)
	rotation.y = _yaw
	# на месте не шагает вбок: идёт, только когда почти развернулся
	var pace: float = SPEED * clampf(1.0 - absf(diff) / 1.2, 0.0, 1.0)
	var forward: Vector2 = Vector2(-sin(_yaw), -cos(_yaw))
	var step: Vector2 = at + forward * pace * delta
	position = Vector3(step.x, 0.0, step.y)
	_anim.speed_scale = maxf(0.35, pace / STRIDE_SPEED)


func _choose_next() -> void:
	var at: Vector2 = ground_position()
	if not _stream.is_empty() and _rng.randf() < 0.3:
		var bank: Vector2 = _stream_bank(at)
		if bank != Vector2.INF and _path_clear(at, bank):
			_go(bank)
			var water: Vector2 = _closest_on_stream(bank) - bank
			_face_after = atan2(-water.x, -water.y)
			return
	for attempt: int in 24:
		var spot: Vector2 = _random_spot() if attempt > 12 else at + Vector2.from_angle(_rng.randf() * TAU) \
				* _rng.randf_range(2.5, 7.0)
		if _free(spot) and _path_clear(at, spot):
			_go(spot)
			return
	_rest(State.IDLE, 2.0)


func _go(spot: Vector2) -> void:
	_target = spot
	_state = State.WALK
	_anim.play("walk", 0.3)


func _rest(state: State, seconds: float) -> void:
	_state = state
	_wait = seconds
	_anim.speed_scale = 1.0
	_anim.play("sniff" if state == State.SNIFF else "idle", 0.4)


func _random_spot() -> Vector2:
	for attempt: int in 60:
		var spot: Vector2 = Vector2(_rng.randf_range(_zone.position.x, _zone.end.x),
				_rng.randf_range(_zone.position.y, _zone.end.y))
		if _free(spot):
			return spot
	return _zone.position


func _free(spot: Vector2) -> bool:
	if not _zone.has_point(spot) or _blocked.has_point(spot) or not _on_screen(spot):
		return false
	for obstacle: Vector3 in _obstacles:
		if spot.distance_to(Vector2(obstacle.x, obstacle.y)) < obstacle.z + BODY_RADIUS:
			return false
	return _stream.is_empty() or spot.distance_to(_closest_on_stream(spot)) > DRINK_OFFSET - 0.2


## Видно ли место камерой (до первого кадра камеры нет — тогда любое).
func _on_screen(spot: Vector2) -> bool:
	if not is_inside_tree():
		return true
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return true
	var at: Vector3 = Vector3(spot.x, 0.0, spot.y)
	if camera.is_position_behind(at):
		return false
	var screen: Vector2 = camera.unproject_position(at) / get_viewport().get_visible_rect().size
	return SAFE_SCREEN.has_point(screen)


func _path_clear(a: Vector2, b: Vector2) -> bool:
	var steps: int = maxi(1, ceili(a.distance_to(b) / 0.5))
	for k: int in range(1, steps + 1):
		var p: Vector2 = a.lerp(b, float(k) / steps)
		if _blocked.has_point(p):
			return false
		for obstacle: Vector3 in _obstacles:
			if p.distance_to(Vector2(obstacle.x, obstacle.y)) < obstacle.z + BODY_RADIUS * 0.8:
				return false
		if not _stream.is_empty() and p.distance_to(_closest_on_stream(p)) < DRINK_OFFSET - 0.3:
			return false
	return true


## Ближайшая точка берега (на DRINK_OFFSET от середины русла) в зоне, со стороны медвежонка.
func _stream_bank(from: Vector2) -> Vector2:
	var best: Vector2 = Vector2.INF
	var best_d: float = INF
	for i: int in _stream.size() - 1:
		var mid: Vector2 = (_stream[i] + _stream[i + 1]) * 0.5
		var along: Vector2 = (_stream[i + 1] - _stream[i]).normalized()
		var normal: Vector2 = Vector2(-along.y, along.x)
		if normal.dot(from - mid) < 0.0:
			normal = -normal
		var bank: Vector2 = mid + normal * DRINK_OFFSET
		var d: float = bank.distance_to(from)
		if d < best_d and d > 2.0 and d < 14.0 and _zone.has_point(bank) and not _blocked.has_point(bank) \
				and _on_screen(bank):
			best_d = d
			best = bank
	return best


func _closest_on_stream(p: Vector2) -> Vector2:
	var best: Vector2 = _stream[0]
	for i: int in _stream.size() - 1:
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, _stream[i], _stream[i + 1])
		if q.distance_squared_to(p) < best.distance_squared_to(p):
			best = q
	return best

class_name ArenaCrow3D
extends Node3D
## Ворона арены — только отображение. Летит по кривой Безье (машет крыльями на подъёме и у посадки,
## парит на снижении), садится и сидит: оглядывается, клюёт, каркает. Две модели по концепту автора
## (new_concept/creatures/sheets): сидящая и летящая — меняются в момент посадки и взлёта.

signal finished(crow: ArenaCrow3D)

const PERCH_SCENE: PackedScene = preload("res://assets/noir/creatures/crow_perch.glb")
const FLY_SCENE: PackedScene = preload("res://assets/noir/creatures/crow_fly.glb")
## Скорость полёта, м/с; посадка и взлёт плавные.
const SPEED: float = 5.8
## Сидящая — почти натуральная (рядом с медвежонком и частоколом), летящая высоко — крупнее:
## над лесом в натуральную величину её не видно. Размер в полёте плавно зависит от высоты.
const PERCH_SCALE: float = 0.85
const FLY_SCALE: float = 1.8
const FLY_SCALE_HEIGHT: Vector2 = Vector2(3.0, 11.0)
## Крен в повороте: доля скорости поворота (рад/с) и предел, рад.
const BANK: float = 0.35
const BANK_LIMIT: float = 0.7
## Посадка (анимация land): первая половина — тормозящие взмахи в воздухе, вторая — уже на месте
## крылья складываются вдоль тела; затем модель меняется на сидящую. Взлёт — та же анимация назад, вдвое быстрее.
const LAND_LEAD: float = 0.5
const TAKEOFF_SPEED: float = 2.0
## Пока складывает крылья, встаёт как сидящая: грудь вверх, тело над лапами и чуть вперёд
## (м при PERCH_SCALE) — силуэт совпадает с сидящей моделью, смена не видна.
const STAND_PITCH: float = 0.5
const STAND_SHIFT: Vector3 = Vector3(0.0, 0.25, -0.15)
## Сложенная летящая модель короче сидящей — к посадке чуть крупнее.
const STAND_GROW: float = 0.12
## После касания: крылья доскладываются (вторая половина land), затем летящая модель плавно перетекает
## в сидящую (обе видны, прозрачность навстречу), с; при касании тело чуть проседает на лапах, м.
const SETTLE_BLEND: float = 0.5
const TOUCH_DIP: float = 0.035
## Взлёт с места: столько секунд птица стоит и раскрывает крылья (модели перетекают), потом отрывается;
## курс и наклон полёта набирает за первые TURN_IN доли пути.
const LAUNCH_WAIT: float = 0.32
const TURN_IN: float = 0.2

## Номер места посадки у стаи (−1 — в воздухе или без места).
var perch_index: int = -1
## Сидит на земле (её спугивает медвежонок).
var on_ground: bool = false
var is_flying: bool = false

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _perch_model: Node3D
var _fly_model: Node3D
var _perch_anim: AnimationPlayer
var _fly_anim: AnimationPlayer
var _points: Array[Vector3] = []
var _progress: float = 0.0
var _duration: float = 1.0
var _lands: bool = false
var _land_yaw: float = 0.0
var _land_ground: bool = false
var _roll: float = 0.0
var _last_yaw: float = 0.0
var _gesture_in: float = 2.0
## Пока идёт посадка или взлёт, полёт не переключает анимацию на flap/glide.
var _anim_lock: float = 0.0
var _folding: bool = false
var _land_time: float = 1.0
var _takeoff: bool = false
var _settle_time: float = 0.0
var _launch_wait: float = 0.0
var _start_yaw: float = 0.0
var _landed_tilt: Vector2 = Vector2.ZERO
var _perch_meshes: Array[GeometryInstance3D] = []
var _fly_meshes: Array[GeometryInstance3D] = []


func _init(seed_value: int) -> void:
	_rng.seed = seed_value
	_perch_model = PERCH_SCENE.instantiate() as Node3D
	_fly_model = FLY_SCENE.instantiate() as Node3D
	add_child(_perch_model)
	add_child(_fly_model)
	_perch_model.scale = Vector3.ONE * PERCH_SCALE
	_fly_model.scale = Vector3.ONE * FLY_SCALE
	_perch_anim = _find_player(_perch_model)
	_fly_anim = _find_player(_fly_model)
	for id: String in ["idle", "flap", "glide"]:
		for player: AnimationPlayer in [_perch_anim, _fly_anim]:
			if player.has_animation(id):
				player.get_animation(id).loop_mode = Animation.LOOP_LINEAR
	_land_time = _fly_anim.get_animation("land").length
	_fly_model.position = Vector3.ZERO
	for node: Node in _perch_model.find_children("*", "GeometryInstance3D", true, false):
		_perch_meshes.append(node as GeometryInstance3D)
	for node: Node in _fly_model.find_children("*", "GeometryInstance3D", true, false):
		_fly_meshes.append(node as GeometryInstance3D)
	_show_flying(true)


## Полёт из from в to. land — сесть в конце (лицом по yaw; ground — на землю), иначе исчезнуть (finished).
func fly(from: Vector3, to: Vector3, land: bool, yaw: float = 0.0, ground: bool = false) -> void:
	var from_perch: bool = not is_flying and _perch_model.visible
	is_flying = true
	on_ground = false
	_land_ground = ground
	_lands = land
	_land_yaw = yaw
	var flat: Vector3 = Vector3(to.x - from.x, 0.0, to.z - from.z)
	var distance: float = maxf(0.5, (to - from).length())
	var side: Vector3 = flat.normalized().cross(Vector3.UP) * _rng.randf_range(-0.35, 0.35) * distance
	# взлёт вверх-вперёд, посадка — сверху, с подлётом
	_points = [from, from + flat * 0.3 + side + Vector3.UP * minf(3.5, distance * 0.25),
			to - flat * 0.25 + side * 0.4 + Vector3.UP * (minf(4.0, distance * 0.3) if land else 0.0), to]
	_duration = _curve_length() / SPEED
	_progress = 0.0
	_settle_time = 0.0
	position = from
	_start_yaw = rotation.y
	_last_yaw = rotation.y
	rotation = Vector3(0.0, rotation.y, 0.0)
	_fly_model.transform = Transform3D(Basis.from_scale(Vector3.ONE * PERCH_SCALE * (1.0 + STAND_GROW)),
			STAND_SHIFT if from_perch else Vector3.ZERO)
	_show_flying(true)
	_folding = false
	_takeoff = from_perch
	_launch_wait = 0.0
	if from_perch:
		# стоя раскрывает крылья (посадка задом наперёд), сидящая модель тает поверх; потом отрывается
		_fly_anim.play("land", 0.0, -TAKEOFF_SPEED, true)
		_anim_lock = _land_time / TAKEOFF_SPEED
		_launch_wait = LAUNCH_WAIT
		_perch_model.visible = true
		_stand_pose()
	else:
		_fly_anim.play("flap", 0.15, _rng.randf_range(0.9, 1.15))
		_anim_lock = 0.0


func sit(at: Vector3, yaw: float, ground: bool) -> void:
	position = at
	rotation = Vector3(0.0, yaw, 0.0)
	is_flying = false
	on_ground = ground
	_show_flying(false)
	_perch_anim.play("caw" if _rng.randf() < 0.4 else "idle", 0.1)
	_perch_anim.queue("idle")
	_gesture_in = _rng.randf_range(1.5, 4.0)


func _process(delta: float) -> void:
	if is_flying:
		_advance(delta)
		return
	_gesture_in -= delta
	if _gesture_in <= 0.0 and _perch_anim.current_animation == "idle":
		var roll: float = _rng.randf()
		var gesture: String = "look"
		if roll < 0.35:
			gesture = "peck" if on_ground or _rng.randf() < 0.3 else "look"
		elif roll < 0.5:
			gesture = "caw"
		_perch_anim.play(gesture, 0.15)
		_perch_anim.queue("idle")
		_gesture_in = _rng.randf_range(1.8, 5.0)


func _advance(delta: float) -> void:
	_anim_lock -= delta
	if _launch_wait > 0.0:
		_launch_wait = maxf(0.0, _launch_wait - delta)
		var shown: float = 1.0 - _launch_wait / LAUNCH_WAIT
		_fade(_fly_meshes, 1.0 - smoothstep(0.0, 0.4, shown))
		_fade(_perch_meshes, smoothstep(0.35, 1.0, shown))
		if _launch_wait == 0.0:
			_perch_model.visible = false
			_fade(_perch_meshes, 0.0)
			_fade(_fly_meshes, 0.0)
			# наклон переходит от модели к узлу (в начале пути он тот же — STAND_PITCH)
			_fly_model.transform = Transform3D(Basis.from_scale(Vector3.ONE * PERCH_SCALE * (1.0 + STAND_GROW)),
					STAND_SHIFT)
			rotation = Vector3(STAND_PITCH, _start_yaw, 0.0)
		return
	if _progress >= 1.0 and _lands:
		if _settle_time == 0.0:
			# дальше наклон и крен — у самой летящей модели, а узел стоит ровно: сидящая проявится без наклона
			_landed_tilt = Vector2(rotation.x, rotation.z)
			_fly_model.transform = Transform3D(Basis.from_euler(Vector3(rotation.x, 0.0, rotation.z)),
					Vector3.ZERO) * _fly_model.transform
			rotation = Vector3(0.0, _land_yaw, 0.0)
		_settle(delta)
		return
	_progress = minf(1.0, _progress + delta / _duration)
	var left: float = (1.0 - _progress) * _duration
	if _lands and not _folding and left <= _land_time * LAND_LEAD:
		_folding = true
		_fly_anim.play("land", 0.2)
		_anim_lock = _land_time
	# тело заранее приходит на высоту стоящей птицы: после касания она уже не подскакивает
	var lift: float = 0.0  # 0 — летит, 1 — тело как у сидящей
	if _lands:
		lift = smoothstep(0.0, 1.0, 1.0 - left / maxf(0.01, _land_time * LAND_LEAD))
	elif _takeoff:
		lift = 1.0 - smoothstep(0.0, 0.25, _progress)
	_fly_model.position = STAND_SHIFT * lift
	# плавно трогается и тормозит у посадки, в середине — ровная скорость
	var eased: float = _ease(_progress)
	var at: Vector3 = _bezier(eased)
	var ahead: Vector3 = _bezier(minf(1.0, eased + 0.02)) - at
	position = at
	_fly_model.scale = Vector3.ONE * lerpf(PERCH_SCALE, FLY_SCALE,
			smoothstep(FLY_SCALE_HEIGHT.x, FLY_SCALE_HEIGHT.y, at.y)) * (1.0 + STAND_GROW * lift)
	if ahead.length() > 0.001:
		var yaw: float = atan2(-ahead.x, -ahead.z)
		var turn: float = wrapf(yaw - _last_yaw, -PI, PI) / maxf(delta, 0.001)
		_last_yaw = yaw
		_roll = lerpf(_roll, clampf(-turn * BANK, -BANK_LIMIT, BANK_LIMIT), minf(1.0, delta * 3.0))
		var pitch: float = clampf(atan2(ahead.y, Vector2(ahead.x, ahead.z).length()), -0.6, 0.6)
		if _lands and _progress > 0.85:
			yaw = lerp_angle(yaw, _land_yaw, (_progress - 0.85) / 0.15)
			pitch = lerpf(pitch, 0.35, (_progress - 0.85) / 0.15)  # у посадки задирает грудь
		if _takeoff and _progress < TURN_IN:
			# с места: от позы сидящей (грудь вверх, прежний курс) к полёту
			var turn_in: float = smoothstep(0.0, TURN_IN, _progress)
			yaw = lerp_angle(_start_yaw, yaw, turn_in)
			pitch = lerpf(STAND_PITCH, pitch, turn_in)
			_roll *= turn_in
		rotation = Vector3(pitch, yaw, _roll)
	var climbing: bool = ahead.y > -0.004 or _progress < 0.18 or (_lands and _progress > 0.82)
	var want: String = "flap" if climbing else "glide"
	if _anim_lock <= 0.0 and _fly_anim.current_animation != want:
		_fly_anim.play(want, 0.35)
	if _progress >= 1.0 and not _lands:
		finished.emit(self)
		queue_free()


## Уже на месте: крылья доскладываются, грудь встаёт, крен уходит, тело чуть проседает на лапах;
## под конец летящая модель перетекает в сидящую (прозрачность навстречу), без подмены за один кадр.
func _settle(delta: float) -> void:
	_settle_time += delta
	var fold_time: float = _land_time * (1.0 - LAND_LEAD)
	var stand: float = smoothstep(0.0, fold_time, _settle_time)
	var tilt: Basis = Basis.from_euler(Vector3(lerpf(_landed_tilt.x, STAND_PITCH, stand), 0.0,
			lerpf(_landed_tilt.y, 0.0, stand)))
	var dip: float = -TOUCH_DIP * sin(PI * clampf(_settle_time / 0.4, 0.0, 1.0))
	var size: float = PERCH_SCALE * (1.0 + STAND_GROW)
	_fly_model.transform = Transform3D(tilt * Basis.from_scale(Vector3.ONE * size),
			tilt * STAND_SHIFT + Vector3(0.0, dip, 0.0))
	position = _points[3]
	var blend_from: float = fold_time - 0.1
	if _settle_time >= blend_from and not _perch_model.visible:
		_perch_model.visible = true
		_perch_anim.play("idle", 0.0)
	# сначала сидящая проявляется поверх непрозрачной летящей, потом летящая тает: птица не светлеет
	var mix: float = clampf((_settle_time - blend_from) / SETTLE_BLEND, 0.0, 1.0)
	_fade(_perch_meshes, 1.0 - smoothstep(0.0, 0.6, mix))
	_fade(_fly_meshes, smoothstep(0.4, 1.0, mix))
	if _settle_time >= blend_from + SETTLE_BLEND:
		_fade(_fly_meshes, 0.0)
		_fade(_perch_meshes, 0.0)
		is_flying = false
		on_ground = _land_ground
		_fly_model.visible = false
		_fly_anim.stop()
		_perch_anim.queue("idle")
		_gesture_in = _rng.randf_range(1.5, 4.0)


## Летящая модель в позе сидящей (как в конце посадки): грудь вверх, тело над лапами; узел — без наклона.
func _stand_pose() -> void:
	var tilt: Basis = Basis.from_euler(Vector3(STAND_PITCH, 0.0, 0.0))
	_fly_model.transform = Transform3D(tilt * Basis.from_scale(Vector3.ONE * PERCH_SCALE * (1.0 + STAND_GROW)),
			tilt * STAND_SHIFT)


static func _fade(meshes: Array[GeometryInstance3D], amount: float) -> void:
	for mesh: GeometryInstance3D in meshes:
		mesh.transparency = amount


func _ease(t: float) -> float:
	var start: float = 0.18
	var finish: float = 0.25 if _lands else 0.0
	if t < start:
		return t * t / start * 0.5
	if t > 1.0 - finish:
		var u: float = (1.0 - t) / finish
		return 1.0 - u * u * finish * 0.5
	var lo: float = start * 0.5
	var hi: float = 1.0 - finish * 0.5
	return lo + (t - start) / (1.0 - start - finish) * (hi - lo)


func _bezier(t: float) -> Vector3:
	return _points[0].bezier_interpolate(_points[1], _points[2], _points[3], t)


func _curve_length() -> float:
	var length: float = 0.0
	var prev: Vector3 = _points[0]
	for k: int in range(1, 17):
		var p: Vector3 = _bezier(k / 16.0)
		length += p.distance_to(prev)
		prev = p
	return length


func _show_flying(flying: bool) -> void:
	_fade(_fly_meshes, 0.0)
	_fade(_perch_meshes, 0.0)
	_fly_model.visible = flying
	_perch_model.visible = not flying
	if flying:
		_perch_anim.stop()
	else:
		_fly_anim.stop()
		rotation.x = 0.0
		rotation.z = 0.0


static func _find_player(model: Node) -> AnimationPlayer:
	var found: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
	return found[0] as AnimationPlayer

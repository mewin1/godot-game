class_name ArenaUnit3D
extends Node3D
## 3D-юнит на дороге. Пять базовых силуэтов: пеший, тяжёлый (броня), летающий (нетопырь),
## босс и колобок; остальные — перекраска и размер из Arena3DStyle.
## Темп шага задаёт настоящая скорость моба (сколько метров он прошёл за секунду).

const DEATH_SECONDS: float = 0.35

var kind: StringName = &"walker"
var dying_left: float = 0.0
var _body: Node3D
var _roller: Node3D
var _limbs: Array[Node3D] = []
var _phase: float = 0.0
var _height: float = 1.0
var _flash: MeshInstance3D
var _rage_ring: MeshInstance3D
var _skeleton: Skeleton3D


## Собирает модель. height — рост в метрах, tint — основной цвет.
func build(model: StringName, tint: Color, height: float, sender_color: Color, mob_id: StringName = &"") -> void:
	kind = model
	_height = height
	_body = Node3D.new()
	add_child(_body)
	if _build_noir(mob_id):
		pass
	else:
		_build_procedural(model, tint)
	_finish_build(height, sender_color)


func _build_procedural(model: StringName, tint: Color) -> void:
	match model:
		&"heavy":
			_build_heavy(tint)
		&"flyer":
			_build_flyer(tint)
		&"boss":
			_build_boss(tint)
		&"blob":
			_build_blob(tint)
		_:
			_build_walker(tint)


## Модель «славянского нуара» (GLB со скелетом): рост приводится к height (тело масштабируется на height).
func _build_noir(mob_id: StringName) -> bool:
	var scene: PackedScene = NoirModels.unit(mob_id)
	if scene == null:
		return false
	var holder: Node3D = Node3D.new()
	holder.scale = Vector3.ONE / NoirModels.HUMAN_HEIGHT
	_body.add_child(holder)
	holder.add_child(scene.instantiate())
	var found: Array[Node] = holder.find_children("*", "Skeleton3D", true, false)
	if not found.is_empty():
		_skeleton = found[0] as Skeleton3D
	kind = &"noir"
	return true


func _finish_build(height: float, sender_color: Color) -> void:
	_body.scale = Vector3.ONE * height
	var shadow: CylinderMesh = ArenaMaterials3D.cylinder(0.24 * height, 0.24 * height, 0.02, 12)
	ArenaMaterials3D.part(self, shadow,
			ArenaMaterials3D.flat(Color(0.0, 0.0, 0.02, 0.3)), Vector3(0, 0.03, 0))
	# Тень луны от десятков мелких деталей удваивает отрисовку; хватает тени-подложки.
	for child: Node in find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if sender_color.a > 0.0:
		var ring: TorusMesh = TorusMesh.new()
		ring.inner_radius = 0.34 * height
		ring.outer_radius = 0.42 * height
		ring.ring_segments = 4
		ring.rings = 20
		ArenaMaterials3D.part(self, ring, ArenaMaterials3D.glow(sender_color, 1.2),
				Vector3(0, 0.04, 0))


## Скрытный моб полупрозрачен (как в 2D), чтобы было видно: башням его не достать.
func set_ghost(alpha: float) -> void:
	for child: Node in find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).transparency = 1.0 - alpha


## Ярость поля: красное кольцо под юнитом.
func set_enraged(enabled: bool, color: Color) -> void:
	if enabled and _rage_ring == null:
		var ring: TorusMesh = TorusMesh.new()
		ring.inner_radius = 0.3 * _height
		ring.outer_radius = 0.38 * _height
		ring.ring_segments = 4
		ring.rings = 18
		_rage_ring = ArenaMaterials3D.part(self, ring, ArenaMaterials3D.glow(color, 1.6),
				Vector3(0, 0.06, 0))
	if _rage_ring != null:
		_rage_ring.visible = enabled


## Шаг анимации. speed — метры в секунду (0 — стоит), flight — высота полёта.
## Размах шага костями у моделей «нуар» (рад).
const NOIR_STRIDE: float = 0.24


func animate(delta: float, speed: float, steps_per_meter: float) -> void:
	_phase += delta * maxf(speed * steps_per_meter, 0.6 if kind == &"flyer" else 0.0) * TAU
	var swing: float = sin(_phase)
	match kind:
		&"noir":
			# малый шаг: у моделей по концептам длинные полы, широкий шаг их растягивает
			_walk_bones(swing, NOIR_STRIDE if speed > 0.05 else 0.0)
			_body.position.y = absf(swing) * 0.04 * _height * float(speed > 0.05)
			_body.rotation.z = swing * 0.04 * float(speed > 0.05)
		&"flyer":
			for i: int in _limbs.size():
				_limbs[i].rotation.z = (1.0 if i == 0 else -1.0) * (0.25 + swing * 0.6)
			_body.position.y = sin(_phase * 0.5) * 0.08
		&"blob":
			_roller.rotation.x += delta * speed / maxf(0.1, _height * 0.36)
			_body.position.y = absf(swing) * 0.04 * _height
		_:
			var stride: float = 0.55 if speed > 0.05 else 0.0
			for i: int in _limbs.size():
				_limbs[i].rotation.x = swing * stride * (1.0 if i % 2 == 0 else -1.0)
			_body.position.y = absf(swing) * 0.05 * _height * float(speed > 0.05)
			_body.rotation.z = swing * 0.05 * float(speed > 0.05)


## Походка костями общего скелета: бёдра и руки качаются навстречу, колено сгибается.
func _walk_bones(swing: float, stride: float) -> void:
	if _skeleton == null:
		return
	for side: String in ["L", "R"]:
		var sign: float = 1.0 if side == "L" else -1.0
		_rotate_bone("thigh." + side, Vector3.RIGHT, swing * stride * sign)
		_rotate_bone("shin." + side, Vector3.RIGHT, -maxf(0.0, -swing * sign) * stride * 0.9)
		_rotate_bone("upper_arm." + side, Vector3.RIGHT, -swing * stride * 0.4 * sign)


func _rotate_bone(bone_name: String, axis: Vector3, angle: float) -> void:
	var bone: int = _skeleton.find_bone(bone_name)
	if bone < 0:
		return
	var rest: Quaternion = _skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
	_skeleton.set_bone_pose_rotation(bone, rest * Quaternion(axis, angle))


## Смерть: короткая вспышка и исчезновение. Возвращает true, когда пора удалить.
func update_death(delta: float) -> bool:
	if _flash == null:
		_flash = ArenaMaterials3D.part(self, ArenaMaterials3D.sphere(0.45 * _height, 8, 4),
				ArenaMaterials3D.glow(Color(1, 0.9, 0.7), 4.0),
				Vector3(0, 0.5 * _height, 0))
		_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dying_left -= delta
	var t: float = clampf(1.0 - dying_left / DEATH_SECONDS, 0.0, 1.0)
	_body.scale = Vector3.ONE * _height * (1.0 - t)
	_flash.scale = Vector3.ONE * (0.6 + t * 1.2) * (1.0 - t)
	return dying_left <= 0.0


func _leg(parent: Node3D, x: float, length: float, width: float, material: Material) -> void:
	var hip: Node3D = Node3D.new()
	hip.position = Vector3(x, length, 0)
	parent.add_child(hip)
	ArenaMaterials3D.part(hip, ArenaMaterials3D.box(Vector3(width, length, width)), material,
			Vector3(0, -length * 0.5, 0))
	_limbs.append(hip)


## Пеший: туловище-капсула, голова, ноги и копьё.
func _build_walker(tint: Color) -> void:
	var cloth: StandardMaterial3D = ArenaMaterials3D.solid(tint)
	var dark: StandardMaterial3D = ArenaMaterials3D.solid(tint.darkened(0.45))
	_leg(_body, -0.08, 0.36, 0.1, dark)
	_leg(_body, 0.08, 0.36, 0.1, dark)
	ArenaMaterials3D.part(_body, ArenaMaterials3D.cylinder(0.2, 0.15, 0.38, 6), cloth,
			Vector3(0, 0.55, 0))
	ArenaMaterials3D.part(_body, ArenaMaterials3D.sphere(0.12, 8, 5),
			ArenaMaterials3D.solid(ArenaMaterials3D.SKIN), Vector3(0, 0.84, 0))
	ArenaMaterials3D.part(_body, ArenaMaterials3D.cylinder(0.14, 0.0, 0.16, 6), dark,
			Vector3(0, 0.96, 0))
	ArenaMaterials3D.part(_body, ArenaMaterials3D.cylinder(0.02, 0.02, 0.9, 4),
			ArenaMaterials3D.solid(ArenaMaterials3D.WOOD), Vector3(0.22, 0.6, 0.05))


## Тяжёлый: широкий корпус в броне, шлем, щит.
func _build_heavy(tint: Color) -> void:
	var metal: StandardMaterial3D = ArenaMaterials3D.solid(tint, 0.45)
	var dark: StandardMaterial3D = ArenaMaterials3D.solid(tint.darkened(0.5), 0.6)
	_leg(_body, -0.11, 0.34, 0.13, dark)
	_leg(_body, 0.11, 0.34, 0.13, dark)
	ArenaMaterials3D.part(_body, ArenaMaterials3D.cylinder(0.28, 0.22, 0.42, 6), metal,
			Vector3(0, 0.55, 0))
	ArenaMaterials3D.part(_body, ArenaMaterials3D.cylinder(0.15, 0.13, 0.2, 6), metal,
			Vector3(0, 0.86, 0))
	ArenaMaterials3D.part(_body, ArenaMaterials3D.cylinder(0.07, 0.0, 0.14, 6),
			ArenaMaterials3D.solid(ArenaMaterials3D.GOLD, 0.4), Vector3(0, 1.02, 0))
	ArenaMaterials3D.part(_body, ArenaMaterials3D.box(Vector3(0.06, 0.42, 0.34)),
			ArenaMaterials3D.solid(Color(0.45, 0.16, 0.12)),
			Vector3(-0.3, 0.55, 0.05))


## Летающий нетопырь: тело и два машущих крыла.
func _build_flyer(tint: Color) -> void:
	var skin: StandardMaterial3D = ArenaMaterials3D.solid(tint)
	ArenaMaterials3D.part(_body, ArenaMaterials3D.sphere(0.2, 8, 5), skin, Vector3.ZERO,
			Vector3.ZERO, Vector3(0.9, 1.0, 1.2))
	ArenaMaterials3D.part(_body, ArenaMaterials3D.sphere(0.04, 6, 3),
			ArenaMaterials3D.glow(Color(1, 0.3, 0.2), 3.0), Vector3(-0.07, 0.07, 0.19))
	ArenaMaterials3D.part(_body, ArenaMaterials3D.sphere(0.04, 6, 3),
			ArenaMaterials3D.glow(Color(1, 0.3, 0.2), 3.0), Vector3(0.07, 0.07, 0.19))
	for side: float in [-1.0, 1.0]:
		var shoulder: Node3D = Node3D.new()
		shoulder.position = Vector3(side * 0.15, 0.05, 0)
		_body.add_child(shoulder)
		var wing: PrismMesh = PrismMesh.new()
		wing.size = Vector3(0.6, 0.36, 0.03)
		ArenaMaterials3D.part(shoulder, wing, ArenaMaterials3D.solid(tint.darkened(0.35)),
				Vector3(side * 0.3, 0, 0),
				Vector3(PI * 0.5, 0, 0))
		_limbs.append(shoulder)


## Босс: массивный корпус, рога, светящиеся глаза.
func _build_boss(tint: Color) -> void:
	var hide: StandardMaterial3D = ArenaMaterials3D.solid(tint)
	var dark: StandardMaterial3D = ArenaMaterials3D.solid(tint.darkened(0.5))
	_leg(_body, -0.14, 0.3, 0.15, dark)
	_leg(_body, 0.14, 0.3, 0.15, dark)
	ArenaMaterials3D.part(_body, ArenaMaterials3D.cylinder(0.34, 0.26, 0.42, 7), hide,
			Vector3(0, 0.5, 0))
	ArenaMaterials3D.part(_body, ArenaMaterials3D.sphere(0.2, 8, 5), hide, Vector3(0, 0.82, 0.04))
	for side: float in [-1.0, 1.0]:
		ArenaMaterials3D.part(_body, ArenaMaterials3D.cylinder(0.05, 0.0, 0.26, 5),
				ArenaMaterials3D.solid(Color(0.88, 0.82, 0.68)),
				Vector3(side * 0.15, 1.0, 0), Vector3(0, 0, side * -0.5))
		ArenaMaterials3D.part(_body, ArenaMaterials3D.sphere(0.035, 6, 3),
				ArenaMaterials3D.glow(Color(1, 0.55, 0.1), 4.0),
				Vector3(side * 0.07, 0.85, 0.21))
	ArenaMaterials3D.part(_body, ArenaMaterials3D.cylinder(0.03, 0.03, 0.9, 4),
			ArenaMaterials3D.solid(ArenaMaterials3D.DARK_WOOD), Vector3(0.36, 0.55, 0.1))


## Колобок: катящийся шар с глазами.
func _build_blob(tint: Color) -> void:
	var holder: Node3D = Node3D.new()
	holder.position = Vector3(0, 0.36, 0)
	_body.add_child(holder)
	ArenaMaterials3D.part(holder, ArenaMaterials3D.sphere(0.36, 10, 6),
			ArenaMaterials3D.solid(tint), Vector3.ZERO)
	for side: float in [-1.0, 1.0]:
		ArenaMaterials3D.part(holder, ArenaMaterials3D.sphere(0.05, 6, 3),
				ArenaMaterials3D.solid(Color(0.08, 0.06, 0.05)),
				Vector3(side * 0.12, 0.08, 0.32))
	_roller = holder

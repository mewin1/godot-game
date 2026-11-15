class_name ArenaMaterials3D
extends RefCounted
## Общие материалы 3D-моделей арены. Один цвет — один материал (кэш), чтобы не плодить копии.

const WOOD: Color = Color(0.34, 0.23, 0.15)
const DARK_WOOD: Color = Color(0.2, 0.13, 0.08)
const STONE: Color = Color(0.42, 0.44, 0.47)
const DARK_STONE: Color = Color(0.26, 0.28, 0.32)
const GOLD: Color = Color(1.0, 0.78, 0.32)
const SKIN: Color = Color(0.86, 0.68, 0.52)

static var _solid: Dictionary[Color, StandardMaterial3D] = {}
static var _glow: Dictionary[Color, StandardMaterial3D] = {}
static var _flat: Dictionary[Color, StandardMaterial3D] = {}
static var _stone: Dictionary[Color, StandardMaterial3D] = {}
static var _grain: NoiseTexture2D
static var _relief: NoiseTexture2D
## Дерево с фактурой (critique_3 п. 20, 24, 25, 32): та же доска, что у частокола, на все примитивы.
const WOOD_GRAIN: Texture2D = preload("res://assets/noir/courtyard/palisade_weathered_oak.png")
static var _wood: Dictionary[String, StandardMaterial3D] = {}
static var _grain_across: ImageTexture
static var _wattle: Dictionary[Color, StandardMaterial3D] = {}


## Матовый материал (дерево, камень, окраска).
static func solid(color: Color, roughness: float = 0.85) -> StandardMaterial3D:
	if not _solid.has(color):
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = roughness
		_solid[color] = material
	return _solid[color]


## Камень с фактурой: процедурный шум как зерно цвета и рельеф (трипланарно, без UV).
static func stone(color: Color) -> StandardMaterial3D:
	if not _stone.has(color):
		if _grain == null:
			_grain = _noise_texture(false)
			_relief = _noise_texture(true)
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = color
		material.albedo_texture = _grain
		material.normal_enabled = true
		material.normal_texture = _relief
		material.normal_scale = 0.9
		material.roughness = 0.92
		material.uv1_triplanar = true
		material.uv1_scale = Vector3.ONE * 0.55
		_stone[color] = material
	return _stone[color]


static func _noise_texture(as_normal: bool) -> NoiseTexture2D:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.035
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.seed = 7
	var texture: NoiseTexture2D = NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.noise = noise
	texture.as_normal_map = as_normal
	texture.bump_strength = 6.0
	if not as_normal:
		# Светлое зерно: цвет плиты остаётся главным, шум только оживляет.
		var ramp: Gradient = Gradient.new()
		ramp.set_color(0, Color(0.72, 0.72, 0.72))
		ramp.set_color(1, Color(1.05, 1.04, 1.02))
		texture.color_ramp = ramp
	return texture


## Дерево с волокнами досок частокола (трипланарно в осях детали). shade — яркость (1 — как
## частокол), across — волокна вдоль оси X детали (доски и брусья), иначе вдоль Y (столбы, брёвна).
static func wood(shade: float, across: bool = false, roughness: float = 0.9) -> StandardMaterial3D:
	var key: String = "%.3f:%s:%.2f" % [shade, across, roughness]
	if not _wood.has(key):
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color(shade, shade, shade)
		material.albedo_texture = _across_grain() if across else WOOD_GRAIN
		material.roughness = roughness
		material.uv1_triplanar = true
		material.uv1_scale = Vector3.ONE * 0.85
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_wood[key] = material
	return _wood[key]


static func _across_grain() -> ImageTexture:
	if _grain_across == null:
		var image: Image = WOOD_GRAIN.get_image()
		if image.is_compressed():
			image.decompress()
		image.rotate_90(CLOCKWISE)
		image.generate_mipmaps()
		_grain_across = ImageTexture.create_from_image(image)
	return _grain_across


## Плетень (critique_3 п. 16, 27): полоса с прутьями и просветами (альфа-срез), неровный верх.
## Рисуется в коде один раз: горизонтальные прутья волной вокруг кольев. Двусторонняя.
static func wattle(color: Color) -> StandardMaterial3D:
	if not _wattle.has(color):
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = color
		material.albedo_texture = _wattle_texture()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.5
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.roughness = 0.95
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_wattle[color] = material
	return _wattle[color]


static func _wattle_texture() -> ImageTexture:
	const W: int = 256
	const H: int = 96
	var image: Image = Image.create(W, H, true, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 91
	# Неровный верх: высота верхнего прута плавно гуляет.
	var rods: int = 7
	for rod: int in rods:
		var base: float = H - 10.0 - rod * 11.5
		var phase: float = rng.randf() * TAU
		var tone: float = rng.randf_range(0.8, 1.15)
		for x: int in W:
			var weave: float = sin(x / float(W) * TAU * 4.0 + (PI if rod % 2 == 1 else 0.0)) * 2.4
			var wobble: float = sin(x * 0.045 + phase) * 1.6
			var y_mid: float = base + weave + wobble
			if rod == rods - 1 and sin(x * 0.03 + phase) > 0.35:
				continue
			for dy: int in range(-4, 5):
				var y: int = roundi(y_mid) + dy
				if y < 0 or y >= H:
					continue
				var shade: float = tone * (1.0 - absf(dy) / 6.0) * (0.9 + 0.1 * sin(x * 0.7 + rod))
				image.set_pixel(x, y, Color(shade, shade * 0.97, shade * 0.93, 1.0))
	# Колья через 64 px — темнее прутьев.
	for stake: int in 4:
		var x0: int = 30 + stake * 64
		for x: int in range(x0 - 3, x0 + 4):
			for y: int in range(4, H):
				image.set_pixel(x, y, Color(0.62, 0.6, 0.58, 1.0))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


## Светящийся акцент (кристалл, огонь, глаза). Яркость выше 1 даёт свечение (glow).
static func glow(color: Color, energy: float = 2.4) -> StandardMaterial3D:
	var key: Color = Color(color, energy / 10.0)
	if not _glow.has(key):
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = energy
		_glow[key] = material
	return _glow[key]


## Плоская полупрозрачная заливка без света (туман закрытых мест, подсветка).
static func flat(color: Color) -> StandardMaterial3D:
	if not _flat.has(color):
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = color
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_flat[color] = material
	return _flat[color]


## Добавляет к родителю деталь из примитива: сетка, материал, позиция.
static func part(parent: Node3D, mesh: Mesh, material: Material, position: Vector3,
		rotation: Vector3 = Vector3.ZERO, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.rotation = rotation
	instance.scale = scale
	parent.add_child(instance)
	return instance


## Цилиндр/конус с гранями (низкополигональный стиль арены).
static func cylinder(bottom: float, top: float, height: float, sides: int = 6) -> CylinderMesh:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return mesh


static func box(size: Vector3) -> BoxMesh:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return mesh


## Сфера; при малом числе сегментов — гранёный камень или кристалл.
static func sphere(radius: float, segments: int = 10, rings: int = 6) -> SphereMesh:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = rings
	return mesh

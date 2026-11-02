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


## Матовый материал (дерево, камень, окраска).
static func solid(color: Color, roughness: float = 0.85) -> StandardMaterial3D:
	if not _solid.has(color):
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = roughness
		_solid[color] = material
	return _solid[color]


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

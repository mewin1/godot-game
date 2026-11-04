class_name NoirModels
extends RefCounted
## Модели редизайна «славянский нуар» (GLB из tools/blender/noir). Нет модели — вызывающий
## строит прежнюю процедурную. Масштаб моделей: 1 м = 1 единица, клетка 2 м, рост человека 1,7 м.

const ROOT: String = "res://assets/noir/"
## Модели из сеток Hunyuan3D (tools/blender/noir/h3d.py): если файл есть, берётся он, иначе прежний из ROOT.
## Старые модели не удаляются — какой вариант оставить, решает автор (сравнения в new_concept/final/).
const ROOT_H3D: String = "res://assets/noir_h3d/"
const HUMAN_HEIGHT: float = 1.7
## Высота постройки по уровню (как в Blender: I ≈ 1 клетка, II ≈ 1,4, III ≈ 1,8).
const TIER_HEIGHT: PackedFloat32Array = [2.0, 2.8, 3.6]

static var _cache: Dictionary[String, PackedScene] = {}


static func tower(id: StringName) -> PackedScene:
	return _load("towers/%s.glb" % id)


## Своя плита постройки (с рисунком концепта) — под центральную клетку фигуры.
static func tower_plate(id: StringName) -> PackedScene:
	return _load("towers/%s_plate.glb" % id)


static func unit(id: StringName) -> PackedScene:
	return _load("units/%s.glb" % id)


static func plate(tier: int, god: StringName) -> PackedScene:
	var school: String = String(god) if not String(god).is_empty() else "neutral"
	var scene: PackedScene = _load("plates/plate_%d_%s.glb" % [clampi(tier, 1, 3), school])
	if scene == null:
		scene = _load("plates/plate_%d_neutral.glb" % clampi(tier, 1, 3))
	return scene


static func base() -> PackedScene:
	return _load("base/terem.glb")


## Своя плита терема (у моделей Hunyuan3D плита отрезана в отдельный файл).
static func base_plate() -> PackedScene:
	return _load("base/terem_plate.glb")


static func idol() -> PackedScene:
	return _load("idols/idol.glb")


static func _load(path: String) -> PackedScene:
	var full: String = ROOT_H3D + path
	if not ResourceLoader.exists(full):
		full = ROOT + path
	if _cache.has(full):
		return _cache[full]
	var scene: PackedScene = null
	if ResourceLoader.exists(full):
		scene = load(full) as PackedScene
	_cache[full] = scene
	return scene

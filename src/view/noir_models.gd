class_name NoirModels
extends RefCounted
## Модели редизайна «славянский нуар» (GLB из tools/blender/noir). Нет модели — вызывающий
## строит прежнюю процедурную. Масштаб моделей: 1 м = 1 единица, клетка 2 м, рост человека 1,7 м.

const ROOT: String = "res://assets/noir/"
## Модели из сеток Hunyuan3D (tools/blender/noir/h3d.py): если файл есть, берётся он, иначе прежний из ROOT.
## Старые модели не удаляются — какой вариант оставить, решает автор (сравнения в new_concept/final/).
const ROOT_H3D: String = "res://assets/noir_h3d/"
const WORKSHOPS: String = "res://assets/noir/courtyard/towers/"
const HUMAN_HEIGHT: float = 1.7
## Высота постройки по уровню (как в Blender: I ≈ 1 клетка, II ≈ 1,4, III ≈ 1,8).
const TIER_HEIGHT: PackedFloat32Array = [2.0, 2.8, 3.6]
## Папки моделей, которые матч берёт по ходу игры (см. all_paths).
const MODEL_FOLDERS: PackedStringArray = ["towers/", "plates/", "units/", "base/", "idols/"]

static var _cache: Dictionary[String, PackedScene] = {}
static var _icons: Dictionary[String, Texture2D] = {}


static func tower(id: StringName) -> PackedScene:
	var current: String = WORKSHOPS + String(id) + ".glb"
	if ResourceLoader.exists(current):
		return _cached_scene(current)
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


## Значок идола для интерфейса — рендер модели Hunyuan3D (tools/blender/noir/idol_icons.py); нет — null.
static func idol_icon(god: StringName) -> Texture2D:
	var key: String = String(god) if not String(god).is_empty() else "empty"
	if _icons.has(key):
		return _icons[key]
	var path: String = ROOT_H3D + "icons/idol_%s.png" % key
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	_icons[key] = texture
	return texture


static func idol() -> PackedScene:
	return _load("idols/idol.glb")


## Все модели матча (постройки, плиты, юниты, терем, идол) — для чтения заранее на экране загрузки,
## иначе модель читается с диска в миг первой постройки и игра подвисает.
static func all_paths() -> PackedStringArray:
	var paths: PackedStringArray = []
	for file: String in ResourceLoader.list_directory(WORKSHOPS):
		if file.get_extension() == "glb":
			paths.append(WORKSHOPS + file)
	for folder: String in MODEL_FOLDERS:
		for file: String in ResourceLoader.list_directory(ROOT_H3D + folder):
			if file.get_extension() == "glb" and (folder != "towers/" or not ResourceLoader.exists(WORKSHOPS + file)):
				paths.append(ROOT_H3D + folder + file)
		for file: String in ResourceLoader.list_directory(ROOT + folder):
			if file.get_extension() == "glb" and not ResourceLoader.exists(ROOT_H3D + folder + file):
				paths.append(ROOT + folder + file)
	return paths


## Модель, прочитанная заранее: дальше она берётся из кэша без обращения к диску.
static func remember(path: String, scene: PackedScene) -> void:
	_cache[path] = scene


static func is_cached(path: String) -> bool:
	return _cache.has(path)


static func _load(path: String) -> PackedScene:
	var full: String = ROOT_H3D + path
	if not ResourceLoader.exists(full):
		full = ROOT + path
	return _cached_scene(full)


static func _cached_scene(full: String) -> PackedScene:
	if _cache.has(full):
		return _cache[full]
	var scene: PackedScene = null
	if ResourceLoader.exists(full):
		scene = load(full) as PackedScene
	_cache[full] = scene
	return scene

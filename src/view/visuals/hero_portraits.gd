class_name HeroPortraits
extends RefCounted
## Портреты героев из атласа; прежние SVG остаются для исторического контента.

const PATH_FORMAT: String = "res://data/visuals/portraits/%s.tres"
## Герой во весь рост — одобренный концепт (tools/concepts/ui_art.py); портрет — кадр лица на нём.
const FULL_ART_FORMAT: String = "res://assets/ui/heroes/%s.jpg"

static var _cache: Dictionary[StringName, Texture2D] = {}


## Портрет героя (null — героя нет или картинки нет).
static func get_portrait(hero: HeroData) -> Texture2D:
	if hero == null:
		return null
	if not _cache.has(hero.id):
		var path: String = PATH_FORMAT % hero.id
		if not ResourceLoader.exists(path):
			path = "res://assets/heroes/%s.svg" % hero.id
		_cache[hero.id] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _cache[hero.id]


## Герой во весь рост (карточка выбора); нет картинки — портрет.
static func get_full_art(hero: HeroData) -> Texture2D:
	if hero == null:
		return null
	var path: String = FULL_ART_FORMAT % hero.id
	return load(path) as Texture2D if ResourceLoader.exists(path) else get_portrait(hero)

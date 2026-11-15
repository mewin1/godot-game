class_name GodSymbols
extends RefCounted
## Только художественные соответствия: символы семи сил и пустого идола.

const ATLAS: Texture2D = preload("res://assets/dusk/sigils.png")
const GODS: Array[StringName] = [
	&"svarog", &"perun", &"water", &"stribog", &"ice", &"curse", &"war", &""]

static var _cache: Dictionary[StringName, Texture2D] = {}


## Общая палитра сил: холодные вода/лёд и тёплые огонь/молния различимы на панелях.
static func get_color(god: StringName) -> Color:
	match god:
		&"svarog":
			return Color("d8644f")
		&"perun":
			return Color("e2bb61")
		&"water":
			return Color("55b3be")
		&"stribog":
			return Color("67ae88")
		&"ice":
			return Color("a3d9f0")
		&"curse":
			return Color("b58cdb")
		&"war":
			return Color("c59968")
	return DuskTheme.GOLD


## Полное имя в подсказках; идентификатор силы приходит из игрового ресурса.
static func get_power_name(god: StringName) -> String:
	match god:
		&"svarog":
			return "Огонь · Сварог"
		&"perun":
			return "Молния · Перун"
		&"water":
			return "Вода"
		&"stribog":
			return "Ветер · Стрибог"
		&"ice":
			return "Лёд"
		&"curse":
			return "Проклятие · Чернобог"
		&"war":
			return "Война · Бог войны"
	return "Без стихии"


## Символ для идола, заговора и справки; незнакомая сила получает пустую основу.
static func get_icon(god: StringName) -> Texture2D:
	if not _cache.has(god):
		var index: int = GODS.find(god)
		if index < 0:
			index = GODS.size() - 1
		var dimensions: Vector2 = Vector2(ATLAS.get_size()) / Vector2(4, 2)
		var texture: AtlasTexture = AtlasTexture.new()
		texture.atlas = ATLAS
		texture.region = Rect2(Vector2(index % 4, index / 4) * dimensions, dimensions)
		texture.filter_clip = true
		_cache[god] = texture
	return _cache[god]

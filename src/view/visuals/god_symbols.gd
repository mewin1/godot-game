class_name GodSymbols
extends RefCounted
## Только художественные соответствия: символы семи сил и пустого идола.

const ATLAS: Texture2D = preload("res://assets/dusk/sigils.png")
const GODS: Array[StringName] = [
	&"svarog", &"perun", &"water", &"stribog", &"ice", &"curse", &"war", &""]

static var _cache: Dictionary[StringName, Texture2D] = {}


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

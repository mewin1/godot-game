class_name CloudShadows3D
extends Node3D
## Тени облаков: большая декаль сверху с рваной облачной маской медленно плывёт по ветру и
## затемняет всё под собой (землю, частокол, постройки, лес), не трогая огонь и окна. Облака
## 20–40 м — то задевают двор краем, то накрывают его целиком. Силу задаёт RitualDaylight.

## Период узора (м): маска повторяется, декаль — 2×2 периода, при сдвиге на период — скачок назад.
const PERIOD: float = 150.0
const PIXELS: int = 256
## Доля неба в облаках и мягкость края.
const COVER: float = 0.5
const SOFTNESS: float = 0.14
## Ветер облаков, м/с.
const WIND: Vector2 = Vector2(2.4, -1.0)
## Над какой точкой мира висит декаль.
var center: Vector3 = Vector3.ZERO
var _decal: Decal
var _offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	_decal = Decal.new()
	_decal.name = "CloudShadow"
	_decal.size = Vector3(PERIOD * 2.0, 80.0, PERIOD * 2.0)
	_decal.texture_albedo = _mask()
	_decal.modulate = Color(0.0, 0.0, 0.0, 1.0)
	_decal.albedo_mix = 0.0
	_decal.upper_fade = 0.0
	_decal.lower_fade = 0.0
	_decal.normal_fade = 0.0
	_decal.distance_fade_enabled = false
	add_child(_decal)
	_place()


## 0 — облаков нет, 1 — под облаком совсем темно.
func set_strength(value: float) -> void:
	if _decal != null:
		_decal.albedo_mix = clampf(value, 0.0, 1.0)


func _process(delta: float) -> void:
	_offset += WIND * delta
	_offset = Vector2(fposmod(_offset.x, PERIOD), fposmod(_offset.y, PERIOD))
	_place()


func _place() -> void:
	_decal.position = center + Vector3(_offset.x, 30.0, _offset.y)


## Облачная маска: бесшовный шум, порог по доле облаков; альфа — плотность тени. 2×2 повтора.
static func _mask() -> ImageTexture:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 31
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 4.5 / PIXELS
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.5
	var source: Image = noise.get_seamless_image(PIXELS, PIXELS)
	source.convert(Image.FORMAT_L8)
	var low: float = 1.0 - COVER - SOFTNESS
	var high: float = 1.0 - COVER + SOFTNESS
	var mask: Image = Image.create(PIXELS * 2, PIXELS * 2, false, Image.FORMAT_LA8)
	for y: int in PIXELS:
		for x: int in PIXELS:
			var density: float = smoothstep(low, high, source.get_pixel(x, y).r)
			var pixel: Color = Color(0.0, 0.0, 0.0, density)
			for tile: Vector2i in [Vector2i(0, 0), Vector2i(PIXELS, 0), Vector2i(0, PIXELS), Vector2i(PIXELS, PIXELS)]:
				mask.set_pixel(x + tile.x, y + tile.y, pixel)
	mask.generate_mipmaps()
	return ImageTexture.create_from_image(mask)

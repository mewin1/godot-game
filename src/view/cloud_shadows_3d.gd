class_name CloudShadows3D
extends Node3D
## Тени облаков: большая декаль сверху с рваной облачной маской медленно плывёт по ветру и
## затемняет всё под собой (землю, частокол, постройки, лес), не трогая огонь и окна. Облака
## 30–60 м с неровными кучевыми краями — то задевают двор краем, то накрывают его целиком.
## Силу задаёт RitualDaylight.

## Период узора (м): маска бесшовная и повторяется TILES × TILES раз. Декаль сдвигается на долю периода,
## а её край всегда дальше периода от середины — раньше декаль была 2×2 периода, и при сдвиге её прямой
## край заходил в кадр («квадратное облако»).
const PERIOD: float = 160.0
const TILES: int = 4
const PIXELS: int = 256
## Доля неба в облаках и мягкость края.
const COVER: float = 0.46
const SOFTNESS: float = 0.12
## Ветер облаков, м/с.
const WIND: Vector2 = Vector2(2.4, -1.0)
## Над какой точкой мира висит декаль.
var center: Vector3 = Vector3.ZERO
var _decal: Decal
var _offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	_decal = Decal.new()
	_decal.name = "CloudShadow"
	_decal.size = Vector3(PERIOD * TILES, 80.0, PERIOD * TILES)
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


## Облачная маска: бесшовный шум с завихрением (рваные кучевые края, без кругов и полос), порог по
## доле облаков; альфа — плотность тени. TILES × TILES повторов.
static func _mask() -> ImageTexture:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 31
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 3.4 / PIXELS
	noise.fractal_octaves = 5
	noise.fractal_gain = 0.55
	noise.domain_warp_enabled = true
	noise.domain_warp_amplitude = 22.0
	noise.domain_warp_frequency = 3.0 / PIXELS
	var source: Image = noise.get_seamless_image(PIXELS, PIXELS)
	source.convert(Image.FORMAT_L8)
	var low: float = 1.0 - COVER - SOFTNESS
	var high: float = 1.0 - COVER + SOFTNESS
	var tile: Image = Image.create(PIXELS, PIXELS, false, Image.FORMAT_RGBA8)
	for y: int in PIXELS:
		for x: int in PIXELS:
			tile.set_pixel(x, y, Color(0.0, 0.0, 0.0, smoothstep(low, high, source.get_pixel(x, y).r)))
	var mask: Image = Image.create(PIXELS * TILES, PIXELS * TILES, false, Image.FORMAT_RGBA8)
	for ty: int in TILES:
		for tx: int in TILES:
			mask.blit_rect(tile, Rect2i(0, 0, PIXELS, PIXELS), Vector2i(tx * PIXELS, ty * PIXELS))
	mask.generate_mipmaps()
	return ImageTexture.create_from_image(mask)

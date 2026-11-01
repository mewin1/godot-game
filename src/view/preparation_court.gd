class_name PreparationCourt
extends TextureRect
## Общий пейзаж подготовки. Стены и ввод привязаны к одному прямоугольнику двора.

const PAINTING: Texture2D = preload("res://assets/dusk/preparation.png")
const WALL_FIT: Shader = preload("res://assets/shaders/preparation.gdshader")

var _wall_material: ShaderMaterial = ShaderMaterial.new()
var _floor_rect: Rect2
var _time: float = 0.0


func _init() -> void:
	texture = PAINTING
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_wall_material.shader = WALL_FIT
	material = _wall_material


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	_wall_material.set_shader_parameter("clock", _time)


## Возвращает прямоугольник пола в координатах экрана и совмещает с ним стены.
func floor_for(board: BoardLayout) -> Rect2:
	var units: Vector2 = Vector2(board.width, board.height * CourtyardPainter.GRID_ASPECT)
	var cell: float = minf(size.x * 0.514 / units.x, size.y * 0.674 / units.y)
	var extent: Vector2 = units * cell
	var floor_rect: Rect2 = Rect2(size * Vector2(0.655, 0.493) - extent * 0.5, extent)
	if floor_rect != _floor_rect and size.x > 0 and size.y > 0:
		_floor_rect = floor_rect
		var a: Vector2 = floor_rect.position / size
		var b: Vector2 = floor_rect.end / size
		_wall_material.set_shader_parameter("court", Vector4(a.x, a.y, b.x, b.y))
	return Rect2(global_position + floor_rect.position, extent)

class_name MobVisual
extends Resource
## Как выглядит вид моба. Связан с MobData по id.

@export var mob_id: StringName = &""
@export var texture: Texture2D
## Размер картинки в клетках.
@export var size_cells: float = 0.6
## Высота подпрыгивания при ходьбе — в долях размера картинки.
@export var bob_height: float = 0.08
## Шагов в секунду.
@export var bob_speed: float = 4.0
## Цвет «пыха» при смерти.
@export var death_color: Color = Color(0.6, 0.6, 0.6)

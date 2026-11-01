class_name TowerVisual
extends Resource
## Как выглядит вид башни: картинка, цвета плит под фигурой и снаряд.
## Связан с TowerData по id — данные симуляции о графике ничего не знают.

enum Projectile { FIREBALL, SHARD, BOLT, LIGHTNING, CURSE }

@export var tower_id: StringName = &""
@export var icon: Texture2D
## Размер картинки в клетках.
@export var icon_scale: float = 1.1
## Источник живых угольков в нормализованных координатах рисунка.
@export var has_embers: bool = false
@export var ember_source: Vector2 = Vector2(0.5, 0.4)
@export var plate_color: Color = Color(0.3, 0.25, 0.2)
@export var plate_edge_color: Color = Color(0.7, 0.55, 0.35)
@export var projectile: Projectile = Projectile.BOLT
@export var projectile_color: Color = Color.WHITE
## Время полёта снаряда (в симуляции попадание мгновенное — это только картинка).
@export var projectile_seconds: float = 0.15
@export var impact_color: Color = Color.WHITE

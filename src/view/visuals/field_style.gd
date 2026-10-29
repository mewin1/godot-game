class_name FieldStyle
extends Resource
## Как выглядит поле: трава, дорога, декор, вход и терем героя.

@export var grass_textures: Array[Texture2D] = []
## Декор на клетках, где строить нельзя (деревья, камни…).
@export var decor_textures: Array[Texture2D] = []
## Сколько процентов таких клеток получают декор.
@export var decor_percent: int = 45
@export var hero_texture: Texture2D
@export var spawn_texture: Texture2D
@export var heart_icon: Texture2D
@export var star_icon: Texture2D
@export var background_color: Color = Color(0.08, 0.063, 0.05)
@export var frame_color: Color = Color(0.16, 0.12, 0.09)
## Затемнение клеток, где строить нельзя.
@export var blocked_shade: Color = Color(0.03, 0.02, 0.04, 0.42)
@export var buildable_tint: Color = Color(0.94, 0.86, 0.66, 0.1)
@export var grid_color: Color = Color(0.94, 0.86, 0.66, 0.16)
@export var road_color: Color = Color(0.55, 0.44, 0.31)
@export var road_edge_color: Color = Color(0.3, 0.23, 0.16)
@export var road_light_color: Color = Color(0.66, 0.54, 0.38)
@export var future_road_color: Color = Color(0.55, 0.44, 0.31, 0.22)
## Ширина дороги в клетках.
@export var road_width: float = 0.62
@export var selected_color: Color = Color(0.91, 0.65, 0.29)
@export var valid_color: Color = Color(0.55, 0.85, 0.45, 0.45)
@export var invalid_color: Color = Color(0.85, 0.3, 0.25, 0.45)
@export var slow_tint: Color = Color(0.6, 0.85, 1.0)
@export var breach_color: Color = Color(0.8, 0.15, 0.1)
@export var gold_text_color: Color = Color(0.95, 0.8, 0.4)
## Ярость (время волны вышло): мобы краснеют.
@export var enrage_tint: Color = Color(1.0, 0.55, 0.45)
## Цвета игроков по номеру: кольцо под юнитами армии и имя в фишке. Первый — вы.
@export var player_colors: Array[Color] = [Color(0.91, 0.65, 0.29), Color(0.82, 0.36, 0.3),
		Color(0.5, 0.72, 0.88), Color(0.56, 0.76, 0.42), Color(0.72, 0.56, 0.86)]


## Цвет игрока по номеру (если игроков больше, чем цветов, — по кругу).
func get_player_color(player_index: int) -> Color:
	return player_colors[player_index % player_colors.size()]

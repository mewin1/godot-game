class_name PlantedSprite
extends RefCounted
## Растровая фигура с контактной тенью в координатах двора.


## Одна опора для основания, контактной и падающей тени. Свет приходит слева сверху.
static func draw(canvas: CanvasItem, icon: Texture2D, foot: Vector2,
		dimensions: Vector2, hue: Color, base_center: float = 0.89) -> void:
	# Anchor the centre of the ground-facing plinth, not its lowest painted pixel.
	var base: Rect2 = Rect2(-dimensions * Vector2(0.5, base_center), dimensions)
	var light: Texture2D = preload("res://data/visuals/soft_light.tres")
	var glow: Vector2 = Vector2(dimensions.x * 1.1, dimensions.y * 0.62)
	canvas.draw_texture_rect(light, Rect2(foot - glow * 0.5, glow), false, Color(hue, 0.25))
	canvas.draw_set_transform_matrix(Transform2D(Vector2(0.97, 0), Vector2(-0.35, -0.25), foot))
	canvas.draw_texture_rect(icon, base, false, Color(0.04, 0.055, 0.08, 0.34))
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	var contact: Vector2 = Vector2(dimensions.x * 0.94, dimensions.y * 0.31)
	canvas.draw_texture_rect(light, Rect2(foot - contact * Vector2(0.48, 0.58), contact),
			false, Color(0.02, 0.035, 0.05, 0.88))
	canvas.draw_texture_rect(icon, Rect2(foot + base.position, dimensions), false,
			Color("e4e9ee"))

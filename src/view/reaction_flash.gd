class_name ReactionFlash
extends RefCounted
## Короткий акцент в точке реакции. Положение в единицах поля переживает смену размера окна.

const LIFETIME: float = 0.54
const GLOW: Texture2D = preload("res://data/visuals/soft_light.tres")

var position_milli: Vector2i
var age: float = 0.0
var element: StringName
var color: Color


func _init(rule: ReactionData, point: Vector2i) -> void:
	position_milli = point
	element = rule.incoming
	if rule.id == &"shatter":
		element = &"ice"
	match element:
		&"ice":
			color = GodSymbols.get_color(&"ice")
		&"lightning":
			color = GodSymbols.get_color(&"perun")
		&"wind":
			color = GodSymbols.get_color(&"stribog")
		&"curse":
			color = GodSymbols.get_color(&"curse")
		&"fire":
			color = Color("efcfac") if rule.id == &"steam" else GodSymbols.get_color(&"svarog")
		_:
			color = GodSymbols.get_color(&"war")


## Пар поднимается, осколки разлетаются, электрические ветви гаснут быстрее следа.
func draw(canvas: CanvasItem, foot: Vector2, cell: float) -> void:
	var t: float = clampf(age / LIFETIME, 0.0, 1.0)
	var fade: float = (1.0 - t) * smoothstep(0.0, 0.065, t)
	var extent: Vector2 = Vector2(1.40, 0.62) * cell * (0.65 + t)
	canvas.draw_texture_rect(GLOW, Rect2(foot - extent * 0.5, extent), false,
			Color(color, fade * 0.72))
	var center: Vector2 = foot - Vector2(0, cell * 0.34)
	var ink: Color = Color(color, fade)
	for i: int in 5:
		var angle: float = TAU * i / 5.0 + 0.4
		var dir: Vector2 = Vector2.from_angle(angle) * Vector2(1.0, 0.74)
		var at: Vector2 = center + dir * cell * (0.12 + 0.54 * ease(t, 0.5))
		match element:
			&"fire":
				var plume: Vector2 = Vector2.ONE * cell * (0.30 + 0.55 * t)
				at.y -= cell * t * 0.50
				canvas.draw_texture_rect(GLOW, Rect2(at - plume * 0.5, plume),
						false, Color(color, fade * 0.85))
			&"ice", &"physical":
				var side: Vector2 = dir.orthogonal() * cell * 0.06 * (1.0 - t)
				canvas.draw_colored_polygon(PackedVector2Array([at + dir * cell * 0.22,
						at + side, at - dir * cell * 0.10, at - side]), ink)
				canvas.draw_line(at, at + dir * cell * 0.22, Color(1, 1, 1, fade), 1, true)
			&"lightning":
				var kink: Vector2 = dir.orthogonal() * cell * 0.13
				var bolt: PackedVector2Array = [center, center.lerp(at, 0.4) + kink,
						center.lerp(at, 0.64) - kink * 0.4, at]
				canvas.draw_polyline(bolt, ink, 3.0, true)
				canvas.draw_polyline(bolt, Color(1, 1, 0.9, fade), 1.0, true)
			_:
				var radius: float = cell * (0.20 + 0.44 * t)
				canvas.draw_set_transform(center, 0, Vector2(1.0, 0.55))
				canvas.draw_arc(Vector2.ZERO, radius, angle + t, angle + t + 0.82,
						12, ink, 2.5, true)
				canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

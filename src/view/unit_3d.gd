class_name Unit3D
extends Node3D
## Простой объёмный силуэт бойца; вид различается цветом, размером и движением.

@onready var _body: MeshInstance3D = $Body
@onready var _head: MeshInstance3D = $Head
@onready var _legs: MeshInstance3D = $Legs


## Цвет игрока либо нейтральной волны и относительный размер модели.
func setup(color: Color, size_factor: float) -> void:
	_body.material_override = _material(color)
	_head.material_override = _material(Color(0.79, 0.69, 0.58))
	_legs.material_override = _material(color.darkened(0.42))
	scale = Vector3.ONE * size_factor


func _material(color: Color) -> StandardMaterial3D:
	var result: StandardMaterial3D = StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.82
	return result

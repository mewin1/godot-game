class_name ArenaTile3D
extends Node3D
## Одна редактируемая плита игрового поля; цвет обозначает состояние клетки.

@onready var _slab: MeshInstance3D = $Slab
@onready var _inset: MeshInstance3D = $Inset


## Задаёт материал клетки без изменения правил размещения.
func setup(color: Color, inset_color: Color) -> void:
	_slab.material_override = _material(color.darkened(0.22))
	_inset.material_override = _material(inset_color)


func _material(color: Color) -> StandardMaterial3D:
	var result: StandardMaterial3D = StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.88
	return result

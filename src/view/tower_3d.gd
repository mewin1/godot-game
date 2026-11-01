class_name Tower3D
extends Node3D
## Базовая модель башни. Цвет задаёт стихия; геометрию можно править в сцене.

@onready var _base: MeshInstance3D = $Base
@onready var _body: MeshInstance3D = $Body
@onready var _crown: MeshInstance3D = $Crown
@onready var _gem: MeshInstance3D = $Gem
@onready var _glow: OmniLight3D = $Glow


## Настраивает цвет и визуальную высоту без влияния на боевые параметры.
func setup(color: Color, level: int) -> void:
	_base.material_override = _material(Color(0.34, 0.38, 0.46))
	_body.material_override = _material(color.darkened(0.3))
	_crown.material_override = _material(color)
	var gem_material: StandardMaterial3D = _material(color.lightened(0.2))
	gem_material.emission_enabled = true
	gem_material.emission = color
	gem_material.emission_energy_multiplier = 1.6
	_gem.material_override = gem_material
	_body.scale.y = 1.0 + 0.15 * (level - 1)
	_crown.position.y = 1.06 + 0.1 * (level - 1)
	_gem.position.y = _crown.position.y + 0.21
	_glow.position.y = _gem.position.y
	_glow.light_color = color


## Короткая отдача после выстрела.
func pulse() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector3(1.08, 1.12, 1.08), 0.08)
	tween.tween_property(self, "scale", Vector3.ONE, 0.18)


func _material(color: Color) -> StandardMaterial3D:
	var result: StandardMaterial3D = StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.65
	return result

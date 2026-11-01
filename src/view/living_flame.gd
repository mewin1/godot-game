class_name LivingFlame
extends SubViewport
## Одна маленькая живая текстура огня на поле, общая для всех жаровен.

var _flame_material: ShaderMaterial = ShaderMaterial.new()


func _init() -> void:
	size = Vector2i(96, 128)
	transparent_bg = true
	disable_3d = true
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var flame: ColorRect = ColorRect.new()
	flame.size = Vector2(size)
	_flame_material.shader = preload("res://assets/shaders/living_flame.gdshader")
	flame.material = _flame_material
	add_child(flame)


## Время берётся от боевого слоя, поэтому огонь подчиняется его паузе и скорости.
func set_time(seconds: float) -> void:
	_flame_material.set_shader_parameter("clock", seconds)

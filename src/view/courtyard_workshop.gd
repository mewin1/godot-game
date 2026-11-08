extends RefCounted
## Ночные материалы построек. Одна карта раскраски для древесины, камня и металла.
const ATLAS: Texture2D = preload("res://assets/noir/courtyard/towers/workshop_atlas.png")
const MAGIC: Shader = preload("res://assets/shaders/noir_workshop_magic.gdshader")
const ELEMENT_EFFECT: Dictionary[String, int] = {"ember": 1, "fireheart": 1, "water": 2, "spark": 3, "wind": 4, "ice": 5, "icecore": 5, "violet": 6}


static func paint(root: Node3D, tower_id: StringName) -> void:
	var parts: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		parts.append(root)
	for node: Node in parts:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for i: int in mesh.get_surface_count():
			var mat: StandardMaterial3D = mesh.surface_get_material(i) as StandardMaterial3D
			if mat == null or mat.has_meta(&"workshop") or not mat.resource_name.begins_with("Zastava_"):
				continue
			var pigment: String = mat.resource_name.trim_prefix("Zastava_")
			if mat.emission_enabled:
				var effect: ShaderMaterial = ShaderMaterial.new()
				effect.shader = MAGIC
				effect.set_shader_parameter("spark_color", mat.emission)
				effect.set_shader_parameter("power", mat.emission_energy_multiplier)
				effect.set_shader_parameter("kind", ELEMENT_EFFECT.get(pigment, 0))
				if tower_id == &"brazier" or tower_id == &"cinder":
					effect.set_shader_parameter("plume_floor", 1.04 if tower_id == &"brazier" else 2.05)
				mesh.surface_set_material(i, effect)
			else:
				mat.albedo_texture = ATLAS
				mat.vertex_color_use_as_albedo = true
				mat.vertex_color_is_srgb = false
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				mat.set_meta(&"workshop", true)

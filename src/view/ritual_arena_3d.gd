extends NoirArena3D
## Рисованный лес и двор PvP, кадрированные для поля «Обряда».

const FOREST_SHADER: Shader = preload("res://assets/shaders/ritual_forest.gdshader")

func _open_cells(field: FieldState, path: Array[Vector2i]) -> Dictionary[Vector2i, bool]:
	var cells: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in field.get_buildable_cells() + path:
		cells[cell] = true
	return cells


func _build_forest() -> void:
	var sets: Dictionary[String, Array] = {}
	# Три яруса за стеной: крупные силуэты, берёзы и более низкая опушка.
	for row: int in 4:
		for column: int in 18:
			var at: Vector2 = Vector2(-22 + column * 5.4 + _rng.randf_range(-2, 2), -29 - row * 8.0 + _rng.randf_range(-2, 2))
			var birch: bool = _rng.randf() < 0.23
			var ids: Array[String] = BIRCH_IDS if birch else PINE_IDS
			_collect(sets, ids[_rng.randi() % ids.size()], at, _rng.randf_range(18, 28), 0)
	for side: int in [-1, 1]:
		for index: int in 11:
			var at: Vector2 = Vector2(-11 if side < 0 else 56, -27 + index * 4.8)
			at += Vector2(_rng.randf_range(-3, 3), _rng.randf_range(-2, 2))
			_collect(sets, PINE_IDS[_rng.randi() % PINE_IDS.size()], at, _rng.randf_range(15, 24), 0)
	# Низкие ели и папоротник обрамляют ближние углы, не закрывая место постройки.
	for index: int in 28:
		var at: Vector2 = Vector2(_rng.randf_range(-6, 48), _rng.randf_range(15, 22))
		var ids: Array[String] = FERN_IDS if index % 3 else SAPLING_IDS
		_collect(sets, ids[_rng.randi() % ids.size()], at, _rng.randf_range(1.4, 3.0), 0)
	_build_collected(sets, self)


func _collect(into: Dictionary[String, Array], id: String, at: Vector2, scale_by: float, yaw: float = -1.0) -> void:
	if at.x > -3 and at.x < 45 and at.y > -24 and at.y < 12:
		return
	super._collect(into, id, at, scale_by, yaw)


func _billboards(id: String, transforms: Array[Transform3D], parent: Node3D) -> void:
	if transforms.is_empty():
		return
	var texture: Texture2D = load(BILLBOARDS % id) as Texture2D
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(float(texture.get_width()) / texture.get_height(), 1)
	quad.center_offset = Vector3(0, 0.5, 0)
	var ink: ShaderMaterial = ShaderMaterial.new()
	ink.shader = FOREST_SHADER
	ink.set_shader_parameter("artwork", texture)
	quad.material = ink
	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = quad
	multi.instance_count = transforms.size()
	for index: int in transforms.size():
		multi.set_instance_transform(index, transforms[index])
	var holder: MultiMeshInstance3D = MultiMeshInstance3D.new()
	holder.multimesh = multi
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(holder)


func _build_ground_mist() -> void:
	super._build_ground_mist()
	var mist: MeshInstance3D = get_node("GroundMist") as MeshInstance3D
	var material: ShaderMaterial = mist.mesh.surface_get_material(0) as ShaderMaterial
	material.set_shader_parameter("yard_rect", Vector4(-2, -23, 44, 12))
	material.set_shader_parameter("density", 0.16)
	material.set_shader_parameter("layer_top", 4.5)
	material.set_shader_parameter("tint", Color("759c9c"))


func _build_fires(_fine: Dictionary[Vector2i, bool], _terem: Vector2) -> void:
	for point: Vector2 in [Vector2(1, -13), Vector2(35, -13), Vector2(1, 4), Vector2(32, 6)]:
		var at: Vector3 = Vector3(point.x, 0, point.y)
		var bowl: Node3D = _place("fire_bowl", at, 0, 1.6)
		_add_flame(bowl, 1.25)
		_warm_light(at + Vector3(0, 1.2, 0), 3.2, 7.0)


func _build_paving(fine: Dictionary[Vector2i, bool]) -> Material:
	var paving: Material = super._build_paving(fine)
	for child: Node in _yard.get_children():
		if child is MeshInstance3D:
			var mesh: MeshInstance3D = child as MeshInstance3D
			var material: ShaderMaterial = mesh.material_override as ShaderMaterial
			if material != null and material.shader == PAVING_SHADER:
				material.set_shader_parameter("custom_palette", true)
				material.set_shader_parameter("grout_color", Color("343c3b"))
				material.set_shader_parameter("stone_dark", Color("222a2b"))
				material.set_shader_parameter("stone_light", Color("3a4140"))
	return paving

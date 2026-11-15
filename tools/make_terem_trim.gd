extends SceneTree
## Терем без тёмной плиты-основания (critique_3 п. 17, ответ автора: только Godot, без Blender).
## Плита 6,5x6,4 м — часть единой поверхности модели assets/noir/courtyard/terem.glb, сменить ей
## материал нельзя. Скрипт убирает треугольники ниже PLINTH_Y вне подклета (сруб и крыльцо остаются),
## и сохраняет сетку в assets/noir/courtyard/terem_trim.res. Материал игра берёт у исходной модели.
##
## godot --headless --path . -s res://tools/make_terem_trim.gd

const SOURCE: String = "res://assets/noir/courtyard/terem.glb"
const TARGET: String = "res://assets/noir/courtyard/terem_trim.res"
## Ниже этой высоты (в единицах модели, до масштаба 1,9) — плита и щебень на ней.
const PLINTH_Y: float = 0.45
## Подклет: прямоугольник под срубом (единицы модели) — ~3,5x3,5 м в мире.
const KEEP: Rect2 = Rect2(-0.84, -0.92, 1.84, 1.84)
## Крыльцо к дороге (+z модели): ступени выше PLINTH_Y остаются и так, низ крыльца — часть плиты.
const PORCH: Rect2 = Rect2()


func _initialize() -> void:
	var scene: Node3D = (load(SOURCE) as PackedScene).instantiate() as Node3D
	var part: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var source: Mesh = part.mesh
	var trimmed: ArrayMesh = ArrayMesh.new()
	for surface: int in source.get_surface_count():
		var arrays: Array = source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			indices.resize(vertices.size())
			for index: int in vertices.size():
				indices[index] = index
		var kept: PackedInt32Array = PackedInt32Array()
		for triangle: int in range(0, indices.size(), 3):
			var low: bool = true
			var inside: bool = false
			for corner: int in 3:
				var v: Vector3 = vertices[indices[triangle + corner]]
				low = low and v.y < PLINTH_Y
				var flat: Vector2 = Vector2(v.x, v.z)
				inside = inside or KEEP.has_point(flat) or PORCH.has_point(flat)
			if low and not inside:
				continue
			kept.append_array(indices.slice(triangle, triangle + 3))
		print("surface ", surface, ": triangles ", indices.size() / 3, " -> ", kept.size() / 3)
		trimmed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _compact(arrays, kept))
	var error: Error = ResourceSaver.save(trimmed, TARGET, ResourceSaver.FLAG_COMPRESS)
	print("saved ", TARGET, " error ", error)
	scene.free()
	quit()


## Только вершины, на которые ссылаются оставшиеся треугольники: границы сетки — без плиты.
static func _compact(arrays: Array, kept: PackedInt32Array) -> Array:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var count: int = vertices.size()
	var remap: PackedInt32Array = PackedInt32Array()
	remap.resize(count)
	remap.fill(-1)
	var order: PackedInt32Array = PackedInt32Array()
	for index: int in kept:
		if remap[index] < 0:
			remap[index] = order.size()
			order.append(index)
	var result: Array = []
	result.resize(Mesh.ARRAY_MAX)
	for slot: int in Mesh.ARRAY_MAX:
		var data: Variant = arrays[slot]
		if data == null or slot == Mesh.ARRAY_INDEX:
			continue
		result[slot] = _pick(data, count, order)
	var indices: PackedInt32Array = PackedInt32Array()
	indices.resize(kept.size())
	for at: int in kept.size():
		indices[at] = remap[kept[at]]
	result[Mesh.ARRAY_INDEX] = indices
	print("vertices ", count, " -> ", order.size())
	return result


static func _pick(data: Variant, count: int, order: PackedInt32Array) -> Variant:
	if data is PackedVector3Array:
		var source: PackedVector3Array = data
		var out: PackedVector3Array = PackedVector3Array()
		for index: int in order:
			out.append(source[index])
		return out
	if data is PackedVector2Array:
		var source2: PackedVector2Array = data
		var out2: PackedVector2Array = PackedVector2Array()
		for index: int in order:
			out2.append(source2[index])
		return out2
	if data is PackedColorArray:
		var colors: PackedColorArray = data
		var out_colors: PackedColorArray = PackedColorArray()
		for index: int in order:
			out_colors.append(colors[index])
		return out_colors
	if data is PackedFloat32Array:
		var floats: PackedFloat32Array = data
		var width: int = floats.size() / count
		var out_floats: PackedFloat32Array = PackedFloat32Array()
		for index: int in order:
			for k: int in width:
				out_floats.append(floats[index * width + k])
		return out_floats
	if data is PackedInt32Array:
		var ints: PackedInt32Array = data
		var width_i: int = ints.size() / count
		var out_ints: PackedInt32Array = PackedInt32Array()
		for index: int in order:
			for k: int in width_i:
				out_ints.append(ints[index * width_i + k])
		return out_ints
	if data is PackedByteArray:
		var bytes: PackedByteArray = data
		var width_b: int = bytes.size() / count
		var out_bytes: PackedByteArray = PackedByteArray()
		for index: int in order:
			for k: int in width_b:
				out_bytes.append(bytes[index * width_b + k])
		return out_bytes
	return data

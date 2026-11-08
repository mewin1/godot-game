extends RefCounted
## Верх подклета следует строительным клеткам. Край с арками огибает настоящую колею,
## включая плавные повороты, которые срезают угол клетки.

var footprints: Dictionary[Vector2i, Array] = {}
var arches: Array[Transform3D] = []
var walls: Array[Transform3D] = []


func roofs(field: FieldState, layout: ArenaLayout3D, lane: PackedVector2Array) -> Mesh:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_color(Color.BLACK)
	surface.set_normal(Vector3.UP)
	var half_size: float = layout.cell_m * 0.5
	for cell: Vector2i in field.get_buildable_cells():
		var at: Vector3 = layout.cell_center(cell)
		var mid: Vector2 = Vector2(at.x, at.z)
		var square: PackedVector2Array = PackedVector2Array()
		for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			square.append(mid + corner * half_size)
		var sections: Array[PackedVector2Array] = Geometry2D.clip_polygons(square, lane)
		footprints[cell] = sections
		for polygon: PackedVector2Array in sections:
			if Geometry2D.is_polygon_clockwise(polygon):
				polygon.reverse()
			for index: int in Geometry2D.triangulate_polygon(polygon):
				var point: Vector2 = polygon[index]
				surface.add_vertex(Vector3(point.x, at.y, point.y))
			for i: int in polygon.size():
				var a: Vector2 = polygon[i]
				var b: Vector2 = polygon[(i + 1) % polygon.size()]
				if a.distance_squared_to(b) < 0.0001:
					continue
				var normal: Vector2 = Vector2(b.y - a.y, a.x - b.x).normalized()
				var outside: Vector2 = (a + b) * 0.5 + normal * 0.012
				var neighbor: Vector2i = cell + Vector2i(((outside - mid) / layout.cell_m).round())
				if neighbor != cell and field.is_buildable(neighbor):
					continue
				_add_face(a, b, normal, cell)
	return surface.commit()


func _add_face(a: Vector2, b: Vector2, normal: Vector2, cell: Vector2i) -> void:
	var length: float = a.distance_to(b)
	var mid: Vector2 = (a + b) * 0.5
	var axes: Basis = Basis(Vector3.UP, atan2(normal.x, normal.y))
	axes.x *= length * 0.5
	var pose: Transform3D = Transform3D(axes, Vector3(mid.x, 0, mid.y))
	if length >= 1.3 and posmod(cell.x + cell.y, 3) != 0:
		arches.append(pose)
	else:
		walls.append(pose)

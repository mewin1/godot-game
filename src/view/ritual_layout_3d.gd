class_name RitualLayout3D
extends ArenaLayout3D
## Собственная геометрия опыта; общий кэш PvP не затрагивается.

func _init(board: BoardLayout) -> void:
	_path_cells = board.path_cells
	for cell: Vector2i in board.path_cells:
		var point: Vector3 = Vector3((cell.x + 0.5) * cell_m, 0.08, (cell.y + 0.5) * cell_m - 20.0)
		_road_points.append(point)
		var length: float = 0.0 if _road_lengths.is_empty() else _road_lengths[-1] + point.distance_to(_road_points[-2])
		_road_lengths.append(length)
		_path_lengths.append(length)

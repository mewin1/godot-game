class_name SiegeTowerSwap
extends RefCounted
## Обмен двух фигур без перестановки порядка стрельбы и без потери их состояния.


static func can_swap(field: FieldState, first: TowerState, second: TowerState) -> bool:
	if first == null or second == null or first == second:
		return false
	var first_cells: Array[Vector2i] = TowerState.shape_cells_at(first.data.shape, second.anchor, first.rotation)
	var second_cells: Array[Vector2i] = TowerState.shape_cells_at(second.data.shape, first.anchor, second.rotation)
	for cell: Vector2i in first_cells:
		if second_cells.has(cell):
			return false
	for cell: Vector2i in first_cells + second_cells:
		if not field.is_buildable(cell):
			return false
		var occupant: TowerState = field.get_tower_at(cell)
		if occupant != null and occupant != first and occupant != second:
			return false
	return true


static func apply(field: FieldState, first: TowerState, second: TowerState) -> void:
	assert(can_swap(field, first, second))
	var order: Array[TowerState] = field.towers.duplicate()
	var origin: Vector2i = first.anchor
	field.remove_tower(first)
	field.remove_tower(second)
	first.anchor = second.anchor
	second.anchor = origin
	field.attach_tower(first)
	field.attach_tower(second)
	field.towers.assign(order)
	field.mark_towers_changed()

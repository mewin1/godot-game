class_name SiegeReservePlan
extends Resource
## Порядок бойцов одного подкрепления; индексы в SiegeTrialConfig.reserves.

@export var display_name: String = ""
@export_multiline var description: String = ""
@export var order: PackedInt32Array = []
## Первые бойцы идут перед основным отрядом, остальные ждут единственного приказа.
@export var opening_count: int = 0


func held_count() -> int:
	return order.size() - opening_count

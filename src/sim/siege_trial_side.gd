class_name SiegeTrialSide
extends RefCounted
## Состояние одного участника опытной дуэли.

var field: FieldState
var hero: StringName
var hp: int
var reserve_kind: int = 0
var released: bool = false
var released_tick: int = -1
var released_automatically: bool = false
var skill_used: bool = false
var skill_tick: int = -1
var destination: Vector2i
var walk_origin: Vector2i
var walk_tower_id: int = 0
var swap_tower_id: int = 0
var swap_left: int = 0
var walk_left: int = 0
var target: Vector2i
var warning_left: int = 0
var fire_left: int = 0
var breached_count: int = 0
var attack: SiegeAttackLedger = SiegeAttackLedger.new()


func add_to_hash(hasher: StateHasher) -> void:
	hasher.add_string(hero)
	hasher.add_many([hp, reserve_kind, int(released), released_tick, int(released_automatically), int(skill_used),
			skill_tick, destination.x, destination.y, walk_origin.x, walk_origin.y, walk_tower_id,
			walk_left, swap_tower_id, swap_left, target.x, target.y, warning_left, fire_left, breached_count])
	field.add_to_hash(hasher)
	attack.add_to_hash(hasher)


func walking_tower() -> TowerState:
	return field.get_tower(walk_tower_id)


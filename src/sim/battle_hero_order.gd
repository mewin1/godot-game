class_name BattleHeroOrder
extends RefCounted
## План и исполнение одного приёма. Индекс -1 принадлежит независимому призраку.

var owner: int
var skill: BattleSkillData
var target: int
var cell: Vector2i = Vector2i(-1, -1)
var tower_id: int = 0
var second_id: int = 0
var used_tick: int = -1
var warning_left: int = 0
var active_left: int = 0
var resolved: bool = false
var origin: Vector2i
var caught: Array[int] = []


func _init(player: int, data: BattleSkillData) -> void:
	owner = player
	target = player
	skill = data


func add_to_hash(hasher: StateHasher) -> void:
	hasher.add_many([owner, target, cell.x, cell.y, tower_id, second_id, used_tick,
			warning_left, active_left, int(resolved), origin.x, origin.y])
	hasher.add_string(skill.hero_id if skill != null else &"")
	hasher.add(caught.size())
	hasher.add_many(caught)
